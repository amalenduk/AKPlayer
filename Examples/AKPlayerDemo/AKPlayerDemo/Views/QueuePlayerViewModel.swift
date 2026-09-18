//
//  QueuePlayerViewModel.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 02/09/26.
//

import SwiftUI
import AKPlayer
import AVFoundation
import Combine
import Foundation

@MainActor
public class QueuePlayerViewModel: NSObject, ObservableObject {
    public let avPlayer = AVPlayer()
    
    public lazy var queuePlayer: AKQueuePlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let p = AKQueuePlayer(
            player: avPlayer,
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
    @Published public var stateDescription: String = "Idle"
    @Published public var isPlaying: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var repeatMode: AKRepeatMode = .off
    @Published public var isShuffleEnabled: Bool = false
    @Published public var canPlayNext: Bool = false
    @Published public var canPlayPrevious: Bool = false
    
    private nonisolated(unsafe) var timeObserverToken: Any?
    private nonisolated(unsafe) var queueSyncTask: Task<Void, Never>?
    
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
        startSyncingQueueState()
    }
    
    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
        }
        queueSyncTask?.cancel()
    }
    
    // MARK: - Queue State Sync
    
    private func startSyncingQueueState() {
        queueSyncTask?.cancel()
        queueSyncTask = Task { [weak self] in
            guard let self else { return }
            for await event in queuePlayer.events {
                guard !Task.isCancelled else { break }
                switch event {
                case .stateDidChange(let state):
                    await MainActor.run {
                        self.stateDescription = state.description
                        self.isPlaying = (state == .playing)
                        self.isLoading = state.isAny(of: [.loading, .buffering, .waitingForNetwork])
                        self.updateQueueProperties()
                    }
                case .mediaDidChange(let media):
                    await MainActor.run {
                        self.currentMedia = media
                        self.updateQueueProperties()
                    }
                case .didReachEnd:
                    await MainActor.run {
                        self.updateQueueProperties()
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func updateQueueProperties() {
        self.currentIndex = queuePlayer.currentIndex
        self.currentMedia = queuePlayer.currentMedia
        self.repeatMode = queuePlayer.repeatMode
        self.isShuffleEnabled = queuePlayer.isShuffleEnabled
        self.canPlayNext = queuePlayer.canPlayNext
        self.canPlayPrevious = queuePlayer.canPlayPrevious
    }
    
    // MARK: - Media Loading
    
    public func loadQueue(with testMedias: [TestMedia], startIndex: Int = 0) {
        self.playlist = testMedias
        let akMedias = testMedias.compactMap { makeAKMedia(from: $0) }
        guard !akMedias.isEmpty else { return }
        
        queuePlayer.load(items: akMedias, startIndex: startIndex, autoPlay: true)
        Task { @MainActor [weak self] in
            await self?.queuePlayer.configureNowPlaying(with: AKNowPlayingCommandPresets.queue())
        }
        self.stateDescription = queuePlayer.state.description
        self.isLoading = queuePlayer.state.isAny(of: [.loading, .buffering, .waitingForNetwork])
        updateQueueProperties()
        loadAndObserveCurrentTime()
    }
    
    // MARK: - Playback Controls
    
    public func togglePlayPause() {
        queuePlayer.togglePlayPause()
        self.isPlaying = (queuePlayer.state == .playing)
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
        self.repeatMode = queuePlayer.repeatMode
        updateQueueProperties()
    }
    
    public func toggleShuffle() {
        queuePlayer.isShuffleEnabled.toggle()
        self.isShuffleEnabled = queuePlayer.isShuffleEnabled
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
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
        queueSyncTask?.cancel()
        queueSyncTask = nil
    }
    
    // MARK: - Time Observation
    
    public func loadAndObserveCurrentTime() {
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                if let dur = self.queuePlayer.currentItem?.duration.seconds, dur.isFinite {
                    self.duration = dur
                }
            }
        }
    }
}

// MARK: - AKPlayerDelegate

extension QueuePlayerViewModel: AKPlayerDelegate {
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        DispatchQueue.main.async {
            self.stateDescription = state.description
            self.isPlaying = (state == .playing)
            self.isLoading = state.isAny(of: [.loading, .buffering, .waitingForNetwork])
            self.updateQueueProperties()
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeCurrentTimeTo currentTime: CMTime, for media: any AKPlayable) {
        DispatchQueue.main.async {
            self.currentTime = currentTime.seconds
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangePlaybackRateTo newRate: AKPlaybackRate, from oldRate: AKPlaybackRate) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didInvokeBoundaryTimeObserverAt time: CMTime, for media: any AKPlayable) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didReachEndAt time: CMTime, for media: any AKPlayable) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didFailWith error: AKPlayerError) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeVolumeTo volume: Float) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeMutedStatusTo isMuted: Bool) {}
}
