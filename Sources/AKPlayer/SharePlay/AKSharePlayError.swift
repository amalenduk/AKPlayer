//
//   AKSharePlayError.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKSharePlayError

/// Strongly-typed error enum representing failures encountered during SharePlay (`GroupActivities`)
/// operations.
public enum AKSharePlayError: Error, Sendable, Equatable, LocalizedError {
    /// Device is currently not in an active FaceTime call or eligible group session.
    case notEligibleForSharePlay

    /// Failed to prepare or activate the `GroupActivity`.
    case sessionActivationFailed(String)

    /// The active group session was invalidated or terminated by the system.
    case sessionInvalidated(String)

    /// Failed to attach `AVPlayerPlaybackCoordinator` to the active session.
    case coordinationFailed(String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .notEligibleForSharePlay:
            "The device is not currently eligible for SharePlay. Ensure an active FaceTime call or Messages conversation is running."
        case let .sessionActivationFailed(reason):
            "Failed to activate SharePlay session: \(reason)"
        case let .sessionInvalidated(reason):
            "The SharePlay session was invalidated: \(reason)"
        case let .coordinationFailed(reason):
            "Failed to coordinate AVPlayer with SharePlay session: \(reason)"
        }
    }
}
