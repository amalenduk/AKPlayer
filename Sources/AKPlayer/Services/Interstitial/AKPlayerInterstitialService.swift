//
//   AKPlayerInterstitialService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayerInterstitialService

/// A concrete implementation of `AKPlayerInterstitialServiceProtocol` managing interstitial ad
/// observation, scheduling, ad markers, and integrated timeline coordination.
public final class AKPlayerInterstitialService: NSObject, AKPlayerInterstitialServiceProtocol,
    @unchecked Sendable
{
    // MARK: - Properties

    /// Asynchronous stream of interstitial lifecycle, marker, and timeline events.
    public var events: AsyncStream<AKInterstitialEvent> {
        eventBroadcaster.makeStream()
    }

    /// The current playback state of the active interstitial ad.
    public private(set) var playbackState: AKInterstitialPlaybackState = .idle

    /// The currently active interstitial event, if one is currently playing.
    public var currentEvent: AVPlayerInterstitialEvent? {
        monitor?.currentEvent
    }

    /// A Boolean value indicating whether an interstitial ad is actively playing.
    public var isPlayingInterstitial: Bool {
        currentEvent != nil
    }

    /// All interstitial events currently scheduled for the active media item.
    public var scheduledEvents: [AVPlayerInterstitialEvent] {
        if !customEvents.isEmpty {
            return customEvents
        }
        if let controllerEvents = controller?.events, !controllerEvents.isEmpty {
            return controllerEvents
        }
        return monitor?.events ?? []
    }

    /// The underlying `AVPlayer` rendering interstitial ad content.
    public var interstitialPlayer: AVPlayer? {
        monitor?.interstitialPlayer
    }

    /// The integrated timeline combining primary content and scheduled interstitials.
    public var integratedTimeline: AVPlayerItemIntegratedTimeline? {
        primaryPlayer?.currentItem?.integratedTimeline
    }

    /// Point-based interstitial segments in the integrated timeline.
    public private(set) var integratedTimelinePointSegments: [AVPlayerItemSegment] = []

    /// Duration-based fill interstitial segments in the integrated timeline.
    public private(set) var integratedTimelineFillSegments: [AVPlayerItemSegment] = []

    /// The current playback position in seconds along the integrated timeline.
    public private(set) var integratedTimelineCurrentTime = 0.0

    /// The start timestamp in seconds along the integrated timeline.
    public private(set) var integratedTimelineStartTime = 0.0

    /// The total duration in seconds of the integrated timeline.
    public private(set) var integratedTimelineDuration = 0.0

    /// Playback restrictions currently applied by the active interstitial event.
    public var currentRestrictions: AVPlayerInterstitialEvent.Restrictions {
        currentEvent?.restrictions ?? []
    }

    /// A Boolean value indicating whether seeking is permitted during the current interstitial.
    public var canSeek: Bool {
        !currentRestrictions.contains(.constrainsSeekingForwardInPrimaryContent)
    }

    /// A Boolean value indicating whether fast-forwarding is permitted during the current
    /// interstitial.
    public var canFastForward: Bool {
        !currentRestrictions.contains(.constrainsSeekingForwardInPrimaryContent) &&
            !currentRestrictions.contains(.requiresPlaybackAtPreferredRateForAdvancement)
    }

    /// Synthesized ad markers for rendering cue points and fill segments on a progress bar.
    public private(set) var markers: [AKInterstitialMarker] = []

    // MARK: - Private State

    /// Collection of custom scheduled interstitial events.
    private var customEvents: [AVPlayerInterstitialEvent] = []
    /// Identifiers of interstitial events that have finished playing.
    private var playedEventIDs: Set<String> = []

    /// Weak reference to the primary content AVPlayer.
    private weak var primaryPlayer: AVPlayer?
    /// Weak reference to the primary content AVPlayerItem.
    private weak var currentItem: AVPlayerItem?

    /// Native AVPlayerInterstitialEventMonitor observing interstitial events.
    private var monitor: AVPlayerInterstitialEventMonitor?
    /// Native AVPlayerInterstitialEventController scheduling interstitial events.
    private var controller: AVPlayerInterstitialEventController?

    /// Internal broadcaster dispatching interstitial events to subscribers.
    private let eventBroadcaster = AKEventBroadcaster<AKInterstitialEvent>()

    /// Periodic progress timer token on the interstitial player.
    private var progressObserverToken: Any?

    /// Key-value observation tokens for the primary player.
    private var playerObservations: [NSKeyValueObservation] = []
    /// Key-value observation tokens for the integrated timeline.
    private var timelineObservations: [NSKeyValueObservation] = []
    /// Key-value observation tokens for the interstitial player status.
    private var interstitialStatusObservations: [NSKeyValueObservation] = []
    /// Key-value observation tokens for the interstitial item buffer flags.
    private var interstitialItemObservations: [NSKeyValueObservation] = []

    /// Asynchronous notification task tracking current interstitial event transitions.
    private var currentEventTask: Task<Void, Never>?
    /// Asynchronous notification task tracking interstitial event schedule updates.
    private var scheduleEventsTask: Task<Void, Never>?
    /// Asynchronous notification task tracking timeline snapshot out-of-sync events.
    private var timelineEventsTask: Task<Void, Never>?
    /// Asynchronous timer task tracking integrated timeline playback position updates.
    private var timelineTimerTask: Task<Void, Never>?

    /// The interstitial event that most recently began playback.
    private var lastStartedEvent: AVPlayerInterstitialEvent?

    // MARK: - Init & Deinit

    /// Initializes a new interstitial service instance for the target primary player.
    /// - Parameter player: The primary `AVPlayer` instance.
    public init(with player: AVPlayer) {
        defer {
            AKLogger.logInit(self)
        }
        primaryPlayer = player
        super.init()

        monitor = AVPlayerInterstitialEventMonitor(primaryPlayer: player)
        controller = AVPlayerInterstitialEventController(primaryPlayer: player)

        setupObservers()
    }

    deinit {
        playerObservations.removeAll()
        timelineObservations.removeAll()
        interstitialStatusObservations.removeAll()
        currentEventTask?.cancel()
        currentEventTask = nil
        scheduleEventsTask?.cancel()
        scheduleEventsTask = nil
        timelineEventsTask?.cancel()
        timelineEventsTask = nil
        timelineTimerTask?.cancel()
        timelineTimerTask = nil
        eventBroadcaster.finish()
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - Observation Lifecycle

    /// Stops observing interstitial events and cleans up active observation tasks.
    public func stopObserving() {
        stopObservingTimeline()
        removeProgressObserver()
        playerObservations.removeAll()
        currentEventTask?.cancel()
        currentEventTask = nil
        scheduleEventsTask?.cancel()
        scheduleEventsTask = nil
        interstitialStatusObservations.removeAll()
    }

    // MARK: - Ad Markers

    /// Finds the ad marker closest to the specified time within the given tolerance.
    public func marker(
        at time: TimeInterval,
        tolerance: TimeInterval = 1.0
    ) -> AKInterstitialMarker? {
        markers.first { abs($0.time - time) <= tolerance }
    }

    /// Finds the next unplayed ad marker scheduled after the given time position.
    public func nextUnplayedMarker(after time: TimeInterval) -> AKInterstitialMarker? {
        markers.first { !$0.isPlayed && $0.time > time }
    }

    // MARK: - Scheduling

    /// Replaces the current schedule with a new collection of interstitial events.
    public func setEvents(_ events: [AVPlayerInterstitialEvent]) {
        customEvents = events
        controller?.events = events
        refreshMarkers()
    }

    /// Appends interstitial events to the existing schedule.
    public func appendEvents(_ events: [AVPlayerInterstitialEvent]) {
        customEvents.append(contentsOf: events)
        controller?.events = customEvents
        refreshMarkers()
    }

    /// Schedules multiple interstitial events from configuration objects.
    public func schedule(_ configs: [AKInterstitialScheduleConfig], replaceExisting: Bool = false) {
        guard let primaryItem = primaryPlayer?.currentItem, let controller else { return }
        guard !configs.isEmpty else { return }

        let newEvents = configs.map { config -> AVPlayerInterstitialEvent in
            let event = AVPlayerInterstitialEvent(
                primaryItem: primaryItem,
                identifier: config.identifier ?? UUID().uuidString,
                time: config.time,
                templateItems: config.templateItems,
                restrictions: config.restrictions,
                resumptionOffset: config.resumptionOffset,
                playoutLimit: config.playoutLimit
            )
            event.timelineOccupancy = config.timelineOccupancy
            event.supplementsPrimaryContent = config.supplementsPrimaryContent
            event.contentMayVary = config.contentMayVary
            return event
        }

        if replaceExisting {
            customEvents = newEvents
        } else {
            customEvents.append(contentsOf: newEvents)
        }
        controller.events = customEvents
        refreshMarkers()
    }

    /// Schedules a single interstitial event.
    public func schedule(
        at time: CMTime,
        templateItems: [AVPlayerItem],
        identifier: String? = nil,
        restrictions: AVPlayerInterstitialEvent.Restrictions = [],
        resumptionOffset: CMTime = .zero,
        playoutLimit: CMTime = .invalid,
        timelineOccupancy: AVPlayerInterstitialEvent.TimelineOccupancy = .singlePoint,
        supplementsPrimaryContent: Bool = false,
        contentMayVary: Bool = true
    ) {
        let config = AKInterstitialScheduleConfig(
            time: time,
            templateItems: templateItems,
            identifier: identifier,
            restrictions: restrictions,
            resumptionOffset: resumptionOffset,
            playoutLimit: playoutLimit,
            timelineOccupancy: timelineOccupancy,
            supplementsPrimaryContent: supplementsPrimaryContent,
            contentMayVary: contentMayVary
        )
        schedule([config], replaceExisting: false)
    }

    /// Cancels the currently active interstitial ad event.
    public func cancelCurrent(resumptionOffset: CMTime = .zero) {
        guard let event = currentEvent else { return }

        playedEventIDs.insert(event.identifier)
        controller?.cancelCurrentEvent(withResumptionOffset: resumptionOffset)
        lastStartedEvent = nil

        setPlaybackState(.finished)
        stopObservingInterstitialPlaybackState()
        removeProgressObserver()
        refreshMarkers()
        emit(.didFinish(event, reason: .cancelled(resumptionOffset: resumptionOffset)))
    }

    // MARK: - Integrated Timeline Seeking

    /// Seeks to a target `CMTime` along the integrated timeline.
    public func seekOnIntegratedTimeline(
        to targetTime: CMTime,
        toleranceBefore: CMTime = .zero,
        toleranceAfter: CMTime = .zero,
        completion: @Sendable @escaping (Bool) -> Void
    ) {
        guard let timeline = currentItem?.integratedTimeline else {
            completion(false)
            return
        }

        let snapshotDur = CMTimeGetSeconds(timeline.currentSnapshot.duration)
        let dur = (integratedTimelineDuration > 0) ? integratedTimelineDuration :
            ((snapshotDur.isFinite && snapshotDur > 0) ? snapshotDur : 0.0)

        let clampedTarget: CMTime
        if dur > 0 {
            let end = integratedTimelineStartTime + dur
            let minTime = CMTime(seconds: integratedTimelineStartTime, preferredTimescale: 600)
            let maxTime = CMTime(seconds: end, preferredTimescale: 600)
            clampedTarget = CMTimeMinimum(CMTimeMaximum(minTime, targetTime), maxTime)
        } else {
            clampedTarget = targetTime
        }

        timeline.seek(
            to: clampedTarget,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter
        ) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    self.integratedTimelineCurrentTime = CMTimeGetSeconds(timeline.currentTime)
                    self.emit(.integratedTimeline(.timeUpdated(
                        currentTime: self.integratedTimelineCurrentTime,
                        startTime: self.integratedTimelineStartTime,
                        duration: self.integratedTimelineDuration
                    )))
                }
                completion(success)
            }
        }
    }

    /// Seeks to a target time interval in seconds along the integrated timeline.
    public func seekOnIntegratedTimeline(
        to time: TimeInterval,
        completion: @Sendable @escaping (Bool) -> Void
    ) {
        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        seekOnIntegratedTimeline(
            to: targetTime,
            toleranceBefore: .zero,
            toleranceAfter: .zero,
            completion: completion
        )
    }

    /// Seeks relative to the current position along the integrated timeline by a delta in seconds.
    public func seekOnIntegratedTimeline(
        by delta: TimeInterval,
        completion: @Sendable @escaping (Bool) -> Void
    ) {
        seekOnIntegratedTimeline(to: integratedTimelineCurrentTime + delta, completion: completion)
    }

    // MARK: - Private Setup & Observers

    /// Registers KVO and notification observers for the primary player and interstitial event
    /// monitor.
    private func setupObservers() {
        guard let primaryPlayer, let monitor else { return }

        // 1. Observe primary player's current item via KVO
        playerObservations.append(
            primaryPlayer.observe(\.currentItem, options: [
                .initial,
                .new,
            ]) { [weak self] player, _ in
                let newItem = player.currentItem
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    self.currentItem = newItem
                    if let newItem {
                        self.observeTimeline(for: newItem)
                    } else {
                        self.stopObservingTimeline()
                    }
                }
            }
        )

        // 2. Observe current interstitial event changes
        currentEventTask = Task { [weak self, weak monitor] in
            guard let monitor else { return }
            for await _ in NotificationCenter.default.notifications(
                named: AVPlayerInterstitialEventMonitor.currentEventDidChangeNotification,
                object: monitor
            ) {
                guard !Task.isCancelled, let self else { break }
                await MainActor.run {
                    self.handleCurrentEventChange()
                }
            }
        }

        // 3. Observe scheduled interstitial events changes
        scheduleEventsTask = Task { [weak self, weak monitor] in
            guard let monitor else { return }
            for await _ in NotificationCenter.default.notifications(
                named: AVPlayerInterstitialEventMonitor.eventsDidChangeNotification,
                object: monitor
            ) {
                guard !Task.isCancelled, let self else { break }
                await MainActor.run {
                    let events = self.scheduledEvents
                    self.refreshMarkers()
                    self.emit(.scheduleDidChange(events))
                }
            }
        }
    }

    /// Attaches observers to the integrated timeline of the provided player item.
    /// - Parameter item: The active primary player item.
    private func observeTimeline(for item: AVPlayerItem) {
        stopObservingTimeline()
        currentItem = item

        let timeline = item.integratedTimeline

        // Initial snapshot sync
        syncSnapshot(timeline.currentSnapshot)

        // KVO on currentSnapshot
        timelineObservations.append(
            timeline.observe(\.currentSnapshot, options: [
                .initial,
                .new,
            ]) { [weak self] observedTimeline, _ in
                let snapshot = observedTimeline.currentSnapshot
                Task { @MainActor [weak self] in
                    self?.syncSnapshot(snapshot)
                }
            }
        )

        // Notification on snapshot sync out-of-order
        timelineEventsTask = Task { [weak self, weak timeline] in
            guard let timeline else { return }
            for await _ in NotificationCenter.default.notifications(
                named: AVPlayerItemIntegratedTimeline.snapshotsOutOfSyncNotification,
                object: timeline
            ) {
                guard !Task.isCancelled, let self else { break }
                await MainActor.run {
                    self.emit(.integratedTimeline(.snapshotOutOfSync))
                }
            }
        }

        // Periodic timer for integrated timeline currentTime tracking
        timelineTimerTask = Task { [weak self, weak timeline] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, let self, let timeline else { break }
                await MainActor.run {
                    let currentSec = CMTimeGetSeconds(timeline.currentTime)
                    if !currentSec.isNaN, !currentSec.isInfinite,
                       abs(self.integratedTimelineCurrentTime - currentSec) > 0.05
                    {
                        self.integratedTimelineCurrentTime = currentSec
                        self.emit(.integratedTimeline(.timeUpdated(
                            currentTime: self.integratedTimelineCurrentTime,
                            startTime: self.integratedTimelineStartTime,
                            duration: self.integratedTimelineDuration
                        )))
                    }
                }
            }
        }
    }

    /// Cleans up integrated timeline observers and resets metrics.
    private func stopObservingTimeline() {
        timelineObservations.removeAll()
        timelineEventsTask?.cancel()
        timelineEventsTask = nil
        timelineTimerTask?.cancel()
        timelineTimerTask = nil
        currentItem = nil
        resetTimelineMetrics()
    }

    /// Resets all metrics and segments related to the integrated timeline.
    private func resetTimelineMetrics() {
        integratedTimelinePointSegments.removeAll()
        integratedTimelineFillSegments.removeAll()
        integratedTimelineCurrentTime = 0.0
        integratedTimelineStartTime = 0.0
        integratedTimelineDuration = 0.0
    }

    // MARK: - Private Current Event Handling

    /// Handles changes in the active interstitial event and triggers state transitions.
    private func handleCurrentEventChange() {
        let newEvent = currentEvent

        if let newEvent {
            if lastStartedEvent?.identifier != newEvent.identifier {
                emit(.willStart(newEvent))
                lastStartedEvent = newEvent
                setPlaybackState(.loading)
                startObservingInterstitialPlaybackState()
                startProgressObserver()
                refreshMarkers()
                emit(.didStart(newEvent))
            }
        } else {
            if let finishedEvent = lastStartedEvent {
                playedEventIDs.insert(finishedEvent.identifier)
                lastStartedEvent = nil
                setPlaybackState(.finished)
                stopObservingInterstitialPlaybackState()
                removeProgressObserver()
                refreshMarkers()
                emit(.didFinish(finishedEvent, reason: .completed))
            }
        }
    }

    // MARK: - Private Progress Observation

    /// Starts observing periodic time progress on the interstitial player.
    private func startProgressObserver() {
        removeProgressObserver()

        guard let interstitialPlayer = monitor?.interstitialPlayer else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)

        progressObserverToken = interstitialPlayer.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.emitProgress()
            }
        }
    }

    /// Removes the periodic progress time observer from the interstitial player.
    private func removeProgressObserver() {
        if let token = progressObserverToken,
           let player = monitor?.interstitialPlayer
        {
            player.removeTimeObserver(token)
        }
        progressObserverToken = nil
    }

    /// Emits progress metrics during active interstitial playback.
    private func emitProgress() {
        guard let item = monitor?.interstitialPlayer.currentItem else { return }

        let current = item.currentTime().seconds
        let duration = item.duration.seconds

        guard current.isFinite, duration.isFinite, duration > 0 else { return }

        let progress = AKPlayerInterstitialProgress(
            currentTime: current,
            duration: duration,
            timeRemaining: max(0, duration - current)
        )
        emit(.progress(progress))
    }

    // MARK: - Private Snapshot & Marker Synthesis

    /// Synchronizes internal timeline segments and metrics with a new integrated timeline snapshot.
    /// - Parameter snapshot: The updated timeline snapshot.
    private func syncSnapshot(_ snapshot: AVPlayerItemIntegratedTimelineSnapshot) {
        guard let timeline = currentItem?.integratedTimeline else { return }

        let segments = snapshot.segments

        var pointSegments: [AVPlayerItemSegment] = []
        var fillSegments: [AVPlayerItemSegment] = []

        for segment in segments where segment.segmentType == .interstitial {
            if let occupancy = segment.interstitialEvent?.timelineOccupancy {
                if occupancy == .singlePoint {
                    pointSegments.append(segment)
                } else if occupancy == .fill {
                    fillSegments.append(segment)
                }
            } else {
                let targetDuration = segment.timeMapping.target.duration
                if targetDuration == .zero {
                    pointSegments.append(segment)
                } else {
                    fillSegments.append(segment)
                }
            }
        }

        integratedTimelinePointSegments = pointSegments
        integratedTimelineFillSegments = fillSegments

        if let firstSegment = segments.first {
            let startSec = CMTimeGetSeconds(firstSegment.timeMapping.target.start)
            integratedTimelineStartTime = (startSec.isNaN || startSec.isInfinite) ? 0.0 : startSec
        } else {
            integratedTimelineStartTime = 0.0
        }

        let snapshotDuration = CMTimeGetSeconds(snapshot.duration)
        integratedTimelineDuration = (snapshotDuration.isNaN || snapshotDuration.isInfinite) ? 0.0 :
            snapshotDuration

        let currentSec = CMTimeGetSeconds(timeline.currentTime)
        if !currentSec.isNaN, !currentSec.isInfinite {
            integratedTimelineCurrentTime = currentSec
        }

        refreshMarkers()

        emit(.integratedTimeline(.segmentsUpdated(
            pointSegments: integratedTimelinePointSegments,
            fillSegments: integratedTimelineFillSegments
        )))

        emit(.integratedTimeline(.timeUpdated(
            currentTime: integratedTimelineCurrentTime,
            startTime: integratedTimelineStartTime,
            duration: integratedTimelineDuration
        )))
    }

    /// Re-synthesizes all timeline markers combining scheduled events and integrated timeline
    /// segments.
    private func refreshMarkers() {
        var newMarkers: [AKInterstitialMarker] = []
        let currentEventID = currentEvent?.identifier

        // Build map of interstitial segments from integrated timeline snapshots
        var segmentsByEventID: [String: AVPlayerItemSegment] = [:]
        if let currentItem {
            for segment in currentItem.integratedTimeline.currentSnapshot.segments
                where segment.segmentType == .interstitial
            {
                if let event = segment.interstitialEvent {
                    segmentsByEventID[event.identifier] = segment
                }
            }
        }

        for segment in integratedTimelinePointSegments + integratedTimelineFillSegments {
            if let event = segment.interstitialEvent, segmentsByEventID[event.identifier] == nil {
                segmentsByEventID[event.identifier] = segment
            }
        }

        let allScheduled = scheduledEvents
        var processedIDs = Set<String>()

        for event in allScheduled {
            let id = event.identifier
            let isCurrent = (id == currentEventID) && isPlayingInterstitial
            let isPlayed = playedEventIDs.contains(id)
            let segment = segmentsByEventID[id]
            newMarkers.append(AKInterstitialMarker(
                event: event,
                segment: segment,
                isPlayed: isPlayed,
                isCurrent: isCurrent
            ))
            processedIDs.insert(id)
        }

        // Also incorporate any interstitial segments that weren't in scheduledEvents
        for (id, segment) in segmentsByEventID where !processedIDs.contains(id) {
            if let event = segment.interstitialEvent {
                let isCurrent = (id == currentEventID) && isPlayingInterstitial
                let isPlayed = playedEventIDs.contains(id)
                newMarkers.append(AKInterstitialMarker(
                    event: event,
                    segment: segment,
                    isPlayed: isPlayed,
                    isCurrent: isCurrent
                ))
                processedIDs.insert(id)
            }
        }

        newMarkers.sort { $0.time < $1.time }

        guard markers != newMarkers else { return }
        markers = newMarkers
        emit(.adMarkersDidChange(markers))
    }

    // MARK: - Private Interstitial Playback State Management

    /// Begins observing playback status and buffer flags on the interstitial player.
    private func startObservingInterstitialPlaybackState() {
        stopObservingInterstitialPlaybackState()

        guard let player = monitor?.interstitialPlayer else { return }

        // timeControlStatus
        interstitialStatusObservations.append(
            player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.updatePlaybackState()
                }
            }
        )

        // currentItem
        interstitialStatusObservations.append(
            player.observe(\.currentItem, options: [
                .initial,
                .new,
            ]) { [weak self] observedPlayer, _ in
                let newItem = observedPlayer.currentItem
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.observeItemBufferFlags(newItem)
                    self.updatePlaybackState()
                }
            }
        )
    }

    /// Observes buffering and readiness properties on the current interstitial player item.
    /// - Parameter item: The active interstitial player item.
    private func observeItemBufferFlags(_ item: AVPlayerItem?) {
        interstitialItemObservations.removeAll()
        guard let item else { return }

        interstitialItemObservations.append(
            item.observe(\.isPlaybackLikelyToKeepUp, options: [
                .initial,
                .new,
            ]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.updatePlaybackState() }
            }
        )

        interstitialItemObservations.append(
            item.observe(\.isPlaybackBufferFull, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.updatePlaybackState() }
            }
        )

        interstitialItemObservations.append(
            item.observe(\.isPlaybackBufferEmpty, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.updatePlaybackState() }
            }
        )

        interstitialItemObservations.append(
            item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.updatePlaybackState() }
            }
        )
    }

    /// Stops observing interstitial player status and item buffer flags.
    private func stopObservingInterstitialPlaybackState() {
        interstitialItemObservations.removeAll()
        interstitialStatusObservations.removeAll()
    }

    /// Evaluates current interstitial player conditions and updates `playbackState`.
    private func updatePlaybackState() {
        guard isPlayingInterstitial,
              let player = monitor?.interstitialPlayer
        else {
            setPlaybackState(.idle)
            return
        }

        let item = player.currentItem

        // 1. Loading
        if item == nil || item?.status != .readyToPlay {
            setPlaybackState(.loading)
            return
        }

        // 2. If buffer is likely to keep up or full, or actively playing
        if item?.isPlaybackLikelyToKeepUp == true || item?.isPlaybackBufferFull == true || player
            .timeControlStatus == .playing
        {
            if player.timeControlStatus == .paused {
                setPlaybackState(.paused)
            } else {
                setPlaybackState(.playing)
            }
            return
        }

        // 3. If buffer is empty or waiting to play -> Buffering
        if item?.isPlaybackBufferEmpty == true || player
            .timeControlStatus == .waitingToPlayAtSpecifiedRate
        {
            if player.reasonForWaitingToPlay == .noItemToPlay {
                setPlaybackState(.idle)
            } else {
                setPlaybackState(.buffering)
            }
            return
        }

        // 4. Fallback by timeControlStatus
        switch player.timeControlStatus {
        case .playing:
            setPlaybackState(.playing)
        case .paused:
            setPlaybackState(.paused)
        case .waitingToPlayAtSpecifiedRate:
            if player.reasonForWaitingToPlay == .noItemToPlay {
                setPlaybackState(.idle)
            } else {
                setPlaybackState(.buffering)
            }
        @unknown default:
            setPlaybackState(.paused)
        }
    }

    /// Updates internal interstitial playback state and emits an event if changed.
    /// - Parameter newState: The newly determined playback state.
    private func setPlaybackState(_ newState: AKInterstitialPlaybackState) {
        guard playbackState != newState else { return }
        playbackState = newState
        emit(.playbackStateDidChange(newState))
    }

    /// Sends an interstitial event to all active stream subscribers.
    /// - Parameter event: The interstitial event to emit.
    private func emit(_ event: AKInterstitialEvent) {
        eventBroadcaster.send(event)
    }
}
