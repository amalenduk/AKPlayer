//
//  AKPlayerInterstitialServiceProtocol.swift
//  AKPlayer
//

//  AKPlayerInterstitialServiceProtocol.swift
//  AKPlayer

import AVFoundation
import CoreMedia

import AVFoundation
import CoreMedia

@MainActor
public protocol AKPlayerInterstitialServiceProtocol: AnyObject {
    
    var events: AsyncStream<AKInterstitialEvent> { get }
    
    var playbackState: AKInterstitialPlaybackState { get }
    var currentEvent: AVPlayerInterstitialEvent? { get }
    var isPlayingInterstitial: Bool { get }
    var scheduledEvents: [AVPlayerInterstitialEvent] { get }
    var interstitialPlayer: AVPlayer? { get }
    var integratedTimeline: AVPlayerItemIntegratedTimeline? { get }
    
    var integratedTimelinePointSegments: [AVPlayerItemSegment] { get }
    var integratedTimelineFillSegments: [AVPlayerItemSegment] { get }
    var integratedTimelineCurrentTime: Double { get }
    var integratedTimelineStartTime: Double { get }
    var integratedTimelineDuration: Double { get }
    
    var currentRestrictions: AVPlayerInterstitialEvent.Restrictions { get }
    var canSeek: Bool { get }
    var canFastForward: Bool { get }
    
    func setEvents(_ events: [AVPlayerInterstitialEvent])
    func appendEvents(_ events: [AVPlayerInterstitialEvent])
    
    func schedule(_ configs: [AKInterstitialScheduleConfig], replaceExisting: Bool)
    
    func schedule(
        at time: CMTime,
        templateItems: [AVPlayerItem],
        identifier: String?,
        restrictions: AVPlayerInterstitialEvent.Restrictions,
        resumptionOffset: CMTime,
        playoutLimit: CMTime,
        timelineOccupancy: AVPlayerInterstitialEvent.TimelineOccupancy,
        supplementsPrimaryContent: Bool,
        contentMayVary: Bool
    )
    
    func cancelCurrent(resumptionOffset: CMTime)
    
    func seekOnIntegratedTimeline(to time: TimeInterval, completion: @escaping (Bool) -> Void)
    func seekOnIntegratedTimeline(by delta: TimeInterval, completion: @escaping (Bool) -> Void)
    
    func stopObserving()
}
