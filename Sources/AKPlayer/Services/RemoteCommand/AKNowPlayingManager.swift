//
//   AKNowPlayingManager.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import MediaPlayer

extension MPNowPlayingInfoLanguageOptionGroup: @retroactive @unchecked Sendable {}
extension MPNowPlayingInfoLanguageOption: @retroactive @unchecked Sendable {}

// MARK: - Queue Metadata Provider

/// Optional interface allowing players (such as AKQueuePlayer) to supply queue index and count
/// info.
@MainActor
public protocol AKNowPlayingQueueInfoProvider: AnyObject, Sendable {
    /// Total count of items in the active playback queue.
    var queueCount: Int { get }
    /// Zero-based index of the currently playing item in the queue.
    var currentQueueIndex: Int? { get }
}

// MARK: - AKNowPlayingManagerProtocol

/// Protocol defining high-level Now Playing and Remote Command management.
@MainActor
public protocol AKNowPlayingManagerProtocol: AnyObject, Sendable {
    // MARK: - Properties

    /// The underlying low-level session managing MPRemoteCommandCenter and MPNowPlayingInfoCenter.
    var session: any AKNowPlayingSessionProtocol { get }

    /// Optional provider for queue metadata (such as AKQueuePlayer).
    var queueInfoProvider: (any AKNowPlayingQueueInfoProvider)? { get set }

    /// Optional service identifier for now playing info
    /// (MPNowPlayingInfoPropertyServiceIdentifier).
    var serviceIdentifier: String? { get set }

    /// The active remote command configuration.
    var commandConfiguration: AKNowPlayingCommandConfiguration { get set }

    // MARK: - Lifecycle & Updates

    /// Starts event observation loops and configures remote command handlers.
    func start() async throws

    /// Stops event observation loops, cancels background tasks, and resets Now Playing metadata.
    func stop()

    /// Forces an explicit update of the current Now Playing metadata payload.
    func updateNowPlayingInfo()

    // MARK: - Command Configuration & Handlers

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

    // MARK: - Metadata Inspection

    /// Retrieves the current static and dynamic metadata container.
    func currentNowPlayingMetadata() -> AKNowPlayableMetadata?

    /// Generates current dynamic state metadata (position, rate, duration, language options,
    /// queue).
    func getNowPlayableDynamicMetadata() -> (any AKNowPlayableDynamicMetadataProtocol)?
}

// MARK: - AKNowPlayingManager

/// High-level manager coordinating MPNowPlayingInfoCenter updates and MPRemoteCommandCenter actions
/// with player state.
@MainActor
public final class AKNowPlayingManager: AKNowPlayingManagerProtocol {
    // MARK: - Properties

    /// The underlying low-level session managing MPRemoteCommandCenter and MPNowPlayingInfoCenter.
    public let session: any AKNowPlayingSessionProtocol
    /// Optional provider for queue metadata (such as AKQueuePlayer).
    public weak var queueInfoProvider: (any AKNowPlayingQueueInfoProvider)?
    /// Optional service identifier for now playing info
    /// (MPNowPlayingInfoPropertyServiceIdentifier).
    public var serviceIdentifier: String?
    /// The active remote command configuration.
    public var commandConfiguration = AKNowPlayingCommandConfiguration()

    /// Weak reference to the parent player manager.
    private weak var playerManager: (any AKPlayerManagerProtocol)?

    /// Active task observing player manager events.
    private var playerObservationTask: Task<Void, Never>?
    /// Active task observing current playable media events.
    private var mediaObservationTask: Task<Void, Never>?
    /// Active task observing metadata provider static metadata updates.
    private var metadataObservationTask: Task<Void, Never>?
    /// Active task observing chapter service updates.
    private var chaptersObservationTask: Task<Void, Never>?

    /// Cached currently active language options for Now Playing info.
    private var cachedCurrentLanguageOptions: [MPNowPlayingInfoLanguageOption]?
    /// Cached available language option groups for Now Playing info.
    private var cachedAvailableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]?
    /// Cached media track groups extracted from the active playable item.
    private var cachedTrackGroups: [AKMediaTrackGroup]?

    // MARK: - Init & Deinit

    /// Initializes a new Now Playing manager.
    /// - Parameters:
    ///   - playerManager: The parent player manager instance.
    ///   - session: Optional custom Now Playing session to use.
    public init(
        playerManager: any AKPlayerManagerProtocol,
        session: (any AKNowPlayingSessionProtocol)? = nil
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.playerManager = playerManager
        self
            .session = session ??
            AKNowPlayingSession(players: [playerManager.playerController.player])
    }

    deinit {
        playerObservationTask?.cancel()
        playerObservationTask = nil
        mediaObservationTask?.cancel()
        mediaObservationTask = nil
        metadataObservationTask?.cancel()
        metadataObservationTask = nil
        chaptersObservationTask?.cancel()
        chaptersObservationTask = nil
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - Lifecycle & Updates

    /// Starts event observation loops and configures remote command handlers.
    public func start() async throws {
        stop()

        guard let playerManager, playerManager.configuration.isNowPlayingEnabled else { return }

        if !session.isActive {
            guard session.canBecomeActive() else {
                throw AKPlayerError.nowPlayingSessionFailure
            }
            let active = await session.becomeActiveIfPossible()
            guard active else {
                AKLogger.error("Failed to activate Now Playing session.", category: .remote)
                throw AKPlayerError.nowPlayingSessionFailure
            }
        }

        await setupDefaultRemoteCommands()
        observePlayerEvents()
    }

    /// Stops event observation loops, cancels background tasks, and resets Now Playing metadata.
    public func stop() {
        playerObservationTask?.cancel()
        playerObservationTask = nil
        mediaObservationTask?.cancel()
        mediaObservationTask = nil
        metadataObservationTask?.cancel()
        metadataObservationTask = nil
        chaptersObservationTask?.cancel()
        chaptersObservationTask = nil

        clearCachedLanguageOptions()
        session.clearNowPlayingPlaybackInfo()
        session.unregisterAll()
    }

    /// Forces an explicit update of the current Now Playing metadata payload.
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

    // MARK: - Command Configuration & Handlers

    /// Applies a remote command configuration preset or custom configuration.
    /// - Parameter config: The new command configuration to apply.
    public func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async {
        commandConfiguration = config
        await session.applyConfiguration(config)
    }

    /// Sets a custom action handler for a specific remote command.
    /// - Parameters:
    ///   - command: The remote command to handle.
    ///   - handler: Closure invoked when the system remote command triggers.
    public func setHandler(
        for command: AKRemoteCommand,
        handler: @escaping AKRemoteCommandHandler
    ) async {
        await session.setHandler(for: command, handler: handler)
    }

    /// Removes a custom action handler for a specific remote command.
    /// - Parameter command: The remote command to unregister.
    public func removeHandler(for command: AKRemoteCommand) async {
        await session.removeHandler(for: command)
    }

    /// Enables specified commands on the remote command center.
    /// - Parameter commands: The list of commands to enable.
    public func enable(commands: [AKRemoteCommand]) async {
        await session.enable(commands: commands)
    }

    /// Disables specified commands on the remote command center.
    /// - Parameter commands: The list of commands to disable.
    public func disable(commands: [AKRemoteCommand]) async {
        await session.disable(commands: commands)
    }

    // MARK: - Metadata Inspection

    /// Retrieves the current static and dynamic metadata container.
    /// - Returns: An `AKNowPlayableMetadata` instance or `nil`.
    public func currentNowPlayingMetadata() -> AKNowPlayableMetadata? {
        guard let currentMedia = playerManager?.currentMedia else { return nil }

        let chapterService = currentMedia.chapterService
        let totalChapters = chapterService.chapterCount > 0 ? chapterService.chapterCount : nil
        let resolvedCreditsStartTime: Double? = currentMedia.staticMetadata?
            .creditsStartTime ?? chapterService.creditsStartTime

        let extracted = currentMedia.metadataProvider.staticMetadata
        let custom = currentMedia.staticMetadata

        // Artwork resolution: custom -> extracted (image or MPMediaItemArtwork)
        let resolvedArtwork: Artwork? = {
            if let customArtwork = custom?.artwork {
                return customArtwork
            }
            if let image = extracted.artworkImage {
                return .image(image)
            }
            if let artwork = extracted.artwork {
                return .artwork(artwork)
            }
            return nil
        }()

        // Dynamic media type detection: Video if visual tracks/presentationSize exist, else Audio
        let defaultMediaType: MPNowPlayingInfoMediaType = {
            if let item = playerManager?.currentItem {
                if item.presentationSize != .zero, item.presentationSize.width > 0 {
                    return .video
                }
                if !item.asset.tracks(withMediaType: .video).isEmpty {
                    return .video
                }
            } else if let asset = currentMedia.asset {
                if !asset.tracks(withMediaType: .video).isEmpty {
                    return .video
                }
            }
            return .audio
        }()

        let staticMetadata = AKNowPlayableStaticMetadata(
            assetURL: custom?.assetURL ?? currentMedia.url,
            mediaType: custom?.mediaType ?? defaultMediaType,
            isLiveStream: custom?.isLiveStream ?? currentMedia.isLive(),
            title: custom?.title ?? extracted.title ?? "Unknown Title",
            artist: custom?.artist ?? extracted.artist,
            artwork: resolvedArtwork,
            albumArtist: custom?.albumArtist ?? extracted.albumArtist,
            albumTitle: custom?.albumTitle ?? extracted.albumTitle,
            collectionIdentifier: custom?.collectionIdentifier,
            externalContentIdentifier: custom?.externalContentIdentifier,
            externalUserProfileIdentifier: custom?.externalUserProfileIdentifier,
            chapterCount: custom?.chapterCount ?? totalChapters,
            creditsStartTime: resolvedCreditsStartTime,
            serviceIdentifier: custom?.serviceIdentifier ?? serviceIdentifier,
            adTimeRanges: custom?.adTimeRanges,
            genre: custom?.genre ?? extracted.genre,
            composer: custom?.composer ?? extracted.composer,
            trackNumber: custom?.trackNumber ?? extracted.trackNumber,
            trackCount: custom?.trackCount ?? extracted.trackCount,
            discNumber: custom?.discNumber ?? extracted.discNumber,
            discCount: custom?.discCount ?? extracted.discCount,
            isExplicit: custom?.isExplicit,
            releaseDate: custom?.releaseDate ?? extracted.releaseDate,
            descriptionText: custom?.descriptionText ?? extracted.descriptionText
        )

        return AKNowPlayableMetadata(
            staticMetadata: staticMetadata,
            dynamicMetadata: getNowPlayableDynamicMetadata()
        )
    }

    /// Generates current dynamic state metadata (position, rate, duration, language options,
    /// queue).
    /// - Returns: A dynamic metadata container or `nil`.
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

        let chapterService = currentMedia.chapterService
        let currentTime = playerManager.currentItem?.currentTime() ?? .zero
        let currentChapterNum = currentTime.isValid ? chapterService
            .currentChapterNumber(at: currentTime) : nil

        let queueProvider = queueInfoProvider ??
            (playerManager as? (any AKNowPlayingQueueInfoProvider))
        let queueCount = queueProvider?.queueCount
        let queueIndex = queueProvider?.currentQueueIndex

        return AKNowPlayableDynamicMetadata(
            rate: Double(playerManager.rate.rate),
            defaultRate: Double(playerManager.defaultRate.rate),
            position: position,
            duration: duration,
            currentLanguageOptions: cachedCurrentLanguageOptions,
            availableLanguageOptionGroups: cachedAvailableLanguageOptionGroups,
            chapterNumber: currentChapterNum,
            currentPlaybackDate: playerManager.currentItem?.currentDate(),
            playbackProgress: playbackProgress,
            playbackQueueCount: queueCount,
            playbackQueueIndex: queueIndex
        )
    }

    // MARK: - Private Event Observation

    /// Starts the background task monitoring high-level player lifecycle events.
    private func observePlayerEvents() {
        playerObservationTask?.cancel()

        playerObservationTask = Task { @MainActor [weak self, weak playerManager] in
            guard let events = playerManager?.events else { return }

            for await event in events {
                guard !Task.isCancelled, let self else { break }

                switch event {
                case let .mediaDidChange(newMedia):
                    clearCachedLanguageOptions()
                    observeMediaEvents(for: newMedia)
                    updateNowPlayingInfo()

                case .stateDidChange, .playbackRateDidChange, .timeDidChange:
                    updateNowPlayingInfo()

                default:
                    break
                }
            }
        }
    }

    /// Sets up background observation for media events, metadata updates, and chapter changes.
    /// - Parameter media: The active `AKPlayable` instance to monitor.
    private func observeMediaEvents(for media: any AKPlayable) {
        mediaObservationTask?.cancel()
        metadataObservationTask?.cancel()
        chaptersObservationTask?.cancel()

        mediaObservationTask = Task { @MainActor [weak self, weak media] in
            guard let stream = media?.events else { return }

            for await event in stream {
                guard !Task.isCancelled, let self, let media else { break }

                switch event {
                case let .stateDidChange(state) where state == .readyToPlay:
                    cacheLanguageOptions(from: media)
                    updateNowPlayingInfo()

                case .tracksDidChange:
                    if media.state == .readyToPlay {
                        cacheLanguageOptions(from: media)
                        updateNowPlayingInfo()
                    }

                default:
                    break
                }
            }
        }

        metadataObservationTask = Task { @MainActor [weak self, weak media] in
            guard let stream = media?.metadataProvider.staticMetadataUpdates else { return }
            for await _ in stream {
                guard !Task.isCancelled, let self else { break }
                updateNowPlayingInfo()
            }
        }

        chaptersObservationTask = Task { @MainActor [weak self, weak media] in
            guard let stream = media?.chapterService.chaptersUpdates else { return }
            for await _ in stream {
                guard !Task.isCancelled, let self else { break }
                updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Private Language Options Caching

    /// Loads and caches language option groups and current selections for the given media item.
    /// - Parameter media: The playable media item to inspect.
    private func cacheLanguageOptions(from media: any AKPlayable) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let trackTypes: [AKTrackType] = [
                    .audio,
                    .audioDescription,
                    .subtitle,
                    .closedCaption,
                ]
                let groups = try await media.trackSelection
                    .availableLanguageOptionGroups(for: trackTypes)
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

    /// Clears cached language options when media item transitions.
    private func clearCachedLanguageOptions() {
        cachedCurrentLanguageOptions = nil
        cachedAvailableLanguageOptionGroups = nil
        cachedTrackGroups = nil
    }

    // MARK: - Private Remote Commands Setup

    /// Configures default remote command handlers on the underlying Now Playing session.
    private func setupDefaultRemoteCommands() async {
        if commandConfiguration.isEmpty {
            commandConfiguration = AKNowPlayingCommandConfiguration()
                .add(.play)
                .add(.pause)
                .add(.stop)
                .add(.togglePlayPause)
                .add(.changePlaybackPosition)
                .add(.skipForward(preferredIntervals: [15]))
                .add(.skipBackward(preferredIntervals: [15]))
        }

        await session.applyConfiguration(commandConfiguration)

        await session.setHandler(for: .play) { @MainActor [weak playerManager] _ in
            guard let playerManager else { return .commandFailed }
            playerManager.play()
            return playerManager.state.isPlaying || playerManager
                .autoPlay ? .success : .commandFailed
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

        await session
            .setHandler(for: .changePlaybackPosition) { @MainActor [weak playerManager] event in
                guard let playerManager,
                      let positionEvent = event as? MPChangePlaybackPositionCommandEvent
                else { return .commandFailed }

                let targetTime = CMTime(
                    seconds: positionEvent.positionTime,
                    preferredTimescale: CMTimeScale(NSEC_PER_SEC)
                )
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

        await session
            .setHandler(for: .skipForward(
                preferredIntervals: [15]
            )) { @MainActor [weak playerManager] event in
                guard let playerManager,
                      let skipEvent = event as? MPSkipIntervalCommandEvent
                else { return .commandFailed }

                let targetSeconds = playerManager.currentTime.seconds + skipEvent.interval
                Task { @MainActor in
                    await playerManager.seek(to: .seconds(targetSeconds))
                }
                return .success
            }

        await session
            .setHandler(for: .skipBackward(
                preferredIntervals: [15]
            )) { @MainActor [weak playerManager] event in
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
            guard let queuePlayer = playerManager as? any AKQueuePlayerProtocol
            else { return .commandFailed }
            queuePlayer.next()
            return .success
        }

        await session.setHandler(for: .previousTrack) { @MainActor [weak playerManager] _ in
            guard let queuePlayer = playerManager as? any AKQueuePlayerProtocol
            else { return .commandFailed }
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
                  let playerManager,
                  let media = playerManager.currentMedia,
                  let languageEvent = event as? MPChangeLanguageOptionCommandEvent
            else { return .commandFailed }

            return enable(languageOption: languageEvent.languageOption, on: media)
        }

        await session.setHandler(for: .disableLanguageOption) { @MainActor [weak self] event in
            guard let self,
                  let playerManager,
                  let media = playerManager.currentMedia,
                  let languageEvent = event as? MPChangeLanguageOptionCommandEvent
            else { return .commandFailed }

            return disable(languageOption: languageEvent.languageOption, on: media)
        }
    }

    /// Handles remote commands to enable a specific language option.
    /// - Parameters:
    ///   - languageOption: The language option requested by the remote command event.
    ///   - media: The active media item on which to select the option.
    /// - Returns: An `MPRemoteCommandHandlerStatus` indicating outcome.
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
                        AKLogger.error(
                            "Failed to select language track: \(error)",
                            category: .media
                        )
                    }
                }
                return .success
            }
        }

        return .noSuchContent
    }

    /// Handles remote commands to disable a specific language option.
    /// - Parameters:
    ///   - languageOption: The language option requested to disable.
    ///   - media: The active media item on which to disable the option.
    /// - Returns: An `MPRemoteCommandHandlerStatus` indicating outcome.
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

            guard group.allowsEmptySelection,
                  type == .subtitle || type == .closedCaption else { continue }

            guard let selected = group.selectedOption,
                  let avOption = selected.option
            else {
                continue
            }

            let matches = avOption.extendedLanguageTag == languageOption.languageTag ||
                avOption.displayName == languageOption.displayName

            if matches {
                Task {
                    do {
                        try await media.trackSelection.select(nil, for: type)
                    } catch {
                        AKLogger.error(
                            "Failed to disable language track: \(error)",
                            category: .remote
                        )
                    }
                }
                return .success
            }
        }

        return .noSuchContent
    }
}
