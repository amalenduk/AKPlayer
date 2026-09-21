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

public enum AKWaitingForNetworkReason: Sendable, Hashable, Equatable {
    case disconnected   // NWPath actually went unsatisfied
    case bufferTimeout  // network stayed "satisfied" the whole time; throughput was the issue
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
    
    private let reason: AKWaitingForNetworkReason
    private let retryCount: Int
    
    private var networkObservationTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a waiting-for-network state instance.
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
    
    // MARK: - Lifecycle Hooks
    
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
    
    override public func beforeStateChange() {
        networkObservationTask?.cancel()
        networkObservationTask = nil
        retryTask?.cancel()
        retryTask = nil
    }
    
    // MARK: - Commands
    
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
    
    override public func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek?.complete(with: false)
        targetSeek = AKSeek(
            target: target,
            completionHandler: completionHandler
        )
    }
    
    override public func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek?.complete(with: false)
        targetSeek = AKSeek(
            target: target,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }
    
    // MARK: - Private Helper Functions
    
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
    
    override public func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            guard isActiveState else { return }
            play()
        case .waitingToPlayAtSpecifiedRate:
            guard isActiveState else { return }
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
            guard isActiveState else { return }
            pause()
        default:
            break
        }
    }
    
    override public func handle(_ event: AKPlayerItemNotificationEvent) {
        switch event {
        case let .failedToPlayToEndTime(error):
            if !(error is URLError) {
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
    
    // MARK: - Availability Overrides
    
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
}
