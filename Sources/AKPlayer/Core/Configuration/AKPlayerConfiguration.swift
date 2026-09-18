//
//   AKPlayerConfiguration.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayerConfiguration

/// Default concrete implementation of `AKPlayerConfigurationProtocol` providing
/// customizable playback, buffering, and audio session options.
public struct AKPlayerConfiguration: AKPlayerConfigurationProtocol, Sendable, Equatable, Hashable {
    
    // MARK: - Playback Observer Configurations
    
    /// The frequency interval at which periodic time observers trigger updates.
    /// Defaults to `.everyQuarterSecond`.
    public var periodicTimeInterval: AKTimeEventFrequency
    
    /// The preferred timescale used when calculating time observations.
    /// Defaults to nanosecond precision (`NSEC_PER_SEC`).
    public var preferredTimeScale: CMTimeScale
    
    /// The offset multiplier applied when calculating boundary time observer
    /// positions relative to media duration. Defaults to `0.10`.
    public var boundaryTimeObserverMultiplier: Double
    
    // MARK: - Buffer Management Configurations
    
    /// The maximum duration in seconds the player waits for buffering before
    /// triggering a timeout error. Defaults to `30` seconds.
    public var bufferObservingTimeout: TimeInterval
    
    /// The polling time interval in seconds used to check current buffer
    /// status. Defaults to `0.5` seconds.
    public var bufferObservingTimeInterval: TimeInterval
    
    // MARK: - Audio Session Configurations
    
    /// The configuration parameters applied to the system audio session
    /// service.
    public var audioSession: AKAudioSessionConfiguration
    
    // MARK: - System Integration Configurations
    
    /// Indicates whether Now Playing metadata integration with
    /// `MPNowPlayingInfoCenter` and remote commands is enabled. Defaults to
    /// `true`.
    public var isNowPlayingEnabled: Bool
    
    /// The list of player states during which the system idle timer (screen
    /// sleep) is disabled. Defaults to `[.buffering, .playing]`.
    public var idleTimerDisabledForStates: [AKPlayerState]
    
    // MARK: - Lifecycle Behavior Configurations
    
    /// Specifies whether playback automatically pauses when the application
    /// resigns active status. Defaults to `false`.
    public var playbackPausesWhenResigningActive: Bool
    
    /// Specifies whether playback automatically pauses when the application
    /// enters the background. Defaults to `false`.
    public var playbackPausesWhenBackgrounded: Bool
    
    /// Specifies whether playback automatically resumes when the application
    /// returns to active status. Defaults to `true`.
    public var playbackResumesWhenBecameActive: Bool
    
    /// Specifies whether playback automatically resumes when the application
    /// enters the foreground. Defaults to `true`.
    public var playbackResumesWhenEnteringForeground: Bool
    
    /// Specifies whether playback automatically resumes after an audio session
    /// interruption ends. Defaults to `true`.
    public var playbackResumesWhenAudioSessionInterruptionEnded: Bool
    
    /// Specifies whether playback freezes on the final video frame upon
    /// reaching media end instead of auto-resetting. Defaults to `true`.
    public var playbackFreezesAtEnd: Bool
    
    // MARK: - Speed Configurations
    
    /// The default speed multiplier used when fast-forwarding playback.
    /// Defaults to `.superfast`.
    public var fastForwardRate: AKPlaybackRate
    
    /// The default speed multiplier used when rewinding playback. Defaults to
    /// `.slowest`.
    public var rewindRate: AKPlaybackRate
    
    // MARK: - Network & Stall Resilience Configurations
    
    /// The maximum number of consecutive buffer stall retry attempts before declaring failure.
    /// Defaults to `4`.
    public var maxBufferRetryCount: Int
    
    /// The initial base backoff cooldown in seconds when waiting for network reconnection.
    /// Defaults to `1.0` seconds.
    public var waitingForNetworkBaseCooldown: TimeInterval
    
    /// The exponential multiplier applied to retry delay intervals during repeated network recovery cycles.
    /// Defaults to `1.8`.
    public var backoffMultiplier: Double
    
    /// The maximum ceiling in seconds for exponential backoff network delay.
    /// Defaults to `20.0` seconds.
    public var maxWaitingForNetworkCooldown: TimeInterval
    
    /// The consecutive threshold count of stalled buffer observation ticks required to trigger a stall state transition.
    /// Defaults to `12` (12 ticks * 0.5s = 6.0 seconds).
    public var bufferStallTickLimit: Int
    
    // MARK: - Static Default Instance
    
    /// A shared default configuration instance initialized with standard preset
    /// settings.
    public static let `default` = AKPlayerConfiguration()
    
    // MARK: - Initialization
    
    /// Creates a new player configuration instance with optional custom parameters.
    public init(
        periodicTimeInterval: AKTimeEventFrequency = .everyQuarterSecond,
        preferredTimeScale: CMTimeScale = .init(NSEC_PER_SEC),
        boundaryTimeObserverMultiplier: Double = 0.10,
        bufferObservingTimeout: TimeInterval = 30,
        bufferObservingTimeInterval: TimeInterval = 0.5,
        audioSession: AKAudioSessionConfiguration = .init(),
        isNowPlayingEnabled: Bool = true,
        idleTimerDisabledForStates: [AKPlayerState] = [.buffering, .playing],
        playbackPausesWhenResigningActive: Bool = false,
        playbackPausesWhenBackgrounded: Bool = false,
        playbackResumesWhenBecameActive: Bool = true,
        playbackResumesWhenEnteringForeground: Bool = true,
        playbackResumesWhenAudioSessionInterruptionEnded: Bool = true,
        playbackFreezesAtEnd: Bool = true,
        fastForwardRate: AKPlaybackRate = .superfast,
        rewindRate: AKPlaybackRate = .slowest,
        maxBufferRetryCount: Int = 4,
        waitingForNetworkBaseCooldown: TimeInterval = 1.0,
        backoffMultiplier: Double = 1.8,
        maxWaitingForNetworkCooldown: TimeInterval = 20.0,
        bufferStallTickLimit: Int = 12
    ) {
        self.periodicTimeInterval = periodicTimeInterval
        self.preferredTimeScale = preferredTimeScale
        self.boundaryTimeObserverMultiplier = boundaryTimeObserverMultiplier
        self.bufferObservingTimeout = bufferObservingTimeout
        self.bufferObservingTimeInterval = bufferObservingTimeInterval
        self.audioSession = audioSession
        self.isNowPlayingEnabled = isNowPlayingEnabled
        self.idleTimerDisabledForStates = idleTimerDisabledForStates
        self.playbackPausesWhenResigningActive = playbackPausesWhenResigningActive
        self.playbackPausesWhenBackgrounded = playbackPausesWhenBackgrounded
        self.playbackResumesWhenBecameActive = playbackResumesWhenBecameActive
        self.playbackResumesWhenEnteringForeground = playbackResumesWhenEnteringForeground
        self.playbackResumesWhenAudioSessionInterruptionEnded = playbackResumesWhenAudioSessionInterruptionEnded
        self.playbackFreezesAtEnd = playbackFreezesAtEnd
        self.fastForwardRate = fastForwardRate
        self.rewindRate = rewindRate
        self.maxBufferRetryCount = maxBufferRetryCount
        self.waitingForNetworkBaseCooldown = waitingForNetworkBaseCooldown
        self.backoffMultiplier = backoffMultiplier
        self.maxWaitingForNetworkCooldown = maxWaitingForNetworkCooldown
        self.bufferStallTickLimit = bufferStallTickLimit
    }
}
