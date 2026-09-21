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
    
    /// Initializes a marker from an `AVPlayerInterstitialEvent` and an optional `AVPlayerItemSegment`.
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
        
        let durationSeconds: TimeInterval? = {
            if let segment {
                let segDur = CMTimeGetSeconds(segment.timeMapping.target.duration)
                if !segDur.isNaN, !segDur.isInfinite, segDur > 0 {
                    return segDur
                }
            }
            let playoutLimit = CMTimeGetSeconds(event.playoutLimit)
            if !playoutLimit.isNaN, !playoutLimit.isInfinite, playoutLimit > 0 {
                return playoutLimit
            }
            return nil
        }()
        
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
}

// MARK: - Equatable & Hashable

extension AKInterstitialMarker {
    public static func == (lhs: AKInterstitialMarker, rhs: AKInterstitialMarker) -> Bool {
        lhs.id == rhs.id &&
        lhs.time == rhs.time &&
        lhs.duration == rhs.duration &&
        lhs.occupancy == rhs.occupancy &&
        lhs.restrictions == rhs.restrictions &&
        lhs.isPlayed == rhs.isPlayed &&
        lhs.isCurrent == rhs.isCurrent &&
        lhs.templateItemCount == rhs.templateItemCount &&
        lhs.title == rhs.title
    }
    
    public func hash(into hasher: inout Hasher) {
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
