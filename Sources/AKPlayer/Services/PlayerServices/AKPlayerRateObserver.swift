//
//   AKPlayerRateObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlaybackRateChange

/// Model representing a rate change event emitted by an AVPlayer instance.
public struct AKPlaybackRateChange: Equatable, Sendable {
    public let previousRate: AKPlaybackRate
    public let currentRate: AKPlaybackRate
    public let reason: AVPlayer.RateDidChangeReason?
    
    public init(
        previousRate: AKPlaybackRate,
        currentRate: AKPlaybackRate,
        reason: AVPlayer.RateDidChangeReason? = nil
    ) {
        self.previousRate = previousRate
        self.currentRate = currentRate
        self.reason = reason
    }
}

// MARK: - AKPlayerRateObserverProtocol

/// Interface describing an object capable of observing rate change notifications on an AVPlayer.
@MainActor
public protocol AKPlayerRateObserverProtocol: AnyObject, Sendable {
    var player: AVPlayer { get }
    var rateChanges: AsyncStream<AKPlaybackRateChange> { get }
    
    func startObserving()
    func stopObserving()
}

// MARK: - AKPlayerRateObserver

/// Class responsible for tracking AVPlayer rate transitions and broadcasting unified change events.
@MainActor
public final class AKPlayerRateObserver: AKPlayerRateObserverProtocol {
    // MARK: - Properties
    
    public let player: AVPlayer
    
    public var rateChanges: AsyncStream<AKPlaybackRateChange> {
        eventBroadcaster.makeStream()
    }
    
    private let eventBroadcaster = AKEventBroadcaster<AKPlaybackRateChange>()
    
    private var isObserving = false
    private var currentRate: AKPlaybackRate?
    private var observationTask: Task<Void, Never>?
    
    // MARK: - Init & Deinit
    
    /// Initializes a rate observer instance bound to an AVPlayer.
    /// - Parameter player: The AVPlayer instance to monitor.
    public init(with player: AVPlayer) {
        self.player = player
    }
    
    deinit {
        observationTask?.cancel()
        observationTask = nil
        eventBroadcaster.finish()
    }
    
    // MARK: - Observation Lifecycle
    
    public func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        currentRate = AKPlaybackRate(rate: player.rate)
        
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self, player] in
            for await notification in NotificationCenter.default.notifications(
                named: AVPlayer.rateDidChangeNotification,
                object: player
            ) {
                guard !Task.isCancelled, let self else { break }
                self.handleRateDidChangeNotification(notification)
            }
        }
    }
    
    public func stopObserving() {
        guard isObserving else { return }
        observationTask?.cancel()
        observationTask = nil
        isObserving = false
    }
    
    // MARK: - Private Notification Handling
    
    private func handleRateDidChangeNotification(_ notification: Notification) {
        let reason = notification.userInfo?[AVPlayer.rateDidChangeReasonKey] as? AVPlayer.RateDidChangeReason
        let previous = currentRate ?? AKPlaybackRate(rate: player.rate)
        let current = AKPlaybackRate(rate: player.rate)
        
        currentRate = current
        
        let change = AKPlaybackRateChange(
            previousRate: previous,
            currentRate: current,
            reason: reason
        )
        
        eventBroadcaster.send(change)
    }
}
