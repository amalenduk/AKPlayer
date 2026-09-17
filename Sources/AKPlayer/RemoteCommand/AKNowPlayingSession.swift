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

/// Protocol defining the interface for managing system Now Playing and MPRemoteCommandCenter sessions.
@MainActor
public protocol AKNowPlayingSessionProtocol: AnyObject, Sendable {
    /// Indicates whether the underlying Now Playing session is actively registered with the system.
    var isActive: Bool { get }
    
    /// The remote command center instance receiving media control events.
    var remoteCommandCenter: MPRemoteCommandCenter { get }
    
    /// The now playing info center managing the lock screen and Control Center metadata.
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter { get }
    
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
    
    /// Sets the Now Playing metadata dictionary on the info center.
    func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?)
    
    /// Clears any active Now Playing metadata from the info center.
    func clearNowPlayingPlaybackInfo()
    
    /// Unregisters all command handlers and targets from the remote command center.
    func unregisterAll()
    
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

@MainActor
public final class AKNowPlayingSession: AKNowPlayingSessionProtocol {
    
    // MARK: - System
    
    private var nowPlayingSession: MPNowPlayingSession?
    private let fallbackRemoteCommandCenter: MPRemoteCommandCenter
    private let fallbackNowPlayingInfoCenter: MPNowPlayingInfoCenter
    
    public var remoteCommandCenter: MPRemoteCommandCenter {
        nowPlayingSession?.remoteCommandCenter ?? fallbackRemoteCommandCenter
    }
    
    public var nowPlayingInfoCenter: MPNowPlayingInfoCenter {
        nowPlayingSession?.nowPlayingInfoCenter ?? fallbackNowPlayingInfoCenter
    }
    
    public var isActive: Bool {
        nowPlayingSession?.isActive ?? false
    }
    
    // MARK: - Local command state
    
    private struct CommandEntry {
        var handler: AKRemoteCommandHandler?
        var isEnabled: Bool
        var target: Any?
    }
    
    private var commands: [String: CommandEntry] = [:]
    
    // MARK: - Initialization
    
    public init(players: [AVPlayer]) {
        let session = MPNowPlayingSession(players: players)
        nowPlayingSession = session
        fallbackRemoteCommandCenter = session.remoteCommandCenter
        fallbackNowPlayingInfoCenter = session.nowPlayingInfoCenter
    }
    
    public init(
        remoteCommandCenter: MPRemoteCommandCenter = .shared(),
        nowPlayingInfoCenter: MPNowPlayingInfoCenter = .default()
    ) {
        nowPlayingSession = nil
        fallbackRemoteCommandCenter = remoteCommandCenter
        fallbackNowPlayingInfoCenter = nowPlayingInfoCenter
    }
    
    // MARK: - Configuration
    
    public func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async {
        let list = config.allCommands
        
        for command in list {
            registerIfNeeded(command)
            if let handler = config.handler(for: command) {
                commands[command.id]?.handler = handler
            }
            setEnabled(config.isEnabled(command), for: command)
        }
    }
    
    public func setHandler(for command: AKRemoteCommand, handler: @escaping AKRemoteCommandHandler) async {
        registerIfNeeded(command)
        commands[command.id]?.handler = handler
    }
    
    public func removeHandler(for command: AKRemoteCommand) async {
        commands[command.id]?.handler = nil
    }
    
    public func enable(commands list: [AKRemoteCommand]) async {
        for command in list {
            registerIfNeeded(command)
            setEnabled(true, for: command)
        }
    }
    
    public func disable(commands list: [AKRemoteCommand]) async {
        for command in list {
            setEnabled(false, for: command)
        }
    }
    
    public func isCommandEnabled(_ command: AKRemoteCommand) -> Bool {
        commands[command.id]?.isEnabled ?? false
    }
    
    // MARK: - Metadata
    
    public func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?) {
        guard let metadata, let info = metadata.getNowPlayingInfo() else {
            clearNowPlayingPlaybackInfo()
            return
        }
        nowPlayingInfoCenter.nowPlayingInfo = info
    }
    
    public func clearNowPlayingPlaybackInfo() {
        nowPlayingInfoCenter.nowPlayingInfo = nil
    }
    
    public func unregisterAll() {
        for (id, entry) in commands {
            if let target = entry.target,
               let command = AKRemoteCommand.all().first(where: { $0.id == id }) {
                let remote = command.metadata.getCommand(remoteCommandCenter)
                remote.removeTarget(target)
                remote.isEnabled = false
            }
        }
        commands.removeAll()
    }
    
    // MARK: - Session activation
    
    public func canBecomeActive() -> Bool {
        nowPlayingSession?.canBecomeActive ?? true
    }
    
    public func becomeActiveIfPossible() async -> Bool {
        guard let systemSession = nowPlayingSession else { return true }
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            systemSession.becomeActiveIfPossible { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    public func addPlayer(_ player: AVPlayer) {
        nowPlayingSession?.addPlayer(player)
    }
    
    public func removePlayer(_ player: AVPlayer) {
        nowPlayingSession?.removePlayer(player)
    }
    
    // MARK: - Private registration
    
    private func registerIfNeeded(_ command: AKRemoteCommand) {
        let id = command.id
        
        switch command {
        case let .skipBackward(intervals):
            if !intervals.isEmpty {
                remoteCommandCenter.skipBackwardCommand.preferredIntervals = intervals.map { NSNumber(value: $0) }
            }
        case let .skipForward(intervals):
            if !intervals.isEmpty {
                remoteCommandCenter.skipForwardCommand.preferredIntervals = intervals.map { NSNumber(value: $0) }
            }
        case let .changePlaybackRate(rates):
            if !rates.isEmpty {
                remoteCommandCenter.changePlaybackRateCommand.supportedPlaybackRates = rates.map { NSNumber(value: $0) }
            }
        default:
            break
        }
        
        guard commands[id] == nil else { return }
        
        let remote = command.metadata.getCommand(remoteCommandCenter)
        
        let target = remote.addTarget { [weak self] event in
            if Thread.isMainThread {
                return MainActor.assumeIsolated {
                    self?.handle(command, event: event) ?? .commandFailed
                }
            } else {
                return DispatchQueue.main.sync {
                    MainActor.assumeIsolated {
                        self?.handle(command, event: event) ?? .commandFailed
                    }
                }
            }
        }
        
        commands[id] = CommandEntry(handler: nil, isEnabled: false, target: target)
    }
    
    private func setEnabled(_ enabled: Bool, for command: AKRemoteCommand) {
        registerIfNeeded(command)
        commands[command.id]?.isEnabled = enabled
        command.metadata.getCommand(remoteCommandCenter).isEnabled = enabled
    }
    
    private func handle(_ command: AKRemoteCommand, event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if let handler = commands[command.id]?.handler {
            return handler(event)
        }
        return .success
    }
}
