//
//   AKSeek.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia
import Foundation
import Synchronization

// MARK: - AKSeek

/// Represents a media seek command containing the target position, tolerances,
/// and completion callback, guaranteeing single-execution safety.
public final class AKSeek: Equatable, Hashable, Identifiable, @unchecked Sendable {
    // MARK: - Properties

    /// Unique identifier for this specific seek request.
    public let id: UUID

    /// The target playback position.
    public let target: AKSeekTarget

    /// The timeline coordinate space targeted by this seek operation.
    public let scope: AKSeekScope

    /// The maximum allowable time before the target time that the player may seek.
    public let toleranceBefore: CMTime

    /// The maximum allowable time after the target time that the player may seek.
    public let toleranceAfter: CMTime

    /// Internal thread-safe storage for the completion handler, cleared upon invocation.
    private let completionStorage: Mutex<(@Sendable (Bool) -> Void)?>

    // MARK: - Initialization

    /// Creates a new seek request.
    /// - Parameters:
    ///   - id: Unique identifier for this request. Defaults to a new `UUID()`.
    ///   - target: The target position to seek to.
    ///   - scope: The timeline scope targeted by this seek. Defaults to `.primary`.
    ///   - toleranceBefore: Tolerance before the target position. Defaults to `.positiveInfinity`.
    ///   - toleranceAfter: Tolerance after the target position. Defaults to `.positiveInfinity`.
    ///   - completionHandler: Callback executed when seeking completes or is canceled.
    public init(
        id: UUID = UUID(),
        target: AKSeekTarget,
        scope: AKSeekScope = .primary,
        toleranceBefore: CMTime = .positiveInfinity,
        toleranceAfter: CMTime = .positiveInfinity,
        completionHandler: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.id = id
        self.target = target
        self.scope = scope
        self.toleranceBefore = toleranceBefore
        self.toleranceAfter = toleranceAfter
        completionStorage = Mutex(completionHandler)
    }

    // MARK: - Completion Execution

    /// Invokes the completion handler with the given result.
    /// Guarantees that the completion handler is called at most once.
    public func complete(with result: Bool) {
        let handler = completionStorage.withLock { storage in
            let action = storage
            storage = nil
            return action
        }
        handler?(result)
    }

    // MARK: - Equatable & Hashable

    /// Returns a boolean value indicating whether two seek objects are equal based on unique
    /// identifiers.
    public static func == (lhs: AKSeek, rhs: AKSeek) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes the essential components of this seek request into the given hasher.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
