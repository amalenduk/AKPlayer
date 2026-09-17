//
//   AKAudioSessionMediaServicesLostObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import Synchronization

// MARK: - AKAudioSessionMediaServicesLostObserverProtocol

/// A protocol defining requirements for observing audio media services loss events.
public protocol AKAudioSessionMediaServicesLostObserverProtocol: AnyObject, Sendable {
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }

    /// Asynchronous stream emitting signals when media services are lost.
    var events: AsyncStream<Void> { get }

    /// Begins observing system-level media services lost notifications.
    func startObserving()

    /// Stops monitoring media services lost notifications and removes active tasks.
    func stopObserving()
}

// MARK: - AKAudioSessionMediaServicesLostObserver

/// A thread-safe observer class responsible for monitoring `AVAudioSession.mediaServicesWereLostNotification`
/// and broadcasting events via `AsyncStream`.
public final class AKAudioSessionMediaServicesLostObserver:
    AKAudioSessionMediaServicesLostObserverProtocol, Sendable
{
    // MARK: - Properties

    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession

    /// Broadcaster managing the asynchronous stream of media services lost events.
    private let eventBroadcaster = AKEventBroadcaster<Void>()

    /// Asynchronous stream of media services lost events for Swift Concurrency.
    public var events: AsyncStream<Void> {
        eventBroadcaster.makeStream()
    }

    /// Mutex protecting the active notification observation task.
    private let observationTask = Mutex<Task<Void, Never>?>(nil)

    // MARK: - Init & Deinit

    /// Initializes a new observer with a target audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }

    deinit {
        stopObserving()
        eventBroadcaster.finish()
    }

    // MARK: - Observation Lifecycle

    /// Starts observing system audio media services lost notifications.
    public func startObserving() {
        stopObserving()

        let task = Task { [weak self, audioSession] in
            for await _ in NotificationCenter.default.notifications(
                named: AVAudioSession.mediaServicesWereLostNotification,
                object: audioSession
            ) {
                guard !Task.isCancelled, let self else { break }
                self.eventBroadcaster.send(())
            }
        }

        observationTask.withLock { $0 = task }
    }

    /// Stops observing media services lost notifications and cancels active observation tasks.
    public func stopObserving() {
        observationTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }
}
