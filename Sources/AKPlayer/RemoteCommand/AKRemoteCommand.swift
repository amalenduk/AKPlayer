//
//   AKRemoteCommand.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation
import MediaPlayer

// MARK: - Handlers & Types

/// A closure type responsible for handling incoming `MPRemoteCommandEvent`
/// requests from system media controls.
/// Executes on the main actor and is thread-safe (`@Sendable`).
public typealias AKRemoteCommandHandler =
@MainActor @Sendable (MPRemoteCommandEvent) ->
MPRemoteCommandHandlerStatus

/// Represents the exhaustive set of remote media commands exposed by
/// `MPRemoteCommandCenter`.
/// Used to define, configure, and route system-level commands with parameter
/// payload support.
public enum AKRemoteCommand: Hashable, Sendable {
    // MARK: - Playback Commands
    
    /// Command to resume or begin audio/video playback.
    case play
    /// Command to suspend active playback temporarily.
    case pause
    /// Command to completely terminate playback.
    case stop
    /// Command to toggle between playing and paused states.
    case togglePlayPause
    
    // MARK: - Navigation Commands
    
    /// Command to jump to the subsequent track or item in a queue.
    case nextTrack
    /// Command to return to the preceding track or restart the current track.
    case previousTrack
    /// Command to modify the playback loop repeat behavior.
    case changeRepeatMode
    /// Command to alter the playback order configuration.
    case changeShuffleMode
    
    // MARK: - Seeking Commands
    
    /// Command to modify playback speed, featuring supported playback rate
    /// configurations.
    case changePlaybackRate(supportedPlaybackRates: [Float])
    /// Command to continuously seek backward through media.
    case seekBackward
    /// Command to continuously seek forward through media.
    case seekForward
    /// Command to jump backward by specific time intervals.
    case skipBackward(preferredIntervals: [TimeInterval])
    /// Command to jump forward by specific time intervals.
    case skipForward(preferredIntervals: [TimeInterval])
    /// Command to move playback instantly to a specific elapsed time position.
    case changePlaybackPosition
    
    // MARK: - Rating/Feedback Commands
    
    /// Command to apply a rating score to the active media item.
    case rating
    /// Command to mark the current track as favorited or liked.
    case like
    /// Command to flag the current track as disliked.
    case dislike
    /// Command to save a bookmark marker within the media stream.
    case bookmark
    
    // MARK: - Language Commands
    
    /// Command to activate a specific audio language track or subtitle option.
    case enableLanguageOption
    /// Command to deactivate an active language or subtitle option.
    case disableLanguageOption
}

// MARK: - Command Metadata

public extension AKRemoteCommand {
    /// A structured container defining strong type references and accessors for
    /// individual remote commands.
    struct CommandMetadata: Sendable {
        /// Unique string representation identifier for the command.
        public let id: String
        /// Human-readable title string describing the command option.
        public let name: String
        /// Closure block resolving the corresponding `MPRemoteCommand` instance
        /// from a target `MPRemoteCommandCenter`.
        public let getCommand:
        @Sendable @MainActor (MPRemoteCommandCenter)
        -> MPRemoteCommand
    }
    
    /// Retrieves full structured metadata for the current command case.
    var metadata: CommandMetadata {
        switch self {
        case .play:
            CommandMetadata(
                id: "play",
                name: "Play",
                getCommand: { $0.playCommand }
            )
        case .pause:
            CommandMetadata(
                id: "pause",
                name: "Pause",
                getCommand: { $0.pauseCommand }
            )
        case .stop:
            CommandMetadata(
                id: "stop",
                name: "Stop",
                getCommand: { $0.stopCommand }
            )
        case .togglePlayPause:
            CommandMetadata(
                id: "togglePlayPause", name: "Toggle Play/Pause",
                getCommand: { $0.togglePlayPauseCommand }
            )
        case .nextTrack:
            CommandMetadata(
                id: "nextTrack", name: "Next Track",
                getCommand: { $0.nextTrackCommand }
            )
        case .previousTrack:
            CommandMetadata(
                id: "previousTrack", name: "Previous Track",
                getCommand: { $0.previousTrackCommand }
            )
        case .changeRepeatMode:
            CommandMetadata(
                id: "changeRepeatMode", name: "Change Repeat Mode",
                getCommand: { $0.changeRepeatModeCommand }
            )
        case .changeShuffleMode:
            CommandMetadata(
                id: "changeShuffleMode", name: "Change Shuffle Mode",
                getCommand: { $0.changeShuffleModeCommand }
            )
        case .changePlaybackRate:
            CommandMetadata(
                id: "changePlaybackRate", name: "Change Playback Rate",
                getCommand: { $0.changePlaybackRateCommand }
            )
        case .seekBackward:
            CommandMetadata(
                id: "seekBackward", name: "Seek Backward",
                getCommand: { $0.seekBackwardCommand }
            )
        case .seekForward:
            CommandMetadata(
                id: "seekForward", name: "Seek Forward",
                getCommand: { $0.seekForwardCommand }
            )
        case .skipBackward:
            CommandMetadata(
                id: "skipBackward", name: "Skip Backward",
                getCommand: { $0.skipBackwardCommand }
            )
        case .skipForward:
            CommandMetadata(
                id: "skipForward", name: "Skip Forward",
                getCommand: { $0.skipForwardCommand }
            )
        case .changePlaybackPosition:
            CommandMetadata(
                id: "changePlaybackPosition", name: "Change Playback Position",
                getCommand: { $0.changePlaybackPositionCommand }
            )
        case .rating:
            CommandMetadata(
                id: "rating",
                name: "Rating",
                getCommand: { $0.ratingCommand }
            )
        case .like:
            CommandMetadata(
                id: "like",
                name: "Like",
                getCommand: { $0.likeCommand }
            )
        case .dislike:
            CommandMetadata(
                id: "dislike",
                name: "Dislike",
                getCommand: { $0.dislikeCommand }
            )
        case .bookmark:
            CommandMetadata(
                id: "bookmark",
                name: "Bookmark",
                getCommand: { $0.bookmarkCommand }
            )
        case .enableLanguageOption:
            CommandMetadata(
                id: "enableLanguageOption", name: "Enable Language Option",
                getCommand: { $0.enableLanguageOptionCommand }
            )
        case .disableLanguageOption:
            CommandMetadata(
                id: "disableLanguageOption", name: "Disable Language Option",
                getCommand: { $0.disableLanguageOptionCommand }
            )
        }
    }
    
    /// A unique string representation ID associated with the command type.
    var id: String {
        metadata.id
    }
    
    /// A localized, human-friendly string label for displaying the command.
    var name: String {
        metadata.name
    }
}

// MARK: - Command Presets

public extension AKRemoteCommand {
    /// A standard array grouping core playback controls (`play`, `pause`,
    /// `stop`, `togglePlayPause`).
    static var playbackCommands: [AKRemoteCommand] {
        [.play, .pause, .stop, .togglePlayPause]
    }
    
    /// A grouped preset configuration for track navigation (`nextTrack`,
    /// `previousTrack`, `changeRepeatMode`, `changeShuffleMode`).
    static var trackNavigationCommands: [AKRemoteCommand] {
        [.nextTrack, .previousTrack, .changeRepeatMode, .changeShuffleMode]
    }
    
    /// Generates a set of seeking and jumping commands configured with custom
    /// jump intervals.
    /// - Parameter intervals: Array of skip intervals in seconds. Defaults to
    /// `[15.0]`.
    /// - Returns: An array containing configured seeking commands.
    static func seekingCommands(intervals: [TimeInterval] = [15.0])
    -> [AKRemoteCommand]
    {
        [
            .skipBackward(preferredIntervals: intervals),
            .skipForward(preferredIntervals: intervals),
            .changePlaybackPosition,
            .seekBackward,
            .seekForward,
        ]
    }
    
    /// A preset collection containing feedback actions (`like`, `dislike`,
    /// `bookmark`, `rating`).
    static var feedbackCommands: [AKRemoteCommand] {
        [.like, .dislike, .bookmark, .rating]
    }
    
    /// A preset collection managing language tracks and subtitle
    /// configurations.
    static var languageCommands: [AKRemoteCommand] {
        [.enableLanguageOption, .disableLanguageOption]
    }
    
    /// A comprehensive standard command preset tailored for general audio
    /// streams, podcasts, and audiobooks.
    static var standardAudioPreset: [AKRemoteCommand] {
        [
            .play, .pause, .togglePlayPause,
            .skipBackward(preferredIntervals: [15.0]),
            .skipForward(preferredIntervals: [15.0]),
            .changePlaybackPosition,
            .changePlaybackRate(supportedPlaybackRates: AKPlaybackRate.allCases.map({ $0.rate })),
        ]
    }
    
    /// A standard preset option optimized for video streaming applications.
    static var standardVideoPreset: [AKRemoteCommand] {
        [
            .play, .pause, .togglePlayPause,
            .seekBackward, .seekForward,
            .skipBackward(preferredIntervals: [10.0]),
            .skipForward(preferredIntervals: [10.0]),
            .changePlaybackPosition,
        ]
    }
    
    /// Returns an exhaustive array representing every defined remote command
    /// variant.
    static func all() -> [AKRemoteCommand] {
        [
            .play, .pause, .stop, .togglePlayPause,
            .nextTrack, .previousTrack,
            .changeRepeatMode, .changeShuffleMode,
            .changePlaybackRate(supportedPlaybackRates: []),
            .seekBackward, .seekForward,
            .skipBackward(preferredIntervals: []),
            .skipForward(preferredIntervals: []),
            .changePlaybackPosition,
            .rating, .like, .dislike, .bookmark,
            .enableLanguageOption, .disableLanguageOption,
        ]
    }
}

extension AKRemoteCommand {
    /// String identifier derived from the command representation.
    var hashKey: String {
        String(describing: self)
    }
}
