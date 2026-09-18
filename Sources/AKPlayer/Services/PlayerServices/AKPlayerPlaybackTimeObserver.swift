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
    var player: AVPlayer { get }
    var periodicTimes: AsyncStream<CMTime> { get }
    var boundaryTimes: AsyncStream<CMTime> { get }

    func startObservingPeriodicTime(for interval: CMTime)
    func startObservingBoundaryTime(for times: [CMTime])
    func stopObservingPeriodicTime()
    func stopObservingBoundaryTime()
}

// MARK: - AKPlayerPlaybackTimeObserver

/// Concrete observer delivering periodic and boundary time progress updates via asynchronous event streams.
@MainActor
public final class AKPlayerPlaybackTimeObserver: AKPlayerPlaybackTimeObserverProtocol {
    // MARK: - Properties

    public let player: AVPlayer

    public var periodicTimes: AsyncStream<CMTime> {
        periodicBroadcaster.makeStream()
    }

    public var boundaryTimes: AsyncStream<CMTime> {
        boundaryBroadcaster.makeStream()
    }

    private let periodicBroadcaster = AKEventBroadcaster<CMTime>()
    private let boundaryBroadcaster = AKEventBroadcaster<CMTime>()

    private nonisolated(unsafe) var periodicTimeObserverToken: Any?
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

    public func startObservingPeriodicTime(for interval: CMTime) {
        stopObservingPeriodicTime()

        periodicTimeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            self?.periodicBroadcaster.send(time)
        }
    }

    public func stopObservingPeriodicTime() {
        if let token = periodicTimeObserverToken {
            player.removeTimeObserver(token)
            periodicTimeObserverToken = nil
        }
    }

    // MARK: - Boundary Time Observation

    public func startObservingBoundaryTime(for times: [CMTime]) {
        stopObservingBoundaryTime()

        let boundaryTimes = times.map { NSValue(time: $0) }
        boundaryTimeObserverToken = player.addBoundaryTimeObserver(
            forTimes: boundaryTimes,
            queue: .main
        ) { [weak self] in
            guard let self else { return }
            self.boundaryBroadcaster.send(self.player.currentTime())
        }
    }

    public func stopObservingBoundaryTime() {
        if let token = boundaryTimeObserverToken {
            player.removeTimeObserver(token)
            boundaryTimeObserverToken = nil
        }
    }
}
