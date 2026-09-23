//
//   IPTVPlayerViewModel.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
public final class IPTVPlayerViewModel: NSObject, ObservableObject {
    // MARK: - Player Instance

    public lazy var player: AKPlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let p = AKPlayer(configuration: configuration, audioSessionService: audioSession)
        p.player.appliesMediaSelectionCriteriaAutomatically = true
        p.delegate = self
        return p
    }()

    static let session = AVAudioSession.sharedInstance()
    let audioSession = AKAudioSessionService(audioSession: session)

    // MARK: - Channel Catalog State

    @Published public var presets: [IPTVPlaylistPreset] = IPTVPlaylistPreset.curatedPresets
    @Published public var selectedPreset = IPTVPlaylistPreset.curatedPresets[0]
    @Published public var selectedCategory: IPTVCategory = .all
    @Published public var searchQuery = ""

    @Published public var channels: [IPTVChannel] = []
    @Published public var isLoadingChannels = false
    @Published public var channelLoadError: String?

    // Custom M3U URL Input
    @Published public var customM3UURLString = ""
    @Published public var isCustomURLEnabled = false

    // MARK: - Playback State

    @Published public var currentChannel: IPTVChannel?
    @Published public var stateDescription = "Idle"
    @Published public var isPlaying = false
    @Published public var isBuffering = false
    @Published public var isAtLiveEdge = true
    @Published public var playbackError: String?
    @Published public var volume: Float = 1.0
    @Published public var isMuted = false
    @Published public var videoGravity: AVLayerVideoGravity = .resizeAspect

    // PiP
    @Published public var isPipPossible = false
    @Published public var isPipActive = false
    public private(set) var pipController: AKPictureInPictureController?

    // Async task references
    private nonisolated(unsafe) var loadChannelsTask: Task<Void, Never>?
    private nonisolated(unsafe) var pipEventsTask: Task<Void, Never>?

    // MARK: - Filtered Channels

    public var filteredChannels: [IPTVChannel] {
        var result = channels

        // 1. Category Filter
        if selectedCategory != .all {
            result = result.filter { channel in
                channel.groupTitle.localizedCaseInsensitiveContains(selectedCategory.rawValue) ||
                    channel.name.localizedCaseInsensitiveContains(selectedCategory.rawValue)
            }
        }

        // 2. Search Filter
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { channel in
                channel.name.localizedCaseInsensitiveContains(query) ||
                    channel.groupTitle.localizedCaseInsensitiveContains(query) ||
                    (channel.country?.localizedCaseInsensitiveContains(query) ?? false) ||
                    (channel.language?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        return result
    }

    // MARK: - Initialization

    override public init() {
        super.init()
        AKLogger.logInit(self)
        Task { @MainActor [weak self] in
            do {
                try await self?.player.prepare()
            } catch {
                AKLogger.error("Failed to prepare IPTV player: \(error)", category: .player)
            }
        }
        loadChannels(for: selectedPreset)
    }

    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
        loadChannelsTask?.cancel()
        pipEventsTask?.cancel()
    }

    // MARK: - Channel Fetching

    public func loadChannels(for preset: IPTVPlaylistPreset) {
        selectedPreset = preset
        isCustomURLEnabled = false
        fetchChannels(from: preset.url)
    }

    public func loadChannels(for category: IPTVCategory) {
        selectedCategory = category
        if let url = category.playlistURL {
            fetchChannels(from: url)
        }
    }

    public func loadCustomPlaylist() {
        guard let url = URL(string: customM3UURLString
            .trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            channelLoadError = "Invalid URL format"
            return
        }
        isCustomURLEnabled = true
        fetchChannels(from: url)
    }

    private func fetchChannels(from url: URL) {
        loadChannelsTask?.cancel()
        isLoadingChannels = true
        channelLoadError = nil

        loadChannelsTask = Task { [weak self] in
            do {
                let fetched = try await IPTVService.shared.fetchChannels(from: url)
                guard !Task.isCancelled, let self else { return }
                self.channels = fetched
                self.isLoadingChannels = false
                if fetched.isEmpty {
                    self.channelLoadError = "No channels found in this playlist."
                }
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.isLoadingChannels = false
                self.channelLoadError = "Failed to load playlist: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Playback Controls

    public func playChannel(_ channel: IPTVChannel) {
        currentChannel = channel
        playbackError = nil
        let media = channel.toAKMedia()
        player.load(media: media, autoPlay: true)
    }

    public func togglePlayPause() {
        player.togglePlayPause()
    }

    public func stop() {
        player.stop()
        currentChannel = nil
        isPlaying = false
        isBuffering = false
    }

    public func jumpToLive() {
        Task {
            await player.jumpToLive()
        }
    }

    public func playNextChannel() {
        let currentList = filteredChannels
        guard !currentList.isEmpty else { return }
        guard let current = currentChannel,
              let currentIndex = currentList.firstIndex(of: current)
        else {
            if let first = currentList.first {
                playChannel(first)
            }
            return
        }

        let nextIndex = (currentIndex + 1) % currentList.count
        playChannel(currentList[nextIndex])
    }

    public func playPreviousChannel() {
        let currentList = filteredChannels
        guard !currentList.isEmpty else { return }
        guard let current = currentChannel,
              let currentIndex = currentList.firstIndex(of: current)
        else {
            if let last = currentList.last {
                playChannel(last)
            }
            return
        }

        let prevIndex = (currentIndex - 1 + currentList.count) % currentList.count
        playChannel(currentList[prevIndex])
    }

    public func setVolume(_ v: Float) {
        player.volume = v
        volume = v
    }

    public func toggleMute() {
        player.isMuted.toggle()
        isMuted = player.isMuted
    }

    public func toggleVideoGravity() {
        switch videoGravity {
        case .resizeAspect:
            videoGravity = .resizeAspectFill
        case .resizeAspectFill:
            videoGravity = .resize
        default:
            videoGravity = .resizeAspect
        }
    }

    // MARK: - Picture in Picture Setup

    public func setupPip(with playerLayer: AVPlayerLayer) {
        guard pipController == nil else { return }
        guard let controller = AKPictureInPictureController(playerLayer: playerLayer)
        else { return }
        controller.delegate = self
        controller.canStartAutomatically = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            pipController = controller
            isPipPossible = controller.isPictureInPicturePossible
        }

        pipEventsTask?.cancel()
        pipEventsTask = Task { [weak self] in
            for await event in controller.events {
                guard !Task.isCancelled, let self else { break }
                switch event {
                case .willStart:
                    break
                case .didStart:
                    isPipActive = true
                case .failedToStart:
                    isPipActive = false
                case .willStop:
                    break
                case .didStop:
                    isPipActive = false
                case .restoreUserInterface:
                    break
                }
            }
        }
    }

    public func togglePip() {
        pipController?.toggle()
    }
}

// MARK: - AKPlayerDelegate

extension IPTVPlayerViewModel: AKPlayerDelegate {
    public nonisolated func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        DispatchQueue.main.async {
            self.stateDescription = state.description
            switch state {
            case .idle:
                self.isPlaying = false
                self.isBuffering = false
            case .loading:
                self.isBuffering = true
            case .loaded:
                self.isBuffering = false
            case .buffering:
                self.isBuffering = true
            case .playing:
                self.isPlaying = true
                self.isBuffering = false
                self.playbackError = nil
            case .paused:
                self.isPlaying = false
                self.isBuffering = false
            case .stopped:
                self.isPlaying = false
                self.isBuffering = false
            case .waitingForNetwork:
                self.isBuffering = true
            case .failed:
                self.isPlaying = false
                self.isBuffering = false
                self.playbackError = player.error?.errorDescription ?? "Stream failed to load"
            }
        }
    }

    public nonisolated func akPlayer(_: AKPlayer, didChangeMediaTo media: (any AKPlayable)?) {
        DispatchQueue.main.async {
            if media == nil {
                self.currentChannel = nil
            }
        }
    }

    public nonisolated func akPlayer(
        _: AKPlayer,
        didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason
    ) {
        DispatchQueue.main.async {
            AKLogger.warning("IPTV command unavailable: \(reason.description)", category: .player)
        }
    }

    public nonisolated func akPlayer(_: AKPlayer, didFailWith error: AKPlayerError) {
        DispatchQueue.main.async {
            self.playbackError = "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - AKPictureInPictureDelegate

extension IPTVPlayerViewModel: AKPictureInPictureDelegate {
    public func pictureInPicture(
        _: AKPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWith completionHandler: @escaping @Sendable (
            Bool
        )
            -> Void
    ) {
        completionHandler(true)
    }
}
