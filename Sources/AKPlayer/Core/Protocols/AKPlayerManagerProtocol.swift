//
//   AKPlayerManagerProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import MediaPlayer

// MARK: - AKPlayerManagerProtocol

/// Primary management protocol exposing high-level player control and
/// now-playing integration.
@MainActor
public protocol AKPlayerManagerProtocol: AKPlayerProtocol,
                                         AKPlayerActionsProtocol
{
    /// The underlying controller managing AVPlayer state machine operations and
    /// commands.
    var playerController: AKPlayerControllerProtocol { get }
    
    /// Configuration options specifying audio session, remote command, and
    /// playback behaviors.
    var configuration: AKPlayerConfigurationProtocol { get }
    
    /// Active state snapshot storing playback and app states during
    /// interruptions for auto-resumption.
    var playerStateSnapshot: AKPlayerStateSnapshot? { get }
    
    /// Service interface handling system `AVAudioSession` categories, modes,
    /// and activation logic.
    var audioSessionService: AKAudioSessionServiceProtocol { get }
    
    /// Manager coordinating Now Playing info center metadata publishing and remote command interactions.
    var nowPlayingManager: (any AKNowPlayingManagerProtocol)? { get }
    
    /// Configures the audio session, registers observers, and prepares the
    /// player for immediate use.
    /// - Throws: `AKPlayerError` or `AVAudioSession` initialization failures if
    /// preparation fails.
    func prepare() async throws
}

// MARK: - AKPlayerStateSnapshot

/// Thread-safe snapshot capturing player state before lifecycle interruptions
/// or audio session events.
public struct AKPlayerStateSnapshot: Sendable {
    /// Indicates whether playback should automatically resume when an
    /// interruption resolves.
    public var shouldResume: Bool
    
    /// The lifecycle state of the application at the precise moment the
    /// snapshot was saved.
    public var applicationState: AKApplicationLifeCycleState
    
    /// The underlying event or system notification that caused the
    /// interruption.
    public var playbackInterruptionReason: AKPlaybackInterruptionReason
    
    /// Initializes a new instance of `AKPlayerStateSnapshot`.
    /// - Parameters:
    ///   - shouldResume: Flag dictating if playback resumes after the
    /// interruption ends.
    ///   - applicationState: Current application state at snapshot creation
    /// time.
    ///   - playbackInterruptionReason: The reason triggering the state capture.
    public init(
        shouldResume: Bool,
        applicationState: AKApplicationLifeCycleState,
        playbackInterruptionReason: AKPlaybackInterruptionReason
    ) {
        self.shouldResume = shouldResume
        self.applicationState = applicationState
        self.playbackInterruptionReason = playbackInterruptionReason
    }
}

// MARK: - AKPlaybackInterruptionReason

/// Enumeration representing reasons for playback interruption.
public enum AKPlaybackInterruptionReason: UInt, Sendable {
    /// Interruption caused by an external audio session event (e.g., incoming
    /// phone call, alarm).
    case audioSessionInterruption
    
    /// Interruption caused when the application resigns active status (e.g.,
    /// opening Control Center).
    case applicationResignActive
    
    /// Interruption caused when the application transitions into the
    /// background.
    case applicationEnteredBackground
    
    /// Flag indicating whether the interruption was caused directly by an app
    /// lifecycle event.
    public var isLifeCycleEvent: Bool {
        self == .applicationEnteredBackground || self == .applicationResignActive
    }
}

public extension AKPlayerManagerProtocol {
    /// Internal seeking service orchestrating seek operations against media.
    var playerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol {
        playerController.playerSeekingThroughMediaService
    }
    
    /// Interstitial service orchestrating ad events, schedules, and integrated timelines.
    var interstitialService: AKPlayerInterstitialServiceProtocol {
        playerController.interstitialService
    }
}

