//
//   AKNowPlayingSession.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import MediaPlayer

// MARK: - AKNowPlayingSessionProtocol

/// Protocol defining the interface for managing system Now Playing and MPRemoteCommandCenter
/// sessions.
@MainActor
public protocol AKNowPlayingSessionProtocol: AnyObject, Sendable {
    // MARK: - Properties

    /// Indicates whether the underlying Now Playing session is actively registered with the system.
    var isActive: Bool { get }

    /// The remote command center instance receiving media control events.
    var remoteCommandCenter: MPRemoteCommandCenter { get }

    /// The now playing info center managing the lock screen and Control Center metadata.
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter { get }

    // MARK: - Remote Command Configuration & Handlers

    /// Applies a remote command configuration to register and enable system commands.
    func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async

    /// Assigns a handler closure for a specific remote command.
    func setHandler(for command: AKRemoteCommand, handler: @escaping AKRemoteCommandHandler) async

    /// Removes the assigned handler closure for a specific remote command.
    func removeHandler(for command: AKRemoteCommand) async

    /// Enables a list of remote commands.
    func enable(commands: [AKRemoteCommand]) async

    /// Disables a list of remote commands.
    func disable(commands: [AKRemoteCommand]) async

    /// Checks whether a specific command is currently enabled.
    func isCommandEnabled(_ command: AKRemoteCommand) -> Bool

    /// Unregisters all command handlers and targets from the remote command center.
    func unregisterAll()

    // MARK: - Now Playing Info Metadata

    /// Sets the Now Playing metadata dictionary on the info center.
    func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?)

    /// Clears any active Now Playing metadata from the info center.
    func clearNowPlayingPlaybackInfo()

    // MARK: - Session Activation & Player Registration

    /// Indicates whether the session can become active.
    func canBecomeActive() -> Bool

    /// Requests the system to activate the Now Playing session.
    func becomeActiveIfPossible() async -> Bool

    /// Adds an AVPlayer instance to the multi-player session.
    func addPlayer(_ player: AVPlayer)

    /// Removes an AVPlayer instance from the multi-player session.
    func removePlayer(_ player: AVPlayer)
}

// MARK: - AKNowPlayingSession

/// Low-level coordinator wrapping system `MPNowPlayingSession`, `MPRemoteCommandCenter`, and
/// `MPNowPlayingInfoCenter`.
@MainActor
public final class AKNowPlayingSession: AKNowPlayingSessionProtocol {
    // MARK: - System

    /// The underlying system MPNowPlayingSession instance for multi-player routing.
    private var nowPlayingSession: MPNowPlayingSession?
    /// Fallback remote command center used when MPNowPlayingSession is unavailable.
    private let fallbackRemoteCommandCenter: MPRemoteCommandCenter
    /// Fallback now playing info center used when MPNowPlayingSession is unavailable.
    private let fallbackNowPlayingInfoCenter: MPNowPlayingInfoCenter

    /// The remote command center associated with this session.
    public var remoteCommandCenter: MPRemoteCommandCenter {
        nowPlayingSession?.remoteCommandCenter ?? fallbackRemoteCommandCenter
    }

    /// The now playing info center associated with this session.
    public var nowPlayingInfoCenter: MPNowPlayingInfoCenter {
        nowPlayingSession?.nowPlayingInfoCenter ?? fallbackNowPlayingInfoCenter
    }

    /// Indicates whether the Now Playing session is currently active.
    public var isActive: Bool {
        nowPlayingSession?.isActive ?? false
    }

    // MARK: - Local command state

    /// Local registration entry wrapping command handlers, enabled flag, and target tokens.
    private struct CommandEntry {
        /// The custom handler closure invoked when this command executes.
        var handler: AKRemoteCommandHandler?
        /// Flag indicating whether the remote command is enabled.
        var isEnabled: Bool
        /// Target token returned by MPRemoteCommand upon adding target.
        var target: Any?
    }

    /// Dictionary storing active command registration entries keyed by command identifier.
    private var commands: [String: CommandEntry] = [:]

    // MARK: - Initialization

    /// Initializes a multi-player Now Playing session bound to the provided AVPlayer instances.
    /// - Parameter players: The player instances associated with this session.
    public init(players: [AVPlayer]) {
        let session = MPNowPlayingSession(players: players)
        nowPlayingSession = session
        fallbackRemoteCommandCenter = session.remoteCommandCenter
        fallbackNowPlayingInfoCenter = session.nowPlayingInfoCenter
    }

    /// Initializes a fallback Now Playing session using shared remote command and info centers.
    /// - Parameters:
    ///   - remoteCommandCenter: The remote command center to use.
    ///   - nowPlayingInfoCenter: The now playing info center to use.
    public init(
        remoteCommandCenter: MPRemoteCommandCenter = .shared(),
        nowPlayingInfoCenter: MPNowPlayingInfoCenter = .default()
    ) {
        nowPlayingSession = nil
        fallbackRemoteCommandCenter = remoteCommandCenter
        fallbackNowPlayingInfoCenter = nowPlayingInfoCenter
    }

    // MARK: - Configuration

    /// Applies a remote command configuration by enabling requested commands and binding handlers.
    /// - Parameter config: The command configuration to apply.
    public func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async {
        // 1. Cleanly disable and reset all remote commands
        for command in AKRemoteCommand.all() {
            setEnabled(false, for: command)
        }

        // 2. Enable and configure only the commands in the new configuration
        for command in config.enabledCommands {
            registerIfNeeded(command)
            if let handler = config.handler(for: command) {
                commands[command.id]?.handler = handler
            }
            setEnabled(true, for: command)
        }
    }

    /// Sets an action handler for a specific remote command.
    /// - Parameters:
    ///   - command: The remote command to register.
    ///   - handler: Closure invoked when the remote command triggers.
    public func setHandler(
        for command: AKRemoteCommand,
        handler: @escaping AKRemoteCommandHandler
    ) async {
        registerIfNeeded(command)
        commands[command.id]?.handler = handler
    }

    /// Clears the action handler for a specific remote command.
    /// - Parameter command: The remote command to clear.
    public func removeHandler(for command: AKRemoteCommand) async {
        commands[command.id]?.handler = nil
    }

    /// Enables the specified list of remote commands.
    /// - Parameter list: The commands to enable.
    public func enable(commands list: [AKRemoteCommand]) async {
        for command in list {
            registerIfNeeded(command)
            setEnabled(true, for: command)
        }
    }

    /// Disables the specified list of remote commands.
    /// - Parameter list: The commands to disable.
    public func disable(commands list: [AKRemoteCommand]) async {
        for command in list {
            setEnabled(false, for: command)
        }
    }

    /// Checks whether a remote command is currently enabled.
    /// - Parameter command: The remote command to check.
    /// - Returns: `true` if enabled, `false` otherwise.
    public func isCommandEnabled(_ command: AKRemoteCommand) -> Bool {
        commands[command.id]?.isEnabled ?? false
    }

    // MARK: - Metadata

    /// Updates the `MPNowPlayingInfoCenter` dictionary with serialized metadata.
    /// - Parameter metadata: The metadata structure containing static and dynamic info.
    public func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?) {
        guard let metadata, let info = metadata.getNowPlayingInfo() else {
            clearNowPlayingPlaybackInfo()
            return
        }
        nowPlayingInfoCenter.nowPlayingInfo = info
    }

    /// Clears active metadata from the Now Playing info center.
    public func clearNowPlayingPlaybackInfo() {
        nowPlayingInfoCenter.nowPlayingInfo = nil
    }

    /// Unregisters all command targets and resets registered remote commands.
    public func unregisterAll() {
        for (id, entry) in commands {
            if let target = entry.target,
               let command = AKRemoteCommand.all().first(where: { $0.id == id })
            {
                let remote = command.metadata.getCommand(remoteCommandCenter)
                remote.removeTarget(target)
                remote.isEnabled = false
            }
        }
        commands.removeAll()
    }

    // MARK: - Session activation

    /// Returns whether the system session can currently become active.
    public func canBecomeActive() -> Bool {
        nowPlayingSession?.canBecomeActive ?? true
    }

    /// Attempts to activate the Now Playing session.
    /// - Returns: `true` if session activation succeeded, `false` otherwise.
    public func becomeActiveIfPossible() async -> Bool {
        guard let systemSession = nowPlayingSession else { return true }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            systemSession.becomeActiveIfPossible { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Adds an AVPlayer instance to the multi-player session.
    /// - Parameter player: The player instance to add.
    public func addPlayer(_ player: AVPlayer) {
        nowPlayingSession?.addPlayer(player)
    }

    /// Removes an AVPlayer instance from the multi-player session.
    /// - Parameter player: The player instance to remove.
    public func removePlayer(_ player: AVPlayer) {
        nowPlayingSession?.removePlayer(player)
    }

    // MARK: - Private registration

    /// Registers target-action handlers on the MPRemoteCommandCenter for the specified command if
    /// not already added.
    /// - Parameter command: The remote command to register.
    private func registerIfNeeded(_ command: AKRemoteCommand) {
        let id = command.id

        switch command {
        case let .skipBackward(intervals):
            if !intervals.isEmpty {
                remoteCommandCenter.skipBackwardCommand.preferredIntervals = intervals
                    .map { NSNumber(value: $0) }
            }
        case let .skipForward(intervals):
            if !intervals.isEmpty {
                remoteCommandCenter.skipForwardCommand.preferredIntervals = intervals
                    .map { NSNumber(value: $0) }
            }
        case let .changePlaybackRate(rates):
            if !rates.isEmpty {
                remoteCommandCenter.changePlaybackRateCommand.supportedPlaybackRates = rates
                    .map { NSNumber(value: $0) }
            }
        default:
            break
        }

        guard commands[id] == nil else { return }

        let remote = command.metadata.getCommand(remoteCommandCenter)

        let target = remote.addTarget { [weak self] event in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.handle(command, event: event) ?? .commandFailed
                }
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated {
                        self?.handle(command, event: event) ?? .commandFailed
                    }
                }
            }
        }

        commands[id] = CommandEntry(handler: nil, isEnabled: false, target: target)
    }

    /// Enables or disables a specific remote command on both local state and MPRemoteCommandCenter.
    /// - Parameters:
    ///   - enabled: Whether to enable or disable the command.
    ///   - command: The target remote command.
    private func setEnabled(_ enabled: Bool, for command: AKRemoteCommand) {
        registerIfNeeded(command)
        commands[command.id]?.isEnabled = enabled
        let remote = command.metadata.getCommand(remoteCommandCenter)
        remote.isEnabled = enabled
        if !enabled, let skip = remote as? MPSkipIntervalCommand {
            skip.preferredIntervals = []
        }
    }

    /// Invokes the registered handler for the given remote command event, returning the handler
    /// status.
    /// - Parameters:
    ///   - command: The triggering remote command.
    ///   - event: The MPRemoteCommandEvent dispatched by the system.
    /// - Returns: An `MPRemoteCommandHandlerStatus` indicating success or failure.
    private func handle(
        _ command: AKRemoteCommand,
        event: MPRemoteCommandEvent
    ) -> MPRemoteCommandHandlerStatus {
        if let handler = commands[command.id]?.handler {
            return handler(event)
        }
        return .success
    }
}
