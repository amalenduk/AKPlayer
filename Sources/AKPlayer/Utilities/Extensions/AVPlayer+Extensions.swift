//
//   AVPlayer+Extensions.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - AVPlayer.TimeControlStatus Extensions

extension AVPlayer.TimeControlStatus {
    // MARK: - Convenience Properties

    /// Indicates whether the player is currently in a paused state.
    var isPaused: Bool {
        self == .paused
    }

    /// Indicates whether the player is actively playing media.
    var isPlaying: Bool {
        self == .playing
    }

    /// Indicates whether the player is waiting for conditions to be met before
    /// playing at the specified rate.
    var isWaitingToPlayAtSpecifiedRate: Bool {
        self == .waitingToPlayAtSpecifiedRate
    }
}
