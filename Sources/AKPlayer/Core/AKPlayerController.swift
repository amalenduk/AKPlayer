//
//   AKPlayerController.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - AKPlayerController

/// Core state machine controller managing playback states, `AVPlayer`
/// interactions, observers, and state transitions.
@MainActor
public class AKPlayerController: AKPlayerControllerProtocol {
    // MARK: - Properties

    /// The underlying `AVPlayer` engine executing system media playback.
    public private(set) var player: AVPlayer

    /// The current concrete playback state exposed by the state controller.
    public var state: AKPlayerState {
        controller.state
    }

    /// The default playback speed multiplier configured on the underlying
    /// player engine.
    public var defaultRate: AKPlaybackRate {
        get { AKPlaybackRate(rate: player.defaultRate) }
        set { player.defaultRate = newValue.rate }
    }

    /// The current playback speed multiplier. Modifying this triggers play or
    /// pause actions accordingly.
    public var rate: AKPlaybackRate {
        get { AKPlaybackRate(rate: player.rate) }
        set {
            if newValue.rate == 0 {
                pause()
            } else {
                play(at: newValue)
            }
        }
    }

    /// The active playable media item loaded into the controller.
    public private(set) var currentMedia: (any AKPlayable)?

    /// The active `AVPlayerItem` associated with current media execution.
    public var currentItem: AVPlayerItem? {
        player.currentItem
    }

    /// The duration of the currently active player item.
    public var currentItemDuration: CMTime {
        currentItem?.duration ?? .indefinite
    }

    /// The current playback position time of the player.
    public var currentTime: CMTime {
        player.currentTime()
    }

    /// The remaining playback time duration for the active media item, if
    /// available.
    public var remainingTime: CMTime? {
        guard currentItemDuration.isValid else { return nil }
        return CMTimeSubtract(currentItemDuration, currentTime)
    }

    /// A boolean flag indicating whether playback will automatically start upon
    /// completing loading/buffering.
    public var autoPlay: Bool {
        controller.autoPlay
    }

    /// Indicates whether a seek operation is currently being performed by the
    /// seeking service.
    public var isSeeking: Bool {
        playerSeekingThroughMediaService.isSeeking
    }

    /// The target position of the last requested seek operation.
    public var lastRequestedSeekPosition: AKSeekTarget? {
        playerSeekingThroughMediaService.lastRequestedSeekTarget
    }

    /// The audio output playback volume level, ranging from 0.0 to 1.0.
    public var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    /// A boolean flag indicating whether player audio output is muted.
    public var isMuted: Bool {
        get { player.isMuted }
        set { player.isMuted = newValue }
    }

    /// The current error object if the controller is in a failed state.
    public var error: AKPlayerError? {
        (controller as? AKFailedState)?.error
    }

    /// Configuration options driving player behavior and timing defaults.
    public private(set) var configuration: any AKPlayerConfigurationProtocol

    /// The active time-pitch algorithm used for pitch preservation and time stretching.
    public var audioTimePitchAlgorithm: AKAudioTimePitchAlgorithm {
        get {
            if let currentItem {
                return AKAudioTimePitchAlgorithm(avAlgorithm: currentItem.audioTimePitchAlgorithm)
            }
            return configuration.audioTimePitchAlgorithm
        }
        set {
            configuration.audioTimePitchAlgorithm = newValue
            currentItem?.audioTimePitchAlgorithm = newValue.avAlgorithm
        }
    }

    /// Asynchronous stream of player events for Swift Concurrency.
    public var events: AsyncStream<AKPlayerEvent> {
        eventBroadcaster.makeStream()
    }

    // MARK: - Live Stream Properties

    /// Indicates whether the active media is a live broadcast stream.
    public var isLive: Bool {
        currentMedia?.isLive() ?? (currentItem?.duration.isIndefinite == true)
    }

    /// Indicates whether playback is currently synced with the live edge (drift <= threshold).
    public var isAtLiveEdge: Bool {
        currentMedia?.isAtLiveEdge ?? true
    }

    // MARK: - Controller Services

    /// Service managing seek operation queuing and execution against
    /// `AVPlayer`.
    public let playerSeekingThroughMediaService: any AKPlayerSeekingThroughMediaServiceProtocol

    /// Interstitial service managing ad scheduling and playback.
    public let interstitialService: any AKPlayerInterstitialServiceProtocol

    /// Service monitoring network availability and reachability changes.
    public let networkStatusMonitor: any AKNetworkStatusMonitorProtocol

    /// Coordinator managing Apple SharePlay (`GroupActivities`) media playback synchronization.
    public let sharePlayCoordinator: (any AKSharePlayCoordinatorProtocol)?

    /// Coordinator managing Apple SharePlay (`GroupActivities`) synchronization.
    public var sharePlay: (any AKSharePlayCoordinatorProtocol)? {
        sharePlayCoordinator
    }

    // MARK: - Internal Properties

    /// The active state controller instance representing current player state
    /// logic.
    private var controller: (any AKPlayerStateControllerProtocol)!

    /// Multicast event broadcaster dispatching playback events to asynchronous stream subscribers.
    private let eventBroadcaster = AKEventBroadcaster<AKPlayerEvent>()

    /// Observer service tracking periodic and boundary time playback events.
    private let playerPlaybackTimeObserver: any AKPlayerPlaybackTimeObserverProtocol

    /// Observer service tracking player rate change updates.
    private let playerRateObserver: any AKPlayerRateObserverProtocol

    /// Native Foundation KVO observations for AVPlayer properties.
    private var observations: [NSKeyValueObservation] = []

    /// Task responsible for asynchronously consuming and processing rate change
    /// events from the player stream.
    private var rateObservationTask: Task<Void, Never>?

    /// Task responsible for asynchronously consuming periodic time events.
    private var periodicTimeObservationTask: Task<Void, Never>?

    /// Task responsible for asynchronously consuming boundary time events.
    private var boundaryTimeObservationTask: Task<Void, Never>?

    /// Task responsible for observing player item notification events.
    private var playerItemNotificationObservationTask: Task<Void, Never>?

    /// Task responsible for observing interstitial playback state updates.
    private var interstitialObservationTask: Task<Void, Never>?

    // MARK: - Initialization & Teardown

    /// Initializes a new `AKPlayerController` instance with a target player
    /// engine and configuration options.
    /// - Parameters:
    ///   - player: The `AVPlayer` engine driving media playback.
    ///   - configuration: Configuration settings driving timing, buffering, and
    /// lifecycle behavior.
    public init(
        player: AVPlayer,
        configuration: any AKPlayerConfigurationProtocol
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.player = player
        self.configuration = configuration

        playerRateObserver = AKPlayerRateObserver(with: player)
        playerPlaybackTimeObserver = AKPlayerPlaybackTimeObserver(with: player)
        let interstitial = AKPlayerInterstitialService(with: player)
        interstitialService = interstitial
        playerSeekingThroughMediaService = AKPlayerSeekingThroughMediaService(
            with: player,
            interstitialService: interstitial
        )
        networkStatusMonitor = AKNetworkStatusMonitor()

        if configuration.isSharePlayEnabled {
            let coordinator = AKSharePlayCoordinator(
                player: player,
                configuration: configuration.sharePlay
            )
            sharePlayCoordinator = coordinator
        } else {
            sharePlayCoordinator = nil
        }

        controller = AKIdleState(playerController: self)

        if let coordinator = sharePlayCoordinator as? AKSharePlayCoordinator {
            coordinator.attach(playerController: self)
            if configuration.sharePlay.autoCoordinateIncomingSessions {
                coordinator.startObservingSessions()
            }
        }
    }

    deinit {
        defer {
            AKLogger.logDeinit(
                String(describing: Self.self),
                pointer: Unmanaged.passUnretained(self)
            )
        }
        observations.removeAll()
        rateObservationTask?.cancel()
        rateObservationTask = nil
        periodicTimeObservationTask?.cancel()
        periodicTimeObservationTask = nil
        boundaryTimeObservationTask?.cancel()
        boundaryTimeObservationTask = nil
        playerItemNotificationObservationTask?.cancel()
        playerItemNotificationObservationTask = nil
        interstitialObservationTask?.cancel()
        interstitialObservationTask = nil
        eventBroadcaster.finish()
        #if os(iOS) || os(tvOS) || os(visionOS)
            Task { @MainActor in
                UIApplication.shared.isIdleTimerDisabled = false
            }
        #endif
    }

    // MARK: - Time Observers

    /// Registers boundary time points to trigger observer delegate callbacks
    /// during playback.
    /// - Parameter times: An array of target boundary times represented as
    /// `CMTime`.
    public func addBoundaryTimeObserver(for times: [CMTime]) {
        playerPlaybackTimeObserver.startObservingBoundaryTime(for: times)
    }

    /// Removes active boundary time observers from the playback pipeline.
    public func removeBoundaryTimeObserver() {
        playerPlaybackTimeObserver.stopObservingBoundaryTime()
    }

    // MARK: - Playback Commands

    /// Loads a playable media item into the state pipeline.
    /// - Parameters:
    ///   - media: The target media item conforming to `AKPlayable`.
    ///   - autoPlay: Controls whether playback automatically begins after
    /// loading.
    ///   - position: An optional initial seek target position to apply upon
    /// load completion.
    public func load(
        media: any AKPlayable,
        autoPlay: Bool,
        at position: AKSeekTarget?
    ) {
        if !state.isAny(of: [.idle, .stopped, .failed]) {
            stop()
        }
        currentMedia = media
        controller.load(media: media, autoPlay: autoPlay, at: position)
    }

    /// Commands the current state controller to initiate or resume playback.
    public func play() {
        controller.play()
    }

    /// Commands the current state controller to initiate playback at a specific
    /// speed multiplier.
    /// - Parameter rate: The target playback rate multiplier.
    public func play(at rate: AKPlaybackRate) {
        controller.play(at: rate)
    }

    /// Commands the current state controller to pause active media playback.
    public func pause() {
        controller.pause()
    }

    /// Commands the current state controller to toggle between play and pause
    /// states.
    public func togglePlayPause() {
        controller.togglePlayPause()
    }

    /// Commands the current state controller to stop media playback and reset
    /// position.
    public func stop() {
        controller.stop()
    }

    // MARK: - Seeking Commands

    /// Asynchronously seeks to a designated target position within current
    /// media.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`,
    /// `.percentage`, or `.date`).
    ///   - scope: The timeline coordinate scope (`.primary` or `.integrated`).
    /// - Returns: `true` if the seek command was accepted and executed
    /// successfully; `false` otherwise.
    public func seek(to target: AKSeekTarget, scope: AKSeekScope) async -> Bool {
        await withCheckedContinuation { continuation in
            seek(to: target, scope: scope) { finished in
                continuation.resume(returning: finished)
            }
        }
    }

    /// Asynchronously seeks to a designated target position with explicit
    /// tolerance bounds.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`,
    /// `.percentage`, or `.date`).
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    ///   - toleranceBefore: Acceptable time offset tolerance before the target
    /// position.
    ///   - toleranceAfter: Acceptable time offset tolerance after the target
    /// position.
    /// - Returns: `true` if the seek command was accepted and executed
    /// successfully; `false` otherwise.
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            seek(
                to: target,
                scope: scope,
                toleranceBefore: toleranceBefore,
                toleranceAfter: toleranceAfter
            ) { finished in
                continuation.resume(returning: finished)
            }
        }
    }

    /// Seeks to a designated target position with a completion callback.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`,
    /// `.percentage`, or `.date`).
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    ///   - completionHandler: A callback invoked when the seek operation
    /// finishes or is canceled, receiving a boolean indicating success.
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        controller.seek(to: target, scope: scope, completionHandler: completionHandler)
    }

    /// Seeks to a designated target position with custom tolerance bounds and a
    /// completion callback.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`,
    /// `.percentage`, or `.date`).
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    ///   - toleranceBefore: Acceptable time offset tolerance before the target
    /// position.
    ///   - toleranceAfter: Acceptable time offset tolerance after the target
    /// position.
    ///   - completionHandler: A callback invoked when the seek operation
    /// finishes or is canceled, receiving a boolean indicating success.
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        controller.seek(
            to: target,
            scope: scope,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }

    // MARK: - Media Navigation

    /// Steps frame-by-frame through video media by a specified frame offset.
    /// - Parameter count: The frame offset count (positive for forward,
    /// negative for reverse).
    public func step(by count: Int) {
        controller.step(by: count)
    }

    /// Fast-forwards playback using the default fast-forward speed defined in
    /// configuration.
    public func fastForward() {
        controller.fastForward()
    }

    /// Fast-forwards playback at a specified custom speed multiplier rate.
    /// - Parameter rate: The target fast-forward playback speed multiplier.
    public func fastForward(at rate: AKPlaybackRate) {
        controller.fastForward(at: rate)
    }

    /// Rewinds playback using the default rewind speed defined in
    /// configuration.
    public func rewind() {
        controller.rewind()
    }

    /// Rewinds playback at a specified custom speed multiplier rate.
    /// - Parameter rate: The target rewind playback speed multiplier.
    public func rewind(at rate: AKPlaybackRate) {
        controller.rewind(at: rate)
    }

    // MARK: - Live Stream Navigation

    /// Jumps directly to the live head of the stream and resumes playback at normal speed.
    @discardableResult
    public func jumpToLive() async -> Bool {
        await controller.jumpToLive()
    }

    /// Jumps directly to the live head of the stream with a completion callback.
    public func jumpToLive(completionHandler: @escaping @Sendable (Bool) -> Void) {
        controller.jumpToLive(completionHandler: completionHandler)
    }

    // MARK: - Helper & Pipeline Management Functions

    /// Prepares the controller pipeline, initializes idle state, starts network
    /// monitoring, and attaches observers.
    /// - Throws: An error if setting up active pipeline components fails.
    public func prepare() throws {
        networkStatusMonitor.startObserving()
        startPlayerObservers()
    }

    /// Transitions the current state controller to a new state controller
    /// instance.
    /// - Parameter newController: The target state controller conforming to
    /// `AKPlayerStateControllerProtocol`.
    public func change(_ newController: any AKPlayerStateControllerProtocol) {
        controller = newController
        eventBroadcaster.send(.stateDidChange(newController.state))
        processStateChange()
        newController.processStateChange()
    }

    /// Hook called whenever state changes to execute custom side effects based
    /// on active state.
    public func processStateChange() {
        updateIdleTimer()

        switch state {
        case .idle, .loading, .buffering, .paused, .playing, .waitingForNetwork:
            break

        case .loaded:
            observePlayerItemNotifications()

        case .failed, .stopped:
            playerItemNotificationObservationTask?.cancel()
            playerItemNotificationObservationTask = nil
        }
    }

    /// Begins observing player rates, volume, mute state, and time changes via
    /// native Swift Concurrency AsyncStreams and Foundation KVO.
    private func startPlayerObservers() {
        stopPlayerObservers()

        playerRateObserver.startObserving()
        playerPlaybackTimeObserver.startObservingPeriodicTime(
            for: configuration.getPeriodicTimeInterval()
        )

        // Rate changes async stream observation
        rateObservationTask = Task { [weak self] in
            guard let stream = self?.playerRateObserver.rateChanges else { return }
            for await change in stream {
                guard !Task.isCancelled, let self else { break }
                eventBroadcaster.send(
                    .playbackRateDidChange(
                        new: change.currentRate,
                        previous: change.previousRate
                    )
                )
            }
        }

        // Periodic time updates async stream observation
        periodicTimeObservationTask = Task { [weak self] in
            guard let stream = self?.playerPlaybackTimeObserver.periodicTimes else { return }
            for await time in stream {
                guard !Task.isCancelled, let self else { break }
                guard currentMedia != nil else { continue }
                eventBroadcaster.send(.timeDidChange(time))
            }
        }

        // Boundary time milestones async stream observation
        boundaryTimeObservationTask = Task { [weak self] in
            guard let stream = self?.playerPlaybackTimeObserver.boundaryTimes else { return }
            for await time in stream {
                guard !Task.isCancelled, let self else { break }
                guard currentMedia != nil else { continue }
                eventBroadcaster.send(.boundaryReached(at: time))
            }
        }

        // Native Foundation KVO for volume
        observations.append(
            player.observe(\.volume, options: [.initial, .new]) { [weak self] observedPlayer, _ in
                let volume = observedPlayer.volume
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.eventBroadcaster.send(.volumeDidChange(volume))
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.eventBroadcaster.send(.volumeDidChange(volume))
                    }
                }
            }
        )

        // Native Foundation KVO for mute status
        observations.append(
            player.observe(\.isMuted, options: [.initial, .new]) { [weak self] observedPlayer, _ in
                let isMuted = observedPlayer.isMuted
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.eventBroadcaster.send(.muteStatusDidChange(isMuted: isMuted))
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.eventBroadcaster.send(.muteStatusDidChange(isMuted: isMuted))
                    }
                }
            }
        )

        // Native Foundation KVO for player readiness status
        observations.append(
            player.observe(\.status, options: [.new]) { [weak self] observedPlayer, _ in
                let status = observedPlayer.status
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.controller.handlePlayerStatusChange(status)
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.controller.handlePlayerStatusChange(status)
                    }
                }
            }
        )

        // Native Foundation KVO for timeControlStatus
        observations.append(
            player.observe(\.timeControlStatus, options: [
                .initial,
                .new,
            ]) { [weak self] observedPlayer, _ in
                let status = observedPlayer.timeControlStatus
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.controller.handleTimeControlStatusChange(status)
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.controller.handleTimeControlStatusChange(status)
                    }
                }
            }
        )
        // Interstitial playback state changes async stream observation
        interstitialObservationTask = Task { [weak self] in
            guard let stream = self?.interstitialService.events else { return }
            for await event in stream {
                guard !Task.isCancelled, let self else { break }
                if case let .playbackStateDidChange(playbackState) = event {
                    guard interstitialService.isPlayingInterstitial else { continue }
                    controller.handleInterstitialPlaybackStateChange(playbackState)
                }
            }
        }
    }

    /// Observes media player item notification events and forwards them to the active state
    /// controller.
    private func observePlayerItemNotifications() {
        playerItemNotificationObservationTask?.cancel()
        guard let events = currentMedia?.playerItemNotifications.events else { return }

        playerItemNotificationObservationTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled, let self else { break }
                controller.handle(event)
            }
        }
    }

    /// Updates the application idle timer (screen sleep) state based on whether
    /// the active playback state is configured in `idleTimerDisabledForStates`.
    private func updateIdleTimer() {
        #if os(iOS) || os(tvOS) || os(visionOS)
            let shouldDisable = configuration.idleTimerDisabledForStates.contains(state)
            if UIApplication.shared.isIdleTimerDisabled != shouldDisable {
                UIApplication.shared.isIdleTimerDisabled = shouldDisable
            }
        #endif
    }

    /// Stops time and rate observers attached to the underlying player
    /// instance.
    private func stopPlayerObservers() {
        observations.removeAll()
        rateObservationTask?.cancel()
        rateObservationTask = nil
        periodicTimeObservationTask?.cancel()
        periodicTimeObservationTask = nil
        boundaryTimeObservationTask?.cancel()
        boundaryTimeObservationTask = nil
        interstitialObservationTask?.cancel()
        interstitialObservationTask = nil

        playerRateObserver.stopObserving()
        playerPlaybackTimeObserver.stopObservingPeriodicTime()
        playerPlaybackTimeObserver.stopObservingBoundaryTime()
    }

    // MARK: - Event Dispatcher

    /// Single entry point for dispatching all player events across the
    /// framework.
    /// Broadcasts the event to the delegate and forwards it to event listeners
    /// (`AsyncStream`).
    /// - Parameter event: The player event that occurred.
    public func emit(_ event: AKPlayerEvent) {
        eventBroadcaster.send(event)
    }
}

// MARK: - Direct Action Implementations

public extension AKPlayerController {
    /// Directly issues a `play()` command to the underlying `AVPlayer` (and interstitial player if
    /// active).
    func performPlay() {
        if interstitialService.isPlayingInterstitial {
            interstitialService.interstitialPlayer?.play()
        }
        player.play()
    }

    /// Directly sets the playback rate on the underlying `AVPlayer` (and interstitial player if
    /// active).
    /// - Parameter rate: The target playback speed rate multiplier.
    func performPlay(at rate: AKPlaybackRate) {
        if interstitialService.isPlayingInterstitial {
            interstitialService.interstitialPlayer?.play()
        }
        player.rate = rate.rate
    }

    /// Directly issues a `pause()` command to the underlying `AVPlayer` (and interstitial player if
    /// active).
    func performPause() {
        if interstitialService.isPlayingInterstitial {
            interstitialService.interstitialPlayer?.pause()
        }
        player.pause()
    }

    /// Directly pauses playback, resets position to time zero, and cancels
    /// pending seek requests.
    func performStop() {
        playerPlaybackTimeObserver.stopObservingPeriodicTime()
        playerPlaybackTimeObserver.stopObservingBoundaryTime()

        playerItemNotificationObservationTask?.cancel()
        playerItemNotificationObservationTask = nil

        if !player.timeControlStatus.isPaused {
            player.pause()
        }

        playerSeekingThroughMediaService.cancelAll()
        currentMedia?.playerItem?.cancelPendingSeeks()
        player.seek(to: .zero)

        currentMedia = nil
        player.replaceCurrentItem(with: nil)
    }

    /// Submits a target seek token directly to the seek service for execution.
    /// - Parameter targetSeek: The seek payload object containing target
    /// parameters and completion callbacks.
    func performSeek(to targetSeek: AKSeek) {
        playerSeekingThroughMediaService.seek(to: targetSeek)
    }

    /// Directly steps the current player item forward or backward by a specific
    /// frame count.
    /// - Parameter count: The frame offset count (positive for forward,
    /// negative for reverse).
    func performStep(by count: Int) {
        player.currentItem?.step(byCount: count)
    }
}
