//
//   AKBufferingState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKBufferingState

/// Concrete state representing active media buffering prior to starting or
/// resuming playback.
@MainActor
public class AKBufferingState: AKBaseState {
    // MARK: - Properties

    /// Optional target playback speed multiplier to apply once buffering
    /// completes.
    private var rate: AKPlaybackRate?

    /// Indicates whether playback should start automatically once buffer
    /// readiness is met.
    public private(set) var autoPlay: Bool

    /// The player state to transition into after buffering resolves if autoPlay
    /// is false.
    private var stateToNavigateAfterBuffering: AKPlayerState

    /// Optional pending seek command to process during or immediately after
    /// buffering.
    private var targetSeek: AKSeek?

    /// Consecutive retry counter for buffer stall escalation.
    private let retryCount: Int

    /// Task tracking the active buffering timeout countdown loop.
    private var timeoutTask: Task<Void, Never>?

    /// Task tracking network connectivity changes.
    private var networkObservationTask: Task<Void, Never>?

    /// Container holding native Foundation KVO observations.
    private var observations: [NSKeyValueObservation] = []

    // MARK: - Init & Deinit

    /// Initializes a buffering state instance.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving execution.
    ///   - autoPlay: Whether playback should start automatically once buffer readiness is met.
    ///   - rate: Optional target playback speed multiplier.
    ///   - stateToNavigateAfterBuffering: State to transition into after buffering resolves if
    /// autoPlay is false.
    ///   - targetSeek: Optional pending seek command to process during buffering.
    ///   - retryCount: Consecutive retry counter for buffer stall escalation.
    public init(
        playerController: (any AKPlayerControllerProtocol)?,
        autoPlay: Bool = false,
        rate: AKPlaybackRate? = nil,
        stateToNavigateAfterBuffering: AKPlayerState? = nil,
        targetSeek: AKSeek? = nil,
        retryCount: Int = 0
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.stateToNavigateAfterBuffering = stateToNavigateAfterBuffering ?? playerController?
            .state ?? .buffering
        self.autoPlay = autoPlay
        self.rate = rate
        self.targetSeek = targetSeek
        self.retryCount = retryCount
        super.init(playerController: playerController, state: .buffering)
    }

    deinit {
        timeoutTask?.cancel()
        timeoutTask = nil
        networkObservationTask?.cancel()
        networkObservationTask = nil
        observations.removeAll()
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - State Lifecycle & Event Handlers

    /// Called when the player transitions into this state, setting up
    /// observation streams, handling pauses, pending seeks, and network
    /// monitoring.
    override public func processStateChange() {
        guard let playerController, let currentMedia = playerController.currentMedia else {
            return stop()
        }
        super.processStateChange()

        if canPlay(), targetSeek == nil {
            let controller = AKPlayingState(
                playerController: playerController,
                rate: rate
            )
            return change(controller)
        }

        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }

        if let targetSeek {
            playerController.performSeek(to: targetSeek)
        }

        startObservingPlayerItemBufferingStatus()
        startProgressAwareBufferTimeoutWatcher()

        if currentMedia.isOverNetwork() {
            observeNetworkChanges()
        }
    }

    /// Responds to changes in the underlying `AVPlayer.Status` to transition into failed state if
    /// needed.
    override public func handlePlayerStatusChange(_ status: AVPlayer.Status) {
        guard isActiveState, let playerController else { return }
        guard status == .failed else { return }
        let controller = AKFailedState(
            playerController: playerController,
            error: .playerCanNoLongerPlay(
                error: playerController.player.error
            )
        )
        change(controller)
    }

    /// Responds to changes in `AVPlayer.TimeControlStatus` while waiting to play.
    override public func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        guard isActiveState, let playerController else { return }
        guard !playerController.interstitialService.isPlayingInterstitial else { return }
        switch status {
        case .waitingToPlayAtSpecifiedRate:
            guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay
            else { return }
            switch reasonForWaitingToPlay {
            case .noItemToPlay:
                stop()
            default:
                break
            }
        default:
            break
        }
    }

    /// Handles media player item notification events such as network errors and playback failures
    /// during buffering.
    override public func handle(_ event: AKPlayerItemNotificationEvent) {
        guard isActiveState, let playerController else { return }
        guard !playerController.interstitialService.isPlayingInterstitial else { return }
        switch event {
        case let .failedToPlayToEndTime(error):
            if error is URLError {
                let controller = AKWaitingForNetworkState(
                    playerController: playerController,
                    autoPlay: autoPlay,
                    rate: rate,
                    stateToNavigateAfterBuffering: stateToNavigateAfterBuffering,
                    targetSeek: targetSeek,
                    reason: .bufferTimeout,
                    retryCount: 0
                )
                change(controller)
            } else {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .playerItemFailedToPlay(
                        reason: .failedToPlayToEndTime(error: error)
                    )
                )
                change(controller)
            }
        default:
            break
        }
    }

    /// Responds to interstitial ad playback state changes while buffering.
    override public func handleInterstitialPlaybackStateChange(
        _ playbackState: AKInterstitialPlaybackState
    ) {
        guard isActiveState else { return }
        switch playbackState {
        case .playing:
            if !autoPlay {
                play()
            } else {
                evaluateBufferingReadiness()
            }
        default:
            break
        }
    }

    // MARK: - Commands

    /// Commands the player to begin media playback, updating autoplay
    /// parameters if already buffering.
    override public func play() {
        if autoPlay {
            playerController?
                .emit(.commandUnavailable(reason: .alreadyTryingToPlay))
        } else {
            autoPlay = true
            startPlayingIfPossible()
        }
    }

    /// Commands the player to begin media playback at a specified speed
    /// multiplier while buffering.
    /// - Parameter rate: The targeted playback rate.
    override public func play(at rate: AKPlaybackRate) {
        performIfAllowed(
            check: { availability(for: .play(at: rate)) },
            action: {
                self.rate = rate
                autoPlay = true
                startPlayingIfPossible()
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController?.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }

    /// Seeks to a target location and executes a callback upon completion.
    /// - Parameters:
    ///   - target: The position or time offset to seek toward.
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    ///   - completionHandler: Closure called with `true` if the seek finished or `false` if
    /// cancelled.
    override public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        performIfAllowed(
            check: { [weak self] in
                guard let self else { return (false, nil) }
                return availability(for: .seek(to: target))
            },
            action: { [weak self] in
                guard let s = self else {
                    completionHandler(false)
                    return
                }
                s.targetSeek?.complete(with: false)
                let seekToken = AKSeek(
                    target: target,
                    scope: scope,
                    completionHandler: completionHandler
                )
                s.targetSeek = seekToken
                s.performTargetSeekIfActive()
                s.restartBufferTimeoutWatcher()
            },
            blocked: { [weak self] reason in
                completionHandler(false)
                guard let self else { return }
                playerController?.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }

    /// Seeks to a target position using tolerance limits and invokes a completion closure.
    /// - Parameters:
    ///   - target: The position or time offset to seek toward.
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    ///   - toleranceBefore: Maximum allowed offset prior to target time.
    ///   - toleranceAfter: Maximum allowed offset after target time.
    ///   - completionHandler: Closure called upon seek completion with success state.
    override public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @Sendable @escaping (Bool) -> Void
    ) {
        performIfAllowed(
            check: { [weak self] in
                guard let self else { return (false, nil) }
                return availability(for: .seek(to: target))
            },
            action: { [weak self] in
                guard let s = self else {
                    completionHandler(false)
                    return
                }
                s.targetSeek?.complete(with: false)
                let seekToken = AKSeek(
                    target: target,
                    scope: scope,
                    toleranceBefore: toleranceBefore,
                    toleranceAfter: toleranceAfter,
                    completionHandler: completionHandler
                )
                s.targetSeek = seekToken
                s.performTargetSeekIfActive()
                s.restartBufferTimeoutWatcher()
            },
            blocked: { [weak self] reason in
                completionHandler(false)
                guard let s = self else { return }
                s.playerController?.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }

    /// Observes the current `AVPlayerItem` buffer state flags to transition out
    /// of buffering as soon as possible.
    private func startObservingPlayerItemBufferingStatus() {
        guard let playerItem = activePlayerItem else { return }

        observations.append(
            playerItem.observe(\.isPlaybackBufferFull, options: [
                .initial,
                .new,
            ]) { [weak self] _, _ in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.evaluateBufferingReadiness()
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.evaluateBufferingReadiness()
                    }
                }
            }
        )

        observations.append(
            playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [
                .initial,
                .new,
            ]) { [weak self] _, _ in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.evaluateBufferingReadiness()
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.evaluateBufferingReadiness()
                    }
                }
            }
        )

        observations.append(
            playerItem.observe(\.loadedTimeRanges, options: [.new]) { [weak self] _, _ in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.evaluateBufferingReadiness()
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.evaluateBufferingReadiness()
                    }
                }
            }
        )
    }

    /// Evaluates whether buffer readiness conditions are met to transition into playing or previous
    /// state.
    private func evaluateBufferingReadiness() {
        guard isActiveState else { return }
        guard canPlay() else { return }
        autoPlay ? startPlayingIfPossible() : changeToPreviousState()
    }

    /// Cancels and restarts the buffer timeout watcher task.
    private func restartBufferTimeoutWatcher() {
        timeoutTask?.cancel()
        startProgressAwareBufferTimeoutWatcher()
    }

    /// Transitions back to the designated state prior to buffering if autoplay
    /// is not requested.
    private func changeToPreviousState() {
        guard isActiveState, let playerController else { return }
        guard activePlayerItem != nil,
              !playerController.isSeeking,
              canPlay()
        else { return }

        switch stateToNavigateAfterBuffering {
        case .loaded:
            let controller = AKLoadedState(
                playerController: playerController,
                rate: rate
            )
            change(controller)
        default:
            let controller = AKPausedState(playerController: playerController)
            change(controller)
        }
    }

    /// Checks buffer availability and transitions into `AKPlayingState` if ready.
    private func startPlayingIfPossible() {
        guard let playerController, canPlay() else { return }

        let controller = AKPlayingState(
            playerController: playerController,
            rate: rate
        )
        change(controller)
    }

    /// Listens for network reachability changes to drop into network waiting state if connectivity
    /// fails.
    private func observeNetworkChanges() {
        networkObservationTask?.cancel()
        networkObservationTask = observeNetworkStatus { [weak self] status in
            guard let self, let playerController, status != .satisfied else { return }

            let controller = AKWaitingForNetworkState(
                playerController: playerController,
                autoPlay: autoPlay,
                rate: rate,
                stateToNavigateAfterBuffering: stateToNavigateAfterBuffering,
                targetSeek: targetSeek,
                reason: .disconnected,
                retryCount: retryCount
            )
            change(controller)
        }
    }

    /// Performs the pending seek command if the state instance is active, and resets the timeout
    /// timer.
    private func performTargetSeekIfActive() {
        guard isActiveState, let targetSeek, let playerController else { return }
        playerController.performSeek(to: targetSeek)
        restartBufferTimeoutWatcher()
    }

    /// Called immediately before transitioning out of this state to cancel tasks and clear
    /// observations.
    override public func beforeStateChange() {
        observations.removeAll()
        timeoutTask?.cancel()
        timeoutTask = nil
        networkObservationTask?.cancel()
        networkObservationTask = nil
    }
}

// MARK: - Progress-Aware Buffer Timeout Watcher

extension AKBufferingState {
    /// Starts a recurring timer task that monitors buffering readiness AND download progress.
    private func startProgressAwareBufferTimeoutWatcher() {
        guard let playerController else { return }
        let interval = playerController.configuration.bufferObservingTimeInterval
        let stallTickLimit = playerController.configuration.bufferStallTickLimit
        let hardTimeout = playerController.configuration.bufferObservingTimeout
        let hardDeadline = Date().addingTimeInterval(hardTimeout)

        timeoutTask = Task { [weak self] in
            var lastLoadedDuration: CMTime = .zero
            var stalledTicks = 0

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }

                if canPlay() {
                    if autoPlay {
                        startPlayingIfPossible()
                    } else {
                        changeToPreviousState()
                    }
                    return
                }

                // Sample progress
                let currentLoaded = totalLoadedDuration()
                let madeProgress = currentLoaded.seconds > lastLoadedDuration.seconds + 0.05

                if madeProgress {
                    stalledTicks = 0
                } else {
                    stalledTicks += 1
                }
                lastLoadedDuration = currentLoaded

                let pastHardDeadline = Date() >= hardDeadline
                let trulyStalled = stalledTicks >= stallTickLimit

                if trulyStalled || pastHardDeadline {
                    handleBufferTimeoutExceeded(
                        madeAnyProgress: currentLoaded.seconds > 0,
                        reason: trulyStalled ? .stalled : .hardTimeoutExceeded
                    )
                    return
                }
            }
        }
    }

    /// Sums the durations of all currently loaded (buffered) time ranges for the active player
    /// item.
    private func totalLoadedDuration() -> CMTime {
        guard let playerItem = activePlayerItem else { return .zero }
        return playerItem.loadedTimeRanges
            .map(\.timeRangeValue.duration)
            .reduce(CMTime.zero, CMTimeAdd)
    }

    /// Categorization of buffer stalling conditions triggering escalation.
    private enum BufferStallReason {
        /// Zero growth observed for stallTickLimit consecutive ticks.
        case stalled
        /// Total buffer wait duration exceeded the hard timeout ceiling.
        case hardTimeoutExceeded
    }

    /// Escalates buffer stall or timeout conditions into network waiting or failure states.
    /// - Parameters:
    ///   - madeAnyProgress: Whether any buffer byte progress was recorded during the current
    /// observation window.
    ///   - reason: The triggering reason for the buffer timeout.
    private func handleBufferTimeoutExceeded(madeAnyProgress: Bool, reason: BufferStallReason) {
        guard let playerController else { return }
        guard let media = playerController.currentMedia, media.isOverNetwork() else {
            let controller = AKFailedState(
                playerController: playerController,
                error: .playerItemFailedToPlay(
                    reason: .failedToPlayToEndTime(
                        error: NSError(
                            domain: "AKPlayer",
                            code: -2,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Local media stalled during buffering.",
                            ]
                        )
                    )
                )
            )
            return change(controller)
        }

        switch reason {
        case .stalled where !madeAnyProgress:
            let controller = AKWaitingForNetworkState(
                playerController: playerController,
                autoPlay: autoPlay,
                rate: rate,
                stateToNavigateAfterBuffering: stateToNavigateAfterBuffering,
                targetSeek: targetSeek,
                reason: .disconnected,
                retryCount: retryCount
            )
            change(controller)

        case .stalled, .hardTimeoutExceeded:
            let maxRetries = playerController.configuration.maxBufferRetryCount
            guard retryCount < maxRetries else {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .playerCanNoLongerPlay(
                        error: NSError(
                            domain: "AKPlayer",
                            code: -3,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Buffering repeatedly failed to keep up — connection appears too slow to sustain playback.",
                            ]
                        )
                    )
                )
                return change(controller)
            }

            let controller = AKWaitingForNetworkState(
                playerController: playerController,
                autoPlay: autoPlay,
                rate: rate,
                stateToNavigateAfterBuffering: stateToNavigateAfterBuffering,
                targetSeek: targetSeek,
                reason: .bufferTimeout,
                retryCount: retryCount + 1
            )
            change(controller)
        }
    }
}
