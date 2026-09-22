//
//   AKPlayerState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKPlayerState

/// Represents the current operational state of the media player.
public enum AKPlayerState: String, CustomStringConvertible, Sendable, Equatable, Hashable,
    CaseIterable
{
    // MARK: - Cases

    /// Initial state when no media is loaded.
    case idle
    /// Media asset is currently being loaded.
    case loading
    /// Media asset is loaded and ready for playback.
    case loaded
    /// Playback is temporarily stalled due to buffering.
    case buffering
    /// Playback is actively paused.
    case paused
    /// Media is actively playing.
    case playing
    /// Playback is stopped.
    case stopped
    /// Playback is paused waiting for network connectivity to restore.
    case waitingForNetwork
    /// Player encountered an unrecoverable error.
    case failed

    // MARK: - Computed Properties

    /// A human-readable description of the player state.
    public var description: String {
        switch self {
        case .waitingForNetwork:
            "Waiting For Network"
        default:
            rawValue.capitalized
        }
    }

    /// Indicates whether the player is currently idle.
    public var isIdle: Bool {
        self == .idle
    }

    /// Indicates whether the player is currently loading media.
    public var isLoading: Bool {
        self == .loading
    }

    /// Indicates whether the media asset is loaded and ready.
    public var isLoaded: Bool {
        self == .loaded
    }

    /// Indicates whether the player is buffering content.
    public var isBuffering: Bool {
        self == .buffering
    }

    /// Indicates whether media is currently playing.
    public var isPlaying: Bool {
        self == .playing
    }

    /// Indicates whether playback is paused.
    public var isPaused: Bool {
        self == .paused
    }

    /// Indicates whether playback has stopped.
    public var isStopped: Bool {
        self == .stopped
    }

    /// Indicates whether the player is waiting for network connectivity.
    public var isWaitingForNetwork: Bool {
        self == .waitingForNetwork
    }

    /// Indicates whether the player is in a failed state.
    public var isFailed: Bool {
        self == .failed
    }

    // MARK: - Helper Methods

    /// Checks if the current state matches any of the provided states.
    /// - Parameter states: An array of target states.
    /// - Returns: `true` if the current state matches any state in the list.
    public func isAny(of states: [AKPlayerState]) -> Bool {
        states.contains(self)
    }

    /// Checks if the current state does not match any of the provided states.
    /// - Parameter states: An array of target states.
    /// - Returns: `true` if the current state does not match any state in the
    /// list.
    public func isNotAny(of states: [AKPlayerState]) -> Bool {
        !states.contains(self)
    }
}
