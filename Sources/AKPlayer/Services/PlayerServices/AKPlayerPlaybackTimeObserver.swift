//
//   AKPlayerPlaybackTimeObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayerPlaybackTimeObserverProtocol

/// Protocol declaring capabilities for monitoring AVPlayer periodic and boundary time updates.
@MainActor
public protocol AKPlayerPlaybackTimeObserverProtocol: AnyObject, Sendable {
    /// The underlying AVPlayer instance being observed.
    var player: AVPlayer { get }
    /// Asynchronous stream of periodic playback time updates.
    var periodicTimes: AsyncStream<CMTime> { get }
    /// Asynchronous stream of boundary time crossings.
    var boundaryTimes: AsyncStream<CMTime> { get }

    /// Starts periodic time observation at the specified interval.
    /// - Parameter interval: The frequency interval for updates.
    func startObservingPeriodicTime(for interval: CMTime)

    /// Stops periodic time observation and removes the registered observer.
    func stopObservingPeriodicTime()

    /// Starts boundary time observation for the specified timestamps.
    /// - Parameter times: The collection of boundary timestamps to observe.
    func startObservingBoundaryTime(for times: [CMTime])

    /// Stops boundary time observation and removes the registered observer.
    func stopObservingBoundaryTime()
}

// MARK: - AKPlayerPlaybackTimeObserver

/// Concrete observer delivering periodic and boundary time progress updates via asynchronous event
/// streams.
@MainActor
public final class AKPlayerPlaybackTimeObserver: AKPlayerPlaybackTimeObserverProtocol {
    // MARK: - Properties

    /// The observed AVPlayer instance.
    public let player: AVPlayer

    /// Asynchronous stream emitting periodic time updates during active playback.
    public var periodicTimes: AsyncStream<CMTime> {
        periodicBroadcaster.makeStream()
    }

    /// Asynchronous stream emitting boundary time events as thresholds are crossed.
    public var boundaryTimes: AsyncStream<CMTime> {
        boundaryBroadcaster.makeStream()
    }

    /// Internal broadcaster dispatching periodic time events.
    private let periodicBroadcaster = AKEventBroadcaster<CMTime>()
    /// Internal broadcaster dispatching boundary time events.
    private let boundaryBroadcaster = AKEventBroadcaster<CMTime>()

    /// Retained token for the periodic time observer on AVPlayer.
    private nonisolated(unsafe) var periodicTimeObserverToken: Any?
    /// Retained token for the boundary time observer on AVPlayer.
    private nonisolated(unsafe) var boundaryTimeObserverToken: Any?

    // MARK: - Init & Deinit

    /// Initializes an observer for player playback time events.
    /// - Parameter player: The AVPlayer instance to monitor.
    public init(with player: AVPlayer) {
        self.player = player
    }

    deinit {
        if let token = periodicTimeObserverToken {
            player.removeTimeObserver(token)
            periodicTimeObserverToken = nil
        }
        if let token = boundaryTimeObserverToken {
            player.removeTimeObserver(token)
            boundaryTimeObserverToken = nil
        }
        periodicBroadcaster.finish()
        boundaryBroadcaster.finish()
    }

    // MARK: - Periodic Time Observation

    /// Starts observing periodic playback time intervals on the player.
    /// - Parameter interval: The interval between time update callbacks.
    public func startObservingPeriodicTime(for interval: CMTime) {
        stopObservingPeriodicTime()

        periodicTimeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            self?.periodicBroadcaster.send(time)
        }
    }

    /// Stops periodic time observation and releases the observer token.
    public func stopObservingPeriodicTime() {
        if let token = periodicTimeObserverToken {
            player.removeTimeObserver(token)
            periodicTimeObserverToken = nil
        }
    }

    // MARK: - Boundary Time Observation

    /// Starts observing boundary timestamps on the player timeline.
    /// - Parameter times: The collection of CMTime points that trigger events when crossed.
    public func startObservingBoundaryTime(for times: [CMTime]) {
        stopObservingBoundaryTime()

        let boundaryTimes = times.map { NSValue(time: $0) }
        boundaryTimeObserverToken = player.addBoundaryTimeObserver(
            forTimes: boundaryTimes,
            queue: .main
        ) { [weak self] in
            guard let self else { return }
            boundaryBroadcaster.send(player.currentTime())
        }
    }

    /// Stops boundary time observation and releases the observer token.
    public func stopObservingBoundaryTime() {
        if let token = boundaryTimeObserverToken {
            player.removeTimeObserver(token)
            boundaryTimeObserverToken = nil
        }
    }
}
