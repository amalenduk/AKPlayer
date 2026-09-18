//
//   AKBaseState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import Network

// MARK: - AKPlayerAction

/// Enumeration representing actionable playback intents evaluated by player
/// state machine preflight checks.
public enum AKPlayerAction: Equatable, Sendable {
    case load
    case play
    case pause
    case stop
    case seek(to: AKSeekTarget)
    case step(by: Int)
    case fastForward
    case rewind
}

// MARK: - AKBaseState

/// Base class for player states implementing state machine logic, preflight
/// validation checks, and action handling.
@MainActor
public class AKBaseState: AKPlayerStateControllerProtocol {
    
    // MARK: - Properties
    
    /// Unowned reference to the parent player controller context.
    public unowned let playerController: any AKPlayerControllerProtocol
    
    /// The explicit player state represented by this class instance.
    public let state: AKPlayerState
    
    public private(set) var hasTransitioned = false
    
    public private(set) var isActiveState = false
    
    // MARK: - Initialization
    
    /// Initializes a base state instance associated with a specific player
    /// controller and state classification.
    /// - Parameters:
    ///   - playerController: The target player controller executing playback
    /// commands.
    ///   - state: The concrete player state classification represented by this
    /// instance.
    public init(
        playerController: any AKPlayerControllerProtocol,
        state: AKPlayerState
    ) {
        self.playerController = playerController
        self.state = state
    }
    
    deinit { }
    
    /// Called when the player transitions into this state. Concrete state
    /// subclasses override to perform setup.
    public func processStateChange() {
        isActiveState = true
    }
    
    // MARK: - Commands
    
    // MARK: 1. Loading Media
    
    /// Initiates loading of a new playable media item into the player pipeline.
    /// - Parameters:
    ///   - media: The playable media target.
    ///   - autoPlay: Controls whether playback should automatically start when
    /// media is ready.
    ///   - position: An optional initial seek target position to apply on load.
    public func load(
        media: any AKPlayable,
        autoPlay: Bool,
        at position: AKSeekTarget?
    ) {
        startLoad(media: media, autoPlay: autoPlay, at: position)
    }
    
    // MARK: 2. Controlling Playback
    
    /// Commands the player to begin media playback.
    public func play() {
        performIfAllowed(
            check: { availability(for: .play) },
            action: {
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: true
                )
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    /// Commands the player to begin media playback at a specified speed
    /// multiplier.
    /// - Parameter rate: The targeted playback rate.
    public func play(at rate: AKPlaybackRate) {
        performIfAllowed(
            check: {
                availability(for: .play)
            },
            action: {
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: true,
                    rate: rate
                )
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    /// Commands the player to pause active media playback.
    public func pause() {
        performIfAllowed(
            check: { availability(for: .pause) },
            action: {
                let controller = AKPausedState(playerController: playerController)
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    /// Toggles between play and pause states depending on current active
    /// playback state.
    public func togglePlayPause() {
        if state.isPlaying || autoPlay {
            pause()
        } else {
            play()
        }
    }
    
    /// Stops playback and tears down active player pipeline.
    public func stop() {
        guard !hasTransitioned && state != .stopped else { return }
        performIfAllowed(
            check: { availability(for: .stop) },
            action: {
                beforeStop()
                let controller = AKStoppedState(playerController: playerController)
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    // MARK: 3. Seeking Through Media
    
    /// Asynchronously seeks to a given target position within current media.
    @discardableResult
    public func seek(to target: AKSeekTarget) async -> Bool {
        await withCheckedContinuation { con in
            seek(to: target) { finished in
                con.resume(returning: finished)
            }
        }
    }
    
    /// Asynchronously seeks to a given target position with explicit tolerance parameters.
    @discardableResult
    public func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool {
        await withCheckedContinuation { con in
            seek(
                to: target,
                toleranceBefore: toleranceBefore,
                toleranceAfter: toleranceAfter
            ) { finished in
                con.resume(returning: finished)
            }
        }
    }
    
    /// Seeks to a designated target position with a completion handler callback.
    public func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        seek(
            to: target,
            toleranceBefore: .positiveInfinity,
            toleranceAfter: .positiveInfinity,
            completionHandler: completionHandler
        )
    }
    
    /// Seeks to a designated target position with custom tolerance bounds and a completion handler callback.
    public func seek(
        to target: AKSeekTarget,
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
                guard let self else {
                    completionHandler(false)
                    return
                }
                let seekToken = AKSeek(
                    target: target,
                    toleranceBefore: toleranceBefore,
                    toleranceAfter: toleranceAfter,
                    completionHandler: completionHandler
                )
                
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: state.isPlaying || autoPlay,
                    targetSeek: seekToken
                )
                
                change(controller)
            },
            blocked: { [weak self] reason in
                completionHandler(false)
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    // MARK: 4. Media Navigation
    
    /// Steps frame-by-frame through video media by a specified frame count
    /// offset.
    /// - Parameter count: The frame offset count (positive for forward,
    /// negative for reverse).
    public func step(by count: Int) {
        performIfAllowed(
            check: { [weak self] in
                guard let self else { return (false, nil) }
                return availability(for: .step(by: count))
            },
            action: { [weak self] in
                guard let self else { return }
                playerController.performStep(by: count)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    /// Fast-forwards playback using default fast-forward speed defined in
    /// player configuration.
    public func fastForward() {
        play(at: playerController.configuration.fastForwardRate)
    }
    
    /// Fast-forwards playback at a custom speed multiplier.
    /// - Parameter rate: The target fast-forward playback speed rate.
    public func fastForward(at rate: AKPlaybackRate) {
        play(at: rate)
    }
    
    /// Rewinds playback using default rewind speed defined in player
    /// configuration.
    public func rewind() {
        play(at: playerController.configuration.rewindRate)
    }
    
    /// Rewinds playback at a custom speed multiplier.
    /// - Parameter rate: The target rewind playback speed rate.
    public func rewind(at rate: AKPlaybackRate) {
        play(at: rate)
    }
    
    // MARK: - State Management Helpers
    
    /// Transitions the state machine context to a new target state instance.
    /// - Parameter controller: The target state controller to activate.
    public func change(_ controller: any AKPlayerStateControllerProtocol) {
        guard !hasTransitioned else { return }
        isActiveState = false
        hasTransitioned = true
        beforeStateChange()
        playerController.change(controller)
    }
    
    /// Validates an action requirement and executes an asynchronous task if
    /// permission check succeeds.
    /// - Parameters:
    ///   - check: Preflight verification closure evaluating action permission
    /// and returning blocking reasons on failure.
    ///   - action: Asynchronous operation closure executed if permission check
    /// succeeds.
    ///   - blocked: Closure called on preflight failure with the associated
    /// reason.
    ///   - fallback: Fallback value returned when action execution is blocked
    /// or prohibited.
    /// - Returns: The result of `action` if allowed; otherwise, `fallback`.
    @discardableResult
    public func performIfAllowed<T: Sendable>(
        check: @MainActor () -> (Bool, AKPlayerUnavailableCommandReason?),
        action: @MainActor () async -> T,
        blocked: (@MainActor (AKPlayerUnavailableCommandReason) -> Void)? = nil,
        fallback: T
    ) async -> T {
        let (allowed, reason) = check()
        guard allowed else {
            if let reason {
                blocked?(reason)
            }
            return fallback
        }
        
        return await action()
    }
    
    /// Validates an action requirement and executes a synchronous task if permission check succeeds.
    /// - Parameters:
    ///   - check: Preflight verification closure evaluating action permission and returning blocking reasons on failure.
    ///   - action: Synchronous operation closure executed if permission check succeeds.
    ///   - blocked: Closure called on preflight failure with the associated reason.
    ///   - fallback: Fallback value returned when action execution is blocked or prohibited.
    /// - Returns: The result of `action` if allowed; otherwise, `fallback`.
    @discardableResult
    public func performIfAllowed<T>(
        check: () -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?),
        action: () -> T,
        blocked: ((AKPlayerUnavailableCommandReason) -> Void)? = nil,
        fallback: T
    ) -> T {
        let (allowed, reason) = check()
        guard allowed else {
            if let reason {
                blocked?(reason)
            }
            return fallback
        }
        
        return action()
    }
    
    /// Evaluates preflight permission and unavailable reasons for a given
    /// player action.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple containing a boolean flag indicating if allowed, and
    /// an optional unavailability reason.
    public func availability(for action: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        switch action {
        case let .seek(to: target):
            guard let currentMedia = playerController.currentMedia else {
                return (false, .loadMediaFirst)
            }
            
            let (flag, reason) = currentMedia.seekingThroughMedia
                .canSeek(to: target)
            return (allowed: flag, reason: reason)
            
        case let .step(by: count):
            guard let currentMedia = playerController.currentMedia else {
                return (false, .loadMediaFirst)
            }
            
            let result = currentMedia.canStep(by: count)
            return (
                allowed: result,
                reason: result
                ? nil
                : (count > 0 ? .canNotStepForward : .canNotStepBackward)
            )
            
        default:
            return (true, nil)
        }
    }
    
    /// Subscribes to system network status changes asynchronously.
    /// - Parameter handler: Closure invoked when network connectivity status changes.
    /// - Returns: A structured `Task` managing the observation lifetime.
    @discardableResult
    public func observeNetworkStatus(
        handler: @escaping @MainActor (NWPath.Status) -> Void
    ) -> Task<Void, Never>? {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.isOverNetwork()
        else {
            return nil
        }
        
        return Task { @MainActor [weak self] in
            guard let monitor = self?.playerController.networkStatusMonitor else { return }
            for await status in monitor.networkStatus {
                guard !Task.isCancelled, let _ = self else { break }
                handler(status)
            }
        }
    }
    
    // MARK: - Private Pipeline
    
    /// Internal helper method executing pre-load lifecycle hooks and
    /// constructing initial loading state.
    /// - Parameters:
    ///   - media: The playable media item to load.
    ///   - autoPlay: Whether playback should start automatically upon load
    /// completion.
    ///   - position: An optional seek target position to apply once loading
    /// completes.
    private func startLoad(
        media: any AKPlayable,
        autoPlay: Bool,
        at position: AKSeekTarget?
    ) {
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        let controller = AKLoadingState(
            playerController: playerController,
            media: media,
            autoPlay: autoPlay,
            position: position
        )
        change(controller)
    }
    
    /// Determines whether the media buffer conditions are sufficient to allow playback.
    public func canPlay() -> Bool {
        guard let playerItem = playerController.currentMedia?.playerItem,
              !playerController.isSeeking
        else { return false }
        
        if playerItem.isPlaybackBufferFull || playerItem.isPlaybackLikelyToKeepUp {
            return true
        }
        
        // Also allow playback if there is at least 1.5s of loaded buffer ahead of current playback time
        let currentTime = playerItem.currentTime()
        if currentTime.isValid && !currentTime.isIndefinite {
            for rangeValue in playerItem.loadedTimeRanges {
                let range = rangeValue.timeRangeValue
                if CMTimeRangeContainsTime(range, time: currentTime) {
                    let bufferedAhead = range.end - currentTime
                    if bufferedAhead.seconds >= 1.5 {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Hook executed immediately prior to stopping media playback.
    public func beforeStop() {}
    
    /// Hook executed immediately prior to performing state transitions.
    public func beforeStateChange() { }
    
    public func handlePlayerStatusChange(_ status: AVPlayer.Status) {}
    
    public func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {}
    
    public func handle(_ event: AKPlayerItemNotificationEvent) {}
}
