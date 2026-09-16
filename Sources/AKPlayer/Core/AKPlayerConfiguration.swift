//
//   AKPlayerConfiguration.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - AKPlayerConfiguration

/// Default concrete implementation of `AKPlayerConfigurationProtocol` providing
/// customizable playback, buffering, and audio session options.
public struct AKPlayerConfiguration: AKPlayerConfigurationProtocol, Sendable {
    
    // MARK: - Playback Observer Configurations
    
    /// The frequency interval at which periodic time observers trigger updates.
    /// Defaults to `.everyQuarterSecond`.
    public var periodicTimeInterval: AKTimeEventFrequency = .everyQuarterSecond
    
    /// The preferred timescale used when calculating time observations.
    /// Defaults to nanosecond precision (`NSEC_PER_SEC`).
    public var preferredTimeScale: CMTimeScale = .init(NSEC_PER_SEC)
    
    /// The offset multiplier applied when calculating boundary time observer
    /// positions relative to media duration. Defaults to `0.10`.
    public var boundaryTimeObserverMultiplier = 0.10
    
    // MARK: - Buffer Management Configurations
    
    /// The maximum duration in seconds the player waits for buffering before
    /// triggering a timeout error. Defaults to `20` seconds.
    public var bufferObservingTimeout: TimeInterval = 20
    
    /// The polling time interval in seconds used to check current buffer
    /// status. Defaults to `0.05` seconds.
    public var bufferObservingTimeInterval: TimeInterval = 0.05
    
    // MARK: - Audio Session Configurations
    
    /// The configuration parameters applied to the system audio session
    /// service.
    public var audioSession: AKAudioSessionConfiguration = .init()
    
    // MARK: - System Integration Configurations
    
    /// Indicates whether Now Playing metadata integration with
    /// `MPNowPlayingInfoCenter` and remote commands is enabled. Defaults to
    /// `true`.
    public var isNowPlayingEnabled = true
    
    /// The list of player states during which the system idle timer (screen
    /// sleep) is disabled. Defaults to `[.buffering, .playing]`.
    public var idleTimerDisabledForStates: [AKPlayerState] = [
        .buffering,
        .playing,
    ]
    
    // MARK: - Lifecycle Behavior Configurations
    
    /// Specifies whether playback automatically pauses when the application
    /// resigns active status. Defaults to `false`.
    public var playbackPausesWhenResigningActive = false
    
    /// Specifies whether playback automatically pauses when the application
    /// enters the background. Defaults to `false`.
    public var playbackPausesWhenBackgrounded = false
    
    /// Specifies whether playback automatically resumes when the application
    /// returns to active status. Defaults to `true`.
    public var playbackResumesWhenBecameActive = true
    
    /// Specifies whether playback automatically resumes when the application
    /// enters the foreground. Defaults to `true`.
    public var playbackResumesWhenEnteringForeground = true
    
    /// Specifies whether playback automatically resumes after an audio session
    /// interruption ends. Defaults to `true`.
    public var playbackResumesWhenAudioSessionInterruptionEnded = true
    
    /// Specifies whether playback freezes on the final video frame upon
    /// reaching media end instead of auto-resetting. Defaults to `true`.
    public var playbackFreezesAtEnd = true
    
    // MARK: - Speed Configurations
    
    /// The default speed multiplier used when fast-forwarding playback.
    /// Defaults to `.superfast`.
    public var fastForwardRate: AKPlaybackRate = .superfast
    
    /// The default speed multiplier used when rewinding playback. Defaults to
    /// `.slowest`.
    public var rewindRate: AKPlaybackRate = .slowest
    
    public var maxBufferRetryCount: Int = 4
    
    public var waitingForNetworkBaseCooldown: TimeInterval = 2.0
    
    public var backoffMultiplier: Double = 1.8
    
    public var maxWaitingForNetworkCooldown: TimeInterval = 20.0
    
    public var bufferStallTickLimit: Int = 4
    
    // MARK: - Static Default Instance
    
    /// A shared default configuration instance initialized with standard preset
    /// settings.
    public static let `default` = AKPlayerConfiguration()
    
    // MARK: - Initialization
    
    /// Creates a new player configuration instance initialized with default
    /// parameters.
    public init() {}
}
