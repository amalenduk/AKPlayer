//
//   AKPlayerEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreMedia

// MARK: - AKPlayerEvent

/// Comprehensive playback, media, service, and interstitial events published by ``AKPlayer``.
///
/// Subscribe with `for await event in player.events`.
public enum AKPlayerEvent: Sendable {
    // MARK: - Media & Media Services Events

    /// The active media item lifecycle, duration, ranges, or capability event.
    case media(AKMediaEvent)

    /// Track selection event for audio, subtitle, and closed captions.
    case trackSelection(AKTrackSelectionEvent)

    /// Underlying AVPlayerItem system notification event.
    case playerItemNotification(AKPlayerItemNotificationEvent)

    /// Metadata provider event (static container metadata and dynamic timed metadata).
    case metadata(AKMediaMetadataEvent)

    /// Chapter service event (chapter markers and active chapter transitions).
    case chapter(AKChapterEvent)

    // MARK: - Core Player State & Playback

    /// The player's operational state transitioned (e.g., from buffering to playing).
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

    // MARK: - SharePlay

    /// The SharePlay group activity synchronization state changed.
    case sharePlayStateDidChange(AKSharePlayState)

    // MARK: - Warnings & Errors

    /// A requested action was blocked because current state preconditions were not met.
    case commandUnavailable(reason: AKPlayerUnavailableCommandReason)

    /// An unrecoverable pipeline failure occurred.
    case didFail(with: AKPlayerError)

    // MARK: - Interstitial (Ad) Events

    /// Interstitial schedule, playback state, progress, or ad markers event.
    case interstitial(AKInterstitialEvent)
}

// MARK: - Equatable Conformance

extension AKPlayerEvent: Equatable {
    /// Compares two `AKPlayerEvent` instances for equality.
    public static func == (lhs: AKPlayerEvent, rhs: AKPlayerEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.media(l), .media(r)):
            l == r
        case let (.trackSelection(l), .trackSelection(r)):
            l == r
        case let (.playerItemNotification(l), .playerItemNotification(r)):
            l == r
        case let (.metadata(l), .metadata(r)):
            l == r
        case let (.chapter(l), .chapter(r)):
            l == r
        case let (.interstitial(l), .interstitial(r)):
            l == r
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
        case let (.sharePlayStateDidChange(l), .sharePlayStateDidChange(r)):
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
