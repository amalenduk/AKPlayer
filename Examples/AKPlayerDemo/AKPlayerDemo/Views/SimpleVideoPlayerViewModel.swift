//
//   SimpleVideoPlayerViewModel.swift
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
public class SimpleVideoPlayerViewModel: NSObject, ObservableObject {
    public lazy var player: AKPlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let p = AKPlayer(configuration: configuration, audioSessionService: audioSession)
        p.player.appliesMediaSelectionCriteriaAutomatically = true
        return p
    }()

    public lazy var interstitialService: AKPlayerInterstitialServiceProtocol = player
        .interstitialService

    let audioSession = AKAudioSessionService()

    // Playback State
    @Published public var stateDescription = "Idle"
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var volume: Float = 1.0
    @Published public var isMuted = false
    @Published public var playbackRate: AKPlaybackRate = .normal
    @Published public var isLoading = false
    @Published public var unavailableMessage: String?
    @Published public var lastLoadedMedia: (any AKPlayable)?
    @Published public var autoPlayEnabled = true
    @Published public var debugInfo: String?

    // Interstitials / Ads
    @Published public var interstitialPlaybackState: AKInterstitialPlaybackState = .idle
    @Published public var interstitialIdentifier: String?
    @Published public var interstitialProgress: AKPlayerInterstitialProgress?
    @Published public var isInterstitialActive = false
    @Published public var adMarkers: [AKInterstitialMarker] = []

    // PiP State
    @Published public var isPipPossible = false
    @Published public var isPipActive = false
    public private(set) var pipController: AKPictureInPictureController?

    /// Track Selection Groups backed by AKTrackSelectionService
    @Published public var selectionGroups: [SelectionGroup] = []

    /// Video Aspect Ratio & Fill Mode
    @Published public var videoGravity: AVLayerVideoGravity = .resizeAspect

    // Chapters backed by AKChapterService
    @Published public var chapters: [AKChapter] = []
    @Published public var currentChapter: AKChapter?

    // Quick Subtitles
    @Published public var isSubtitleEnabled = false
    @Published public var activeSubtitleLanguage: String?

    private nonisolated(unsafe) var playerEventsTask: Task<Void, Never>?
    private var clearUnavailableWorkItem: DispatchWorkItem?
    private nonisolated(unsafe) var interstitialTask: Task<Void, Never>?
    private nonisolated(unsafe) var pipEventsTask: Task<Void, Never>?
    private nonisolated(unsafe) var chaptersTask: Task<Void, Never>?

    // MARK: - Models for Selection Sheet

    public struct SelectionOption: Identifiable {
        public var id: String {
            option.id
        }

        public let option: AKMediaTrackOption
        public let isSelected: Bool
    }

    public struct SelectionGroup: Identifiable {
        public var id: String {
            title
        }

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
        observePlayerEvents()
    }

    private func observePlayerEvents() {
        playerEventsTask?.cancel()
        playerEventsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in self.player.events {
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
        interstitialTask?.cancel()
        pipEventsTask?.cancel()
        chaptersTask?.cancel()
        playerEventsTask?.cancel()
    }

    // MARK: - Interstitial Observation

    private func observeInterstitialEvents() {
        interstitialTask?.cancel()
        adMarkers = interstitialService.markers
        interstitialTask = Task { [weak self] in
            guard let service = self?.interstitialService else { return }
            for await event in service.events {
                guard !Task.isCancelled, let self else { break }
                switch event {
                case .scheduleDidChange:
                    break
                case .adMarkersDidChange:
                    adMarkers = service.markers
                case let .willStart(event):
                    interstitialIdentifier = event.identifier
                    isInterstitialActive = true
                case .didStart:
                    break
                case let .progress(progress):
                    interstitialProgress = progress
                case .didFinish:
                    isInterstitialActive = false
                    interstitialIdentifier = nil
                    interstitialProgress = nil
                case let .integratedTimeline(timelineEvent):
                    switch timelineEvent {
                    case let .timeUpdated(current, _, dur):
                        if dur > 0 {
                            duration = dur
                        }
                        currentTime = current
                    case .segmentsUpdated, .snapshotOutOfSync:
                        break
                    }
                case let .playbackStateDidChange(state):
                    interstitialPlaybackState = state
                }
            }
        }
    }

    // MARK: - Chapters Observation

    private func observeChapterEvents(for media: any AKPlayable) {
        chaptersTask?.cancel()
        chapters = media.chapterService.chapters
        currentChapter = media.chapterService.currentChapter(at: player.currentTime)

        chaptersTask = Task { [weak self] in
            guard let self else { return }
            for await event in media.chapterService.events {
                guard !Task.isCancelled else { break }
                if case let .chaptersDidChange(updatedChapters) = event {
                    await MainActor.run {
                        self.chapters = updatedChapters
                        self.currentChapter = media.chapterService.currentChapter(
                            at: self.player.currentTime
                        )
                    }
                }
            }
        }
    }

    public func selectChapter(_ chapter: AKChapter) {
        Task {
            await player.seek(to: .seconds(chapter.startTime), scope: .primary)
        }
    }

    public func refreshChapters() {
        guard let media = player.currentMedia else {
            chapters = []
            currentChapter = nil
            return
        }
        chapters = media.chapterService.chapters
        currentChapter = media.chapterService.currentChapter(at: player.currentTime)
    }

    // MARK: - Media Loading

    public func load(media: any AKPlayable, autoPlay: Bool = true, at target: AKSeekTarget? = nil) {
        lastLoadedMedia = media
        currentTime = 0
        duration = 0
        isLoading = true
        stateDescription = "Loading"
        player.load(media: media, autoPlay: autoPlay, at: target)
        observeInterstitialEvents()
        observeChapterEvents(for: media)
    }

    // MARK: - Playback Controls

    public func play() {
        player.play()
    }

    public func pause() {
        player.pause()
    }

    public func stop() {
        player.stop()
        interstitialTask?.cancel()
        interstitialTask = nil
        pipEventsTask?.cancel()
        pipEventsTask = nil
        chaptersTask?.cancel()
        chaptersTask = nil
        chapters = []
        currentChapter = nil
    }

    public func setVolume(_ v: Float) {
        player.volume = v; volume = v
    }

    public func toggleMute() {
        player.isMuted = !player.isMuted; isMuted = player.isMuted
    }

    public func seek(to seconds: Double) {
        Task {
            if interstitialService.integratedTimeline != nil {
                await player.seek(to: .seconds(seconds), scope: .integrated)
            } else {
                await player.seek(to: .seconds(seconds))
            }
        }
    }

    public func step(by count: Int) {
        player.step(by: count)
    }

    public func seekOffset(_ offset: Double) {
        Task {
            if interstitialService.integratedTimeline != nil {
                await player.seek(to: .offset(offset), scope: .integrated)
            } else {
                await player.seek(to: .offset(offset))
            }
        }
    }

    public func setRate(_ rate: AKPlaybackRate) {
        player.play(at: .custom(rate.rate))
    }

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

    // MARK: - Track Selection via AKTrackSelectionService

    public func refreshSelectionGroups() {
        guard let media = player.currentMedia else {
            selectionGroups = []
            return
        }

        Task {
            let trackTypes: [(AKTrackType, String)] = [
                (.audio, "Audio"),
                (.subtitle, "Subtitles"),
                (.closedCaption, "Closed Captions"),
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

                    groups.append(SelectionGroup(
                        type: type,
                        title: title,
                        info: group,
                        options: options
                    ))
                } catch {
                    print("Failed to load tracks for \(title): \(error)")
                }
            }

            await MainActor.run {
                self.selectionGroups = groups
            }
        }
    }

    public func select(option: SelectionOption, in group: SelectionGroup) {
        guard let media = player.currentMedia else { return }

        Task {
            do {
                try await media.trackSelection.select(option.option, for: group.type)
                let selectedSubtitle = try? await media.trackSelection.selectedTrack(for: .subtitle)
                await MainActor.run {
                    self.isSubtitleEnabled = (selectedSubtitle != nil && selectedSubtitle != .off)
                    self
                        .activeSubtitleLanguage =
                        (selectedSubtitle != nil && selectedSubtitle != .off) ? selectedSubtitle?
                            .title : nil
                }
                self.refreshSelectionGroups()
            } catch {
                print("Failed to select track: \(error)")
            }
        }
    }

    public func toggleVideoGravity() {
        if videoGravity == .resizeAspect {
            videoGravity = .resizeAspectFill
        } else if videoGravity == .resizeAspectFill {
            videoGravity = .resize
        } else {
            videoGravity = .resizeAspect
        }
    }

    public func toggleQuickSubtitles() {
        guard let media = player.currentMedia else { return }
        Task {
            do {
                if isSubtitleEnabled {
                    try await media.trackSelection.select(.off, for: .subtitle)
                    await MainActor.run {
                        self.isSubtitleEnabled = false
                        self.activeSubtitleLanguage = nil
                    }
                } else {
                    let subtitles = try await media.trackSelection.availableTracks(for: .subtitle)
                    if let firstOption = subtitles.first(where: { $0 != .off }) {
                        try await media.trackSelection.select(firstOption, for: .subtitle)
                        await MainActor.run {
                            self.isSubtitleEnabled = true
                            self.activeSubtitleLanguage = firstOption.title
                        }
                    } else {
                        try await media.trackSelection.selectPreferredTrack(for: .subtitle)
                        let current = try await media.trackSelection.selectedTrack(for: .subtitle)
                        await MainActor.run {
                            self.isSubtitleEnabled = (current != nil && current != .off)
                            self.activeSubtitleLanguage = current?.title
                        }
                    }
                }
                self.refreshSelectionGroups()
            } catch {
                print("Failed to toggle quick subtitles: \(error)")
            }
        }
    }

    // MARK: - Setup PiP

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

// MARK: - Player Events Handling

extension SimpleVideoPlayerViewModel {
    private func handlePlayerEvent(_ event: AKPlayerEvent) {
        switch event {
        case let .stateDidChange(state):
            self.stateDescription = state.description
            self
                .isLoading =
                (state == .waitingForNetwork || state == .buffering || state == .loading)
            let intDur = self.interstitialService.integratedTimelineDuration
            let dur = player.currentItemDuration.seconds
            if intDur > 0 {
                self.duration = intDur
            } else if dur.isFinite, dur > 0, self.duration == 0 {
                self.duration = dur
            }

        case let .mediaDidChange(media):
            self.lastLoadedMedia = media
            let intTime = self.interstitialService.integratedTimelineCurrentTime
            self.currentTime = (intTime > 0) ? intTime : player.currentTime.seconds
            let intDur = self.interstitialService.integratedTimelineDuration
            let dur = player.currentItemDuration.seconds
            if intDur > 0 {
                self.duration = intDur
            } else {
                self.duration = (dur.isFinite && dur > 0) ? dur : 0
            }
            self.refreshSelectionGroups()

        case let .timeDidChange(currentTime):
            let hasIntegratedTimeline = (self.interstitialService.integratedTimeline != nil)
            if !hasIntegratedTimeline, !self.isInterstitialActive,
               !self.interstitialService.isPlayingInterstitial
            {
                self.currentTime = currentTime.seconds
                let dur = player.currentItemDuration.seconds
                if dur.isFinite, dur > 0, self.duration == 0 {
                    self.duration = dur
                }
            }
            if let media = player.currentMedia {
                self.currentChapter = media.chapterService.currentChapter(at: currentTime)
                if self.chapters.isEmpty, !media.chapterService.chapters.isEmpty {
                    self.chapters = media.chapterService.chapters
                }
            }

        case let .playbackRateDidChange(newRate, _):
            self.playbackRate = newRate

        case let .volumeDidChange(volume):
            self.volume = volume

        case let .muteStatusDidChange(isMuted):
            self.isMuted = isMuted

        case let .commandUnavailable(reason):
            self.clearUnavailableWorkItem?.cancel()
            self.unavailableMessage = reason.description
            let work = DispatchWorkItem { [weak self] in
                DispatchQueue.main.async { self?.unavailableMessage = nil }
            }
            self.clearUnavailableWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)

        case let .didFail(error):
            self.unavailableMessage = "Error: \(error.localizedDescription)"

        case .didReachEnd, .boundaryReached, .sharePlayStateDidChange, .interstitial, .media,
             .trackSelection, .playerItemNotification, .metadata, .chapter:
            break
        }
    }
}

// MARK: - AKPictureInPictureDelegate

extension SimpleVideoPlayerViewModel: AKPictureInPictureDelegate {
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
