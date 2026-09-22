//
//   AKPlayer.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import GroupActivities

// MARK: - AKPlayer

/// Primary high-level interface providing media playback control, state
/// inspection, and delegate forwarding.
@MainActor
public class AKPlayer: NSObject, AKPlayerProtocol {
    // MARK: - Properties

    /// The underlying `AVPlayer` engine driving system media execution.
    public var player: AVPlayer {
        manager.player
    }

    /// The current concrete playback state of the player.
    public var state: AKPlayerState {
        manager.state
    }

    /// The default speed multiplier used when initiating normal playback.
    public var defaultRate: AKPlaybackRate {
        get { manager.defaultRate }
        set { manager.defaultRate = newValue }
    }

    /// The active playback rate speed multiplier.
    public var rate: AKPlaybackRate {
        get { manager.rate }
        set { manager.rate = newValue }
    }

    /// The currently active playable media item loaded into the player
    /// pipeline.
    public var currentMedia: (any AKPlayable)? {
        manager.currentMedia
    }

    /// The underlying `AVPlayerItem` associated with the current media item.
    public var currentItem: AVPlayerItem? {
        manager.currentItem
    }

    /// The total duration of the currently active media item.
    public var currentItemDuration: CMTime {
        manager.currentItemDuration
    }

    /// The current playback time position of the active media item.
    public var currentTime: CMTime {
        manager.currentTime
    }

    /// The remaining playback time duration for the active media item, if
    /// available.
    public var remainingTime: CMTime? {
        manager.remainingTime
    }

    /// Indicates whether playback will automatically start upon completing
    /// media load and buffering operations.
    public var autoPlay: Bool {
        manager.autoPlay
    }

    /// A boolean flag indicating whether a seek operation is currently in
    /// progress.
    public var isSeeking: Bool {
        manager.isSeeking
    }

    /// The target position of the most recent seek request.
    public var lastRequestedSeekPosition: AKSeekTarget? {
        manager.lastRequestedSeekPosition
    }

    /// The audio output playback volume level, ranging from 0.0 to 1.0.
    public var volume: Float {
        get { manager.volume }
        set { manager.volume = newValue }
    }

    /// A boolean flag indicating whether player audio output is muted.
    public var isMuted: Bool {
        get { manager.isMuted }
        set { manager.isMuted = newValue }
    }

    /// The most recent error encountered by the player state machine or
    /// underlying pipeline.
    public var error: AKPlayerError? {
        manager.error
    }

    /// Configuration options driving player behavior and timing defaults.
    public var configuration: any AKPlayerConfigurationProtocol {
        manager.configuration
    }

    /// The active time-pitch algorithm used for pitch preservation and time stretching.
    public var audioTimePitchAlgorithm: AKAudioTimePitchAlgorithm {
        get { manager.audioTimePitchAlgorithm }
        set { manager.audioTimePitchAlgorithm = newValue }
    }

    /// Asynchronous stream of player events for Swift Concurrency.
    public var events: AsyncStream<AKPlayerEvent> {
        manager.events
    }

    // MARK: - SharePlay

    /// Coordinator managing Apple SharePlay (`GroupActivities`) synchronization.
    public var sharePlay: (any AKSharePlayCoordinatorProtocol)? {
        manager.sharePlay
    }

    // MARK: - Live Stream Properties

    /// Indicates whether the active media is a live broadcast stream.
    public var isLive: Bool {
        manager.isLive
    }

    /// Indicates whether playback is currently synced with the live edge (drift <= threshold).
    public var isAtLiveEdge: Bool {
        manager.isAtLiveEdge
    }

    // MARK: - Manager & Services

    /// The player manager instance handling core state machine lifecycle and
    /// engine operations.
    private var manager: AKPlayerManagerProtocol

    /// The active Now Playing info and remote command center session.
    public var nowPlayingManager: (any AKNowPlayingManagerProtocol)? {
        manager.nowPlayingManager
    }

    /// The service managing sequential seeking actions through media queues.
    public var playerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol {
        manager.playerSeekingThroughMediaService
    }

    /// The service managing scheduled interstitial (ad) events and playback timelines.
    public var interstitialService: AKPlayerInterstitialServiceProtocol {
        manager.interstitialService
    }

    /// The delegate object receiving high-level player state transitions,
    /// playback events, and error notifications.
    public weak var delegate: AKPlayerDelegate?

    /// Task managing the asynchronous event stream from the player controller.
    private var playerEventsTask: Task<Void, Never>?

    // MARK: - Initialization & Teardown

    /// Initializes a new `AKPlayer` instance configured with player
    /// dependencies.
    /// - Parameters:
    ///   - player: The underlying `AVPlayer` instance. Defaults to a new
    /// instance.
    ///   - configuration: Configuration options driving player behavior.
    /// Defaults to `AKPlayerConfiguration.default`.
    ///   - audioSessionService: The audio session management service instance.
    /// Defaults to `AKAudioSessionService()`.
    public init(
        player: AVPlayer = AVPlayer(),
        configuration: AKPlayerConfigurationProtocol = AKPlayerConfiguration
            .default,
        audioSessionService: AKAudioSessionServiceProtocol =
            AKAudioSessionService()
    ) {
        defer {
            AKLogger.logInit(self)
        }
        manager = AKPlayerManager(
            player: player,
            configuration: configuration,
            audioSessionService: audioSessionService
        )
        super.init()

        startObservingPlayerEvents()
    }

    deinit {
        defer {
            AKLogger.logDeinit(
                String(describing: Self.self),
                pointer: Unmanaged.passUnretained(self)
            )
        }
        playerEventsTask?.cancel()
        playerEventsTask = nil
    }

    // MARK: - Setup

    /// Prepares the player pipeline and configures initial system audio session
    /// settings.
    /// - Throws: An error if setting up the underlying audio session fails.
    public func prepare() async throws {
        try await manager.prepare()
    }

    /// Configures boundary observers to trigger notifications when specific
    /// media playback times are reached.
    /// - Parameter times: An array of target boundary time points represented
    /// as `CMTime`.
    public func addBoundaryTimeObserver(for times: [CMTime]) {
        manager.addBoundaryTimeObserver(for: times)
    }

    /// Removes active boundary time observers from the media pipeline.
    public func removeBoundaryTimeObserver() {
        manager.removeBoundaryTimeObserver()
    }

    // MARK: - Loading Media

    /// Loads a new playable media item into the player pipeline.
    /// - Parameters:
    ///   - media: The target media item conforming to `AKPlayable`.
    ///   - autoPlay: Controls whether playback automatically begins when media
    /// loading and buffering complete.
    ///   - position: An optional initial seek target position to apply upon
    /// load completion.
    public func load(
        media: any AKPlayable,
        autoPlay: Bool,
        at position: AKSeekTarget?
    ) {
        manager.load(
            media: media,
            autoPlay: autoPlay,
            at: position
        )
    }

    // MARK: - Controlling Playback

    /// Commands the player to begin media playback at the current default rate.
    public func play() {
        manager.play()
    }

    /// Commands the player to begin media playback at a specified speed
    /// multiplier.
    /// - Parameter rate: The target playback rate multiplier.
    public func play(at rate: AKPlaybackRate) {
        manager.play(at: rate)
    }

    /// Commands the player to pause active media playback.
    public func pause() {
        manager.pause()
    }

    /// Toggles between play and pause states based on current active playback
    /// status.
    public func togglePlayPause() {
        manager.togglePlayPause()
    }

    /// Stops playback and tears down active player pipeline operations.
    public func stop() {
        manager.stop()
    }

    // MARK: - Seeking Through Media

    /// Asynchronously seeks to a designated target position within the current
    /// media.
    /// - Parameter target: The target position (`.time`, `.seconds`, `.offset`,
    /// `.percentage`, or `.date`).
    /// - Returns: `true` if the seek command was accepted and successfully
    /// executed; `false` otherwise.
    @discardableResult
    public func seek(to target: AKSeekTarget, scope: AKSeekScope) async -> Bool {
        await manager.seek(to: target, scope: scope)
    }

    /// Asynchronously seeks to a designated target position with explicit
    /// tolerance parameters.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`,
    /// `.percentage`, or `.date`).
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    ///   - toleranceBefore: Acceptable time offset tolerance before the target
    /// position.
    ///   - toleranceAfter: Acceptable time offset tolerance after the target
    /// position.
    /// - Returns: `true` if the seek command was accepted and successfully
    /// executed; `false` otherwise.
    @discardableResult
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool {
        await manager.seek(
            to: target,
            scope: scope,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter
        )
    }

    /// Seeks to a designated target position with a completion callback.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`,
    /// `.percentage`, or `.date`).
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    ///   - completionHandler: A callback invoked when the seek operation
    /// completes or is canceled, receiving a boolean indicating success.
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        manager.seek(to: target, scope: scope, completionHandler: completionHandler)
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
    /// completes or is canceled, receiving a boolean indicating success.
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        manager.seek(
            to: target,
            scope: scope,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }

    // MARK: - Media Navigation

    /// Steps frame-by-frame through video media by a specified frame count
    /// offset.
    /// - Parameter count: The frame offset count (positive for forward,
    /// negative for reverse).
    public func step(by count: Int) {
        manager.step(by: count)
    }

    /// Fast-forwards playback using the default fast-forward speed defined in
    /// player configuration.
    public func fastForward() {
        manager.fastForward()
    }

    /// Fast-forwards playback at a custom speed multiplier.
    /// - Parameter rate: The target fast-forward playback rate multiplier.
    public func fastForward(at rate: AKPlaybackRate) {
        manager.fastForward(at: rate)
    }

    /// Rewinds playback using the default rewind speed defined in player
    /// configuration.
    public func rewind() {
        manager.rewind()
    }

    /// Rewinds playback at a custom speed multiplier.
    /// - Parameter rate: The target rewind playback rate multiplier.
    public func rewind(at rate: AKPlaybackRate) {
        manager.rewind(at: rate)
    }

    // MARK: - Live Stream Navigation

    /// Seeks immediately to the live edge of the current broadcast stream.
    /// - Returns: `true` if the seek command was accepted and executed successfully; `false`
    /// otherwise.
    @discardableResult
    public func jumpToLive() async -> Bool {
        await manager.jumpToLive()
    }

    /// Seeks immediately to the live edge with a completion callback.
    /// - Parameter completionHandler: A callback invoked with the success status of the operation.
    public func jumpToLive(completionHandler: @escaping @Sendable (Bool) -> Void) {
        manager.jumpToLive(completionHandler: completionHandler)
    }

    // MARK: - Private Event Handling

    private func startObservingPlayerEvents() {
        playerEventsTask?.cancel()

        playerEventsTask = Task { [weak self] in
            guard let managerEvents = self?.manager.events else { return }

            for await event in managerEvents {
                guard !Task.isCancelled, let self else { break }

                handleControllerEvent(event)
            }
        }
    }

    private func handleControllerEvent(_ event: AKPlayerEvent) {
        switch event {
        case let .stateDidChange(state):
            delegate?.akPlayer(self, didChangeStateTo: state)

        case let .mediaDidChange(media):
            delegate?.akPlayer(self, didChangeMediaTo: media)

        case let .timeDidChange(time):
            guard let currentMedia else { return }
            delegate?.akPlayer(
                self,
                didChangeCurrentTimeTo: time,
                for: currentMedia
            )

        case let .didReachEnd(time):
            guard let currentMedia else { return }
            delegate?.akPlayer(self, didReachEndAt: time, for: currentMedia)

        case let .boundaryReached(time):
            guard let currentMedia else { return }
            delegate?.akPlayer(
                self,
                didInvokeBoundaryTimeObserverAt: time,
                for: currentMedia
            )

        case let .playbackRateDidChange(newRate, previousRate):
            delegate?.akPlayer(
                self,
                didChangePlaybackRateTo: newRate,
                from: previousRate
            )

        case let .volumeDidChange(volume):
            delegate?.akPlayer(self, didChangeVolumeTo: volume)

        case let .muteStatusDidChange(isMuted):
            delegate?.akPlayer(self, didChangeMutedStatusTo: isMuted)

        case let .sharePlayStateDidChange:
            break

        case let .commandUnavailable(reason):
            delegate?.akPlayer(self, didEncounterUnavailableAction: reason)

        case let .didFail(error):
            delegate?.akPlayer(self, didFailWith: error)
        }
    }
}
