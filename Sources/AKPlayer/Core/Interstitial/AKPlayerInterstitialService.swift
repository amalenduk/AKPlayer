//
//  AKPlayerInterstitialService.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar. All rights reserved.
//  Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine
import Foundation

// MARK: - AKPlayerInterstitialService

@MainActor
public final class AKPlayerInterstitialService: NSObject, AKPlayerInterstitialServiceProtocol {
    
    // MARK: - Public Properties
    
    public var events: AsyncStream<AKInterstitialEvent> {
        eventBroadcaster.makeStream()
    }
    
    public var currentEvent: AVPlayerInterstitialEvent? {
        monitor?.currentEvent
    }
    
    public var isPlayingInterstitial: Bool {
        currentEvent != nil
    }
    
    public var scheduledEvents: [AVPlayerInterstitialEvent] {
        monitor?.events ?? []
    }
    
    public var interstitialPlayer: AVPlayer? {
        monitor?.interstitialPlayer
    }
    
    public var integratedTimeline: AVPlayerItemIntegratedTimeline? {
        primaryPlayer?.currentItem?.integratedTimeline
    }
    
    // MARK: - Integrated Timeline UI Properties
    
    public private(set) var integratedTimelinePointSegments: [AVPlayerItemSegment] = []
    public private(set) var integratedTimelineFillSegments: [AVPlayerItemSegment] = []
    public private(set) var integratedTimelineCurrentTime: Double = 0.0
    public private(set) var integratedTimelineStartTime: Double = 0.0
    public private(set) var integratedTimelineDuration: Double = 0.0
    
    // MARK: - Ad Restrictions Capabilities
    
    public var currentRestrictions: AVPlayerInterstitialEvent.Restrictions {
        currentEvent?.restrictions ?? []
    }
    
    public var canSeek: Bool {
        !currentRestrictions.contains(.constrainsSeekingForwardInPrimaryContent)
    }
    
    public var canFastForward: Bool {
        !currentRestrictions.contains(.constrainsSeekingForwardInPrimaryContent) &&
        !currentRestrictions.contains(.requiresPlaybackAtPreferredRateForAdvancement)
    }
    
    // MARK: - Private Properties
    
    private weak var primaryPlayer: AVPlayer?
    private weak var currentItem: AVPlayerItem?
    
    private var monitor: AVPlayerInterstitialEventMonitor?
    private var controller: AVPlayerInterstitialEventController?
    
    private let eventBroadcaster = AKEventBroadcaster<AKInterstitialEvent>()
    
    private var progressObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    private var timelineCancellables = Set<AnyCancellable>()
    
    private var lastStartedEvent: AVPlayerInterstitialEvent?
    
    // MARK: - Initialization
    
    public init(player: AVPlayer) {
        self.primaryPlayer = player
        super.init()
        
        self.monitor = AVPlayerInterstitialEventMonitor(primaryPlayer: player)
        self.controller = AVPlayerInterstitialEventController(primaryPlayer: player)
        
        setupObservers()
    }
    
    deinit {
        eventBroadcaster.finish()
    }
    
    // MARK: - Timeline & Event Observation Lifecycle
    
    public func stopObserving() {
        stopObservingTimeline()
        removeProgressObserver()
        cancellables.removeAll()
    }
    
    private func stopObservingTimeline() {
        timelineCancellables.removeAll()
        currentItem = nil
        resetTimelineMetrics()
    }
    
    // MARK: - System Interstitial Event Observers
    
    private func setupObservers() {
        guard let monitor else { return }
        
        primaryPlayer?
            .publisher(for: \.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newItem in
                guard let self else { return }
                guard let newItem else {
                    self.stopObservingTimeline()
                    return
                }
                self.handleItemChanged(newItem)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: AVPlayerInterstitialEventMonitor.currentEventDidChangeNotification, object: monitor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.handleCurrentEventDidChange()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: AVPlayerInterstitialEventMonitor.eventsDidChangeNotification, object: monitor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.handleScheduleDidChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleItemChanged(_ newItem: AVPlayerItem) {
        stopObservingTimeline()
        self.currentItem = newItem
        
        // Observe status safely before referencing timeline
        newItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak newItem] status in
                guard let self = self, let newItem = newItem, self.currentItem === newItem else { return }
                
                if status == .readyToPlay {
                    self.setupIntegratedTimelineObservation(for: newItem)
                } else if status == .failed {
                    self.stopObservingTimeline()
                }
            }
            .store(in: &timelineCancellables)
    }
    
    private func setupIntegratedTimelineObservation(for item: AVPlayerItem) {
        let timeline = item.integratedTimeline
        
        // Initial Snapshot Sync
        syncSnapshot(timeline.currentSnapshot)
        
        // 1. Observe Snapshot Out-Of-Sync Notification safely on Main
        NotificationCenter.default
            .publisher(for: AVPlayerItemIntegratedTimeline.snapshotsOutOfSyncNotification, object: timeline)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak item] _ in
                guard let self = self, let activeItem = item, self.currentItem === activeItem else { return }
                self.syncSnapshot(activeItem.integratedTimeline.currentSnapshot)
                self.emit(.integratedTimeline(.snapshotOutOfSync))
            }
            .store(in: &timelineCancellables)
        
        // 2. Safe Main-Thread Timer to observe current time changes without CoreMedia thread breaks
        Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self, weak item] _ in
                guard let self = self, let activeItem = item, self.currentItem === activeItem else { return }
                let time = activeItem.integratedTimeline.currentTime.seconds
                
                guard !time.isNaN, !time.isInfinite else { return }
                self.integratedTimelineCurrentTime = time
                
                self.emit(.integratedTimeline(.timeUpdated(
                    currentTime: self.integratedTimelineCurrentTime,
                    startTime: self.integratedTimelineStartTime,
                    duration: self.integratedTimelineDuration
                )))
            }
            .store(in: &timelineCancellables)
    }
    
    private func handleCurrentEventDidChange() {
        let newEvent = monitor?.currentEvent
        
        if let newEvent {
            if lastStartedEvent?.identifier != newEvent.identifier {
                if let previous = lastStartedEvent {
                    emit(.didFinish(previous, reason: .completed))
                }
                
                lastStartedEvent = newEvent
                emit(.willStart(newEvent))
                emit(.didStart(newEvent))
                startProgressObserver()
            }
        } else {
            if let finished = lastStartedEvent {
                emit(.didFinish(finished, reason: .completed))
                lastStartedEvent = nil
            }
            removeProgressObserver()
        }
    }
    
    private func handleScheduleDidChange() {
        emit(.scheduleDidChange(scheduledEvents))
    }
    
    // MARK: - Ad Progress Observer
    
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
    
    private func removeProgressObserver() {
        if let token = progressObserverToken,
           let player = monitor?.interstitialPlayer {
            player.removeTimeObserver(token)
        }
        progressObserverToken = nil
    }
    
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
    
    // MARK: - Scheduling API
    
    public func setEvents(_ events: [AVPlayerInterstitialEvent]) {
        controller?.events = events
    }
    
    public func appendEvents(_ events: [AVPlayerInterstitialEvent]) {
        guard let controller else { return }
        var currentEvents = controller.events
        controller.events.append(contentsOf: events)
        controller.events = currentEvents
    }
    
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
        guard let primaryItem = primaryPlayer?.currentItem else { return }
        
        let event = AVPlayerInterstitialEvent(
            primaryItem: primaryItem,
            identifier: identifier ?? UUID().uuidString,
            time: time,
            templateItems: templateItems,
            restrictions: restrictions,
            resumptionOffset: resumptionOffset,
            playoutLimit: playoutLimit
        )
        
        event.timelineOccupancy = timelineOccupancy
        event.supplementsPrimaryContent = supplementsPrimaryContent
        event.contentMayVary = contentMayVary
        
        appendEvents([event])
    }
    
    // MARK: - Control API
    
    public func cancelCurrent(resumptionOffset: CMTime = .zero) {
        guard let event = currentEvent else { return }
        
        controller?.cancelCurrentEvent(withResumptionOffset: resumptionOffset)
        emit(.didFinish(event, reason: .cancelled(resumptionOffset: resumptionOffset)))
        lastStartedEvent = nil
        removeProgressObserver()
    }
    
    // MARK: - Private Helpers
    
    private func syncSnapshot(_ snapshot: AVPlayerItemIntegratedTimelineSnapshot) {
        guard let timeline = currentItem?.integratedTimeline else { return }
        
        let segments = snapshot.segments
        
        var pointSegments: [AVPlayerItemSegment] = []
        var fillSegments: [AVPlayerItemSegment] = []
        
        for segment in segments where segment.segmentType == .interstitial {
            if segment.interstitialEvent?.timelineOccupancy == .singlePoint {
                pointSegments.append(segment)
            } else if segment.interstitialEvent?.timelineOccupancy == .fill {
                fillSegments.append(segment)
            }
        }
        
        self.integratedTimelinePointSegments = pointSegments
        self.integratedTimelineFillSegments = fillSegments
        
        if let firstSegment = segments.first {
            let startSec = CMTimeGetSeconds(firstSegment.timeMapping.target.start)
            self.integratedTimelineStartTime = (startSec.isNaN || startSec.isInfinite) ? 0.0 : startSec
        } else {
            self.integratedTimelineStartTime = 0.0
        }
        
        let snapshotDuration = CMTimeGetSeconds(snapshot.duration)
        self.integratedTimelineDuration = (snapshotDuration.isNaN || snapshotDuration.isInfinite) ? 0.0 : snapshotDuration
        
        let currentSec = CMTimeGetSeconds(timeline.currentTime)
        if !currentSec.isNaN, !currentSec.isInfinite {
            self.integratedTimelineCurrentTime = currentSec
        }
        
        emit(.integratedTimeline(.segmentsUpdated(
            pointSegments: self.integratedTimelinePointSegments,
            fillSegments: self.integratedTimelineFillSegments
        )))
        
        emit(.integratedTimeline(.timeUpdated(
            currentTime: self.integratedTimelineCurrentTime,
            startTime: self.integratedTimelineStartTime,
            duration: self.integratedTimelineDuration
        )))
    }
    
    public func seekOnIntegratedTimeline(to time: TimeInterval, completion: @escaping (Bool) -> Void) {
        guard let timeline = currentItem?.integratedTimeline else {
            completion(false)
            return
        }
        
        var targetTime = CMTime(seconds: time, preferredTimescale: 600)
        
        let integratedTimelineEndTime = integratedTimelineStartTime + integratedTimelineDuration
        let minTime = CMTime(seconds: integratedTimelineStartTime, preferredTimescale: 600)
        let maxTime = CMTime(seconds: integratedTimelineEndTime, preferredTimescale: 600)
        
        targetTime = CMTimeMinimum(CMTimeMaximum(minTime, targetTime), maxTime)
        
        timeline.seek(
            to: targetTime,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if success {
                    self.integratedTimelineCurrentTime = CMTimeGetSeconds(timeline.currentTime)
                }
                completion(success)
            }
        }
    }
    
    public func seekOnIntegratedTimeline(by delta: TimeInterval, completion: @escaping (Bool) -> Void) {
        let targetTime = integratedTimelineCurrentTime + delta
        seekOnIntegratedTimeline(to: targetTime, completion: completion)
    }
    
    private func resetTimelineMetrics() {
        integratedTimelinePointSegments.removeAll()
        integratedTimelineFillSegments.removeAll()
        integratedTimelineCurrentTime = 0.0
        integratedTimelineStartTime = 0.0
        integratedTimelineDuration = 0.0
    }
    
    private func emit(_ event: AKInterstitialEvent) {
        eventBroadcaster.send(event)
    }
}
