//
//   AKSubtitleEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKSubtitleEvent

/// Events emitted when subtitle or caption cues change or the service state updates.
public enum AKSubtitleEvent: Sendable, Equatable {
    /// The active subtitle cue changed (or nil if cleared).
    case cueDidChange(AKSubtitleCue?)

    /// The subtitle output listening status changed.
    case isRunningDidChange(Bool)
}
