//
//  SimpleVideoPlayerViewModel.swift
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
public class SimpleVideoPlayerViewModel: NSObject, ObservableObject {
    public let avPlayer = AVPlayer()
    
    public lazy var player: AKPlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let p = AKPlayer(player: avPlayer, configuration: configuration, audioSessionService: audioSession)
        p.player.appliesMediaSelectionCriteriaAutomatically = true
        p.delegate = self
        return p
    }()
    
    public lazy var interstitialService: AKPlayerInterstitialServiceProtocol = {
        player.interstitialService
    }()
    
    static let session = AVAudioSession.sharedInstance()
    let audioSession = AKAudioSessionService(audioSession: session)
    
    // Playback State
    @Published public var stateDescription: String = "Idle"
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var volume: Float = 1.0
    @Published public var isMuted: Bool = false
    @Published public var playbackRate: AKPlaybackRate = .normal
    @Published public var isLoading: Bool = false
    @Published public var unavailableMessage: String?
    @Published public var lastLoadedMedia: (any AKPlayable)?
    @Published public var autoPlayEnabled: Bool = true
    @Published public var debugInfo: String?
    
    // Interstitials / Ads
    @Published public var interstitialPlaybackState: AKInterstitialPlaybackState = .idle
    @Published public var interstitialIdentifier: String?
    @Published public var interstitialProgress: AKPlayerInterstitialProgress?
    @Published public var isInterstitialActive: Bool = false
    
    // PiP State
    @Published public var isPipPossible: Bool = false
    @Published public var isPipActive: Bool = false
    public private(set) var pipController: AKPictureInPictureController?
    
    // Track Selection Groups backed by AKTrackSelectionService
    @Published public var selectionGroups: [SelectionGroup] = []
    
    // Chapters backed by AKChapterService
    @Published public var chapters: [AKChapter] = []
    @Published public var currentChapter: AKChapter?
    
    private nonisolated(unsafe) var timeObserverToken: Any?
    private var clearUnavailableWorkItem: DispatchWorkItem?
    private nonisolated(unsafe) var interstitialTask: Task<Void, Never>?
    private nonisolated(unsafe) var pipEventsTask: Task<Void, Never>?
    private nonisolated(unsafe) var chaptersTask: Task<Void, Never>?
    
    // MARK: - Models for Selection Sheet
    
    public struct SelectionOption: Identifiable {
        public var id: String { option.id }
        public let option: AKMediaTrackOption
        public let isSelected: Bool
    }
    
    public struct SelectionGroup: Identifiable {
        public var id: String { title }
        public let type: AKTrackType
        public let title: String
        public let info: AKMediaTrackGroup
        public var options: [SelectionOption]
    }
    
    override public init() {
        super.init()
        AKLogger.logInit(self)
        Task { @MainActor [weak self] in
            do {
                try await self?.player.prepare()
            } catch {
                AKLogger.error("Failed to prepare player: \(error)", category: .player)
            }
        }
        observeInterstitialEvents()
    }
    
    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
        }
        interstitialTask?.cancel()
        pipEventsTask?.cancel()
        chaptersTask?.cancel()
    }
    
    // MARK: - Interstitial Observation
    
    private func observeInterstitialEvents() {
        interstitialTask?.cancel()
        interstitialTask = Task { [weak self] in
            guard let service = self?.interstitialService else { return }
            for await event in service.events {
                guard !Task.isCancelled, let self else { break }
                switch event {
                case .scheduleDidChange:
                    break
                case .willStart(let event):
                    self.interstitialIdentifier = event.identifier
                    self.isInterstitialActive = true
                case .didStart(let event):
                    self.interstitialIdentifier = event.identifier
                    self.isInterstitialActive = true
                case .progress(let progress):
                    self.interstitialProgress = progress
                case .didFinish:
                    self.isInterstitialActive = false
                    self.interstitialIdentifier = nil
                    self.interstitialProgress = nil
                case .integratedTimeline:
                    break
                case .playbackStateDidChange(let state):
                    self.interstitialPlaybackState = state
                    self.isInterstitialActive = (state != .idle && state != .finished)
                }
            }
        }
    }
    
    // MARK: - Chapters Observation
    
    private func observeChapterEvents(for media: any AKPlayable) {
        chaptersTask?.cancel()
        chapters = media.chapterService.chapters
        currentChapter = media.chapterService.currentChapter
        
        chaptersTask = Task { [weak self] in
            guard let self else { return }
            for await updatedChapters in media.chapterService.chaptersUpdates {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.chapters = updatedChapters
                    self.currentChapter = media.chapterService.currentChapter(
                        at: CMTime(seconds: self.currentTime, preferredTimescale: 600)
                    )
                }
            }
        }
    }
    
    public func refreshChapters() {
        guard let media = player.currentMedia else {
            self.chapters = []
            self.currentChapter = nil
            return
        }
        self.chapters = media.chapterService.chapters
        self.currentChapter = media.chapterService.currentChapter(
            at: CMTime(seconds: currentTime, preferredTimescale: 600)
        )
    }
    
    public func selectChapter(_ chapter: AKChapter) {
        seek(to: chapter.startTime)
    }
    
    // MARK: - Media Loading
    
    public func load(media: any AKPlayable, autoPlay: Bool) {
        self.lastLoadedMedia = media
        observeChapterEvents(for: media)
        player.load(media: media, autoPlay: autoPlay)
        self.stateDescription = player.state.description
        self.isLoading = (player.state == .waitingForNetwork || player.state == .buffering || player.state == .loading)
    }
    
    // MARK: - Playback Controls
    
    public func play() { player.play() }
    public func pause() { player.pause() }
    public func stop() {
        player.stop()
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
        interstitialTask?.cancel()
        interstitialTask = nil
        pipEventsTask?.cancel()
        pipEventsTask = nil
        chaptersTask?.cancel()
        chaptersTask = nil
        chapters = []
        currentChapter = nil
    }
    
    public func setVolume(_ v: Float) { player.volume = v; volume = v }
    public func toggleMute() { player.isMuted = !player.isMuted; isMuted = player.isMuted }
    public func seek(to seconds: Double) {
        Task {
            await player.seek(to: .seconds(seconds))
        }
    }
    public func step(by count: Int) { player.step(by: count) }
    public func seekOffset(_ offset: Double) {
        Task {
            await player.seek(to: .offset(offset))
        }
    }
    public func setRate(_ rate: AKPlaybackRate) { player.play(at: .custom(rate.rate)) }
    
    // MARK: - Interstitial Controls
    
    public func pauseInterstitial() {
        interstitialService.interstitialPlayer?.pause()
    }
    
    public func playInterstitial() {
        interstitialService.interstitialPlayer?.play()
    }
    
    public func cancelInterstitial() {
        interstitialService.cancelCurrent(resumptionOffset: .zero)
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
                guard let self = self else { return }
                self.currentTime = time.seconds
                if let dur = self.player.currentItem?.duration.seconds, dur.isFinite {
                    self.duration = dur
                }
            }
        }
    }
    
    // MARK: - Track Selection via AKTrackSelectionService
    
    public func refreshSelectionGroups() {
        guard let media = player.currentMedia else {
            self.selectionGroups = []
            return
        }
        
        Task {
            let trackTypes: [(AKTrackType, String)] = [
                (.audio, "Audio"),
                (.subtitle, "Subtitles"),
                (.closedCaption, "Closed Captions"),
                (.audioDescription, "Audio Description")
            ]
            
            var groups: [SelectionGroup] = []
            let trackService = media.trackSelection
            
            for (type, title) in trackTypes {
                do {
                    guard let group = try await trackService.trackGroup(for: type),
                          !group.options.isEmpty else { continue }
                    
                    let options = group.options.map { trackOption in
                        SelectionOption(
                            option: trackOption,
                            isSelected: trackOption == group.selectedOption
                        )
                    }
                    
                    groups.append(SelectionGroup(type: type, title: title, info: group, options: options))
                } catch {
                    print("Failed to load tracks for \(title): \(error)")
                }
            }
            
            self.selectionGroups = groups
        }
    }
    
    public func select(option: SelectionOption, in group: SelectionGroup) {
        guard let media = player.currentMedia else { return }
        
        Task {
            do {
                try await media.trackSelection.select(option.option, for: group.type)
                self.refreshSelectionGroups()
            } catch {
                print("Failed to select track: \(error)")
            }
        }
    }
    
    // MARK: - Setup PiP
    
    public func setupPip(with playerLayer: AVPlayerLayer) {
        guard pipController == nil else { return }
        guard let controller = AKPictureInPictureController(playerLayer: playerLayer) else { return }
        controller.delegate = self
        controller.canStartAutomatically = true
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pipController = controller
            self.isPipPossible = controller.isPictureInPicturePossible
        }
        
        pipEventsTask?.cancel()
        pipEventsTask = Task { [weak self] in
            for await event in controller.events {
                guard !Task.isCancelled, let self else { break }
                switch event {
                case .willStart:
                    break
                case .didStart:
                    self.isPipActive = true
                case .failedToStart:
                    self.isPipActive = false
                case .willStop:
                    break
                case .didStop:
                    self.isPipActive = false
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

extension SimpleVideoPlayerViewModel: AKPlayerDelegate {
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        DispatchQueue.main.async {
            self.stateDescription = state.description
            self.isLoading = (state == .waitingForNetwork || state == .buffering || state == .loading)
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeCurrentTimeTo currentTime: CMTime, for media: any AKPlayable) {
        DispatchQueue.main.async {
            self.currentTime = currentTime.seconds
            self.currentChapter = media.chapterService.currentChapter(at: currentTime)
            if self.chapters.isEmpty && !media.chapterService.chapters.isEmpty {
                self.chapters = media.chapterService.chapters
            }
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangePlaybackRateTo newRate: AKPlaybackRate, from oldRate: AKPlaybackRate) {
        DispatchQueue.main.async { self.playbackRate = newRate }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didInvokeBoundaryTimeObserverAt time: CMTime, for media: any AKPlayable) {}
    
    nonisolated public func akPlayer(_ player: AKPlayer, didReachEndAt time: CMTime, for media: any AKPlayable) {}
    
    nonisolated public func akPlayer(_ player: AKPlayer, didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason) {
        DispatchQueue.main.async {
            self.clearUnavailableWorkItem?.cancel()
            self.unavailableMessage = reason.description
            let work = DispatchWorkItem { [weak self] in
                DispatchQueue.main.async { self?.unavailableMessage = nil }
            }
            self.clearUnavailableWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didFailWith error: AKPlayerError) {
        DispatchQueue.main.async {
            self.unavailableMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeVolumeTo volume: Float) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeMutedStatusTo isMuted: Bool) {}
}

// MARK: - AKPictureInPictureDelegate

extension SimpleVideoPlayerViewModel: AKPictureInPictureDelegate {
    public func pictureInPicture(
        _ controller: AKPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWith completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
