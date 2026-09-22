//
//   AKSharePlayState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKSharePlaySuspensionReason

/// Represents reasons why group playback coordination was temporarily suspended.
public enum AKSharePlaySuspensionReason: String, Sendable, CaseIterable, Equatable, Hashable,
    Codable, CustomStringConvertible
{
    /// Playback was paused or suspended due to explicit local or remote user action.
    case userAction

    /// Playback is suspended while waiting for one or more participants to finish buffering.
    case buffering

    /// Playback is suspended due to network congestion or connectivity stalls.
    case networkStall

    /// Playback is waiting for joining participants to sync timeline state.
    case waitingForParticipants

    /// The suspension reason is unspecified.
    case unknown

    public var description: String {
        switch self {
        case .userAction:
            "User Action"
        case .buffering:
            "Buffering"
        case .networkStall:
            "Network Stall"
        case .waitingForParticipants:
            "Waiting For Participants"
        case .unknown:
            "Unknown"
        }
    }
}

// MARK: - AKSharePlayState

/// Represents the active state of an Apple SharePlay (`GroupActivities`) session.
public enum AKSharePlayState: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// No active SharePlay session is running or coordinating.
    case inactive

    /// A SharePlay session has been activated and is establishing connection across participants.
    case connecting

    /// SharePlay is actively synchronizing playback with the specified number of participants.
    case active(participantCount: Int)

    /// SharePlay synchronization is temporarily suspended.
    case suspended(reason: AKSharePlaySuspensionReason)

    /// The SharePlay session was terminated or left.
    case ended

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .inactive:
            "Inactive"
        case .connecting:
            "Connecting"
        case let .active(count):
            "Active (\(count) participant\(count == 1 ? "" : "s"))"
        case let .suspended(reason):
            "Suspended (\(reason.description))"
        case .ended:
            "Ended"
        }
    }

    /// Indicates whether a SharePlay session is currently connected and active.
    public var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }

    /// Indicates whether a SharePlay session is currently in any connected or coordinating state.
    public var isCoordinating: Bool {
        switch self {
        case .connecting, .active, .suspended:
            true
        case .inactive, .ended:
            false
        }
    }
}
