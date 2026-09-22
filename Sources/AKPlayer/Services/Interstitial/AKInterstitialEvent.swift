//
//   AKInterstitialEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreMedia

// MARK: - AKInterstitialEvent

/// Events emitted exclusively while interstitial content is active or when the schedule changes.
/// Subscribe via `interstitialService.events`.
public enum AKInterstitialEvent: @unchecked Sendable {
    /// The full schedule of interstitial events changed (server-side or client-side).
    case scheduleDidChange([AVPlayerInterstitialEvent])

    /// The playback state of the active interstitial ad changed.
    case playbackStateDidChange(AKInterstitialPlaybackState)

    /// An interstitial is about to begin (currentEvent became non-nil).
    case willStart(AVPlayerInterstitialEvent)

    /// An interstitial has started playing.
    case didStart(AVPlayerInterstitialEvent)

    /// Periodic progress while an interstitial is playing.
    case progress(AKPlayerInterstitialProgress)

    /// The interstitial finished, was skipped, or was cancelled.
    case didFinish(AVPlayerInterstitialEvent, reason: FinishReason)

    /// The collection of synthesized ad markers changed.
    case adMarkersDidChange([AKInterstitialMarker])

    /// Stitched integrated timeline event emitted during synchronized playback.
    case integratedTimeline(_ event: AKIntegratedTimelineEvent)

    // MARK: - FinishReason

    /// The reason why an interstitial completed or terminated.
    public enum FinishReason: Sendable, Equatable {
        /// The interstitial played to natural completion.
        case completed
        /// The interstitial was cancelled or skipped with the specified resumption offset.
        case cancelled(resumptionOffset: CMTime)
        /// The interstitial terminated due to a playback error.
        case error(Error)

        /// Returns a boolean value indicating whether two finish reasons are equal.
        public static func == (lhs: FinishReason, rhs: FinishReason) -> Bool {
            switch (lhs, rhs) {
            case (.completed, .completed):
                true
            case let (.cancelled(l), .cancelled(r)):
                l == r
            case (.error, .error):
                true // Error itself is not Equatable in a useful way here
            default:
                false
            }
        }
    }
}

// MARK: - Equatable

extension AKInterstitialEvent: Equatable {
    /// Returns a boolean value indicating whether two interstitial events are equal.
    public static func == (lhs: AKInterstitialEvent, rhs: AKInterstitialEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.scheduleDidChange(l), .scheduleDidChange(r)):
            l.map(\.identifier) == r.map(\.identifier)
        case let (.playbackStateDidChange(l), .playbackStateDidChange(r)):
            l == r
        case let (.willStart(l), .willStart(r)),
             let (.didStart(l), .didStart(r)):
            l.identifier == r.identifier
        case let (.progress(l), .progress(r)):
            l.currentTime == r.currentTime && l.duration == r.duration
        case let (.didFinish(lEvent, lReason), .didFinish(rEvent, rReason)):
            lEvent.identifier == rEvent.identifier && lReason == rReason
        case let (.adMarkersDidChange(l), .adMarkersDidChange(r)):
            l == r
        case let (.integratedTimeline(l), .integratedTimeline(r)):
            l == r
        default:
            false
        }
    }
}

/// Represents events emitted by the integrated timeline coordinator.
public enum AKIntegratedTimelineEvent: Sendable, Equatable {
    /// Integrated timeline segments updated with point and fill segments.
    case segmentsUpdated(pointSegments: [AVPlayerItemSegment], fillSegments: [AVPlayerItemSegment])
    /// Integrated timeline position and duration metrics updated.
    case timeUpdated(currentTime: Double, startTime: Double, duration: Double)
    /// The integrated timeline snapshot fell out of sync with underlying player item.
    case snapshotOutOfSync
}
