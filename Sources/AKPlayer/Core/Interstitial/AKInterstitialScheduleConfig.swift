//
//  AKInterstitialScheduleConfig.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar. All rights reserved.
//  Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreMedia

public struct AKInterstitialScheduleConfig: @unchecked Sendable {
    public var time: CMTime
    public var templateItems: [AVPlayerItem]
    public var identifier: String?
    public var restrictions: AVPlayerInterstitialEvent.Restrictions
    public var resumptionOffset: CMTime
    public var playoutLimit: CMTime
    public var timelineOccupancy: AVPlayerInterstitialEvent.TimelineOccupancy
    public var supplementsPrimaryContent: Bool
    public var contentMayVary: Bool
    
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
