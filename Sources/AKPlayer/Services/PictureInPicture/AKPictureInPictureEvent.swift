//
//   AKPictureInPictureEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKPictureInPictureEvent

/// Lifecycle events emitted during Picture-in-Picture transitions.
public enum AKPictureInPictureEvent: Sendable, Equatable {
    /// PiP is about to start animating onto the screen.
    case willStart

    /// PiP is fully active and playing in floating window.
    case didStart

    /// PiP failed to start.
    case failedToStart(String)

    /// PiP is about to close.
    case willStop

    /// PiP has fully closed and returned.
    case didStop

    /// User tapped the restore button in the floating PiP window.
    case restoreUserInterface
}
