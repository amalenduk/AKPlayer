//
//   AKEventBroadcaster.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation
import Synchronization

/// Thread-safe multicast broadcaster managing multiple `AsyncStream` subscribers.
final class AKEventBroadcaster<Event: Sendable>: Sendable {
    
    /// Internal state holding registered continuations protected by a Mutex.
    private let state = Mutex<[UUID: AsyncStream<Event>.Continuation]>([:])
    
    /// Initializes a new thread-safe event broadcaster instance.
    init() {}
    
    deinit {
        finish()
    }
    
    /// Broadcasts an event to all actively connected asynchronous stream listeners.
    /// - Parameter event: The event payload to emit.
    func send(_ event: Event) {
        let activeContinuations = state.withLock { continuations in
            Array(continuations.values)
        }
        for continuation in activeContinuations {
            continuation.yield(event)
        }
    }
    
    /// Creates a new `AsyncStream` subscriber connected to this broadcaster.
    /// - Parameter bufferingPolicy: The buffering strategy to apply to the stream continuation.
    /// - Returns: An active `AsyncStream<Event>`.
    func makeStream(
        bufferingPolicy: AsyncStream<Event>.Continuation.BufferingPolicy = .bufferingNewest(100)
    ) -> AsyncStream<Event> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            state.withLock { $0[id] = continuation }
            
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { _ = $0.removeValue(forKey: id) }
            }
        }
    }
    
    /// Finishes all active continuations, terminating subscriber streams.
    func finish() {
        let activeContinuations = state.withLock { continuations -> [AsyncStream<Event>.Continuation] in
            let values = Array(continuations.values)
            continuations.removeAll()
            return values
        }
        for continuation in activeContinuations {
            continuation.finish()
        }
    }
}

