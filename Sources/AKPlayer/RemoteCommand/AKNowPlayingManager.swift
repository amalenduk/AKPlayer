//
//  AKNowPlayingManager.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar. All rights reserved.
//  Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import MediaPlayer

extension MPNowPlayingInfoLanguageOptionGroup: @retroactive @unchecked Sendable {}
extension MPNowPlayingInfoLanguageOption: @retroactive @unchecked Sendable {}

// MARK: - Queue Metadata Provider

/// Optional interface allowing players (such as AKQueuePlayer) to supply queue index and count info.
@MainActor
public protocol AKNowPlayingQueueInfoProvider: AnyObject, Sendable {
    var queueCount: Int { get }
    var currentQueueIndex: Int? { get }
}

// MARK: - AKNowPlayingManagerProtocol

/// Protocol defining high-level Now Playing and Remote Command management.
@MainActor
public protocol AKNowPlayingManagerProtocol: AnyObject, Sendable {
    /// The underlying low-level session managing MPRemoteCommandCenter and MPNowPlayingInfoCenter.
    var session: any AKNowPlayingSessionProtocol { get }
    
    /// Starts event observation loops and configures remote command handlers.
    func start() throws
    
    /// Stops event observation loops, cancels background tasks, and resets Now Playing metadata.
    func stop()
    
    /// Forces an explicit update of the current Now Playing metadata payload.
    func updateNowPlayingInfo()
    
    /// Applies a remote command configuration preset or custom configuration.
    func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async
    
    /// Sets a custom action handler for a specific remote command.
    func setHandler(for command: AKRemoteCommand, handler: @escaping AKRemoteCommandHandler) async
    
    /// Removes a custom action handler for a specific remote command.
    func removeHandler(for command: AKRemoteCommand) async
    
    /// Enables specified commands on the remote command center.
    func enable(commands: [AKRemoteCommand]) async
    
    /// Disables specified commands on the remote command center.
    func disable(commands: [AKRemoteCommand]) async
    
    /// Retrieves the current static and dynamic metadata container.
    func currentNowPlayingMetadata() -> AKNowPlayableMetadata?
    
    /// Generates current dynamic state metadata (position, rate, duration, language options, queue).
    func getNowPlayableDynamicMetadata() -> (any AKNowPlayableDynamicMetadataProtocol)?
}

// MARK: - AKNowPlayingManager

@MainActor
public final class AKNowPlayingManager: AKNowPlayingManagerProtocol {
    // MARK: - Properties
    
    public let session: any AKNowPlayingSessionProtocol
    private weak var playerManager: (any AKPlayerManagerProtocol)?
    
    private var playerObservationTask: Task<Void, Never>?
    private var mediaObservationTask: Task<Void, Never>?
    
    // Cached language options extracted when media is ready to play
    private var cachedCurrentLanguageOptions: [MPNowPlayingInfoLanguageOption]?
    private var cachedAvailableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]?
    private var cachedTrackGroups: [AKMediaTrackGroup]?
    
    // MARK: - Initialization & Lifecycle
    
    public init(
        playerManager: any AKPlayerManagerProtocol,
        session: (any AKNowPlayingSessionProtocol)? = nil
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.playerManager = playerManager
        self.session = session ?? AKNowPlayingSession(players: [playerManager.playerController.player])
    }
    
    public func start() throws {
        stop()
        
        guard let playerManager, playerManager.configuration.isNowPlayingEnabled else { return }
        
        if !session.isActive {
            guard session.canBecomeActive() else {
                throw AKPlayerError.nowPlayingSessionFailure
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let active = await self.session.becomeActiveIfPossible()
                guard active else {
                    AKLogger.warning("Failed to activate Now Playing session.", category: .remote)
                    return
                }
                await self.setupDefaultRemoteCommands()
            }
        } else {
            Task { @MainActor [weak self] in
                await self?.setupDefaultRemoteCommands()
            }
        }
        
        observePlayerEvents()
    }
    
    public func stop() {
        playerObservationTask?.cancel()
        playerObservationTask = nil
        mediaObservationTask?.cancel()
        mediaObservationTask = nil
        
        clearCachedLanguageOptions()
        session.clearNowPlayingPlaybackInfo()
        session.unregisterAll()
    }
    
    deinit {
        playerObservationTask?.cancel()
        playerObservationTask = nil
        mediaObservationTask?.cancel()
        mediaObservationTask = nil
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }
    
    // MARK: - High-Level Command Forwarding
    
    public func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async {
        await session.applyConfiguration(config)
    }
    
    public func setHandler(for command: AKRemoteCommand, handler: @escaping AKRemoteCommandHandler) async {
        await session.setHandler(for: command, handler: handler)
    }
    
    public func removeHandler(for command: AKRemoteCommand) async {
        await session.removeHandler(for: command)
    }
    
    public func enable(commands: [AKRemoteCommand]) async {
        await session.enable(commands: commands)
    }
    
    public func disable(commands: [AKRemoteCommand]) async {
        await session.disable(commands: commands)
    }
    
    // MARK: - Event Observation
    
    private func observePlayerEvents() {
        playerObservationTask?.cancel()
        
        playerObservationTask = Task { @MainActor [weak self, weak playerManager] in
            guard let events = playerManager?.events else { return }
            
            for await event in events {
                guard !Task.isCancelled, let self else { break }
                
                switch event {
                case .mediaDidChange(let newMedia):
                    self.clearCachedLanguageOptions()
                    self.observeMediaEvents(for: newMedia)
                    self.updateNowPlayingInfo()
                    
                case .stateDidChange, .playbackRateDidChange, .timeDidChange:
                    self.updateNowPlayingInfo()
                    
                default:
                    break
                }
            }
        }
    }
    
    private func observeMediaEvents(for media: any AKPlayable) {
        mediaObservationTask?.cancel()
        
        mediaObservationTask = Task { @MainActor [weak self, weak media] in
            guard let stream = media?.events else { return }
            
            for await event in stream {
                guard !Task.isCancelled, let self, let media else { break }
                
                switch event {
                case .stateDidChange(let state) where state == .readyToPlay:
                    self.cacheLanguageOptions(from: media)
                    self.updateNowPlayingInfo()
                    
                case .tracksDidChange:
                    if media.state == .readyToPlay {
                        self.cacheLanguageOptions(from: media)
                        self.updateNowPlayingInfo()
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Now Playing Info Management
    
    public func updateNowPlayingInfo() {
        guard let playerManager,
              playerManager.configuration.isNowPlayingEnabled,
              let metadata = currentNowPlayingMetadata()
        else {
            session.clearNowPlayingPlaybackInfo()
            return
        }
        
        session.setNowPlayingInfo(metadata)
    }
    
    public func currentNowPlayingMetadata() -> AKNowPlayableMetadata? {
        guard let currentMedia = playerManager?.currentMedia else { return nil }
        
        return AKNowPlayableMetadata(
            staticMetadata: currentMedia.staticMetadata,
            dynamicMetadata: getNowPlayableDynamicMetadata()
        )
    }
    
    public func getNowPlayableDynamicMetadata() -> (any AKNowPlayableDynamicMetadataProtocol)? {
        guard let playerManager,
              let currentMedia = playerManager.currentMedia
        else { return nil }
        
        let position: Double? = currentMedia.isLive() ? nil : {
            guard let item = playerManager.currentItem,
                  item.currentTime().isValid,
                  !item.currentTime().isIndefinite,
                  !item.currentTime().seconds.isNaN,
                  item.currentTime().seconds.isFinite
            else { return nil }
            return Double(item.currentTime().seconds)
        }()
        
        let duration: Float? = currentMedia.isLive() ? nil : {
            guard let item = playerManager.currentItem,
                  item.duration.isValid,
                  !item.duration.isIndefinite,
                  !item.duration.seconds.isNaN,
                  item.duration.seconds.isFinite
            else { return nil }
            return Float(item.duration.seconds)
        }()
        
        let playbackProgress: Float? = {
            guard let pos = position, let dur = duration, dur > 0 else { return nil }
            return min(max(Float(pos / Double(dur)), 0.0), 1.0)
        }()
        
        // Populate queue info if available
        let queueProvider = playerManager as? (any AKNowPlayingQueueInfoProvider)
        
        return AKNowPlayableDynamicMetadata(
            rate: Double(playerManager.rate.rate),
            defaultRate: Double(playerManager.defaultRate.rate),
            position: position,
            duration: duration,
            currentLanguageOptions: cachedCurrentLanguageOptions,
            availableLanguageOptionGroups: cachedAvailableLanguageOptionGroups,
            chapterCount: nil,
            chapterNumber: nil,
            creditsStartTime: nil,
            currentPlaybackDate: playerManager.currentItem?.currentDate(),
            playbackProgress: playbackProgress,
            playbackQueueCount: queueProvider?.queueCount,
            playbackQueueIndex: queueProvider?.currentQueueIndex,
            serviceIdentifier: nil
        )
    }
    
    // MARK: - Language Options Caching
    
    private func cacheLanguageOptions(from media: any AKPlayable) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let trackTypes: [AKTrackType] = [.audio, .audioDescription, .subtitle, .closedCaption]
                let groups = try await media.trackSelection.availableLanguageOptionGroups(for: trackTypes)
                let current = try await media.trackSelection.currentLanguageOptions(for: trackTypes)
                let domainTrackGroups = try await media.trackSelection.trackGroups(for: trackTypes)
                cachedAvailableLanguageOptionGroups = groups
                cachedCurrentLanguageOptions = current
                cachedTrackGroups = domainTrackGroups
                updateNowPlayingInfo()
            } catch {
                // keep previous cache
            }
        }
    }
    
    private func clearCachedLanguageOptions() {
        cachedCurrentLanguageOptions = nil
        cachedAvailableLanguageOptionGroups = nil
        cachedTrackGroups = nil
    }
    
    // MARK: - Default Remote Commands Setup
    
    private func setupDefaultRemoteCommands() async {
        let defaultConfig = AKNowPlayingCommandConfiguration()
            .add(.play)
            .add(.pause)
            .add(.stop)
            .add(.togglePlayPause)
            .add(.changePlaybackPosition)
            .add(.skipForward(preferredIntervals: [15]))
            .add(.skipBackward(preferredIntervals: [15]))
        
        await session.applyConfiguration(defaultConfig)
        
        await session.setHandler(for: .play) { @MainActor [weak playerManager] _ in
            guard let playerManager else { return .commandFailed }
            playerManager.play()
            return playerManager.state.isPlaying || playerManager.autoPlay ? .success : .commandFailed
        }
        
        await session.setHandler(for: .pause) { @MainActor [weak playerManager] _ in
            guard let playerManager else { return .commandFailed }
            playerManager.pause()
            return playerManager.state.isPaused ? .success : .commandFailed
        }
        
        await session.setHandler(for: .stop) { @MainActor [weak playerManager] _ in
            guard let playerManager else { return .commandFailed }
            playerManager.stop()
            return playerManager.state.isStopped ? .success : .commandFailed
        }
        
        await session.setHandler(for: .togglePlayPause) { @MainActor [weak playerManager] _ in
            guard let playerManager else { return .commandFailed }
            playerManager.togglePlayPause()
            return .success
        }
        
        await session.setHandler(for: .changePlaybackPosition) { @MainActor [weak playerManager] event in
            guard let playerManager,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            
            let targetTime = CMTime(seconds: positionEvent.positionTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            Task { @MainActor in
                await playerManager.seek(to: .time(targetTime))
            }
            return .success
        }
        
        await session.setHandler(
            for: .changePlaybackRate(
                supportedPlaybackRates: AKPlaybackRate
                    .allCases.map(\.rate)
            )
        ) { @MainActor [weak playerManager] event in
            guard let playerManager,
                  let currentMedia = playerManager.currentMedia,
                  let rateEvent = event as? MPChangePlaybackRateCommandEvent,
                  currentMedia.canPlay(at: AKPlaybackRate(rate: rateEvent.playbackRate))
            else {
                return .commandFailed
            }
            
            playerManager.play(at: AKPlaybackRate(rate: rateEvent.playbackRate))
            return .success
        }
        
        await session.setHandler(for: .seekForward) { @MainActor [weak playerManager] event in
            guard let playerManager,
                  let currentMedia = playerManager.currentMedia,
                  let seekEvent = event as? MPSeekCommandEvent,
                  currentMedia.canPlay(at: AKPlaybackRate.fastest)
            else {
                return .commandFailed
            }
            
            switch seekEvent.type {
            case .beginSeeking:
                playerManager.fastForward(at: .fastest)
            case .endSeeking:
                playerManager.play(at: .normal)
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        
        await session.setHandler(for: .seekBackward) { @MainActor [weak playerManager] event in
            guard let playerManager,
                  let currentMedia = playerManager.currentMedia,
                  let seekEvent = event as? MPSeekCommandEvent,
                  currentMedia.canPlay(at: AKPlaybackRate.slowest)
            else {
                return .commandFailed
            }
            
            switch seekEvent.type {
            case .beginSeeking:
                playerManager.rewind(at: .slowest)
            case .endSeeking:
                playerManager.play(at: .normal)
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        
        await session.setHandler(for: .skipForward(preferredIntervals: [15])) { @MainActor [weak playerManager] event in
            guard let playerManager,
                  let skipEvent = event as? MPSkipIntervalCommandEvent
            else { return .commandFailed }
            
            let targetSeconds = playerManager.currentTime.seconds + skipEvent.interval
            Task { @MainActor in
                await playerManager.seek(to: .seconds(targetSeconds))
            }
            return .success
        }
        
        await session.setHandler(for: .skipBackward(preferredIntervals: [15])) { @MainActor [weak playerManager] event in
            guard let playerManager,
                  let skipEvent = event as? MPSkipIntervalCommandEvent
            else { return .commandFailed }
            
            let targetSeconds = max(0, playerManager.currentTime.seconds - skipEvent.interval)
            Task { @MainActor in
                await playerManager.seek(to: .seconds(targetSeconds))
            }
            return .success
        }
        
        await session.setHandler(for: .nextTrack) { @MainActor [weak playerManager] _ in
            guard let queuePlayer = playerManager as? any AKQueuePlayerProtocol else { return .commandFailed }
            queuePlayer.next()
            return .success
        }
        
        await session.setHandler(for: .previousTrack) { @MainActor [weak playerManager] _ in
            guard let queuePlayer = playerManager as? any AKQueuePlayerProtocol else { return .commandFailed }
            queuePlayer.previous()
            return .success
        }
        
        await session.setHandler(for: .changeRepeatMode) { @MainActor [weak playerManager] event in
            guard let queuePlayer = playerManager as? any AKQueuePlayerProtocol,
                  let repeatEvent = event as? MPChangeRepeatModeCommandEvent
            else { return .commandFailed }
            
            switch repeatEvent.repeatType {
            case .off:
                queuePlayer.repeatMode = .off
            case .one:
                queuePlayer.repeatMode = .one
            case .all:
                queuePlayer.repeatMode = .all
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        
        await session.setHandler(for: .changeShuffleMode) { @MainActor [weak playerManager] event in
            guard let queuePlayer = playerManager as? any AKQueuePlayerProtocol,
                  let shuffleEvent = event as? MPChangeShuffleModeCommandEvent
            else { return .commandFailed }
            
            switch shuffleEvent.shuffleType {
            case .off:
                queuePlayer.isShuffleEnabled = false
            case .items, .collections:
                queuePlayer.isShuffleEnabled = true
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        
        await session.setHandler(for: .enableLanguageOption) { @MainActor [weak self] event in
            guard let self,
                  let playerManager = self.playerManager,
                  let media = playerManager.currentMedia,
                  let languageEvent = event as? MPChangeLanguageOptionCommandEvent
            else { return .commandFailed }
            
            return self.enable(languageOption: languageEvent.languageOption, on: media)
        }
        
        await session.setHandler(for: .disableLanguageOption) { @MainActor [weak self] event in
            guard let self,
                  let playerManager = self.playerManager,
                  let media = playerManager.currentMedia,
                  let languageEvent = event as? MPChangeLanguageOptionCommandEvent
            else { return .commandFailed }
            
            return self.disable(languageOption: languageEvent.languageOption, on: media)
        }
    }
    
    private func enable(
        languageOption: MPNowPlayingInfoLanguageOption,
        on media: any AKPlayable
    ) -> MPRemoteCommandHandlerStatus {
        let types: [AKTrackType] = languageOption.languageOptionType == .legible
            ? [.subtitle, .closedCaption]
            : [.audio, .audioDescription]
        
        guard let cachedTrackGroups else {
            return .noSuchContent
        }
        
        for type in types {
            guard let group = cachedTrackGroups.first(where: { $0.type == type }) else { continue }
            
            if let match = group.options.first(where: { trackOption in
                guard let avOption = trackOption.option else { return false }
                
                return avOption.extendedLanguageTag == languageOption.languageTag ||
                    avOption.displayName == languageOption.displayName
            }) {
                Task {
                    do {
                        try await media.trackSelection.select(match, for: type)
                    } catch {
                        AKLogger.error("Failed to select language track: \(error)", category: .media)
                    }
                }
                return .success
            }
        }
        
        return .noSuchContent
    }
    
    private func disable(
        languageOption: MPNowPlayingInfoLanguageOption,
        on media: any AKPlayable
    ) -> MPRemoteCommandHandlerStatus {
        let types: [AKTrackType] = languageOption.languageOptionType == .legible
            ? [.subtitle, .closedCaption]
            : [.audio]
        
        guard let cachedTrackGroups else {
            return .noSuchContent
        }
        
        for type in types {
            guard let group = cachedTrackGroups.first(where: { $0.type == type }) else { continue }
            
            guard group.allowsEmptySelection && (type == .subtitle || type == .closedCaption) else { continue }
            
            guard let selected = group.selectedOption,
                  let avOption = selected.option else {
                continue
            }
            
            let matches = avOption.extendedLanguageTag == languageOption.languageTag ||
                avOption.displayName == languageOption.displayName
            
            if matches {
                Task {
                    do {
                        try await media.trackSelection.select(nil, for: type)
                    } catch {
                        AKLogger.error("Failed to disable language track: \(error)", category: .remote)
                    }
                }
                return .success
            }
        }
        
        return .noSuchContent
    }
}
