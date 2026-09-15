//
//   AKPausedState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKPausedState

/// Concrete state representing a state where media playback is actively paused.
@MainActor
public class AKPausedState: AKBaseState {
    // MARK: - Properties
    
    /// Flag indicating whether playback paused naturally because the media
    /// reached its end time.
    private let playerItemDidPlayToEndTime: Bool
    
    /// Container holding reactive Combine event subscriptions.
    private var subscriptions: Set<AnyCancellable> = Set<AnyCancellable>()
    
    // MARK: - Init
    
    /// Initializes a paused state instance.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving
    /// execution.
    ///   - playerItemDidPlayToEndTime: True if the item was paused because it
    /// played through to the end.
    public init(
        playerController: any AKPlayerControllerProtocol,
        playerItemDidPlayToEndTime: Bool = false
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.playerItemDidPlayToEndTime = playerItemDidPlayToEndTime
        super.init(playerController: playerController, state: .paused)
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
    
    /// Entry point for paused state processing. Ensures playback pauses and
    /// fires delegate notifications if end-of-media was reached.
    override public func processStateChange() {
        startObservingPlayerItemNotifications()
        super.processStateChange()
        
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        
        if playerItemDidPlayToEndTime,
           let currentMedia = playerController.currentMedia
        {
            playerController
                .emit(.didReachEnd(at: playerController.currentTime))
        }
    }
    
    // MARK: - Commands
    
    /// Resumes playback. Transitions to loading state if media is not ready, or
    /// buffering state if ready.
    override public func play() {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.state.isReadyToPlay
        else {
            if let media = playerController.currentMedia {
                load(media: media, autoPlay: true)
            }
            return
        }
        
        let initialSeek: AKSeek? =
        playerItemDidPlayToEndTime
        ? AKSeek(
            target: .time(.zero),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) : nil
        
        let controller = AKBufferingState(
            playerController: playerController,
            autoPlay: true,
            targetSeek: initialSeek
        )
        change(controller)
    }
    
    /// Resumes playback at a target rate. Validates capability or requests
    /// loading if unready.
    /// - Parameter rate: The target playback speed.
    override public func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.state.isReadyToPlay
        else {
            if let media = playerController.currentMedia {
                let controller = AKLoadingState(
                    playerController: playerController,
                    media: media,
                    autoPlay: true,
                    rate: rate
                )
                change(controller)
            }
            return
        }
        
        guard currentMedia.canPlay(at: rate) else {
            playerController
                .emit(.commandUnavailable(reason: .canNotPlayAtSpecifiedRate))
            return
        }
        
        let initialSeek: AKSeek? =
        playerItemDidPlayToEndTime
        ? AKSeek(target: .time(.zero)) : nil
        
        let controller = AKBufferingState(
            playerController: playerController,
            autoPlay: true,
            rate: rate,
            targetSeek: initialSeek
        )
        change(controller)
    }
    
    // MARK: - Additional Helper Functions
    
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
            guard isActiveState else { return }
            print("From pause state play")
            play()
        case .waitingToPlayAtSpecifiedRate:
            guard isActiveState else { return }
            guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay else { return }
            switch reasonForWaitingToPlay {
            case .evaluatingBufferingRate, .interstitialEvent, .toMinimizeStalls, .waitingForCoordinatedPlayback:
                print("From pause state play, ", reasonForWaitingToPlay)
                play()
            case .noItemToPlay:
                stop()
            default:
                break
            }
        default: break
        }
    }
    
    
    /// Registers notification center listeners for player item playback failure
    /// notifications.
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
            
            let controller = AKBufferingState(playerController: playerController, autoPlay: false)
            change(controller)
        }
        .store(in: &subscriptions)
    }
    
    // MARK: - Availability Overrides
    
    /// Checks action availability in paused state.
    override public func availability(for action: AKPlayerAction)
    -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?)
    {
        switch action {
        case .pause:
            (false, .alreadyPaused)
        default:
            super.availability(for: action)
        }
    }
    
    /// Cleans active Combine observers prior to state transition.
    override public func beforeStateChange() {
        subscriptions.forEach({ $0.cancel() })
        subscriptions.removeAll()
    }
}
