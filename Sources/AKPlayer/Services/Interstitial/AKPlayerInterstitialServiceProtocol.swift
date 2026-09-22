//
//   AKPlayerInterstitialServiceProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreMedia
import Foundation

// MARK: - AKPlayerInterstitialServiceProtocol

/// Protocol defining requirements for managing interstitial ad playback, event scheduling,
/// ad markers, and integrated timeline navigation.
public protocol AKPlayerInterstitialServiceProtocol: AnyObject, Sendable {
    // MARK: - Properties

    /// Asynchronous stream of interstitial lifecycle, marker, and timeline events.
    var events: AsyncStream<AKInterstitialEvent> { get }

    /// The current playback state of the active interstitial ad.
    var playbackState: AKInterstitialPlaybackState { get }

    /// The currently active interstitial event, if one is currently playing.
    var currentEvent: AVPlayerInterstitialEvent? { get }

    /// A Boolean value indicating whether an interstitial ad is actively playing.
    var isPlayingInterstitial: Bool { get }

    /// All interstitial events currently scheduled for the active media item.
    var scheduledEvents: [AVPlayerInterstitialEvent] { get }

    /// The underlying `AVPlayer` rendering interstitial ad content.
    var interstitialPlayer: AVPlayer? { get }

    /// The integrated timeline combining primary content and scheduled interstitials.
    var integratedTimeline: AVPlayerItemIntegratedTimeline? { get }

    /// Point-based interstitial segments in the integrated timeline.
    var integratedTimelinePointSegments: [AVPlayerItemSegment] { get }

    /// Duration-based fill interstitial segments in the integrated timeline.
    var integratedTimelineFillSegments: [AVPlayerItemSegment] { get }

    /// The current playback position in seconds along the integrated timeline.
    var integratedTimelineCurrentTime: Double { get }

    /// The start timestamp in seconds along the integrated timeline.
    var integratedTimelineStartTime: Double { get }

    /// The total duration in seconds of the integrated timeline.
    var integratedTimelineDuration: Double { get }

    /// Playback restrictions currently applied by the active interstitial event.
    var currentRestrictions: AVPlayerInterstitialEvent.Restrictions { get }

    /// A Boolean value indicating whether seeking is permitted during the current interstitial.
    var canSeek: Bool { get }

    /// A Boolean value indicating whether fast-forwarding is permitted during the current interstitial.
    var canFastForward: Bool { get }

    /// Synthesized ad markers for rendering cue points and fill segments on a progress bar.
    var markers: [AKInterstitialMarker] { get }

    // MARK: - Observation Lifecycle

    /// Stops observing interstitial events and cleans up active observation tasks.
    func stopObserving()

    // MARK: - Ad Markers

    /// Finds the ad marker closest to the specified time within the given tolerance.
    /// - Parameters:
    ///   - time: Target presentation timestamp in seconds.
    ///   - tolerance: Search tolerance in seconds. Defaults to `1.0`.
    /// - Returns: The closest matching `AKInterstitialMarker`, or `nil` if none found.
    func marker(at time: TimeInterval, tolerance: TimeInterval) -> AKInterstitialMarker?

    /// Finds the next unplayed ad marker scheduled after the given time position.
    /// - Parameter time: The reference timestamp in seconds.
    /// - Returns: The next unplayed `AKInterstitialMarker`, or `nil` if none remain.
    func nextUnplayedMarker(after time: TimeInterval) -> AKInterstitialMarker?

    // MARK: - Scheduling

    /// Replaces the current schedule with a new collection of interstitial events.
    /// - Parameter events: The interstitial events to schedule.
    func setEvents(_ events: [AVPlayerInterstitialEvent])

    /// Appends interstitial events to the existing schedule.
    /// - Parameter events: The interstitial events to append.
    func appendEvents(_ events: [AVPlayerInterstitialEvent])

    /// Schedules multiple interstitial events from configuration objects.
    /// - Parameters:
    ///   - configs: Array of `AKInterstitialScheduleConfig` items.
    ///   - replaceExisting: If `true`, replaces existing events; otherwise appends.
    func schedule(_ configs: [AKInterstitialScheduleConfig], replaceExisting: Bool)

    /// Schedules a single interstitial event.
    /// - Parameters:
    ///   - time: Presentation time for the interstitial.
    ///   - templateItems: Array of `AVPlayerItem` instances to play.
    ///   - identifier: Optional unique string identifier.
    ///   - restrictions: Playback restrictions to apply.
    ///   - resumptionOffset: Resumption offset in the primary content.
    ///   - playoutLimit: Maximum playout duration limit.
    ///   - timelineOccupancy: Timeline occupancy behavior (`.singlePoint` or `.fill`).
    ///   - supplementsPrimaryContent: Whether the interstitial supplements primary content.
    ///   - contentMayVary: Whether interstitial content may vary.
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

    /// Cancels the currently active interstitial ad event.
    /// - Parameter resumptionOffset: Resumption offset in the primary content.
    func cancelCurrent(resumptionOffset: CMTime)

    // MARK: - Integrated Timeline Seeking

    /// Seeks to a target `CMTime` along the integrated timeline.
    /// - Parameters:
    ///   - targetTime: Target timestamp on the integrated timeline.
    ///   - toleranceBefore: Tolerance before target time.
    ///   - toleranceAfter: Tolerance after target time.
    ///   - completion: Completion closure invoked with a boolean indicating success.
    func seekOnIntegratedTimeline(
        to targetTime: CMTime,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completion: @Sendable @escaping (Bool) -> Void
    )

    /// Seeks to a target time interval in seconds along the integrated timeline.
    /// - Parameters:
    ///   - time: Target timestamp in seconds.
    ///   - completion: Completion closure invoked with a boolean indicating success.
    func seekOnIntegratedTimeline(to time: TimeInterval, completion: @Sendable @escaping (Bool) -> Void)

    /// Seeks relative to the current position along the integrated timeline by a delta in seconds.
    /// - Parameters:
    ///   - delta: Time delta in seconds to seek by.
    ///   - completion: Completion closure invoked with a boolean indicating success.
    func seekOnIntegratedTimeline(by delta: TimeInterval, completion: @Sendable @escaping (Bool) -> Void)
}
