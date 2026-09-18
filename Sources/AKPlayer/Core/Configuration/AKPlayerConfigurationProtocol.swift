//
//   AKPlayerConfigurationProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKAudioSessionConfiguration

/// Represents audio session parameters used to configure `AVAudioSession`
/// behavior.
public struct AKAudioSessionConfiguration: Sendable {
    // MARK: - Properties
    
    /// The audio session category defining the general audio behavior of the
    /// app. Defaults to `.playback`.
    public var category: AVAudioSession.Category = .playback
    
    /// The options applied when activating or deactivating the audio session.
    /// Defaults to empty set `[]`.
    public var activeOptions: AVAudioSession.SetActiveOptions = []
    
    /// The audio session mode clarifying the intended use of the category.
    /// Defaults to `.default`.
    public var mode: AVAudioSession.Mode = .default
    
    /// Additional options refining the audio session category behavior.
    /// Defaults to empty set `[]`.
    public var categoryOptions: AVAudioSession.CategoryOptions = []
    
    // MARK: - Initialization
    
    /// Initializes a new audio session configuration with customizable options.
    /// - Parameters:
    ///   - category: The audio session category. Defaults to `.playback`.
    ///   - activeOptions: Options applied during session activation/deactivation. Defaults to `[]`.
    ///   - mode: The intended operational audio session mode. Defaults to `.default`.
    ///   - categoryOptions: Options refining audio category behavior. Defaults to `[]`.
    public init(
        category: AVAudioSession.Category = .playback,
        activeOptions: AVAudioSession.SetActiveOptions = [],
        mode: AVAudioSession.Mode = .default,
        categoryOptions: AVAudioSession.CategoryOptions = []
    ) {
        self.category = category
        self.activeOptions = activeOptions
        self.mode = mode
        self.categoryOptions = categoryOptions
    }
}

// MARK: - Equatable & Hashable Conformance

extension AKAudioSessionConfiguration: Equatable {
    public static func == (lhs: AKAudioSessionConfiguration, rhs: AKAudioSessionConfiguration) -> Bool {
        lhs.category == rhs.category &&
        lhs.activeOptions.rawValue == rhs.activeOptions.rawValue &&
        lhs.mode == rhs.mode &&
        lhs.categoryOptions.rawValue == rhs.categoryOptions.rawValue
    }
}

extension AKAudioSessionConfiguration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(category)
        hasher.combine(activeOptions.rawValue)
        hasher.combine(mode)
        hasher.combine(categoryOptions.rawValue)
    }
}

// MARK: - AKPlayerConfigurationProtocol

/// Protocol defining configuration properties driving player behavior,
/// buffering, audio sessions, and lifecycle events.
public protocol AKPlayerConfigurationProtocol: Sendable {
    // MARK: - Playback Observer Configurations
    
    /// The frequency interval at which periodic time observers trigger updates.
    var periodicTimeInterval: AKTimeEventFrequency { get set }
    
    /// The offset multiplier applied when calculating boundary time observer
    /// positions relative to media duration.
    var boundaryTimeObserverMultiplier: Double { get set }
    
    /// The preferred timescale used when calculating time observations.
    var preferredTimeScale: CMTimeScale { get set }
    
    // MARK: - Buffer Management Configurations
    
    /// The maximum duration in seconds the player waits for buffering before
    /// triggering a timeout error.
    var bufferObservingTimeout: TimeInterval { get set }
    
    /// The polling time interval in seconds used to check current buffer
    /// status.
    var bufferObservingTimeInterval: TimeInterval { get set }
    
    // MARK: - Audio Session Configurations
    
    /// The configuration parameters applied to the system audio session
    /// service.
    var audioSession: AKAudioSessionConfiguration { get set }
    
    // MARK: - Lifecycle Behavior Configurations
    
    /// Pauses playback automatically when the application resigns active
    /// status.
    var playbackPausesWhenResigningActive: Bool { get set }
    
    /// Pauses playback automatically when the application enters the
    /// background.
    var playbackPausesWhenBackgrounded: Bool { get set }
    
    /// Resumes playback automatically when the application returns to active
    /// status.
    var playbackResumesWhenBecameActive: Bool { get set }
    
    /// Resumes playback automatically when the application enters the
    /// foreground.
    var playbackResumesWhenEnteringForeground: Bool { get set }
    
    /// Resumes playback automatically after an audio session interruption ends.
    var playbackResumesWhenAudioSessionInterruptionEnded: Bool { get set }
    
    /// Playback freezes on the last frame when true and does not reset seek
    /// position timestamp upon completion.
    var playbackFreezesAtEnd: Bool { get set }
    
    // MARK: - System Integration Configurations
    
    /// Indicates whether Now Playing metadata integration with
    /// `MPNowPlayingInfoCenter` and remote commands is enabled.
    var isNowPlayingEnabled: Bool { get set }
    
    /// The list of player states during which the system idle timer (screen
    /// sleep) is disabled.
    var idleTimerDisabledForStates: [AKPlayerState] { get set }
    
    // MARK: - Speed Configurations
    
    /// The default speed multiplier used when fast-forwarding playback.
    var fastForwardRate: AKPlaybackRate { get set }
    
    /// The default speed multiplier used when rewinding playback.
    var rewindRate: AKPlaybackRate { get set }
    
    // MARK: - Network & Stall Resilience Configurations
    
    /// The maximum number of consecutive buffer stall retry attempts before declaring failure.
    var maxBufferRetryCount: Int { get set }
    
    /// The initial base backoff cooldown in seconds when waiting for network reconnection.
    var waitingForNetworkBaseCooldown: TimeInterval { get set }
    
    /// The exponential multiplier applied to retry delay intervals during repeated network recovery cycles.
    var backoffMultiplier: Double { get set }
    
    /// The maximum ceiling in seconds for exponential backoff network delay.
    var maxWaitingForNetworkCooldown: TimeInterval { get set }
    
    /// The consecutive threshold count of stalled buffer observation ticks required to trigger a stall state transition.
    var bufferStallTickLimit: Int { get set }
    
    // MARK: - Live Stream Configurations
    
    /// Controls whether AVPlayer automatically preserves time offset from live edge. Defaults to `true`.
    var automaticallyPreservesTimeOffsetFromLive: Bool { get set }
}

// MARK: - Protocol Extension

public extension AKPlayerConfigurationProtocol {
    /// Calculates and returns the periodic time observer interval represented
    /// as a `CMTime` struct.
    /// - Returns: A `CMTime` computed from the current `periodicTimeInterval`
    /// and `preferredTimeScale`.
    func getPeriodicTimeInterval() -> CMTime {
        CMTimeMakeWithSeconds(
            periodicTimeInterval.value,
            preferredTimescale: preferredTimeScale
        )
    }
}

// MARK: - AKTimeEventFrequency

/// Defines predefined time event frequency options for periodic time observers.
public enum AKTimeEventFrequency: Sendable, Hashable, Equatable, CaseIterable {
    /// Fires time events every second (1.0 second).
    case everySecond
    
    /// Fires time events every half second (0.5 seconds).
    case everyHalfSecond
    
    /// Fires time events every quarter second (0.25 seconds).
    case everyQuarterSecond
    
    /// The floating-point time interval value in seconds corresponding to the
    /// frequency choice.
    public var value: Double {
        switch self {
        case .everySecond:
            1.0
        case .everyHalfSecond:
            0.5
        case .everyQuarterSecond:
            0.25
        }
    }
}
