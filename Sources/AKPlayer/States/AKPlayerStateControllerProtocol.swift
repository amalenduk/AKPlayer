//
//   AKPlayerStateControllerProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayerStateControllerProtocol

/// A protocol defining the core interface for player state machine controllers.
///
/// Implementations of this protocol represent specific player states (e.g.,
/// buffering, playing, paused) and handle state-specific behaviors, action validations,
/// and state transitions within the state pattern.
@MainActor
public protocol AKPlayerStateControllerProtocol: AnyObject, Sendable, AKPlayerActionsProtocol {
    /// The underlying player controller driving playback, asset management, and
    /// audio state transitions.
    var playerController: (any AKPlayerControllerProtocol)? { get }

    /// The current operational state classification represented by this state
    /// controller instance.
    var state: AKPlayerState { get }

    /// Indicates whether media playback should automatically begin upon asset
    /// load completion.
    var autoPlay: Bool { get }

    /// Evaluates current state conditions and performs necessary state
    /// transition or status evaluation logic.
    func processStateChange()

    /// Responds to changes in the underlying `AVPlayer.Status` (unknown, readyToPlay, failed).
    func handlePlayerStatusChange(_ status: AVPlayer.Status)

    /// Responds to changes in the underlying `AVPlayer.TimeControlStatus` (paused,
    /// waitingToPlayAtSpecifiedRate, playing).
    func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus)

    /// Handles lifecycle and progress events forwarded from `AVPlayerItem`.
    func handle(_ event: AKPlayerItemNotificationEvent)

    /// Responds to playback state transitions forwarded from the interstitial service.
    func handleInterstitialPlaybackStateChange(_ playbackState: AKInterstitialPlaybackState)
}

// MARK: - Default Implementations

public extension AKPlayerStateControllerProtocol {
    /// Default implementation returning `false` for automatic playback behavior.
    var autoPlay: Bool {
        false
    }
}
