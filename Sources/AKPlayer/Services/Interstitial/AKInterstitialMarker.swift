//
//   AKInterstitialMarker.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreMedia
import Foundation

// MARK: - AKInterstitialMarker

/// Represents an ad cue point or ad segment on the primary content timeline.
public struct AKInterstitialMarker: Identifiable, Sendable, Equatable, Hashable {
    // MARK: - Properties

    /// Unique identifier for this ad marker or event.
    public let id: String

    /// Presentation timestamp in seconds along the primary media timeline.
    public let time: TimeInterval

    /// Estimated or actual duration of the ad break in seconds, if known.
    public let duration: TimeInterval?

    /// Indicates whether this ad is a single point cue or fills a portion of the timeline.
    public let occupancy: AVPlayerInterstitialEvent.TimelineOccupancy

    /// Playback and seeking restrictions applied during this interstitial.
    public let restrictions: AVPlayerInterstitialEvent.Restrictions

    /// Indicates whether this ad break has already played to completion.
    public var isPlayed: Bool

    /// Indicates whether this ad break is actively playing right now.
    public var isCurrent: Bool

    /// Number of ad items in this interstitial pod.
    public let templateItemCount: Int

    /// Optional user-friendly display title or label (e.g., "Ad 1").
    public let title: String?

    // MARK: - Computed Properties

    /// Indicates whether seeking past or into this ad break is permitted.
    public var canSeek: Bool {
        !restrictions.contains(.constrainsSeekingForwardInPrimaryContent)
    }

    /// Indicates whether fast-forwarding through this ad break is permitted.
    public var canFastForward: Bool {
        !restrictions.contains(.constrainsSeekingForwardInPrimaryContent) &&
            !restrictions.contains(.requiresPlaybackAtPreferredRateForAdvancement)
    }

    /// Indicates if the marker occupies a single point in the timeline.
    public var isSinglePoint: Bool {
        occupancy == .singlePoint
    }

    /// Indicates if the marker occupies a fill range segment in the timeline.
    public var isFill: Bool {
        occupancy == .fill
    }

    // MARK: - Initialization

    /// Initializes a new interstitial cue or ad segment marker.
    /// - Parameters:
    ///   - id: Unique identifier for the marker. Defaults to a new UUID string.
    ///   - time: Presentation timestamp in seconds along the primary timeline.
    ///   - duration: Duration of the ad break in seconds if known.
    ///   - occupancy: Single point vs fill range timeline occupancy. Defaults to `.singlePoint`.
    ///   - restrictions: Playback and seeking restrictions applied during the ad. Defaults to `[]`.
    ///   - isPlayed: Whether the ad has finished playing. Defaults to `false`.
    ///   - isCurrent: Whether the ad is actively playing. Defaults to `false`.
    ///   - templateItemCount: Number of ad items in this interstitial pod. Defaults to `1`.
    ///   - title: Display title or label for the ad marker.
    public init(
        id: String = UUID().uuidString,
        time: TimeInterval,
        duration: TimeInterval? = nil,
        occupancy: AVPlayerInterstitialEvent.TimelineOccupancy = .singlePoint,
        restrictions: AVPlayerInterstitialEvent.Restrictions = [],
        isPlayed: Bool = false,
        isCurrent: Bool = false,
        templateItemCount: Int = 1,
        title: String? = nil
    ) {
        self.id = id
        self.time = time
        self.duration = duration
        self.occupancy = occupancy
        self.restrictions = restrictions
        self.isPlayed = isPlayed
        self.isCurrent = isCurrent
        self.templateItemCount = templateItemCount
        self.title = title
    }

    /// Initializes a marker from an `AVPlayerInterstitialEvent` and an optional
    /// `AVPlayerItemSegment`.
    /// - Parameters:
    ///   - event: The AVPlayer interstitial event to extract metadata from.
    ///   - segment: Optional matching AVPlayer item segment.
    ///   - isPlayed: Whether the marker has already finished. Defaults to `false`.
    ///   - isCurrent: Whether the marker is currently active. Defaults to `false`.
    public init(
        event: AVPlayerInterstitialEvent,
        segment: AVPlayerItemSegment? = nil,
        isPlayed: Bool = false,
        isCurrent: Bool = false
    ) {
        let timeSeconds: Double = {
            if let segment {
                let segStart = CMTimeGetSeconds(segment.timeMapping.target.start)
                if !segStart.isNaN, !segStart.isInfinite, segStart >= 0 {
                    return segStart
                }
            }
            let eventTime = CMTimeGetSeconds(event.time)
            if !eventTime.isNaN, !eventTime.isInfinite, event.time.isValid, eventTime >= 0 {
                return eventTime
            }
            return 0.0
        }()

        let durationSeconds: TimeInterval? = Self.adDuration(from: segment, event: event)

        self.init(
            id: event.identifier,
            time: timeSeconds,
            duration: durationSeconds,
            occupancy: event.timelineOccupancy,
            restrictions: event.restrictions,
            isPlayed: isPlayed,
            isCurrent: isCurrent,
            templateItemCount: max(1, event.templateItems.count),
            title: event.identifier
        )
    }

    /// Extracts the effective ad duration in seconds from an optional segment or interstitial
    /// event.
    /// - Parameters:
    ///   - segment: Optional matching AVPlayer item segment.
    ///   - event: Optional AVPlayer interstitial event.
    /// - Returns: The calculated duration in seconds if positive and finite, or `nil` otherwise.
    public static func adDuration(
        from segment: AVPlayerItemSegment? = nil,
        event: AVPlayerInterstitialEvent? = nil
    ) -> TimeInterval? {
        if let segment {
            let segDur = CMTimeGetSeconds(segment.timeMapping.target.duration)
            if !segDur.isNaN, !segDur.isInfinite, segDur > 0 {
                return segDur
            }
        }
        if let event {
            let playoutLimit = CMTimeGetSeconds(event.playoutLimit)
            if !playoutLimit.isNaN, !playoutLimit.isInfinite, playoutLimit > 0 {
                return playoutLimit
            }
            let totalTemplateDuration = event.templateItems.reduce(0.0) { total, item in
                let itemDur = CMTimeGetSeconds(item.duration)
                if !itemDur.isNaN, !itemDur.isInfinite, itemDur > 0 {
                    return total + itemDur
                }
                return total
            }
            if totalTemplateDuration > 0 {
                return totalTemplateDuration
            }
        }
        return nil
    }
}

// MARK: - Equatable & Hashable

public extension AKInterstitialMarker {
    /// Hashes the essential components of this marker into the given hasher.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(time)
        hasher.combine(duration)
        hasher.combine(occupancy)
        hasher.combine(restrictions.rawValue)
        hasher.combine(isPlayed)
        hasher.combine(isCurrent)
        hasher.combine(templateItemCount)
        hasher.combine(title)
    }
}
