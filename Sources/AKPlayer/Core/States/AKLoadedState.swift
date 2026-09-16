//
//   AKLoadedState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKLoadedState

/// Concrete state representing a state where media has been loaded into the
/// pipeline and is ready for playback or seeking.
@MainActor
public class AKLoadedState: AKBaseState {
    // MARK: - Properties
    
    /// Indicates whether autoplay should trigger automatically once preparation
    /// finishes.
    public private(set) var autoPlay: Bool
    
    /// Optional target position to navigate to upon loading.
    private let position: AKSeekTarget?
    
    /// Optional target playback speed multiplier to apply on play.
    private var rate: AKPlaybackRate?
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a loaded state instance associated with the specified player
    /// controller.
    /// - Parameters:
    ///   - playerController: The target player controller executing playback
    /// commands.
    ///   - autoPlay: Controls whether playback should automatically start upon
    /// entering this state.
    ///   - position: An optional initial position to apply on load.
    ///   - rate: An optional initial playback rate speed multiplier.
    public init(
        playerController: any AKPlayerControllerProtocol,
        autoPlay: Bool = false,
        position: AKSeekTarget? = nil,
        rate: AKPlaybackRate? = nil
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.autoPlay = autoPlay
        self.position = position
        self.rate = rate
        super.init(playerController: playerController, state: .loaded)
    }
    
    deinit {
       
            AKLogger.logDeinit(
                String(describing: Self.self),
                pointer: Unmanaged.passUnretained(self)
            )
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Processes state updates, sets up KVO observations, and handles automatic
    /// seek or playback triggers.
    override public func processStateChange() {
        super.processStateChange()
        
        playerController.emit(.timeDidChange(playerController.currentTime))
        
        if autoPlay {
            play()
        } else if let position, let currentMedia = playerController.currentMedia {
            let (canSeek, reason) = currentMedia.seekingThroughMedia.canSeek(to: position)
            guard canSeek else {
                if let reason {
                    playerController.emit(.commandUnavailable(reason: reason))
                }
                return
            }
            
            let controller = AKBufferingState(
                playerController: playerController,
                autoPlay: false,
                rate: rate,
                targetSeek: AKSeek(target: position)
            )
            
            change(controller)
        }
    }
    
    // MARK: - Commands
    
    /// Commands the player to unpause and enter the buffering state prior to
    /// active playback.
    override public func play() {
        var controller: AKBufferingState
        if let position {
            controller = AKBufferingState(
                playerController: playerController,
                autoPlay: true,
                rate: rate,
                targetSeek: AKSeek(target: position)
            )
        } else {
            controller = AKBufferingState(
                playerController: playerController,
                autoPlay: true,
                rate: rate,
            )
        }
        
        change(controller)
    }
    
    /// Commands the player to unpause and play at a specific target rate
    /// multiplier.
    /// - Parameter rate: Target playback rate multiplier.
    override public func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.canPlay(at: rate)
        else {
            playerController
                .emit(.commandUnavailable(reason: .canNotPlayAtSpecifiedRate))
            return
        }
        
        var controller: AKBufferingState
        
        if let position {
            controller = AKBufferingState(
                playerController: playerController,
                autoPlay: true,
                rate: rate,
                targetSeek: AKSeek(target: position)
            )
        } else {
            controller = AKBufferingState(
                playerController: playerController,
                autoPlay: true,
                rate: rate
            )
        }
        change(controller)
    }
    
    /// Commands the player to pause. Disables `autoPlay` if queued, or emits an
    /// `.alreadyPaused` unavailability warning.
    override public func pause() {
        if autoPlay {
            autoPlay = false
        } else {
            playerController.emit(.commandUnavailable(reason: .alreadyPaused))
        }
    }
    
    // MARK: - Private Pipeline Helpers
    
    /// Binds KVO status publishers to monitor player status and missing current
    /// items.
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
        switch status {
        case .playing:
            play()
        case .waitingToPlayAtSpecifiedRate:
            guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay else { return }
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
}
