//
//   AKNowPlayingCommandConfiguration.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation
import MediaPlayer

// MARK: - AKNowPlayingCommandConfiguration

/// Thread-safe builder for configuring Now Playing remote command sessions.
/// Designed as a value type (`struct`) conforming to `Sendable` using an
/// immutable copy-on-write builder pattern.
public struct AKNowPlayingCommandConfiguration: Sendable {
    // MARK: - Properties

    /// Unique set of remote commands added to this configuration.
    private var commands: Set<AKRemoteCommand> = []

    /// Map tracking enablement state for registered commands.
    private var commandEnablementMap: [AKRemoteCommand: Bool] = [:]

    /// Dictionary mapping explicit remote commands to their custom handlers.
    private var customHandlers: [AKRemoteCommand: AKRemoteCommandHandler] = [:]

    // MARK: - Initialization

    /// Creates a new instance of `AKNowPlayingCommandConfiguration`.
    public init() {}

    // MARK: - Builder Methods

    /// Adds a single command to the configuration.
    /// - Parameter command: The remote command to add.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func add(_ command: AKRemoteCommand) -> Self {
        var copy = self
        copy.commands.insert(command)
        copy.commandEnablementMap[command] = true
        return copy
    }

    /// Adds multiple commands to the configuration.
    /// - Parameter commands: Array of commands to add.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func add(commands: [AKRemoteCommand]) -> Self {
        var copy = self
        for command in commands {
            copy = copy.add(command)
        }
        return copy
    }

    /// Removes a command from the configuration.
    /// - Parameter command: Target command to remove.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func remove(_ command: AKRemoteCommand) -> Self {
        var copy = self
        copy.commands.remove(command)
        copy.commandEnablementMap.removeValue(forKey: command)
        copy.customHandlers.removeValue(forKey: command)
        return copy
    }

    /// Removes multiple commands from the configuration.
    /// - Parameter commands: Array of target commands to remove.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func remove(commands: [AKRemoteCommand]) -> Self {
        var copy = self
        for command in commands {
            copy = copy.remove(command)
        }
        return copy
    }

    /// Applies the standard audio/podcast command preset.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useAudioPreset() -> Self {
        add(commands: AKRemoteCommand.standardAudioPreset)
    }

    /// Applies the standard video command preset.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useVideoPreset() -> Self {
        add(commands: AKRemoteCommand.standardVideoPreset)
    }

    /// Applies essential playback commands (play, pause, toggle, stop).
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func usePlaybackCommands() -> Self {
        add(commands: AKRemoteCommand.playbackCommands)
    }

    /// Applies track navigation commands (next track, previous track).
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useTrackNavigationCommands() -> Self {
        add(commands: AKRemoteCommand.trackNavigationCommands)
    }

    /// Applies seeking commands with custom time skip intervals.
    /// - Parameter intervals: Time intervals in seconds for skip
    /// forward/backward commands.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useSeekingCommands(intervals: [Double] = [15.0]) -> Self {
        add(commands: AKRemoteCommand.seekingCommands(intervals: intervals))
    }

    /// Applies feedback and rating commands (like, dislike, bookmark).
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useFeedbackCommands() -> Self {
        add(commands: AKRemoteCommand.feedbackCommands)
    }

    /// Applies language and audio/subtitle selection commands.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useLanguageCommands() -> Self {
        add(commands: AKRemoteCommand.languageCommands)
    }

    /// Enables a specific command in this configuration.
    /// - Parameter command: Target command to enable.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func enable(_ command: AKRemoteCommand) -> Self {
        var copy = self
        copy.commands.insert(command)
        copy.commandEnablementMap[command] = true
        return copy
    }

    /// Enables multiple commands in this configuration.
    /// - Parameter commands: Array of commands to enable.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func enable(commands: [AKRemoteCommand]) -> Self {
        var copy = self
        for command in commands {
            copy = copy.enable(command)
        }
        return copy
    }

    /// Disables a specific command in this configuration.
    /// - Parameter command: Target command to disable.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func disable(_ command: AKRemoteCommand) -> Self {
        var copy = self
        copy.commands.insert(command)
        copy.commandEnablementMap[command] = false
        return copy
    }

    /// Disables multiple commands in this configuration.
    /// - Parameter commands: Array of commands to disable.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func disable(commands: [AKRemoteCommand]) -> Self {
        var copy = self
        for command in commands {
            copy = copy.disable(command)
        }
        return copy
    }

    /// Registers a custom `@Sendable` handler closure for a command.
    /// - Parameters:
    ///   - command: The target remote command to assign the handler to.
    ///   - handler: Concurrency-safe event handler closure.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func setHandler(
        for command: AKRemoteCommand,
        handler: @escaping AKRemoteCommandHandler
    ) -> Self {
        var copy = self
        copy.customHandlers[command] = handler
        if !copy.commands.contains(command) {
            copy.commands.insert(command)
            copy.commandEnablementMap[command] = true
        }
        return copy
    }

    /// Clears all stored commands, enablement flags, and custom handlers.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func clear() -> Self {
        var copy = self
        copy.commands.removeAll()
        copy.commandEnablementMap.removeAll()
        copy.customHandlers.removeAll()
        return copy
    }

    // MARK: - Query Methods

    /// Returns an array of all registered commands in this configuration.
    public var allCommands: [AKRemoteCommand] {
        Array(commands)
    }

    /// Returns an array containing only currently enabled commands.
    public var enabledCommands: [AKRemoteCommand] {
        commands.filter { commandEnablementMap[$0] ?? false }
    }

    /// Returns an array containing only currently disabled commands.
    public var disabledCommands: [AKRemoteCommand] {
        commands.filter { !(commandEnablementMap[$0] ?? false) }
    }

    /// Retrieves the registered custom handler for a given command.
    /// - Parameter command: Target command to inspect.
    /// - Returns: The registered `@Sendable` handler, or `nil` if none exists.
    public func handler(for command: AKRemoteCommand)
        -> AKRemoteCommandHandler?
    {
        customHandlers[command]
    }

    /// Checks whether a command is set as enabled in this configuration.
    /// - Parameter command: Target command to inspect.
    /// - Returns: `true` if configured and enabled; otherwise `false`.
    public func isEnabled(_ command: AKRemoteCommand) -> Bool {
        commandEnablementMap[command] ?? false
    }
}

// MARK: - Preset Configurations

public extension AKNowPlayingCommandConfiguration {
    /// Factory creating a pre-configured audio preset instance (playback, skip intervals, scrubber, playback rate).
    static func audio() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration()
        return config.useAudioPreset()
    }

    /// Factory creating a pre-configured video preset instance (playback, seeking, skip intervals, scrubber).
    static func video() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration()
        return config.useVideoPreset()
    }
    
    /// Factory creating a pre-configured queue / playlist preset instance (next/previous track, repeat, shuffle, scrubbing, without skip interval buttons).
    static func queue() -> AKNowPlayingCommandConfiguration {
        AKNowPlayingCommandConfiguration()
            .usePlaybackCommands()
            .useTrackNavigationCommands()
            .add(.changePlaybackPosition)
            .disable(commands: [
                .skipBackward(preferredIntervals: [15.0]),
                .skipForward(preferredIntervals: [15.0]),
                .seekBackward,
                .seekForward
            ])
    }

    /// Factory creating a minimal configuration with primary playback controls
    /// (.play, .pause, .togglePlayPause).
    static func minimal() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration()
        return config.add(commands: [.play, .pause, .togglePlayPause])
    }

    /// Factory creating a complete configuration with all available commands
    /// added.
    static func full() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration()
        return config.add(commands: AKRemoteCommand.all())
    }

    /// Factory creating an empty configuration starting from scratch.
    static func custom() -> AKNowPlayingCommandConfiguration {
        AKNowPlayingCommandConfiguration()
    }
}
