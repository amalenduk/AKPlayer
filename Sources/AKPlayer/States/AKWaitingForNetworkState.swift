//
//   AKWaitingForNetworkState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKWaitingForNetworkReason

/// Represents the specific reason why the player transitioned into the waiting-for-network state.
public enum AKWaitingForNetworkReason: Sendable, Hashable, Equatable {
    /// Indicates that the network path became unsatisfied or disconnected.
    case disconnected
    /// Indicates that buffering timed out while the network remained satisfied (e.g., low throughput).
    case bufferTimeout
}

// MARK: - AKWaitingForNetworkState

/// Concrete state representing a period where playback is paused while waiting
/// for network connectivity to restore.
@MainActor
public class AKWaitingForNetworkState: AKBaseState {
    // MARK: - Properties
    
    /// Optional target playback speed multiplier to apply once network connection recovers.
    private var rate: AKPlaybackRate?
    
    /// Indicates whether playback should resume automatically when network connectivity is re-established.
    public private(set) var autoPlay = false
    
    /// The player state to transition into after buffering resolves following network restoration.
    private var stateToNavigateAfterBuffering: AKPlayerState?
    
    /// Optional pending seek command to preserve across network waiting state.
    private var targetSeek: AKSeek?
    
    /// The underlying reason that triggered the transition to waiting for network.
    private let reason: AKWaitingForNetworkReason
    /// The current retry attempt count for exponential backoff buffering retries.
    private let retryCount: Int
    
    /// The active task observing network connectivity updates.
    private var networkObservationTask: Task<Void, Never>?
    /// The active task running the backoff delay before retrying buffering.
    private var retryTask: Task<Void, Never>?
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a waiting-for-network state instance.
    /// - Parameters:
    ///   - playerController: The player controller managing state transitions.
    ///   - autoPlay: Indicates whether playback should resume automatically when network connectivity is re-established.
    ///   - rate: Optional target playback speed multiplier to apply once network connection recovers.
    ///   - stateToNavigateAfterBuffering: The player state to transition into after buffering resolves.
    ///   - targetSeek: Optional pending seek command to preserve across network waiting state.
    ///   - reason: The underlying reason that triggered the transition to waiting for network.
    ///   - retryCount: The current retry attempt count for exponential backoff.
    public init(
        playerController: any AKPlayerControllerProtocol,
        autoPlay: Bool = false,
        rate: AKPlaybackRate? = nil,
        stateToNavigateAfterBuffering: AKPlayerState? = nil,
        targetSeek: AKSeek? = nil,
        reason: AKWaitingForNetworkReason,
        retryCount: Int
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.stateToNavigateAfterBuffering = stateToNavigateAfterBuffering
        self.autoPlay = autoPlay
        self.rate = rate
        self.targetSeek = targetSeek
        self.reason = reason
        self.retryCount = retryCount
        super.init(
            playerController: playerController,
            state: .waitingForNetwork
        )
    }
    
    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }
    
    // MARK: - State Lifecycle & Event Handlers
    
    /// Entry point for state setup. Ensures player is paused, starts observer pipelines, and monitors network changes.
    override public func processStateChange() {
        guard let media = playerController.currentMedia else { return stop() }
        super.processStateChange()
        
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        
        switch reason {
        case .disconnected:
            if media.isOverNetwork() {
                observeNetworkChanges()
            }
            
        case .bufferTimeout:
            scheduleBackoffRetry()
        }
    }
    
    /// Handles changes to the AVPlayer's status, transitioning to failed if an error occurs.
    /// - Parameter status: The updated player status.
    override public func handlePlayerStatusChange(_ status: AVPlayer.Status) {
        guard status == .failed else { return }
        let controller = AKFailedState(
            playerController: playerController,
            error: .playerCanNoLongerPlay(
                error: playerController.player.error
            )
        )
        change(controller)
    }
    
    /// Handles changes to the player's time control status while waiting for network.
    /// - Parameter status: The updated time control status.
    override public func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        guard isActiveState else { return }
        guard !playerController.interstitialService.isPlayingInterstitial else { return }
        switch status {
        case .playing:
            play()
        case .waitingToPlayAtSpecifiedRate:
            guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay else { return }
            switch reasonForWaitingToPlay {
            case .evaluatingBufferingRate, .toMinimizeStalls, .waitingForCoordinatedPlayback:
                retryBuffering()
            case .noItemToPlay:
                stop()
            default:
                break
            }
        case .paused:
            pause()
        default:
            break
        }
    }
    
    /// Handles player item notification events such as playback stalling or failure to play to end time.
    /// - Parameter event: The player item notification event.
    override public func handle(_ event: AKPlayerItemNotificationEvent) {
        guard isActiveState else { return }
        guard !playerController.interstitialService.isPlayingInterstitial else { return }
        switch event {
        case let .failedToPlayToEndTime(error):
            if !(error.underlyingError is URLError) {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .itemFailedToPlayToEndTime
                )
                change(controller)
            }
        case .playbackStalled:
            guard let media = playerController.currentMedia else { return }
            if media.isLocal() {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .itemFailedToPlayToEndTime
                )
                change(controller)
            } else {
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: true,
                    rate: rate
                )
                change(controller)
            }
        default:
            break
        }
    }
    
    /// Handles changes in interstitial playback state.
    /// - Parameter playbackState: The updated interstitial playback state.
    override public func handleInterstitialPlaybackStateChange(_ playbackState: AKInterstitialPlaybackState) {
        guard isActiveState else { return }
        switch playbackState {
        case .playing:
            if !autoPlay {
                play()
            }
        default:
            break
        }
    }
    
    /// Performs cleanup before transitioning away from the waiting-for-network state, cancelling active observation and retry tasks.
    override public func beforeStateChange() {
        networkObservationTask?.cancel()
        networkObservationTask = nil
        retryTask?.cancel()
        retryTask = nil
    }
    
    // MARK: - Commands
    
    // MARK: - Controlling Playback
    
    /// Requests to resume playback once network connectivity is restored by enabling autoplay.
    override public func play() {
        if autoPlay {
            playerController
                .emit(.commandUnavailable(reason: .alreadyTryingToPlay))
        } else {
            performIfAllowed(
                check: { availability(for: .play()) },
                action: {
                    autoPlay = true
                },
                blocked: { [weak self] reason in
                    guard let self else { return }
                    playerController.emit(.commandUnavailable(reason: reason))
                },
                fallback: ()
            )
        }
    }
    
    /// Requests to resume playback at the specified rate once network connectivity is restored.
    /// - Parameter rate: The target playback rate.
    override public func play(at rate: AKPlaybackRate) {
        performIfAllowed(
            check: { availability(for: .play(at: rate)) },
            action: {
                self.rate = rate
                autoPlay = true
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    // MARK: - Seeking Through Media
    
    /// Saves the pending seek target to be executed once network connectivity is restored.
    /// - Parameters:
    ///   - target: The target seek position.
    ///   - scope: The seek scope.
    ///   - completionHandler: The completion handler called with `false` if cancelled or replaced.
    override public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek?.complete(with: false)
        targetSeek = AKSeek(
            target: target,
            scope: scope,
            completionHandler: completionHandler
        )
    }
    
    /// Saves the pending seek target and tolerances to be executed once network connectivity is restored.
    /// - Parameters:
    ///   - target: The target seek position.
    ///   - scope: The seek scope.
    ///   - toleranceBefore: Tolerance before the target timestamp.
    ///   - toleranceAfter: Tolerance after the target timestamp.
    ///   - completionHandler: The completion handler called with `false` if cancelled or replaced.
    override public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek?.complete(with: false)
        targetSeek = AKSeek(
            target: target,
            scope: scope,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }
    
    // MARK: - Availability Overrides
    
    /// Evaluates the command availability for a given player action while waiting for network.
    /// - Parameter action: The requested player action.
    /// - Returns: A tuple containing whether the action is allowed and an optional unavailable reason.
    override public func availability(for action: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        switch action {
        case .step:
            (false, .waitingForEstablishedNetwork)
        default:
            super.availability(for: action)
        }
    }
    
    // MARK: - Private Helper Functions
    
    /// Starts observing network status changes to detect when network path becomes satisfied.
    private func observeNetworkChanges() {
        networkObservationTask?.cancel()
        networkObservationTask = observeNetworkStatus { [weak self] status in
            guard let self, status == .satisfied else { return }
            let controller = AKBufferingState(
                playerController: self.playerController,
                autoPlay: self.autoPlay,
                rate: self.rate,
                stateToNavigateAfterBuffering: self.stateToNavigateAfterBuffering ?? .paused,
                targetSeek: self.targetSeek
            )
            self.change(controller)
        }
    }
    
    /// Schedules an exponential backoff task to retry buffering after a timeout.
    private func scheduleBackoffRetry() {
        let base = playerController.configuration.waitingForNetworkBaseCooldown
        let multiplier = playerController.configuration.backoffMultiplier
        let maxCooldown = playerController.configuration.maxWaitingForNetworkCooldown
        let cooldown = min(base * pow(multiplier, Double(retryCount)), maxCooldown)
        
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(cooldown * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.retryBuffering()
        }
    }
    
    /// Transitions back to the buffering state to attempt re-buffering media.
    private func retryBuffering() {
        let controller = AKBufferingState(
            playerController: playerController,
            autoPlay: autoPlay,
            rate: rate,
            stateToNavigateAfterBuffering: stateToNavigateAfterBuffering ?? .paused,
            targetSeek: targetSeek,
            retryCount: retryCount
        )
        change(controller)
    }
}
