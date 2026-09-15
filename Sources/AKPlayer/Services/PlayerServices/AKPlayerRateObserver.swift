//
//   AKPlayerRateObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKPlaybackRateChange

/// Model representing a rate change event emitted by an AVPlayer instance.
public struct AKPlaybackRateChange: Sendable {
    public let previousRate: AKPlaybackRate
    public let currentRate: AKPlaybackRate
    public let reason: AVPlayer.RateDidChangeReason

    public init(
        previousRate: AKPlaybackRate,
        currentRate: AKPlaybackRate,
        reason: AVPlayer.RateDidChangeReason
    ) {
        self.previousRate = previousRate
        self.currentRate = currentRate
        self.reason = reason
    }
}

// MARK: - AKPlayerRateObserverProtocol

/// Interface describing an object capable of observing rate change
/// notifications on an AVPlayer.
@MainActor
public protocol AKPlayerRateObserverProtocol: AnyObject {
    var player: AVPlayer { get }
    var rateChanges: AsyncStream<AKPlaybackRateChange> { get }

    func startObserving()
    func stopObserving()
}

// MARK: - AKPlayerRateObserver

/// Class responsible for tracking AVPlayer rate transitions and publishing
/// unified change events.
@MainActor
public class AKPlayerRateObserver: AKPlayerRateObserverProtocol {
    // MARK: - Properties

    public let player: AVPlayer

    public var rateChanges: AsyncStream<AKPlaybackRateChange> {
        rateChangeStream
    }

    private let rateChangeStream: AsyncStream<AKPlaybackRateChange>
    private let rateChangeContinuation:
        AsyncStream<AKPlaybackRateChange>
        .Continuation

    private var isObserving = false

    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()

    private var currentRate: AKPlaybackRate?

    // MARK: - Init & Deinit

    /// Initializes a rate observer instance bound to an AVPlayer.
    /// - Parameter player: The AVPlayer instance to monitor.
    public init(with player: AVPlayer) {
        self.player = player

        let (stream, continuation) =
            AsyncStream
                .makeStream(of: AKPlaybackRateChange.self)
        rateChangeStream = stream
        rateChangeContinuation = continuation
    }

    deinit {
        rateChangeContinuation.finish()
    }

    // MARK: - Observation Lifecycle

    public func startObserving() {
        guard !isObserving else { return }

        let initialRate = AKPlaybackRate(rate: player.rate)
        currentRate = initialRate

        // Listen to NotificationCenter updates using @MainActor closure
        // isolation
        NotificationCenter.default.publisher(
            for: AVPlayer.rateDidChangeNotification,
            object: player
        )
        .sink { [weak self] notification in
            guard let self else { return }

            guard
                let userInfo = notification.userInfo,
                let reason = userInfo[AVPlayer.rateDidChangeReasonKey]
                as? AVPlayer.RateDidChangeReason
            else {
                return
            }

            let previous =
                currentRate
                    ?? AKPlaybackRate(rate: player.rate)

            let current = AKPlaybackRate(rate: player.rate)

            currentRate = current

            let change = AKPlaybackRateChange(
                previousRate: previous,
                currentRate: current,
                reason: reason
            )

            rateChangeContinuation.yield(change)
        }
        .store(in: &subscriptions)

        isObserving = true
    }

    public func stopObserving() {
        guard isObserving else { return }
        subscriptions.removeAll()
        isObserving = false
    }
}
