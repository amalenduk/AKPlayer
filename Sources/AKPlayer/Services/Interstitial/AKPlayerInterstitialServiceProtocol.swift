import AVFoundation
import CoreMedia
import Foundation

public protocol AKPlayerInterstitialServiceProtocol: AnyObject, Sendable {
    
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
    
    // MARK: - Ad Markers
    
    /// Synthesized ad markers for rendering cue points and fill segments on a progress bar.
    var markers: [AKInterstitialMarker] { get }
    
    /// Finds the ad marker closest to the specified time within the given tolerance.
    func marker(at time: TimeInterval, tolerance: TimeInterval) -> AKInterstitialMarker?
    
    /// Finds the next unplayed ad marker scheduled after the given time position.
    func nextUnplayedMarker(after time: TimeInterval) -> AKInterstitialMarker?
    
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
    
    func seekOnIntegratedTimeline(to time: TimeInterval, completion: @Sendable @escaping (Bool) -> Void)
    func seekOnIntegratedTimeline(by delta: TimeInterval, completion: @Sendable @escaping (Bool) -> Void)
    
    func stopObserving()
}
