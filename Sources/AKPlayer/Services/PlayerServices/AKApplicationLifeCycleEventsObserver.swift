//
//   AKApplicationLifeCycleEventsObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import Synchronization
import UIKit

// MARK: - AKApplicationLifeCycleEvent

/// Events emitted when the application transitions through different lifecycle
/// phases.
public enum AKApplicationLifeCycleEvent: Sendable, Equatable, Hashable, CaseIterable {
    // MARK: - Cases

    /// The application is about to lose active status (e.g., phone call or
    /// control center presentation).
    case willResignActive

    /// The application has become active and is ready to accept user
    /// interactions.
    case didBecomeActive

    /// The application has entered the background state.
    case didEnterBackground

    /// The application is preparing to transition back to the foreground.
    case willEnterForeground
}

// MARK: - AKApplicationLifeCycleState

/// Represents the current tracked state of the application's lifecycle.
public enum AKApplicationLifeCycleState: Sendable, Equatable, Hashable, CaseIterable {
    // MARK: - Cases

    /// The application is in an inactive state.
    case resignActive

    /// The application is currently active in the foreground.
    case active

    /// The application is running in the background.
    case background

    /// The application is in the process of coming to the foreground.
    case foreground

    // MARK: - Computed Properties

    /// A convenience property returning `true` if the app is currently
    /// `.active` or `.foreground`.
    public var isActiveOrForeground: Bool {
        self == .active || self == .foreground
    }

    /// A convenience property returning `true` if the app is currently
    /// `.resignActive` or `.background`.
    public var isResignActiveOrBackground: Bool {
        self == .resignActive || self == .background
    }
}

// MARK: - AKApplicationLifeCycleEventsObserverProtocol

/// A protocol defining requirements for observing application lifecycle state transitions.
public protocol AKApplicationLifeCycleEventsObserverProtocol: AnyObject, Sendable {
    // MARK: - Properties

    /// The current state of the application lifecycle.
    var state: AKApplicationLifeCycleState { get }

    /// Asynchronous stream of lifecycle events.
    var events: AsyncStream<AKApplicationLifeCycleEvent> { get }

    // MARK: - Methods

    /// Begins observing system lifecycle notifications.
    func startObserving()

    /// Stops observing system lifecycle notifications and cleans up active observation tasks.
    func stopObserving()
}

// MARK: - AKApplicationLifeCycleEventsObserver

/// A thread-safe observer class responsible for listening to `UIApplication` lifecycle
/// notifications and broadcasting state changes through `AsyncStream`.
public final class AKApplicationLifeCycleEventsObserver: AKApplicationLifeCycleEventsObserverProtocol, Sendable {
    // MARK: - Properties

    /// Thread-safe storage for the current lifecycle state of the application.
    private let stateStorage = Mutex<AKApplicationLifeCycleState>(.foreground)

    /// The current lifecycle state of the application.
    public var state: AKApplicationLifeCycleState {
        stateStorage.withLock { $0 }
    }

    /// Broadcaster managing the asynchronous event stream for lifecycle events.
    private let eventBroadcaster = AKEventBroadcaster<AKApplicationLifeCycleEvent>()

    /// Asynchronous stream of lifecycle events for Swift Concurrency.
    public var events: AsyncStream<AKApplicationLifeCycleEvent> {
        eventBroadcaster.makeStream()
    }

    /// Mutex protecting the active notification center observation task.
    private let observationTask = Mutex<Task<Void, Never>?>(nil)

    // MARK: - Init & Deinit

    /// Initializes a new instance of the application lifecycle events observer.
    public init() {}

    deinit {
        stopObserving()
        eventBroadcaster.finish()
    }

    // MARK: - Observation Lifecycle

    /// Starts observing system lifecycle notifications.
    ///
    /// Subscribes to `willResignActiveNotification`,
    /// `didBecomeActiveNotification`,
    /// `didEnterBackgroundNotification`, and `willEnterForegroundNotification`.
    public func startObserving() {
        stopObserving()

        let task = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                // 1. Will Resign Active
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: UIApplication.willResignActiveNotification) {
                        guard !Task.isCancelled, let self else { break }
                        self.handleApplicationWillResignActive()
                    }
                }

                // 2. Did Become Active
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                        guard !Task.isCancelled, let self else { break }
                        self.handleApplicationDidBecomeActive()
                    }
                }

                // 3. Did Enter Background
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                        guard !Task.isCancelled, let self else { break }
                        self.handleApplicationDidEnterBackground()
                    }
                }

                // 4. Will Enter Foreground
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                        guard !Task.isCancelled, let self else { break }
                        self.handleApplicationWillEnterForeground()
                    }
                }
            }
        }

        observationTask.withLock { $0 = task }
    }

    /// Stops observing system lifecycle notifications and cancels active observation tasks.
    public func stopObserving() {
        observationTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }

    // MARK: - Handlers

    /// Updates state to `.resignActive` and emits `.willResignActive` through the event stream.
    private func handleApplicationWillResignActive() {
        stateStorage.withLock { $0 = .resignActive }
        eventBroadcaster.send(.willResignActive)
    }

    /// Updates state to `.active` and emits `.didBecomeActive` through the event stream.
    private func handleApplicationDidBecomeActive() {
        stateStorage.withLock { $0 = .active }
        eventBroadcaster.send(.didBecomeActive)
    }

    /// Updates state to `.background` and emits `.didEnterBackground` through the event stream.
    private func handleApplicationDidEnterBackground() {
        stateStorage.withLock { $0 = .background }
        eventBroadcaster.send(.didEnterBackground)
    }

    /// Updates state to `.foreground` and emits `.willEnterForeground` through the event stream.
    private func handleApplicationWillEnterForeground() {
        stateStorage.withLock { $0 = .foreground }
        eventBroadcaster.send(.willEnterForeground)
    }
}
