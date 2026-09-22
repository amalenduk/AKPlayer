//
//   AKAudioSessionInterruptionObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

/*
 Ref:
 https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_interruptions
 https://developer.apple.com/documentation/avfaudio/avaudiosession/1616596-interruptionnotification
 */

import AVFoundation
import Foundation
import Synchronization

// MARK: - AKAudioSessionInterruptionEvent

/// Events emitted during system audio session interruptions.
public enum AKAudioSessionInterruptionEvent: Sendable, Equatable {
    /// The audio session interruption began with an optional reason.
    case began(reason: AVAudioSession.InterruptionReason?)

    /// The audio session interruption ended, indicating if playback should resume.
    case ended(shouldResume: Bool)
}

// MARK: - AKAudioSessionInterruptionObserverProtocol

/// A protocol defining requirements for observing audio session lifecycle interruptions.
public protocol AKAudioSessionInterruptionObserverProtocol: AnyObject, Sendable {
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }

    /// A Boolean value indicating whether the audio session is currently in an interrupted state.
    var isInterrupted: Bool { get }

    /// Asynchronous stream of interruption events for Swift Concurrency.
    var events: AsyncStream<AKAudioSessionInterruptionEvent> { get }

    /// Begins observing system-level audio session interruption notifications.
    func startObserving()

    /// Stops monitoring audio session interruption notifications and removes active tasks.
    func stopObserving()
}

// MARK: - AKAudioSessionInterruptionObserver

/// A thread-safe observer class responsible for monitoring audio session interruptions
/// and broadcasting events via `AsyncStream`.
public final class AKAudioSessionInterruptionObserver: AKAudioSessionInterruptionObserverProtocol,
    Sendable
{
    // MARK: - Properties

    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession

    /// Thread-safe atomic flag tracking interrupted state.
    private let interruptedState = Mutex<Bool>(false)

    /// A Boolean value indicating whether the audio session is currently interrupted.
    public var isInterrupted: Bool {
        interruptedState.withLock { $0 }
    }

    /// Broadcaster managing the asynchronous stream of interruption events.
    private let eventBroadcaster = AKEventBroadcaster<AKAudioSessionInterruptionEvent>()

    /// Asynchronous stream of interruption events for Swift Concurrency.
    public var events: AsyncStream<AKAudioSessionInterruptionEvent> {
        eventBroadcaster.makeStream()
    }

    /// Mutex protecting the active notification observation task.
    private let observationTask = Mutex<Task<Void, Never>?>(nil)

    // MARK: - Init & Deinit

    /// Initializes a new interruption observer with a target audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }

    deinit {
        stopObserving()
        eventBroadcaster.finish()
    }

    // MARK: - Observation Lifecycle

    /// Starts observing audio session interruption notifications.
    public func startObserving() {
        stopObserving()

        let task = Task { [weak self, audioSession] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification,
                object: audioSession
            ) {
                guard !Task.isCancelled, let self else { break }
                handleAudioSessionInterruption(notification)
            }
        }

        observationTask.withLock { $0 = task }
    }

    /// Stops observing interruptions and cancels active observation tasks.
    public func stopObserving() {
        observationTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }

    // MARK: - Handlers

    /// Processes incoming interruption notifications and emits stream events.
    /// - Parameter notification: The `Notification` object containing interruption metadata.
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
        case .began:
            var interruptionReason: AVAudioSession.InterruptionReason?
            if let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt,
               let reason = AVAudioSession.InterruptionReason(rawValue: reasonValue)
            {
                interruptionReason = reason
            }
            interruptedState.withLock { $0 = true }
            eventBroadcaster.send(.began(reason: interruptionReason))

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            interruptedState.withLock { $0 = false }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume)
            eventBroadcaster.send(.ended(shouldResume: shouldResume))

        @unknown default:
            break
        }
    }
}
