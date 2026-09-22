//
//   AKRepeatMode.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKRepeatMode

/// Defines queue repeat behavior for playback queues.
public enum AKRepeatMode: String, CaseIterable, Sendable, Equatable, Hashable,
    CustomStringConvertible
{
    /// Playback stops after reaching the end of the queue.
    case off
    /// The current media item repeats indefinitely.
    case one
    /// The entire queue repeats from the beginning upon completion.
    case all

    // MARK: - CustomStringConvertible

    /// A human-readable display title describing the repeat mode.
    public var description: String {
        switch self {
        case .off: "Off"
        case .one: "Repeat One"
        case .all: "Repeat All"
        }
    }
}
