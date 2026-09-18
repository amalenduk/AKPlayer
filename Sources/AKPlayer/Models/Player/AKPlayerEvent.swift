//
//   AKPlayerEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia

// MARK: - AKPlayerEvent

/// Playback events published by ``AKPlayer``.
///
/// Subscribe with `for await event in player.events`. The existing
/// ``AKPlayerDelegate`` remains supported as a compatibility adapter.
public enum AKPlayerEvent: Sendable {
    // MARK: - State & Media

    /// The player's operational state transitioned (e.g., from buffering to
    /// playing).
    case stateDidChange(AKPlayerState)

    /// The active playable media item was swapped or updated.
    case mediaDidChange(any AKPlayable)

    // MARK: - Playback Progress

    /// Playback time progressed.
    case timeDidChange(CMTime)

    /// Media reached its natural end of timeline.
    case didReachEnd(at: CMTime)

    /// Playback crossed a registered boundary time milestone.
    case boundaryReached(at: CMTime)

    // MARK: - Playback Settings

    /// Playback speed rate changed.
    case playbackRateDidChange(new: AKPlaybackRate, previous: AKPlaybackRate)

    /// Output volume level changed.
    case volumeDidChange(Float)

    /// Audio mute toggle state changed.
    case muteStatusDidChange(isMuted: Bool)

    // MARK: - Warnings & Errors

    /// A requested action was blocked because current state preconditions were
    /// not met.
    case commandUnavailable(reason: AKPlayerUnavailableCommandReason)

    /// An unrecoverable pipeline failure occurred.
    case didFail(with: AKPlayerError)
}

// MARK: - Equatable Conformance

extension AKPlayerEvent: Equatable {
    /// Compares two `AKPlayerEvent` instances for equality.
    public static func == (lhs: AKPlayerEvent, rhs: AKPlayerEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.mediaDidChange(l), .mediaDidChange(r)):
            l.isEqual(to: r)
        case let (.stateDidChange(l), .stateDidChange(r)):
            l == r
        case let (.timeDidChange(l), .timeDidChange(r)):
            l == r
        case let (.didReachEnd(l), .didReachEnd(r)):
            l == r
        case let (.boundaryReached(l), .boundaryReached(r)):
            l == r
        case let (
            .playbackRateDidChange(lNew, lOld),
            .playbackRateDidChange(rNew, rOld)
        ):
            lNew == rNew && lOld == rOld
        case let (.volumeDidChange(l), .volumeDidChange(r)):
            l == r
        case let (.muteStatusDidChange(l), .muteStatusDidChange(r)):
            l == r
        case let (.commandUnavailable(l), .commandUnavailable(r)):
            l == r
        case let (.didFail(l), .didFail(r)):
            l == r
        default:
            false
        }
    }
}
