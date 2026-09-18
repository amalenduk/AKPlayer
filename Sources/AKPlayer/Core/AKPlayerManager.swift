//
//   AKPlayerManager.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import MediaPlayer

// MARK: - AKPlayerManager

/// Main orchestrator managing audio session lifecycles, player controls,
/// lifecycle observer updates, and `MPNowPlayingInfoCenter` integrations.
@MainActor
public class AKPlayerManager: NSObject, AKPlayerManagerProtocol {
    // MARK: - Properties
    
    /// The underlying `AVPlayer` instance controlling media playback.
    public var player: AVPlayer {
        playerController.player
    }
    
    /// Current state of the player (e.g., playing, paused, stopped, failed).
    public var state: AKPlayerState {
        playerController.state
    }
    
    /// Default rate used when initiating media playback.
    public var defaultRate: AKPlaybackRate {
        get { playerController.defaultRate }
        set { playerController.defaultRate = newValue }
    }
    
    /// Current rate of audio playback (1.0 = normal, 0.0 = paused).
    public var rate: AKPlaybackRate {
        get { playerController.rate }
        set { playerController.rate = newValue }
    }
    
    /// The current active playable media metadata item.
    public var currentMedia: (any AKPlayable)? {
        playerController.currentMedia
    }
    
    /// The current `AVPlayerItem` loaded in the player.
    public var currentItem: AVPlayerItem? {
        playerController.currentItem
    }
    
    /// The total duration of the currently playing item as `CMTime`.
    public var currentItemDuration: CMTime {
        playerController.currentItemDuration
    }
    
    /// The current playback position in time as `CMTime`.
    public var currentTime: CMTime {
        playerController.currentTime
    }
    
    /// The remaining playback time of the active item, if available.
    public var remainingTime: CMTime? {
        playerController.remainingTime
    }
    
    /// Flag indicating whether playback starts automatically upon loading
    /// media.
    public var autoPlay: Bool {
        playerController.autoPlay
    }
    
    /// Flag indicating if a seek action is currently in progress.
    public var isSeeking: Bool {
        playerController.isSeeking
    }
    
    /// The target time or position requested during the latest seek command.
    public var lastRequestedSeekPosition: AKSeekTarget? {
        playerController.lastRequestedSeekPosition
    }
    
    /// The current output volume level (0.0 to 1.0).
    public var volume: Float {
        get { playerController.volume }
        set { playerController.volume = newValue }
    }
    
    /// Flag indicating whether the player volume is muted.
    public var isMuted: Bool {
        get { playerController.isMuted }
        set { playerController.isMuted = newValue }
    }
    
    /// Contains player errors if any occur during initialization or playback.
    public var error: AKPlayerError? {
        playerController.error
    }
    
    /// Asynchronous stream of player events for Swift Concurrency.
    public var events: AsyncStream<AKPlayerEvent> {
        playerController.events
    }
    
    /// Controller managing underlying AVPlayer actions and state machine
    /// transitions.
    public let playerController: AKPlayerControllerProtocol
    
    /// Configuration options governing player behavior, audio session settings,
    /// and remote controls.
    public var configuration: AKPlayerConfigurationProtocol {
        playerController.configuration
    }
    
    /// Snapshot storing playback and app states during interruptions for
    /// resumption logic.
    public private(set) var playerStateSnapshot: AKPlayerStateSnapshot?
    
    private let eventBroadcaster = AKEventBroadcaster<AKPlayerEvent>()
    
    /// Task managing the asynchronous event stream from the player controller.
    private var playerEventsTask: Task<Void, Never>?
    
    /// Tracks connection status of external audio devices (e.g., Bluetooth,
    /// headphones).
    private var isExternalAudioPlaybackDeviceConnected = false
    
    /// Audio session service managing system category, modes, and activation
    /// state.
    public let audioSessionService: AKAudioSessionServiceProtocol
    
    /// Session handling integration with system Now Playing info and lock
    /// screen controls.
    public var nowPlayingManager: (any AKNowPlayingManagerProtocol)?
    
    /// Observer responsible for audio interruption notifications (e.g.,
    /// incoming phone calls).
    private var audioSessionInterruptionObserver: (any AKAudioSessionInterruptionObserverProtocol)!
    
    /// Observer handling route changes (e.g., unplugging headphones or
    /// disconnecting Bluetooth).
    private var audioSessionRouteChangesObserver: (any AKAudioSessionRouteChangesObserverProtocol)!
    
    /// Observer handling `mediaServicesWereReset` system restore notifications.
    private var audioSessionMediaServicesWereResetObserver:
    (any AKAudioSessionMediaServicesWereResetObserverProtocol)!
    
    /// Observer monitoring app lifecycle changes (entering
    /// background/foreground, resigning active).
    private var applicationLifeCycleEventsObserver: (any AKApplicationLifeCycleEventsObserverProtocol)!
    
    private var applicationLifeCycleEventsTask: Task<Void, Never>?
    private var audioSessionInterruptionTask: Task<Void, Never>?
    private var audioSessionRouteChangesTask: Task<Void, Never>?
    private var audioSessionMediaServicesResetTask: Task<Void, Never>?
    
    // MARK: - Init & Deinit
    
    /// Initializes a new instance of `AKPlayerManager`.
    /// - Parameters:
    ///   - player: The `AVPlayer` instance used for playback.
    ///   - configuration: Configuration settings for player audio and control
    /// parameters.
    ///   - audioSessionService: Service interface for managing
    /// `AVAudioSession`.
    public init(
        player: AVPlayer,
        configuration: AKPlayerConfigurationProtocol,
        audioSessionService: AKAudioSessionServiceProtocol
    ) {
        defer {
            AKLogger.logInit(self)
        }
        playerController = AKPlayerController(
            player: player,
            configuration: configuration
        )
        self.audioSessionService = audioSessionService
        super.init()
        
        audioSessionInterruptionObserver = AKAudioSessionInterruptionObserver(
            audioSession: audioSessionService.audioSession
        )
        audioSessionRouteChangesObserver = AKAudioSessionRouteChangesObserver(
            audioSession: audioSessionService.audioSession
        )
        audioSessionMediaServicesWereResetObserver =
        AKAudioSessionMediaServicesWereResetObserver(
            audioSession: audioSessionService.audioSession
        )
        applicationLifeCycleEventsObserver = AKApplicationLifeCycleEventsObserver()
        
        if configuration.isNowPlayingEnabled {
            nowPlayingManager = AKNowPlayingManager(playerManager: self)
        }
        
        startObservingPlayerEvents()
        startObservingLifeCycleEvents()
        startObservingAudioSessionEvents()
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
        applicationLifeCycleEventsTask?.cancel()
        applicationLifeCycleEventsTask = nil
        audioSessionInterruptionTask?.cancel()
        audioSessionInterruptionTask = nil
        audioSessionRouteChangesTask?.cancel()
        audioSessionRouteChangesTask = nil
        audioSessionMediaServicesResetTask?.cancel()
        audioSessionMediaServicesResetTask = nil
        eventBroadcaster.finish()
    }
    
    // MARK: - Lifecycle Preparation
    
    /// Configures the audio session, prepares the player controller, activates
    /// Now Playing, and begins system observers.
    /// - Throws: `AKPlayerError` or `AVAudioSession` setup errors during
    /// initialization.
    public func prepare() async throws {
        try setAudioSession(true)
        try playerController.prepare()
        try await nowPlayingManager?.start()
        
        startObservers()
        isExternalAudioPlaybackDeviceConnected =
        audioSessionRouteChangesObserver.isExternalDeviceConnected()
    }
    
    // MARK: - Boundary Observers
    
    /// Adds boundary time tracking points to notify when playback reaches
    /// explicit timestamps.
    /// - Parameter times: Array of `CMTime` markers to observe.
    public func addBoundaryTimeObserver(for times: [CMTime]) {
        playerController.addBoundaryTimeObserver(for: times)
    }
    
    /// Removes active boundary time observers from the underlying player.
    public func removeBoundaryTimeObserver() {
        playerController.removeBoundaryTimeObserver()
    }
    
    // MARK: - Playback Commands
    
    /// Loads a media item into the player controller with optional
    /// auto-playback and initial seek target.
    /// - Parameters:
    ///   - media: Any playable item conforming to `AKPlayable`.
    ///   - autoPlay: Whether playback should start automatically after loading.
    ///   - position: Optional seek target location to initialize playback at.
    public func load(
        media: any AKPlayable,
        autoPlay: Bool,
        at position: AKSeekTarget?
    ) {
        guard canPlayInCurrentLifecycleState()
        else { return actionNotPermitted() }
        return performPlaybackAction { [weak self] in
            self?.playerController.load(
                media: media,
                autoPlay: autoPlay,
                at: position
            )
        }
    }
    
    /// Initiates media playback at normal default speed.
    public func play() {
        guard canPlayInCurrentLifecycleState()
        else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in self?.playerController.play() }
    }
    
    /// Initiates media playback at a specified custom rate.
    /// - Parameter rate: Speed target encapsulated by `AKPlaybackRate`.
    public func play(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState()
        else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.play(at: rate)
        }
    }
    
    /// Pauses active playback.
    public func pause() {
        playerController.pause()
    }
    
    /// Toggles between play and pause states based on current state.
    public func togglePlayPause() {
        switch state {
        case .loaded where !autoPlay, .paused, .stopped, .failed:
            guard canPlayInCurrentLifecycleState()
            else { return actionNotPermitted() }
            performPlaybackAction { [weak self] in
                self?.playerController.togglePlayPause()
            }
        default:
            playerController.togglePlayPause()
        }
    }
    
    /// Stops playback and invalidates active state resumption flags.
    public func stop() {
        playerStateSnapshot?.shouldResume = false
        playerController.stop()
    }
    
    /// Asynchronously seeks to a specific time target.
    /// - Parameter target: The position target defined as an `AKSeekTarget`.
    /// - Returns: `true` if the seek completed successfully; otherwise `false`.
    @discardableResult
    public func seek(to target: AKSeekTarget) async -> Bool {
        await playerController.seek(to: target)
    }
    
    /// Asynchronously seeks to a specific target within specified exact
    /// tolerance windows.
    /// - Parameters:
    ///   - target: The position target defined as an `AKSeekTarget`.
    ///   - toleranceBefore: Maximum allowed time delta before the target
    /// position.
    ///   - toleranceAfter: Maximum allowed time delta after the target
    /// position.
    /// - Returns: `true` if the seek completed successfully; otherwise `false`.
    @discardableResult
    public func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async
    -> Bool
    {
        await playerController.seek(
            to: target,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter
        )
    }
    
    public func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        playerController.seek(to: target, completionHandler: completionHandler)
    }
    
    public func seek(
        to target: AKSeekTarget, toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        playerController.seek(
            to: target, toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }
    
    /// Steps forward or backward by a specific number of frames.
    /// - Parameter count: Positive integer for forward frame steps, negative
    /// for backward steps.
    public func step(by count: Int) {
        playerController.step(by: count)
    }
    
    /// Fast-forwards playback using default fast rate settings.
    public func fastForward() {
        guard canPlayInCurrentLifecycleState()
        else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.fastForward()
        }
    }
    
    /// Fast-forwards playback at a custom rate speed.
    /// - Parameter rate: Speed target encapsulated by `AKPlaybackRate`.
    public func fastForward(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState()
        else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.fastForward(at: rate)
        }
    }
    
    /// Rewinds playback using default rewind settings.
    public func rewind() {
        guard canPlayInCurrentLifecycleState()
        else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.rewind()
        }
    }
    
    /// Rewinds playback at a custom rate speed.
    /// - Parameter rate: Speed target encapsulated by `AKPlaybackRate`.
    public func rewind(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState()
        else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.rewind(at: rate)
        }
    }
    
    // MARK: - Internal Helper Functions
    
    /// Subscribes system observers to route changes, interruptions, media
    /// resets, and lifecycle events.
    private func startObservers() {
        audioSessionInterruptionObserver.startObserving()
        audioSessionRouteChangesObserver.startObserving()
        audioSessionMediaServicesWereResetObserver.startObserving()
        applicationLifeCycleEventsObserver.startObserving()
    }
    
    /// Unsubscribes active observers from system notifications.
    private func stopObservers() {
        audioSessionInterruptionObserver.stopObserving()
        audioSessionRouteChangesObserver.stopObserving()
        audioSessionMediaServicesWereResetObserver.stopObserving()
        applicationLifeCycleEventsObserver.stopObserving()
    }
    
    /// Configures system `AVAudioSession` categories, options, and active
    /// states.
    /// - Parameter active: `true` to activate the audio session; `false` to
    /// deactivate.
    /// - Throws: Session setup errors thrown by system calls.
    private func setAudioSession(_ active: Bool) throws {
        guard active else {
            return try audioSessionService.activate(
                false,
                options: configuration.audioSession.activeOptions
            )
        }
        
        try audioSessionService.setCategory(
            configuration.audioSession.category,
            mode: configuration.audioSession.mode,
            options: configuration.audioSession.categoryOptions
        )
        try audioSessionService.activate(
            true,
            options: configuration.audioSession.activeOptions
        )
    }
    
    /// Verifies if app configuration rules allow playback based on the current
    /// background/inactive application state.
    /// - Returns: `true` if current lifecycle conditions allow playback to
    /// begin or resume.
    private func canPlayInCurrentLifecycleState() -> Bool {
        switch applicationLifeCycleEventsObserver.state {
        case .resignActive
            where configuration.playbackPausesWhenResigningActive: false
        case .background
            where configuration.playbackPausesWhenBackgrounded: false
        default: true
        }
    }
    
    /// Safely executes throwing blocks and forwards errors to the delegate
    /// interface.
    /// - Parameters:
    ///   - block: Closure containing throwing operations.
    ///   - completion: Callback indicating whether execution succeeded without
    /// throwing.
    private func execute(
        block: () throws -> Void,
        completion: (Bool) -> Void = { _ in }
    ) {
        do {
            try block()
            return completion(true)
        } catch {
            let playerError = (error as? AKPlayerError) ?? .playerCanNoLongerPlay(error: error)
    emit(.didFail(with: playerError))
        }
        return completion(false)
    }
    
    /// Captures the current application lifecycle and playback interruption
    /// state to handle automatic state recovery.
    /// - Parameters:
    ///   - playbackInterruptionReason: The underlying reason for the
    /// interruption.
    ///   - shouldResume: Whether playback should automatically resume when the
    /// interruption ends.
    private func savePlayerStateSnapshot(
        playbackInterruptionReason: AKPlaybackInterruptionReason,
        shouldResume: Bool
    ) {
        guard var snapshot = playerStateSnapshot else {
            playerStateSnapshot = AKPlayerStateSnapshot(
                shouldResume: shouldResume,
                applicationState: applicationLifeCycleEventsObserver.state,
                playbackInterruptionReason: playbackInterruptionReason
            )
            return
        }
        
        snapshot.applicationState = applicationLifeCycleEventsObserver.state
        playerStateSnapshot = snapshot
    }
    
    /// Clears any cached player state snapshot.
    private func clearPlayerStateSnapshot() {
        playerStateSnapshot = nil
    }
    
    /// Notifies the delegate when an action is unavailable due to lifecycle or
    /// state restrictions.
    private func actionNotPermitted() {
        emit(.commandUnavailable(reason: .actionNotPermitted))
    }
    
    /// Wraps playback operations to check audio session activation and snapshot
    /// clearance before execution.
    /// - Parameter action: Closure containing playback action commands.
    private func performPlaybackAction(action: () -> Void) {
        guard let snapshot = playerStateSnapshot else { return action() }
        if snapshot.playbackInterruptionReason.isLifeCycleEvent
            || snapshot.applicationState.isResignActiveOrBackground
        {
            execute {
                try setAudioSession(true)
            } completion: { finished in
                if finished {
                    action()
                }
            }
        } else {
            action()
        }
        clearPlayerStateSnapshot()
    }
    
    /// Single entry point for dispatching all player events across the
    /// framework.
    /// Broadcasts the event to the delegate and forwards it to event listeners
    /// (`AsyncStream`).
    /// - Parameter event: The player event that occurred.
    private func emit(_ event: AKPlayerEvent) {
        eventBroadcaster.send(event)
    }
    
    private func startObservingPlayerEvents() {
        playerEventsTask?.cancel()
        
        playerEventsTask = Task { [weak self] in
            guard let events = self?.playerController.events else { return }
            
            for await event in events {
                guard !Task.isCancelled, let self else { break }
                
                self.handleControllerEvent(event)
            }
        }
    }
    
    private func handleControllerEvent(_ event: AKPlayerEvent) {
        eventBroadcaster.send(event)
    }
    
    private func startObservingLifeCycleEvents() {
        applicationLifeCycleEventsTask?.cancel()
        
        applicationLifeCycleEventsTask = Task { [weak self] in
            guard let stream = self?.applicationLifeCycleEventsObserver.events else { return }
            for await event in stream {
                guard !Task.isCancelled, let self else { break }
                self.handleApplicationLifeCycleEvent(event)
            }
        }
    }
    
    private func handleApplicationLifeCycleEvent(_ event: AKApplicationLifeCycleEvent) {
        switch event {
        case .willResignActive:
            if configuration.playbackPausesWhenResigningActive {
                if autoPlay || state == .playing {
                    savePlayerStateSnapshot(
                        playbackInterruptionReason: .applicationResignActive,
                        shouldResume: true
                    )
                    pause()
                }
                execute { try self.setAudioSession(false) }
            } else {
                if !autoPlay, !state.isPlaying {
                    savePlayerStateSnapshot(
                        playbackInterruptionReason: .applicationResignActive,
                        shouldResume: false
                    )
                    execute { try self.setAudioSession(false) }
                }
            }
        case .didBecomeActive:
            guard configuration.playbackResumesWhenBecameActive,
                  let snapshot = playerStateSnapshot,
                  snapshot.playbackInterruptionReason.isLifeCycleEvent,
                  snapshot.shouldResume
            else { return }
            
            play()
        case .didEnterBackground:
            if configuration.playbackPausesWhenBackgrounded {
                if autoPlay || state == .playing {
                    savePlayerStateSnapshot(
                        playbackInterruptionReason: .applicationEnteredBackground,
                        shouldResume: true
                    )
                    pause()
                }
                execute { try self.setAudioSession(false) }
            } else {
                if !autoPlay, !state.isPlaying {
                    savePlayerStateSnapshot(
                        playbackInterruptionReason: .applicationEnteredBackground,
                        shouldResume: false
                    )
                    execute { try self.setAudioSession(false) }
                }
            }
        case .willEnterForeground:
            guard configuration.playbackResumesWhenEnteringForeground,
                  let snapshot = playerStateSnapshot,
                  snapshot.playbackInterruptionReason.isLifeCycleEvent,
                  snapshot.shouldResume
            else { return }
            
            play()
        }
    }
    private func startObservingAudioSessionEvents() {
        audioSessionInterruptionTask?.cancel()
        audioSessionInterruptionTask = Task { [weak self] in
            guard let stream = self?.audioSessionInterruptionObserver.events else { return }
            for await event in stream {
                guard !Task.isCancelled, let self else { break }
                self.handleAudioSessionInterruptionEvent(event)
            }
        }
        
        audioSessionRouteChangesTask?.cancel()
        audioSessionRouteChangesTask = Task { [weak self] in
            guard let stream = self?.audioSessionRouteChangesObserver.events else { return }
            for await event in stream {
                guard !Task.isCancelled, let self else { break }
                self.handleAudioSessionRouteChangeEvent(event)
            }
        }
        
        audioSessionMediaServicesResetTask?.cancel()
        audioSessionMediaServicesResetTask = Task { [weak self] in
            guard let stream = self?.audioSessionMediaServicesWereResetObserver.events else { return }
            for await _ in stream {
                guard !Task.isCancelled, let self else { break }
                self.handleMediaServicesWereReset()
            }
        }
    }
    
    private func handleAudioSessionInterruptionEvent(_ event: AKAudioSessionInterruptionEvent) {
        switch event {
        case .began:
            guard
                (state.isAny(of: [
                    .loading,
                    .loaded,
                    .buffering,
                    .waitingForNetwork,
                ]) && autoPlay)
                    || state == .playing
            else { return }
            
            savePlayerStateSnapshot(
                playbackInterruptionReason: .audioSessionInterruption,
                shouldResume: true
            )
            pause()
            
        case .ended(let shouldResume):
            guard configuration.playbackResumesWhenAudioSessionInterruptionEnded,
                  let snapshot = playerStateSnapshot,
                  snapshot.playbackInterruptionReason == .audioSessionInterruption,
                  snapshot.shouldResume, shouldResume
            else { return }
            
            play()
        }
    }
    
    private func handleAudioSessionRouteChangeEvent(_ event: AKAudioSessionRouteChangeEvent) {
        let isExternalDeviceConnected = audioSessionRouteChangesObserver.isExternalDeviceConnected()
        defer {
            self.isExternalAudioPlaybackDeviceConnected = isExternalDeviceConnected
        }
        
        guard
            self.isExternalAudioPlaybackDeviceConnected
                && !isExternalDeviceConnected
                && (state.isAny(of: [
                    .loading,
                    .loaded,
                    .buffering,
                    .waitingForNetwork,
                ]) && autoPlay)
                || state == .playing
        else { return }
        
        pause()
    }
    
    private func handleMediaServicesWereReset() {
        stop()
    }
}


