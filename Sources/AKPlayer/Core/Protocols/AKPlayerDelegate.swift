//
//   AKPlayerDelegate.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayerDelegate

/// Delegate protocol for receiving high-level player state changes, playback
/// progress, media updates, and error events.
@MainActor
public protocol AKPlayerDelegate: AnyObject, Sendable {
    /// Called when the player transitions to a new operational state.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - state: The new player state.
    func akPlayer(
        _ player: AKPlayer,
        didChangeStateTo state: AKPlayerState
    )

    /// Called when the active playable media item changes.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - media: The newly assigned playable media item.
    func akPlayer(
        _ player: AKPlayer,
        didChangeMediaTo media: any AKPlayable
    )

    /// Called when the player's effective playback rate changes.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - newRate: The new active playback rate.
    ///   - oldRate: The previous playback rate before the change.
    func akPlayer(
        _ player: AKPlayer,
        didChangePlaybackRateTo newRate: AKPlaybackRate,
        from oldRate: AKPlaybackRate
    )

    /// Called periodically as playback progresses to report time updates.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - currentTime: The current playback position as a `CMTime`.
    ///   - media: The media item associated with the playback timeline.
    func akPlayer(
        _ player: AKPlayer,
        didChangeCurrentTimeTo currentTime: CMTime,
        for media: any AKPlayable
    )

    /// Called when media playback reaches a pre-registered boundary time
    /// observer milestone.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - time: The specific boundary time crossed.
    ///   - media: The active playable media item.
    func akPlayer(
        _ player: AKPlayer,
        didInvokeBoundaryTimeObserverAt time: CMTime,
        for media: any AKPlayable
    )

    /// Called when media playback reaches the end of its timeline.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - time: The terminal position time.
    ///   - media: The completed playable media item.
    func akPlayer(
        _ player: AKPlayer,
        didReachEndAt time: CMTime,
        for media: any AKPlayable
    )

    /// Called when the player volume is modified.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - volume: The new volume level (ranging from `0.0` to `1.0`).
    func akPlayer(
        _ player: AKPlayer,
        didChangeVolumeTo volume: Float
    )

    /// Called when the player's audio muted status changes.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - isMuted: `true` if audio output is muted; `false` otherwise.
    func akPlayer(
        _ player: AKPlayer,
        didChangeMutedStatusTo isMuted: Bool
    )

    /// Called when a requested player command is blocked by state preflight
    /// prerequisites.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - reason: The underlying reason prohibiting action execution.
    func akPlayer(
        _ player: AKPlayer,
        didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason
    )

    /// Called when an unrecoverable error occurs within the player pipeline.
    /// - Parameters:
    ///   - player: The issuing player instance.
    ///   - error: The player error describing the failure.
    func akPlayer(
        _ player: AKPlayer,
        didFailWith error: AKPlayerError
    )
}

// MARK: - Default Implementations

public extension AKPlayerDelegate {
    /// Default empty implementation for state transition callback.
    func akPlayer(
        _: AKPlayer,
        didChangeStateTo _: AKPlayerState
    ) {}

    /// Default empty implementation for active media change callback.
    func akPlayer(
        _: AKPlayer,
        didChangeMediaTo _: any AKPlayable
    ) {}

    /// Default empty implementation for playback rate change callback.
    func akPlayer(
        _: AKPlayer,
        didChangePlaybackRateTo _: AKPlaybackRate,
        from _: AKPlaybackRate
    ) {}

    /// Default empty implementation for periodic time update callback.
    func akPlayer(
        _: AKPlayer,
        didChangeCurrentTimeTo _: CMTime,
        for _: any AKPlayable
    ) {}

    /// Default empty implementation for boundary time callback.
    func akPlayer(
        _: AKPlayer,
        didInvokeBoundaryTimeObserverAt _: CMTime,
        for _: any AKPlayable
    ) {}

    /// Default empty implementation for media end reached callback.
    func akPlayer(
        _: AKPlayer,
        didReachEndAt _: CMTime,
        for _: any AKPlayable
    ) {}

    /// Default empty implementation for volume change callback.
    func akPlayer(
        _: AKPlayer,
        didChangeVolumeTo _: Float
    ) {}

    /// Default empty implementation for mute status change callback.
    func akPlayer(
        _: AKPlayer,
        didChangeMutedStatusTo _: Bool
    ) {}

    /// Default empty implementation for unavailable command callback.
    func akPlayer(
        _: AKPlayer,
        didEncounterUnavailableAction _: AKPlayerUnavailableCommandReason
    ) {}

    /// Default empty implementation for playback failure callback.
    func akPlayer(
        _: AKPlayer,
        didFailWith _: AKPlayerError
    ) {}
}
