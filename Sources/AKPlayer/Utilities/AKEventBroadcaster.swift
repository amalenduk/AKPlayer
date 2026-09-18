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
    
    private let state = Mutex<[UUID: AsyncStream<Event>.Continuation]>([:])
    
    init() {}
    
    deinit {
        finish()
    }
    
    func send(_ event: Event) {
        let activeContinuations = state.withLock { continuations in
            Array(continuations.values)
        }
        for continuation in activeContinuations {
            continuation.yield(event)
        }
    }
    
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
