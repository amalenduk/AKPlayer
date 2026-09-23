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
        p.delegate = self
        return p
    }()

    static let session = AVAudioSession.sharedInstance()
    let audioSession = AKAudioSessionService(audioSession: session)

    // Playback State
    @Published public var playlist: [TestMedia] = []
    @Published public var currentMedia: (any AKPlayable)?
    @Published public var currentIndex: Int? = nil
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
    }

    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
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

// MARK: - AKPlayerDelegate

extension QueuePlayerViewModel: AKPlayerDelegate {
    public nonisolated func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        DispatchQueue.main.async {
            self.stateDescription = state.description
            self.isPlaying = (state == .playing)
            self.isLoading = state.isAny(of: [.loading, .buffering, .waitingForNetwork])
            let intDur = player.interstitialService.integratedTimelineDuration
            let dur = player.currentItemDuration.seconds
            let effectiveDur = (intDur > 0) ? intDur : ((dur.isFinite && dur > 0) ? dur : 0)
            if effectiveDur > 0 {
                self.duration = effectiveDur
            }
            self.updateQueueProperties()
        }
    }

    public nonisolated func akPlayer(_ player: AKPlayer, didChangeMediaTo media: any AKPlayable) {
        DispatchQueue.main.async {
            self.currentMedia = media
            let intTime = player.interstitialService.integratedTimelineCurrentTime
            self.currentTime = (intTime > 0) ? intTime : player.currentTime.seconds
            let intDur = player.interstitialService.integratedTimelineDuration
            let dur = player.currentItemDuration.seconds
            let effectiveDur = (intDur > 0) ? intDur : ((dur.isFinite && dur > 0) ? dur : 0)
            self.duration = effectiveDur
            self.updateQueueProperties()
        }
    }

    public nonisolated func akPlayer(
        _ player: AKPlayer,
        didChangeCurrentTimeTo currentTime: CMTime,
        for _: any AKPlayable
    ) {
        DispatchQueue.main.async {
            let intTime = player.interstitialService.integratedTimelineCurrentTime
            if intTime > 0 {
                self.currentTime = intTime
            } else {
                self.currentTime = currentTime.seconds
            }
            let intDur = player.interstitialService.integratedTimelineDuration
            let dur = player.currentItemDuration.seconds
            let effectiveDur = (intDur > 0) ? intDur : ((dur.isFinite && dur > 0) ? dur : 0)
            if effectiveDur > 0, self.duration != effectiveDur {
                self.duration = effectiveDur
            }
        }
    }

    public nonisolated func akPlayer(
        _: AKPlayer,
        didChangePlaybackRateTo _: AKPlaybackRate,
        from _: AKPlaybackRate
    ) {}
    public nonisolated func akPlayer(
        _: AKPlayer,
        didInvokeBoundaryTimeObserverAt _: CMTime,
        for _: any AKPlayable
    ) {}

    public nonisolated func akPlayer(_: AKPlayer, didReachEndAt _: CMTime, for _: any AKPlayable) {
        DispatchQueue.main.async {
            self.updateQueueProperties()
        }
    }

    public nonisolated func akPlayer(
        _: AKPlayer,
        didEncounterUnavailableAction _: AKPlayerUnavailableCommandReason
    ) {}
    public nonisolated func akPlayer(_: AKPlayer, didFailWith _: AKPlayerError) {}
    public nonisolated func akPlayer(_: AKPlayer, didChangeVolumeTo _: Float) {}
    public nonisolated func akPlayer(_: AKPlayer, didChangeMutedStatusTo _: Bool) {}
}
