//
//   AKPlayingState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKPlayingState

/// Concrete state representing active media playback.
@MainActor
public class AKPlayingState: AKBaseState {
    // MARK: - Properties
    
    /// The target playback speed multiplier requested when entering the playing
    /// state.
    private var rate: AKPlaybackRate?
    
    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()
    
    private var playingStarted: Bool = false
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a playing state instance associated with the specified
    /// player controller.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving
    /// execution.
    ///   - rate: An optional initial playback speed multiplier.
    public init(
        playerController: any AKPlayerControllerProtocol,
        rate: AKPlaybackRate? = nil
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.rate = rate
        super.init(playerController: playerController, state: .playing)
    }
    
    deinit {
        defer {
            AKLogger.logDeinit(
                String(describing: Self.self),
                pointer: Unmanaged.passUnretained(self)
            )
        }
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Entry point for playing state setup. Begins observing player status and
    /// item notifications, triggers playback, and applies targeted playback
    /// rate.
    override public func processStateChange() {
        super.processStateChange()
        startObservingPlayerItemNotifications()
        
        if let rate, playerController.player.rate != rate.rate {
            play(at: rate)
        } else {
            playerController.performPlay()
        }
    }
    
    /// Cleans up Combine observation pipelines before transitioning to another
    /// state.
    override public func beforeStateChange() {
        subscriptions.forEach({ $0.cancel() })
        subscriptions.removeAll()
    }
    
    // MARK: - Commands
    
    /// Adjusts playback rate when supported by the current media item.
    /// - Parameter rate: The targeted playback speed multiplier.
    override public func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.canPlay(at: rate)
        else {
            playerController
                .emit(.commandUnavailable(reason: .canNotPlayAtSpecifiedRate))
            return
        }
        
        self.rate = rate
        playerController.performPlay(at: rate)
    }
    
    // MARK: - Private Helper Functions
    
    public override func handlePlayerStatusChange(_ status: AVPlayer.Status) {
        guard status == .failed else { return }
        let controller = AKFailedState(
            playerController: playerController,
            error: .playerCanNoLongerPlay(
                error: playerController.player
                    .error
            )
        )
        change(controller)
    }
    
    public override func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        switch playerController.player.timeControlStatus {
        case .playing:
            playingStarted = true
            print("From palying state play")
        case .waitingToPlayAtSpecifiedRate:
            guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay,
                  let currentItem = playerController.currentItem else { return }
            switch reasonForWaitingToPlay {
            case .evaluatingBufferingRate, .toMinimizeStalls, .waitingForCoordinatedPlayback:
                guard let currentItem = playerController.currentItem else { return }
                playingStarted = true
                guard currentItem.isPlaybackBufferFull && currentItem.isPlaybackLikelyToKeepUp else {
                    
                    let controller = AKBufferingState(
                        playerController: playerController,
                        autoPlay: true,
                        rate: rate
                    )
                    return change(controller)
                }
            case .noItemToPlay:
                stop()
            default:
                break
            }
        case .paused:
            guard playingStarted else { return }
            pause()
        default:
            break
        }
    }
    
    /// Registers notification listeners for player item playback completion,
    /// failure, and buffering stall conditions.
    private func startObservingPlayerItemNotifications() {
        guard let playerItem = playerController.currentMedia?.playerItem
        else { return }
        
        NotificationCenter.default.publisher(
            for: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
        .sink { [weak self] notification in
            guard let self,
                  let error = notification
                .userInfo?[
                    AVPlayerItemFailedToPlayToEndTimeErrorKey
                ] as? NSError
            else { return }
            
            guard error is URLError else {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .itemFailedToPlayToEndTime
                )
                return change(controller)
            }
            
            let controller = AKBufferingState(playerController: playerController, autoPlay: true, rate: rate)
            change(controller)
        }
        .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(
            for: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem
        )
        .sink { [weak self] _ in
            guard let self else { return }
            
            let controller = AKPausedState(
                playerController: playerController,
                playerItemDidPlayToEndTime: true
            )
            change(controller)
        }
        .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(
            for: AVPlayerItem.playbackStalledNotification,
            object: playerItem
        )
        .sink { [weak self] _ in
            guard let self, let media = playerController.currentMedia else { return }
            
            /*
             he notification’s object is the player item whose playback is unable to continue due to network delays. Streaming-media playback continues after the player item retrieves a sufficient amount of data. File-based playback doesn’t continue.
             */
            if media.isLocal()  {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .itemFailedToPlayToEndTime
                )
                return change(controller)
            }
            let controller = AKBufferingState(
                playerController: playerController,
                autoPlay: true,
                rate: rate
            )
            change(controller)
        }
        .store(in: &subscriptions)
    }
    
    // MARK: - Availability Overrides
    
    /// Evaluates preflight permission and unavailable reasons for a given
    /// player action when actively playing.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.alreadyPlaying` for `.play`
    /// action; base availability otherwise.
    override public func availability(for action: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        switch action {
        case .play:
            (false, .alreadyPlaying)
        default:
            super.availability(for: action)
        }
    }
}
