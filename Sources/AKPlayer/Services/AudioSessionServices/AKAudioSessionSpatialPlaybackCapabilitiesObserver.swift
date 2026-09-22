//
//   AKAudioSessionSpatialPlaybackCapabilitiesObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import Synchronization

// MARK: - AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol

/// A protocol defining requirements for observing spatial playback capabilities changes.
public protocol AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol: AnyObject, Sendable {
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }

    /// Asynchronous stream of spatial audio enablement updates.
    var events: AsyncStream<Bool> { get }

    /// Begins observing system-level spatial playback capabilities notifications.
    func startObserving()

    /// Stops monitoring spatial playback capabilities notifications and clears active tasks.
    func stopObserving()
}

// MARK: - AKAudioSessionSpatialPlaybackCapabilitiesObserver

/// A thread-safe observer class responsible for monitoring
/// `AVAudioSession.spatialPlaybackCapabilitiesChangedNotification`
/// and broadcasting updates via `AsyncStream`.
public final class AKAudioSessionSpatialPlaybackCapabilitiesObserver:
    AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol, Sendable
{
    // MARK: - Properties

    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession

    /// Broadcaster managing the asynchronous stream of spatial playback capability changes.
    private let eventBroadcaster = AKEventBroadcaster<Bool>()

    /// Asynchronous stream of spatial playback capability events for Swift Concurrency.
    public var events: AsyncStream<Bool> {
        eventBroadcaster.makeStream()
    }

    /// Mutex protecting the active notification observation task.
    private let observationTask = Mutex<Task<Void, Never>?>(nil)

    // MARK: - Init & Deinit

    /// Initializes a new spatial playback capabilities observer with a target audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }

    deinit {
        stopObserving()
        eventBroadcaster.finish()
    }

    // MARK: - Observation Lifecycle

    /// Starts observing spatial playback capabilities notifications.
    public func startObserving() {
        stopObserving()

        let task = Task { [weak self, audioSession] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.spatialPlaybackCapabilitiesChangedNotification,
                object: audioSession
            ) {
                guard !Task.isCancelled, let self else { break }
                handleSpatialPlaybackCapabilitiesChangedNotification(notification)
            }
        }

        observationTask.withLock { $0 = task }
    }

    /// Stops observing spatial playback capabilities notifications and clears active tasks.
    public func stopObserving() {
        observationTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }

    // MARK: - Handlers

    /// Processes incoming spatial playback capabilities changed notifications and emits stream
    /// events.
    /// - Parameter notification: The `Notification` object containing capability metadata.
    private func handleSpatialPlaybackCapabilitiesChangedNotification(
        _ notification: Notification
    ) {
        guard let userInfo = notification.userInfo,
              let isSpatialAudioEnabled =
              userInfo[AVAudioSessionSpatialAudioEnabledKey] as? NSNumber
        else {
            return
        }

        let isEnabled = isSpatialAudioEnabled.boolValue
        eventBroadcaster.send(isEnabled)
    }
}
