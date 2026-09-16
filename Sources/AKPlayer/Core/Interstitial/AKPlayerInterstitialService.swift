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
    
    // MARK: - Private
    
    private weak var primaryPlayer: AVPlayer?
    private var monitor: AVPlayerInterstitialEventMonitor?
    private var controller: AVPlayerInterstitialEventController?
    
    private let eventBroadcaster = AKEventBroadcaster<AKInterstitialEvent>()
    
    private var progressObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    
    /// Tracks the last emitted “started” event so we can emit a clean finish.
    private var lastStartedEvent: AVPlayerInterstitialEvent?
    
    // MARK: - Init
    
    public init(player: AVPlayer) {
        self.primaryPlayer = player
        super.init()
        
        // Monitor always observes (server-side + client-side).
        monitor = AVPlayerInterstitialEventMonitor(primaryPlayer: player)
        
        // Controller is used only when the app wants to schedule client-side events.
        controller = AVPlayerInterstitialEventController(primaryPlayer: player)
        
        setupObservers()
    }
    
    deinit {
        removeProgressObserver()
        eventBroadcaster.finish()
        cancellables.removeAll()
    }
    
    // MARK: - Setup Observers
    
    private func setupObservers() {
        guard let monitor else { return }
        
        // 1. Current event changed (start / end of an interstitial)
        NotificationCenter.default
            .publisher(for: AVPlayerInterstitialEventMonitor.currentEventDidChangeNotification, object: monitor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleCurrentEventDidChange()
            }
            .store(in: &cancellables)
        
        // 2. Schedule changed
        NotificationCenter.default
            .publisher(for: AVPlayerInterstitialEventMonitor.eventsDidChangeNotification, object: monitor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleScheduleDidChange()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Handlers
    
    private func handleCurrentEventDidChange() {
        let newEvent = monitor?.currentEvent
        
        if let newEvent {
            // Transition into interstitial
            if lastStartedEvent?.identifier != newEvent.identifier {
                // Finish previous if any (edge case of rapid switch)
                if let previous = lastStartedEvent {
                    emit(.didFinish(previous, reason: .completed))
                }
                
                lastStartedEvent = newEvent
                emit(.willStart(newEvent))
                emit(.didStart(newEvent))
                startProgressObserver()
            }
        } else {
            // Transition back to primary
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
    
    // MARK: - Progress Observer (only while interstitial is active)
    
    private func startProgressObserver() {
        removeProgressObserver()
        
        guard let interstitialPlayer = monitor?.interstitialPlayer else { return }
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        progressObserverToken = interstitialPlayer.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
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
    
    // MARK: - Public API – Scheduling
    
    public func setEvents(_ events: [AVPlayerInterstitialEvent]) {
        controller?.events = events
    }
    
    public func appendEvents(_ events: [AVPlayerInterstitialEvent]) {
        guard let controller else { return }
        controller.events.append(contentsOf: events)
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
    
    // MARK: - Public API – Control
    
    public func cancelCurrent(resumptionOffset: CMTime = .zero) {
        guard let event = currentEvent else { return }
        
        controller?.cancelCurrentEvent(withResumptionOffset: resumptionOffset)
        
        emit(.didFinish(event, reason: .cancelled(resumptionOffset: resumptionOffset)))
        lastStartedEvent = nil
        removeProgressObserver()
    }
    
    // MARK: - Private Helpers
    
    private func emit(_ event: AKInterstitialEvent) {
        eventBroadcaster.send(event)
    }
}
