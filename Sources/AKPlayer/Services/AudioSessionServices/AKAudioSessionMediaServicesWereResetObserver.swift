//
//   AKAudioSessionMediaServicesWereResetObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

// Ref: https://developer.apple.com/documentation/avfaudio/avaudiosession/1616540-mediaserviceswereresetnotificati

import AVFoundation
import Foundation
import Synchronization

// MARK: - AKAudioSessionMediaServicesWereResetObserverProtocol

/// A protocol defining requirements for observing audio media services reset events.
public protocol AKAudioSessionMediaServicesWereResetObserverProtocol: AnyObject, Sendable {
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }

    /// Asynchronous stream emitting signals when media services are reset.
    var events: AsyncStream<Void> { get }

    /// Begins observing system-level media services reset notifications.
    func startObserving()

    /// Stops monitoring media services reset notifications and clears active tasks.
    func stopObserving()
}

// MARK: - AKAudioSessionMediaServicesWereResetObserver

/// A thread-safe observer class responsible for monitoring
/// `AVAudioSession.mediaServicesWereResetNotification`
/// and broadcasting events via `AsyncStream`.
public final class AKAudioSessionMediaServicesWereResetObserver:
    AKAudioSessionMediaServicesWereResetObserverProtocol, Sendable
{
    // MARK: - Properties

    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession

    /// Broadcaster managing the asynchronous stream of media services reset events.
    private let eventBroadcaster = AKEventBroadcaster<Void>()

    /// Asynchronous stream of media services reset events for Swift Concurrency.
    public var events: AsyncStream<Void> {
        eventBroadcaster.makeStream()
    }

    /// Mutex protecting the active notification observation task.
    private let observationTask = Mutex<Task<Void, Never>?>(nil)

    // MARK: - Init & Deinit

    /// Initializes a new reset observer with a target audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }

    deinit {
        stopObserving()
        eventBroadcaster.finish()
    }

    // MARK: - Observation Lifecycle

    /// Starts observing audio media services reset notifications.
    public func startObserving() {
        stopObserving()

        let task = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: AVAudioSession.mediaServicesWereResetNotification,
                object: nil
            ) {
                guard !Task.isCancelled, let self else { break }
                eventBroadcaster.send(())
            }
        }

        observationTask.withLock { $0 = task }
    }

    /// Stops observing media services reset notifications and cancels active tasks.
    public func stopObserving() {
        observationTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }
}
