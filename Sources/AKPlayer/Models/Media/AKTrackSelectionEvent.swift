//
//   AKTrackSelectionEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKTrackSelectionEvent

/// Events emitted when active or available media tracks update.
public enum AKTrackSelectionEvent: Sendable, Equatable {
    /// The active track selection for a given track type changed.
    case selectedTrackDidChange(AKMediaTrackOption?, for: AKTrackType)

    /// The available track choices for a given track type updated.
    case availableTracksDidChange([AKMediaTrackOption], for: AKTrackType)
}
