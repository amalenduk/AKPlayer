//
//  AKPlayerInterstitialServiceProtocol.swift
//  AKPlayer
//

import AVFoundation
import CoreMedia

public protocol AKPlayerInterstitialServiceProtocol: AnyObject {
    
    /// Dedicated stream of interstitial-only events.
    var events: AsyncStream<AKInterstitialEvent> { get }
    
    /// Currently playing interstitial (nil when primary content is active).
    var currentEvent: AVPlayerInterstitialEvent? { get }
    
    /// Convenience flag.
    var isPlayingInterstitial: Bool { get }
    
    /// Full current schedule (both server-side HLS + client-side).
    var scheduledEvents: [AVPlayerInterstitialEvent] { get }
    
    /// The interstitial player (useful for custom UI / volume etc.).
    var interstitialPlayer: AVPlayer? { get }
    
    /// Integrated timeline of the primary item (point + fill occupancy).
    var integratedTimeline: AVPlayerItemIntegratedTimeline? { get }
    
    // MARK: - Scheduling
    
    /// Replace the entire client-side schedule.
    func setEvents(_ events: [AVPlayerInterstitialEvent])
    
    /// Append one or more events.
    func appendEvents(_ events: [AVPlayerInterstitialEvent])
    
    /// Convenience for a single ad / ad-pod at a specific time.
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
    
    // MARK: - Control
    
    /// Skip the currently playing interstitial (Apple’s official API).
    func skipCurrent()
    
    /// Cancel current + pending and resume primary at the given offset.
    func cancelCurrent(resumptionOffset: CMTime)
}
