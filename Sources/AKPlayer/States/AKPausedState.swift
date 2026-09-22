//
//   AKPausedState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPausedState

/// Concrete state representing a state where media playback is actively paused.
@MainActor
public class AKPausedState: AKBaseState {
    // MARK: - Properties

    /// Flag indicating whether playback paused naturally because the media
    /// reached its end time.
    private let playerItemDidPlayToEndTime: Bool

    // MARK: - Init

    /// Initializes a paused state instance.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving execution.
    ///   - playerItemDidPlayToEndTime: True if the item was paused because it played through to the
    /// end.
    public init(
        playerController: (any AKPlayerControllerProtocol)?,
        playerItemDidPlayToEndTime: Bool = false
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.playerItemDidPlayToEndTime = playerItemDidPlayToEndTime
        super.init(playerController: playerController, state: .paused)
    }

    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - State Lifecycle & Event Handlers

    /// Entry point for paused state processing. Ensures playback pauses and
    /// fires delegate notifications if end-of-media was reached.
    override public func processStateChange() {
        super.processStateChange()

        guard let playerController else { return }

        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }

        if playerItemDidPlayToEndTime {
            playerController
                .emit(.didReachEnd(at: playerController.currentTime))
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

    /// Responds to changes in `AVPlayer.TimeControlStatus` to resume playback or handle buffering
    /// requirements.
    override public func handleTimeControlStatusChange(_: AVPlayer.TimeControlStatus) {
        guard isActiveState, let playerController else { return }
        guard !playerController.interstitialService.isPlayingInterstitial else { return }
        switch playerController.player.timeControlStatus {
        case .playing:
            play()
        case .waitingToPlayAtSpecifiedRate:
            guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay
            else { return }
            switch reasonForWaitingToPlay {
            case .evaluatingBufferingRate, .toMinimizeStalls, .waitingForCoordinatedPlayback:
                play()
            case .noItemToPlay:
                stop()
            default:
                break
            }
        default:
            break
        }
    }

    /// Handles media player item notification events such as playback failures.
    override public func handle(_ event: AKPlayerItemNotificationEvent) {
        guard isActiveState, let playerController else { return }
        guard !playerController.interstitialService.isPlayingInterstitial else { return }
        switch event {
        case let .failedToPlayToEndTime(error):
            if error.underlyingError is URLError {
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: false
                )
                change(controller)
            } else {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .itemFailedToPlayToEndTime
                )
                change(controller)
            }
        default:
            break
        }
    }

    /// Responds to interstitial ad playback state changes to resume content when active.
    override public func handleInterstitialPlaybackStateChange(
        _ playbackState: AKInterstitialPlaybackState
    ) {
        guard isActiveState else { return }
        switch playbackState {
        case .playing:
            play()
        default:
            break
        }
    }

    // MARK: - Commands

    /// Resumes playback. Transitions to loading state if media is not ready, or
    /// buffering state if ready.
    override public func play() {
        guard let playerController else { return }
        guard let currentMedia = playerController.currentMedia,
              currentMedia.state.isReadyToPlay
        else {
            if let media = playerController.currentMedia {
                load(media: media, autoPlay: true)
            }
            return
        }

        let initialSeek: AKSeek? = playerItemDidPlayToEndTime
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
        performIfAllowed(
            check: { availability(for: .play(at: rate)) },
            action: {
                guard let playerController else { return }
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

                let initialSeek: AKSeek? = playerItemDidPlayToEndTime
                    ? AKSeek(target: .time(.zero)) : nil

                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: true,
                    rate: rate,
                    targetSeek: initialSeek
                )
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController?.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
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
}
