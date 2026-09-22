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
    /// The previous playback rate before the transition.
    public let previousRate: AKPlaybackRate
    /// The new current playback rate.
    public let currentRate: AKPlaybackRate
    /// The system-reported reason for the rate change, if available.
    public let reason: AVPlayer.RateDidChangeReason?

    /// Initializes a new playback rate change event payload.
    /// - Parameters:
    ///   - previousRate: The previous playback rate before the transition.
    ///   - currentRate: The new active playback rate.
    ///   - reason: The optional system reason explaining why the rate changed.
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
    /// The target AVPlayer instance being observed.
    var player: AVPlayer { get }
    /// Asynchronous stream yielding rate change events.
    var rateChanges: AsyncStream<AKPlaybackRateChange> { get }

    /// Begins observing rate change notifications on the player.
    func startObserving()
    /// Stops observing rate change notifications and cancels observation tasks.
    func stopObserving()
}

// MARK: - AKPlayerRateObserver

/// Class responsible for tracking AVPlayer rate transitions and broadcasting unified change events.
@MainActor
public final class AKPlayerRateObserver: AKPlayerRateObserverProtocol {
    // MARK: - Properties

    /// The underlying AVPlayer instance being observed.
    public let player: AVPlayer

    /// Asynchronous stream emitting playback rate changes.
    public var rateChanges: AsyncStream<AKPlaybackRateChange> {
        eventBroadcaster.makeStream()
    }

    /// Internal broadcaster dispatching playback rate change events.
    private let eventBroadcaster = AKEventBroadcaster<AKPlaybackRateChange>()

    /// Boolean indicating whether the observer is actively listening for rate notifications.
    private var isObserving = false
    /// Cached playback rate used to compute previous vs new rate changes.
    private var currentRate: AKPlaybackRate?
    /// Active task receiving and handling rate change notifications.
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

    /// Starts observing system rate change notifications for the player.
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
                handleRateDidChangeNotification(notification)
            }
        }
    }

    /// Stops observing system rate change notifications and cleans up observation tasks.
    public func stopObserving() {
        guard isObserving else { return }
        observationTask?.cancel()
        observationTask = nil
        isObserving = false
    }

    // MARK: - Private Notification Handling

    /// Processes rate change notifications from AVPlayer and broadcasts delta change events.
    /// - Parameter notification: The `AVPlayer.rateDidChangeNotification` instance containing
    /// reason payload.
    private func handleRateDidChangeNotification(_ notification: Notification) {
        let reason = notification.userInfo?[AVPlayer.rateDidChangeReasonKey] as? AVPlayer
            .RateDidChangeReason
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
