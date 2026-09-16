//
//  AKPlayerInterstitialServiceProtocol.swift
//  AKPlayer
//

//  AKPlayerInterstitialServiceProtocol.swift
//  AKPlayer

import AVFoundation
import CoreMedia

@MainActor
public protocol AKPlayerInterstitialServiceProtocol: AnyObject {
    
    // MARK: - Streams & Core State
    
    /// Dedicated stream of interstitial and integrated timeline events.
    var events: AsyncStream<AKInterstitialEvent> { get }
    
    /// Currently active interstitial event (nil when playing primary content).
    var currentEvent: AVPlayerInterstitialEvent? { get }
    
    /// Convenience flag indicating whether an interstitial is playing.
    var isPlayingInterstitial: Bool { get }
    
    /// Scheduled interstitial events (both server-side HLS and client-side).
    var scheduledEvents: [AVPlayerInterstitialEvent] { get }
    
    /// Internal player handling the active interstitial item.
    var interstitialPlayer: AVPlayer? { get }
    
    /// Native integrated timeline reference.
    var integratedTimeline: AVPlayerItemIntegratedTimeline? { get }
    
    // MARK: - Integrated Timeline UI Properties
    
    /// Distinct point markers along the integrated timeline (e.g., ad insertion locations).
    var integratedTimelinePointSegments: [AVPlayerItemSegment] { get }
    
    /// Continuous ranges along the integrated timeline (content vs ad pods).
    var integratedTimelineFillSegments: [AVPlayerItemSegment] { get }
    
    /// Current position in seconds across the entire integrated timeline.
    var integratedTimelineCurrentTime: Double { get }
    
    /// Start offset in seconds of the overall integrated timeline.
    var integratedTimelineStartTime: Double { get }
    
    /// Total aggregate duration in seconds of content + ad segments.
    var integratedTimelineDuration: Double { get }
    
    // MARK: - Ad Restrictions & Capabilities
    
    /// Returns the active restrictions configured on the current interstitial (e.g., `.constrainsSeeking`).
    var currentRestrictions: AVPlayerInterstitialEvent.Restrictions { get }
    
    /// Indicates whether seeking or scrubbing is permitted on the current active item.
    var canSeek: Bool { get }
    
    /// Indicates whether fast-forwarding is allowed on the current item.
    var canFastForward: Bool { get }
    
    // MARK: - Observation Lifecycle & Scheduling
    
    /// Replaces the client-side interstitial schedule.
    func setEvents(_ events: [AVPlayerInterstitialEvent])
    
    /// Appends events to the client-side schedule.
    func appendEvents(_ events: [AVPlayerInterstitialEvent])
    
    /// Schedules an ad or ad-pod event at a specific time position.
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
    
    func scheduleBatch(_ configurations: [(time: CMTime, templateItems: [AVPlayerItem])])
    
    // MARK: - Playback Control
    
    /// Cancels the active interstitial event and resumes primary content at the offset.
    func cancelCurrent(resumptionOffset: CMTime)
}
