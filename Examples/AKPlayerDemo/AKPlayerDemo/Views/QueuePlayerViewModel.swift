//
//   QueuePlayerViewModel.swift
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
public class QueuePlayerViewModel: NSObject, ObservableObject {
    public lazy var queuePlayer: AKQueuePlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let p = AKQueuePlayer(
            configuration: configuration,
            audioSessionService: audioSession
        )
        p.player.appliesMediaSelectionCriteriaAutomatically = true
        return p
    }()

    let audioSession = AKAudioSessionService()

    // Playback State
    @Published public var playlist: [TestMedia] = []
    @Published public var currentMedia: (any AKPlayable)?
    @Published public var currentIndex: Int? = nil
    private nonisolated(unsafe) var playerEventsTask: Task<Void, Never>?
    @Published public var stateDescription = "Idle"
    @Published public var isPlaying = false
    @Published public var isLoading = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var repeatMode: AKRepeatMode = .off
    @Published public var isShuffleEnabled = false
    @Published public var canPlayNext = false
    @Published public var canPlayPrevious = false

    override public init() {
        super.init()
        AKLogger.logInit(self)
        Task { @MainActor [weak self] in
            do {
                try await self?.queuePlayer.prepare()
            } catch {
                AKLogger.error("Failed to prepare queue player: \(error)", category: .player)
            }
        }
        observePlayerEvents()
    }

    private func observePlayerEvents() {
        playerEventsTask?.cancel()
        playerEventsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in self.queuePlayer.events {
                guard !Task.isCancelled else { break }
                self.handlePlayerEvent(event)
            }
        }
    }

    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
        playerEventsTask?.cancel()
    }

    private func updateQueueProperties() {
        currentIndex = queuePlayer.currentIndex
        currentMedia = queuePlayer.currentMedia
        repeatMode = queuePlayer.repeatMode
        isShuffleEnabled = queuePlayer.isShuffleEnabled
        canPlayNext = queuePlayer.canPlayNext
        canPlayPrevious = queuePlayer.canPlayPrevious
    }

    // MARK: - Media Loading

    public func loadQueue(with testMedias: [TestMedia], startIndex: Int = 0) {
        playlist = testMedias
        let akMedias = testMedias.compactMap { makeAKMedia(from: $0) }
        guard !akMedias.isEmpty else { return }

        queuePlayer.load(items: akMedias, startIndex: startIndex, autoPlay: true)
        Task { @MainActor [weak self] in
            await self?.queuePlayer.configureNowPlaying(with: AKNowPlayingCommandPresets.queue())
        }
        stateDescription = queuePlayer.state.description
        isLoading = queuePlayer.state.isAny(of: [.loading, .buffering, .waitingForNetwork])
        updateQueueProperties()
    }

    // MARK: - Playback Controls

    public func togglePlayPause() {
        queuePlayer.togglePlayPause()
        isPlaying = (queuePlayer.state == .playing)
    }

    public func next() {
        queuePlayer.next()
        updateQueueProperties()
    }

    public func previous() {
        queuePlayer.previous()
        updateQueueProperties()
    }

    public func jumpTo(index: Int) {
        queuePlayer.jumpTo(index: index)
        updateQueueProperties()
    }

    public func toggleRepeat() {
        switch queuePlayer.repeatMode {
        case .off:
            queuePlayer.repeatMode = .all
        case .all:
            queuePlayer.repeatMode = .one
        case .one:
            queuePlayer.repeatMode = .off
        }
        repeatMode = queuePlayer.repeatMode
        updateQueueProperties()
    }

    public func toggleShuffle() {
        queuePlayer.isShuffleEnabled.toggle()
        isShuffleEnabled = queuePlayer.isShuffleEnabled
        updateQueueProperties()
    }

    public func removeItem(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        playlist.remove(at: index)
        queuePlayer.remove(at: index)
        updateQueueProperties()
    }

    public func moveItem(from source: IndexSet, to destination: Int) {
        playlist.move(fromOffsets: source, toOffset: destination)
        if let first = source.first {
            queuePlayer.move(from: first, to: destination > first ? destination - 1 : destination)
        }
        updateQueueProperties()
    }

    public func seek(to seconds: Double) {
        Task {
            await queuePlayer.seek(to: .seconds(seconds))
        }
    }

    public func stop() {
        queuePlayer.stop()
    }
}

// MARK: - Player Events Handling

extension QueuePlayerViewModel {
    private func handlePlayerEvent(_ event: AKPlayerEvent) {
        switch event {
        case let .stateDidChange(state):
            self.stateDescription = state.description
            self.isPlaying = (state == .playing)
            self.isLoading = state.isAny(of: [.loading, .buffering, .waitingForNetwork])
            let intDur = queuePlayer.interstitialService.integratedTimelineDuration
            let dur = queuePlayer.currentItemDuration.seconds
            let effectiveDur = (intDur > 0) ? intDur : ((dur.isFinite && dur > 0) ? dur : 0)
            if effectiveDur > 0 {
                self.duration = effectiveDur
            }
            self.updateQueueProperties()

        case let .mediaDidChange(media):
            self.currentMedia = media
            let intTime = queuePlayer.interstitialService.integratedTimelineCurrentTime
            self.currentTime = (intTime > 0) ? intTime : queuePlayer.currentTime.seconds
            let intDur = queuePlayer.interstitialService.integratedTimelineDuration
            let dur = queuePlayer.currentItemDuration.seconds
            let effectiveDur = (intDur > 0) ? intDur : ((dur.isFinite && dur > 0) ? dur : 0)
            self.duration = effectiveDur
            self.updateQueueProperties()

        case let .timeDidChange(currentTime):
            let intTime = queuePlayer.interstitialService.integratedTimelineCurrentTime
            if intTime > 0 {
                self.currentTime = intTime
            } else {
                self.currentTime = currentTime.seconds
            }
            let intDur = queuePlayer.interstitialService.integratedTimelineDuration
            let dur = queuePlayer.currentItemDuration.seconds
            let effectiveDur = (intDur > 0) ? intDur : ((dur.isFinite && dur > 0) ? dur : 0)
            if effectiveDur > 0, self.duration != effectiveDur {
                self.duration = effectiveDur
            }

        case .didReachEnd:
            self.updateQueueProperties()

        case .playbackRateDidChange, .boundaryReached, .volumeDidChange, .muteStatusDidChange,
             .sharePlayStateDidChange, .commandUnavailable, .didFail, .interstitial, .media,
             .trackSelection, .playerItemNotification, .metadata, .chapter:
            break
        }
    }
}
