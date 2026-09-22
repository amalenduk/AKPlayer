//
//  AKInterstitialScheduleConfig.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar. All rights reserved.
//  Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreMedia

// MARK: - AKInterstitialScheduleConfig

/// Configuration parameters used to construct and schedule an `AVPlayerInterstitialEvent`.
public struct AKInterstitialScheduleConfig: @unchecked Sendable {
    /// The scheduled presentation timestamp along the primary content timeline.
    public var time: CMTime
    /// The template items representing the interstitial media assets to be played.
    public var templateItems: [AVPlayerItem]
    /// Optional unique identifier string for this scheduled interstitial event.
    public var identifier: String?
    /// Seeking and playback restrictions enforced during the interstitial.
    public var restrictions: AVPlayerInterstitialEvent.Restrictions
    /// Offset relative to primary timeline upon resumption after interstitial completion.
    public var resumptionOffset: CMTime
    /// Maximum allowable playout limit duration for the interstitial.
    public var playoutLimit: CMTime
    /// Specifies whether the interstitial represents a single point cue or fills timeline duration.
    public var timelineOccupancy: AVPlayerInterstitialEvent.TimelineOccupancy
    /// Whether this interstitial supplements the primary content without replacing timeline intervals.
    public var supplementsPrimaryContent: Bool
    /// Indicates whether dynamic server-side variations in content duration or payload may occur.
    public var contentMayVary: Bool
    
    /// Initializes an interstitial schedule configuration payload.
    /// - Parameters:
    ///   - time: Scheduled timestamp along the primary media timeline.
    ///   - templateItems: Array of template player items to play during the interstitial.
    ///   - identifier: Optional unique identifier for the event.
    ///   - restrictions: Playback and seeking restrictions to enforce. Defaults to `[]`.
    ///   - resumptionOffset: Offset upon returning to primary playback. Defaults to `.zero`.
    ///   - playoutLimit: Maximum duration limit. Defaults to `.invalid` (unlimited).
    ///   - timelineOccupancy: Single-point cue vs fill segment. Defaults to `.singlePoint`.
    ///   - supplementsPrimaryContent: Whether it supplements primary content. Defaults to `false`.
    ///   - contentMayVary: Whether ad content duration or payload may vary dynamically. Defaults to `true`.
    public init(
        time: CMTime,
        templateItems: [AVPlayerItem],
        identifier: String? = nil,
        restrictions: AVPlayerInterstitialEvent.Restrictions = [],
        resumptionOffset: CMTime = .zero,
        playoutLimit: CMTime = .invalid,
        timelineOccupancy: AVPlayerInterstitialEvent.TimelineOccupancy = .singlePoint,
        supplementsPrimaryContent: Bool = false,
        contentMayVary: Bool = true
    ) {
        self.time = time
        self.templateItems = templateItems
        self.identifier = identifier
        self.restrictions = restrictions
        self.resumptionOffset = resumptionOffset
        self.playoutLimit = playoutLimit
        self.timelineOccupancy = timelineOccupancy
        self.supplementsPrimaryContent = supplementsPrimaryContent
        self.contentMayVary = contentMayVary
    }
}
