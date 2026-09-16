//
//   AKNowPlayingIntegration.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import MediaPlayer

// MARK: - Integration with AKPlayer

/// Extension to AKPlayer for convenient Now Playing session setup.
public extension AKPlayer {
    /// Configures Now Playing with a preset configuration.
    func configureNowPlaying(
        with configuration: AKNowPlayingCommandConfiguration
    ) async {
        guard let session = nowPlayingManager?.session else { return }
        await session.applyConfiguration(configuration)
    }
}

// MARK: - Protocol for Manager

/// Protocol to be added to AKPlayerManager for Now Playing session integration.
@MainActor
public protocol AKNowPlayingSessionProvider: AnyObject {
    var nowPlayingSession: AKNowPlayingSession? { get }
}

// MARK: - Command Preset Manager

/// Manages predefined command presets for different use cases.
public enum AKNowPlayingCommandPresets {
    /// Preset: Minimal playback controls only
    public static func minimal() -> AKNowPlayingCommandConfiguration {
        AKNowPlayingCommandConfiguration.minimal()
    }
    
    /// Preset: Standard music streaming
    public static func music() -> AKNowPlayingCommandConfiguration {
        AKNowPlayingCommandConfiguration.audio()
    }
    
    /// Preset: Podcast with 15-second skip back, 30-second skip forward
    public static func podcast() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration.audio()
        _ = config.add(.skipBackward(preferredIntervals: [15.0]))
        _ = config.add(.skipForward(preferredIntervals: [30.0]))
        _ = config.disable(.changeShuffleMode)
        return config
    }
    
    /// Preset: Audiobook with bookmarking
    public static func audiobook() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration.audio()
        _ = config.add(.bookmark)
        _ = config.disable(.changeShuffleMode)
        return config
    }
    
    /// Preset: Standard video playback
    public static func video() -> AKNowPlayingCommandConfiguration {
        AKNowPlayingCommandConfiguration.video()
    }
    
    /// Preset: Live stream (no seeking)
    public static func livestream() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration.audio()
        _ = config.disable(.seekBackward)
        _ = config.disable(.seekForward)
        _ = config.disable(.changePlaybackPosition)
        return config
    }
}
