//
//   AKAudioSessionSilenceSecondaryAudioHintObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

// Ref: https://developer.apple.com/documentation/avfaudio/avaudiosession/1616622-silencesecondaryaudiohintnotific

import AVFoundation
import Foundation
import Synchronization

// MARK: - AKAudioSessionSilenceSecondaryAudioHintEvent

/// Events emitted when system secondary audio silence hints begin or end.
public enum AKAudioSessionSilenceSecondaryAudioHintEvent: Sendable, Equatable {
    /// Another application with a non-mixable audio session started playing audio.
    case began
    /// Another application with a non-mixable audio session finished playing audio.
    case ended
}

// MARK: - AKAudioSessionSilenceSecondaryAudioHintObserverProtocol

/// A protocol defining requirements for observing secondary audio hints.
public protocol AKAudioSessionSilenceSecondaryAudioHintObserverProtocol: AnyObject, Sendable {
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }

    /// Asynchronous stream of secondary audio hint events for Swift Concurrency.
    var events: AsyncStream<AKAudioSessionSilenceSecondaryAudioHintEvent> { get }

    /// Begins observing system-level secondary audio hint notifications.
    func startObserving()

    /// Stops monitoring secondary audio hint notifications and clears active tasks.
    func stopObserving()
}

// MARK: - AKAudioSessionSilenceSecondaryAudioHintObserver

/// A thread-safe observer class responsible for monitoring
/// `AVAudioSession.silenceSecondaryAudioHintNotification`
/// and broadcasting events via `AsyncStream`.
public final class AKAudioSessionSilenceSecondaryAudioHintObserver:
    AKAudioSessionSilenceSecondaryAudioHintObserverProtocol, Sendable
{
    // MARK: - Properties

    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession

    /// Broadcaster managing the asynchronous stream of secondary audio hint events.
    private let eventBroadcaster =
        AKEventBroadcaster<AKAudioSessionSilenceSecondaryAudioHintEvent>()

    /// Asynchronous stream of secondary audio hint events for Swift Concurrency.
    public var events: AsyncStream<AKAudioSessionSilenceSecondaryAudioHintEvent> {
        eventBroadcaster.makeStream()
    }

    /// Mutex protecting the active notification observation task.
    private let observationTask = Mutex<Task<Void, Never>?>(nil)

    // MARK: - Init & Deinit

    /// Initializes a new secondary audio hint observer with a target audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }

    deinit {
        stopObserving()
        eventBroadcaster.finish()
    }

    // MARK: - Observation Lifecycle

    /// Starts observing secondary audio hint notifications.
    public func startObserving() {
        stopObserving()

        let task = Task { [weak self, audioSession] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.silenceSecondaryAudioHintNotification,
                object: audioSession
            ) {
                guard !Task.isCancelled, let self else { break }
                handleSilenceSecondaryAudioHintNotification(notification)
            }
        }

        observationTask.withLock { $0 = task }
    }

    /// Stops observing secondary audio hint notifications and cancels active tasks.
    public func stopObserving() {
        observationTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }

    // MARK: - Handlers

    /// Processes incoming secondary audio hint notifications and emits stream events.
    /// - Parameter notification: The `Notification` object containing hint metadata.
    private func handleSilenceSecondaryAudioHintNotification(
        _ notification: Notification
    ) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue)
        else {
            return
        }

        switch type {
        case .begin:
            eventBroadcaster.send(.began)
        case .end:
            eventBroadcaster.send(.ended)
        @unknown default:
            break
        }
    }
}
