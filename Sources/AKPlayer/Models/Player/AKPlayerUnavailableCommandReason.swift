//
//   AKPlayerUnavailableCommandReason.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKPlayerUnavailableCommandReason

/// Defines reasons why a specific player command or action cannot be executed.
public enum AKPlayerUnavailableCommandReason: Equatable, Sendable {
    // MARK: - Cases

    /// Command ignored because playback is already paused.
    case alreadyPaused
    /// Command ignored because media is already playing.
    case alreadyPlaying
    /// Command ignored because the player is already stopped.
    case alreadyStopped
    /// Command ignored because a playback initiation request is already in
    /// progress.
    case alreadyTryingToPlay
    /// The requested seek position is invalid or outside valid bounds.
    case seekPositionNotAvailable
    /// The requested seek target exceeds the current media duration.
    case seekOverstepPosition
    /// Action failed because no media item is currently loaded.
    case loadMediaFirst
    /// Action postponed until network connection is re-established.
    case waitingForEstablishedNetwork
    /// Action postponed until media item completes initial asset loading.
    case waitTillMediaLoaded
    /// The current media asset does not support stepping forward.
    case canNotStepForward
    /// The current media asset does not support stepping backward.
    case canNotStepBackward
    /// The requested playback rate is unsupported by the current media asset.
    case canNotPlayAtSpecifiedRate
    /// Action forbidden by the current player state or security policy.
    case actionNotPermitted
    /// Player encountered an unrecoverable failure and can no longer process
    /// commands.
    case playerCanNoLongerPlay
}

// MARK: - CustomStringConvertible

extension AKPlayerUnavailableCommandReason: CustomStringConvertible {
    /// A human-readable textual representation describing the reason command
    /// was unavailable.
    public var description: String {
        switch self {
        case .alreadyPaused:
            "Already Paused"
        case .alreadyPlaying:
            "Already Playing"
        case .alreadyStopped:
            "Already Stopped"
        case .alreadyTryingToPlay:
            "Wait a moment, already trying to play"
        case .seekPositionNotAvailable:
            "Seek position not available"
        case .seekOverstepPosition:
            "Seek position beyond duration"
        case .loadMediaFirst:
            "Load media first"
        case .waitingForEstablishedNetwork:
            "Waiting for network connection to be established"
        case .waitTillMediaLoaded:
            "Waiting for media item to finish loading"
        case .canNotStepForward:
            "Item doesn't support stepping forward"
        case .canNotStepBackward:
            "Item doesn't support stepping backward"
        case .canNotPlayAtSpecifiedRate:
            "Item can't be played at the specified rate"
        case .actionNotPermitted:
            "Action is not permitted"
        case .playerCanNoLongerPlay:
            "Player can no longer play"
        }
    }
}
