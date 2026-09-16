import AVFoundation
import Foundation
import MediaPlayer

@MainActor
public protocol AKNowPlayingSessionProtocol: AnyObject {
    var isActive: Bool { get }
    var remoteCommandCenter: MPRemoteCommandCenter { get }
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter { get }
    
    func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async
    func setHandler(for command: AKRemoteCommand, handler: @escaping AKRemoteCommandHandler) async
    func removeHandler(for command: AKRemoteCommand) async
    func enable(commands: [AKRemoteCommand]) async
    func disable(commands: [AKRemoteCommand]) async
    func isCommandEnabled(_ command: AKRemoteCommand) -> Bool
    
    func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?)
    func clearNowPlayingPlaybackInfo()
    func unregisterAll()
    
    func canBecomeActive() -> Bool
    func becomeActiveIfPossible() async -> Bool
    func addPlayer(_ player: AVPlayer)
    func removePlayer(_ player: AVPlayer)
}

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
    
    // MARK: - Local command state (replaces public Registry)
    
    private struct CommandEntry {
        var handler: AKRemoteCommandHandler?
        var isEnabled: Bool
        var target: Any?
    }
    
    private var commands: [String: CommandEntry] = [:]
    
    // MARK: - Init
    
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
    
    deinit {
        // targets cleaned when centers go away; avoid main-actor calls here
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
        guard commands[id] == nil else { return }
        
        let remote = command.metadata.getCommand(remoteCommandCenter)
        
        switch command {
        case let .skipBackward(intervals):
            remoteCommandCenter.skipBackwardCommand.preferredIntervals = intervals.map { NSNumber(value: $0) }
        case let .skipForward(intervals):
            remoteCommandCenter.skipForwardCommand.preferredIntervals = intervals.map { NSNumber(value: $0) }
        case let .changePlaybackRate(rates):
            remoteCommandCenter.changePlaybackRateCommand.supportedPlaybackRates = rates.map { NSNumber(value: $0) }
        default:
            break
        }
        
        let target = remote.addTarget { [weak self] event in
            self?.handle(command, event: event) ?? .commandFailed
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
