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
    public let observable: AKPlayerObservable

    public var player: AKPlayer {
        observable.player
    }

    public var interstitialService: AKPlayerInterstitialServiceProtocol {
        player.interstitialService
    }

    let audioSession: AKAudioSessionService

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

    private var observationTask: Task<Void, Never>?
    private var pipEventsTask: Task<Void, Never>?
    private var clearUnavailableWorkItem: DispatchWorkItem?

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
        let audioSessionService = AKAudioSessionService()
        self.audioSession = audioSessionService
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let player = AKPlayer(
            configuration: configuration,
            audioSessionService: audioSessionService
        )
        player.player.appliesMediaSelectionCriteriaAutomatically = true
        let obs = AKPlayerObservable(player: player)
        obs.timelineSource = .integrated
        self.observable = obs
        super.init()
        AKLogger.logInit(self)

        Task { @MainActor [weak self] in
            do {
                try await self?.observable.prepare()
            } catch {
                AKLogger.error("Failed to prepare player: \(error)", category: .player)
            }
        }

        startObservingObservable()
    }

    private func startObservingObservable() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        self.syncFromObservable()
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    private func syncFromObservable() {
        self.stateDescription = observable.state.description
        self.isLoading = observable.isLoading
        self.currentTime = observable.currentTimeSeconds
        self.duration = observable.durationSeconds
        self.volume = observable.volume
        self.isMuted = observable.isMuted
        self.playbackRate = observable.playbackRate
        self.lastLoadedMedia = observable.currentMedia
        self.isInterstitialActive = observable.isInterstitialActive
        self.interstitialPlaybackState = observable.interstitialPlaybackState
        self.adMarkers = observable.adMarkers
        self.interstitialIdentifier = observable.currentInterstitialIdentifier
        self.interstitialProgress = observable.interstitialProgress
        self.chapters = observable.chapters
        self.currentChapter = observable.currentChapter

        if let err = observable.error {
            self.unavailableMessage = "Error: \(err.localizedDescription)"
        } else if case let .commandUnavailable(reason) = observable.latestEvent {
            self.showUnavailable(reason.description)
        }

        let subtitleTrack = observable.selectedSubtitleTrack
        self.isSubtitleEnabled = (subtitleTrack != nil && subtitleTrack != .off)
        self.activeSubtitleLanguage = self.isSubtitleEnabled ? subtitleTrack?.title : nil

        self.updateSelectionGroups()
    }

    private func showUnavailable(_ message: String) {
        clearUnavailableWorkItem?.cancel()
        unavailableMessage = message
        let work = DispatchWorkItem { [weak self] in
            self?.unavailableMessage = nil
        }
        clearUnavailableWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    private func updateSelectionGroups() {
        let trackTypes: [(AKTrackType, String)] = [
            (.audio, "Audio"),
            (.subtitle, "Subtitles"),
            (.closedCaption, "Closed Captions"),
        ]

        var groups: [SelectionGroup] = []
        for (type, title) in trackTypes {
            let options = observable.availableTracks[type] ?? []
            guard !options.isEmpty else { continue }
            let selected = observable.selectedTracks[type]
            let mappedOptions = options.map { opt in
                SelectionOption(option: opt, isSelected: opt == selected)
            }
            let group = AKMediaTrackGroup(
                type: type,
                options: options,
                selectedOption: selected
            )
            groups.append(SelectionGroup(
                type: type,
                title: title,
                info: group,
                options: mappedOptions
            ))
        }
        self.selectionGroups = groups
    }

    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - Media Loading

    public func load(media: any AKPlayable, autoPlay: Bool = true, at target: AKSeekTarget? = nil) {
        lastLoadedMedia = media
        currentTime = 0
        duration = 0
        isLoading = true
        stateDescription = "Loading"
        observable.load(media: media, autoPlay: autoPlayEnabled && autoPlay, at: target)
    }

    // MARK: - Playback Controls

    public func play() {
        observable.play()
    }

    public func pause() {
        observable.pause()
    }

    public func stop() {
        observable.stop()
        pipEventsTask?.cancel()
        pipEventsTask = nil
        chapters = []
        currentChapter = nil
    }

    public func setVolume(_ v: Float) {
        observable.setVolume(v)
    }

    public func toggleMute() {
        observable.toggleMute()
    }

    public func seek(to seconds: Double) {
        Task {
            _ = await observable.seek(
                to: seconds,
                scope: (observable.timelineSource == .integrated) ? .integrated : .primary
            )
        }
    }

    public func step(by count: Int) {
        player.step(by: count)
    }

    public func seekOffset(_ offset: Double) {
        Task {
            if offset > 0 {
                _ = await observable.skipForward(by: offset)
            } else {
                _ = await observable.skipBackward(by: abs(offset))
            }
        }
    }

    public func setPlaybackRate(_ rate: AKPlaybackRate) {
        observable.setPlaybackRate(rate)
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

    // MARK: - Chapters

    public func selectChapter(_ chapter: AKChapter) {
        Task {
            _ = await observable.seek(to: chapter)
        }
    }

    public func refreshChapters() {
        chapters = observable.chapters
        currentChapter = observable.currentChapter
    }

    // MARK: - Track Selection

    public func refreshSelectionGroups() {
        Task {
            try? await observable.refreshTracks(for: [.audio, .subtitle, .closedCaption])
            updateSelectionGroups()
        }
    }

    public func select(option: SelectionOption, in group: SelectionGroup) {
        Task {
            do {
                try await observable.selectTrack(option.option, for: group.type)
                updateSelectionGroups()
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
        Task {
            do {
                if isSubtitleEnabled {
                    try await observable.selectTrack(.off, for: .subtitle)
                } else {
                    let subtitles = observable.subtitleTracks
                    if let firstOption = subtitles.first(where: { $0 != .off }) {
                        try await observable.selectTrack(firstOption, for: .subtitle)
                    } else {
                        try await observable.selectPreferredTrack(for: .subtitle)
                    }
                }
                updateSelectionGroups()
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

        pipController = controller
        isPipPossible = controller.isPictureInPicturePossible

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
