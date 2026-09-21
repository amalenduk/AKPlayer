//
//   AKPlayingState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayingState

/// Concrete state representing active media playback.
@MainActor
public class AKPlayingState: AKBaseState {
    // MARK: - Properties
    
    /// The target playback speed multiplier requested when entering the playing state.
    private var rate: AKPlaybackRate?
    
    private var playingStarted: Bool = false
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a playing state instance associated with the specified player controller.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving execution.
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
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Entry point for playing state setup. Begins playback and applies targeted playback rate.
    override public func processStateChange() {
        super.processStateChange()
        
        if playerController.player.timeControlStatus == .playing {
            playingStarted = true
        }
        
        if let rate, playerController.player.rate != rate.rate {
            play(at: rate)
        } else {
            playerController.performPlay()
        }
    }
    
    // MARK: - Commands
    
    /// Adjusts playback rate when supported by the current media item.
    /// - Parameter rate: The targeted playback speed multiplier.
    override public func play(at rate: AKPlaybackRate) {
        performIfAllowed(
            check: { availability(for: .play(at: rate)) },
            action: {
                self.rate = rate
                playerController.performPlay(at: rate)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    // MARK: - Player Lifecycle & Notifications
    
    override public func handlePlayerStatusChange(_ status: AVPlayer.Status) {
        guard isActiveState else { return }
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
        guard isActiveState else { return }
        switch playerController.player.timeControlStatus {
        case .playing:
            playingStarted = true
        case .waitingToPlayAtSpecifiedRate:
            guard playingStarted else { return }
            guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay else { return }
            switch reasonForWaitingToPlay {
            case .evaluatingBufferingRate, .toMinimizeStalls, .waitingForCoordinatedPlayback:
                guard !canPlay() else { return }
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: true,
                    rate: rate
                )
                return change(controller)
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
    
    override public func handle(_ event: AKPlayerItemNotificationEvent) {
        guard isActiveState else { return }
        switch event {
        case let .failedToPlayToEndTime(error):
            if error is URLError {
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: true,
                    rate: rate
                )
                change(controller)
            } else {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .itemFailedToPlayToEndTime
                )
                change(controller)
            }
        case .didPlayToEndTime:
            let controller = AKPausedState(
                playerController: playerController,
                playerItemDidPlayToEndTime: true
            )
            change(controller)
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
    
    // MARK: - Availability Overrides
    
    /// Evaluates preflight permission and unavailable reasons for a given player action when actively playing.
    override public func availability(for action: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        switch action {
        case .play(at: .normal):
            (false, .alreadyPlaying)
        default:
            super.availability(for: action)
        }
    }
}
