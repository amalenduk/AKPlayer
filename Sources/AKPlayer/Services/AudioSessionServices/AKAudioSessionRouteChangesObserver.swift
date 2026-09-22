//
//   AKAudioSessionRouteChangesObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

// Ref: https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_route_changes

import AVFoundation
import Foundation
import Synchronization

// MARK: - AKAudioSessionRouteChangeEvent

/// Event payload emitted when the active audio output route changes.
public struct AKAudioSessionRouteChangeEvent: Sendable, Equatable {
    /// The current audio route description.
    public let currentRoute: AVAudioSessionRouteDescription
    /// The previous audio route description before the change, if available.
    public let previousRoute: AVAudioSessionRouteDescription?
    /// The specific reason for the route change (e.g. category change, device plugged/unplugged).
    public let reason: AVAudioSession.RouteChangeReason

    /// Initializes a new route change event payload.
    /// - Parameters:
    ///   - currentRoute: The current active route description.
    ///   - previousRoute: The previous route description before the change occurred.
    ///   - reason: The underlying reason triggering the route change.
    public init(
        currentRoute: AVAudioSessionRouteDescription,
        previousRoute: AVAudioSessionRouteDescription?,
        reason: AVAudioSession.RouteChangeReason
    ) {
        self.currentRoute = currentRoute
        self.previousRoute = previousRoute
        self.reason = reason
    }
}

// MARK: - AKAudioSessionRouteChangesObserverProtocol

/// A protocol defining requirements for observing audio route changes and
/// inspecting connected audio output devices.
public protocol AKAudioSessionRouteChangesObserverProtocol: AnyObject, Sendable {
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }

    /// Asynchronous stream of route change events for Swift Concurrency.
    var events: AsyncStream<AKAudioSessionRouteChangeEvent> { get }

    /// Begins observing system-level audio route change notifications.
    func startObserving()

    /// Stops monitoring audio route change notifications and clears active
    /// tasks.
    func stopObserving()

    /// Checks if an external audio device (other than the built-in speaker) is
    /// currently connected.
    /// - Returns: A Boolean value indicating whether an external device is
    /// active.
    func isExternalDeviceConnected() -> Bool

    /// Checks if headphones are currently connected as an audio output route.
    /// - Returns: A Boolean value indicating whether headphones are connected.
    func hasHeadphonesConnected() -> Bool
}

// MARK: - AKAudioSessionRouteChangesObserver

/// A thread-safe observer class responsible for monitoring audio route changes
/// and broadcasting events via `AsyncStream`.
public final class AKAudioSessionRouteChangesObserver: AKAudioSessionRouteChangesObserverProtocol, Sendable {
    // MARK: - Properties

    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession

    /// Broadcaster managing the asynchronous stream of route change events.
    private let eventBroadcaster = AKEventBroadcaster<AKAudioSessionRouteChangeEvent>()

    /// Asynchronous stream of route change events for Swift Concurrency.
    public var events: AsyncStream<AKAudioSessionRouteChangeEvent> {
        eventBroadcaster.makeStream()
    }

    /// Mutex protecting the active notification observation task.
    private let observationTask = Mutex<Task<Void, Never>?>(nil)

    // MARK: - Init & Deinit

    /// Initializes a new route changes observer with a target audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }

    deinit {
        stopObserving()
        eventBroadcaster.finish()
    }

    // MARK: - Observation Lifecycle

    /// Starts observing audio route change notifications.
    public func startObserving() {
        stopObserving()

        let task = Task { [weak self, audioSession] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.routeChangeNotification,
                object: audioSession
            ) {
                guard !Task.isCancelled, let self else { break }
                self.handleRouteChange(notification)
            }
        }

        observationTask.withLock { $0 = task }
    }

    /// Stops observing audio route change notifications and cancels active
    /// tasks.
    public func stopObserving() {
        observationTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }

    // MARK: - Handlers

    /// Processes incoming route change notifications and emits stream events.
    /// - Parameter notification: The `Notification` object posted by the
    /// system.
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }
        let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        let currentRoute = audioSession.currentRoute

        let event = AKAudioSessionRouteChangeEvent(
            currentRoute: currentRoute,
            previousRoute: previousRoute,
            reason: reason
        )
        eventBroadcaster.send(event)
    }

    // MARK: - Helper Functions

    /// Determines whether an external output device is currently active
    /// (excluding the built-in speaker).
    /// - Returns: `true` if any output port other than the built-in speaker is
    /// in use; otherwise, `false`.
    public func isExternalDeviceConnected() -> Bool {
        !audioSession.currentRoute.outputs
            .contains(where: { $0.portType == .builtInSpeaker })
    }

    /// Determines whether headphones are currently connected as an audio output
    /// route.
    /// - Returns: `true` if a headphone port is present in the current outputs;
    /// otherwise, `false`.
    public func hasHeadphonesConnected() -> Bool {
        audioSession.currentRoute.outputs
            .contains(where: { $0.portType == .headphones })
    }

    /// Determines whether an AirPlay destination is currently connected as an audio output route.
    /// - Returns: `true` if an AirPlay output port is active; otherwise, `false`.
    public func isAirPlayConnected() -> Bool {
        audioSession.currentRoute.outputs
            .contains(where: { $0.portType == .airPlay })
    }

    /// Determines whether a Bluetooth device (A2DP, LE, HFP) is currently connected as an audio output route.
    /// - Returns: `true` if a Bluetooth output port is active; otherwise, `false`.
    public func isBluetoothConnected() -> Bool {
        audioSession.currentRoute.outputs
            .contains(where: {
                $0.portType == .bluetoothA2DP ||
                $0.portType == .bluetoothLE ||
                $0.portType == .bluetoothHFP
            })
    }
}
