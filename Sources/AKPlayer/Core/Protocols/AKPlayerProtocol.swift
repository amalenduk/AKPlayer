//
//   AKPlayerProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayerProtocol

/// Protocol defining the main player instance properties, playback metrics, and
/// boundary observation capabilities.
@MainActor
public protocol AKPlayerProtocol: AnyObject, Sendable, AKPlayerActionsProtocol {
    // MARK: - Core Properties

    /// The underlying `AVPlayer` instance managing media playback.
    var player: AVPlayer { get }

    /// The current playback state of the player (e.g., idle, playing, paused,
    /// stopped, failed).
    var state: AKPlayerState { get }

    /// The default playback rate used when initiating or resuming normal
    /// playback.
    var defaultRate: AKPlaybackRate { get set }

    /// The active playback rate speed multiplier (1.0 = normal, 0.0 = paused).
    var rate: AKPlaybackRate { get set }

    /// The currently active playable media item conforming to `AKPlayable`.
    var currentMedia: (any AKPlayable)? { get }

    /// The currently active `AVPlayerItem` loaded in the player queue.
    var currentItem: AVPlayerItem? { get }

    /// The total duration of the currently loaded media item as `CMTime`.
    var currentItemDuration: CMTime { get }

    /// The current playback position in time as `CMTime`.
    var currentTime: CMTime { get }

    /// The remaining playback time duration of the active item, if available.
    var remainingTime: CMTime? { get }

    /// Flag indicating whether media playback starts automatically upon
    /// loading.
    var autoPlay: Bool { get }

    /// Flag indicating whether a seek action is currently in progress.
    var isSeeking: Bool { get }

    /// The most recent seek target requested by the caller.
    var lastRequestedSeekPosition: AKSeekTarget? { get }

    /// The current audio output volume level, ranging from `0.0` (silent) to
    /// `1.0` (maximum).
    var volume: Float { get set }

    /// Flag indicating whether player audio output is muted.
    var isMuted: Bool { get set }

    /// Contains error details if a failure occurs during initialization or
    /// playback.
    var error: AKPlayerError? { get }

    /// Player configuration specifying timing, audio session, and buffering policies.
    var configuration: any AKPlayerConfigurationProtocol { get }

    /// The time-pitch algorithm used for pitch preservation and time stretching during
    /// variable-speed
    /// playback.
    var audioTimePitchAlgorithm: AKAudioTimePitchAlgorithm { get set }

    /// An asynchronous sequence of player lifecycle and playback events.
    var events: AsyncStream<AKPlayerEvent> { get }

    // MARK: - Live Stream Properties

    /// Indicates whether the active media is a live broadcast stream.
    var isLive: Bool { get }

    /// Indicates whether playback is currently synced with the live edge (drift <= threshold).
    var isAtLiveEdge: Bool { get }

    // MARK: - Boundary Time Observers

    /// Registers a boundary time observer to trigger notifications when
    /// playback reaches explicit time markers.
    /// - Parameter times: An array of target `CMTime` markers to observe during
    /// playback.
    func addBoundaryTimeObserver(for times: [CMTime])

    /// Removes the currently registered boundary time observer from the
    /// underlying player instance.
    func removeBoundaryTimeObserver()
}

// MARK: - Playback State Convenience Extension

public extension AKPlayerProtocol {
    /// Indicates whether the player is actively playing media.
    var isPlaying: Bool {
        state.isPlaying
    }

    /// Indicates whether the player is currently paused.
    var isPaused: Bool {
        state.isPaused
    }

    /// Indicates whether the player is currently buffering media content.
    var isBuffering: Bool {
        state.isBuffering
    }

    /// Indicates whether the player is currently loading initial media assets.
    var isLoading: Bool {
        state.isLoading
    }

    /// Indicates whether the player is currently in an idle state.
    var isIdle: Bool {
        state.isIdle
    }

    /// Indicates whether playback has encountered a fatal error.
    var isFailed: Bool {
        state.isFailed
    }
}
