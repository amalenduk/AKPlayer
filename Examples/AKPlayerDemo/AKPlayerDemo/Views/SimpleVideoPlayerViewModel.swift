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
    public let aVplayer = AVPlayer()
    
    public lazy var player: AKPlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let p = AKPlayer(player: aVplayer, configuration: configuration, audioSessionService: audioSession)
        p.player.appliesMediaSelectionCriteriaAutomatically = true
        p.delegate = self
        return p
    }()
    
    public lazy var interstitialService: AKPlayerInterstitialService = {
        var service = AKPlayerInterstitialService(player: aVplayer)
        return service
    }()

    static let session = AVAudioSession.sharedInstance()
    let audioSession = AKAudioSessionService(audioSession: session)
    
    @Published public var isPipPossible: Bool = false
    @Published public var isPipActive: Bool = false
    
    
    @Published public var stateDescription: String = ""
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var volume: Float = 1.0
    @Published public var isMuted: Bool = false
    @Published public var canStepForward: Bool = false
    @Published public var canStepBackward: Bool = false
    @Published public var debugInfo: String?
    @Published public var playbackRate: AKPlaybackRate = .normal
    @Published public var bufferedRanges: [ClosedRange<Double>] = []
    @Published public var isLoading: Bool = false
    @Published public var unavailableMessage: String?
    @Published public var lastLoadedMedia: AKMedia?
    @Published public var autoPlayEnabled: Bool = true
    
    // Updated track selection groups backed by AKTrackSelectionService
    @Published public var selectionGroups: [SelectionGroup] = []
    
    private nonisolated(unsafe) var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    private var clearUnavailableWorkItem: DispatchWorkItem?
    public private(set) var pipController: AKPictureInPictureController?
    
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
        try? player.prepare()
        
        Task {
            for await event in interstitialService.events {
                switch event {
                case .scheduleDidChange(let events):
                    //print("Schedule updated: \(events.count) events")
                    break
                case .willStart(let event):
                    //print("Ad about to start: \(event.identifier)")
                    break
                case .didStart(let event):
                    // Show “Skip Ad” button, hide primary controls, etc.
              //print("Printing add \(event)")
                    break
                case .progress(let progress):
//                    print("Current Time: \(progress.currentTime) Duration : \(progress.duration) Remaining: \(progress.timeRemaining)")
//                    print(interstitialService.integratedTimeline?.currentTime)
                    
                    break
                    
                case .didFinish(_, let reason):
                    //print("Finish Reason : \(reason)")
                    switch reason {
                    case .completed: break
                    case .cancelled: break
                    case .error(let err): print(err)
                    }
                case .integratedTimeline(let timelineevent):
                    switch timelineevent {
                    case .segmentsUpdated(pointSegments: let pointSegments, fillSegments: let fillSegments):
                        print(pointSegments)
                    case .timeUpdated(currentTime: let currentTime, startTime: let startTime, duration: let duration):
                        break
                    case .snapshotOutOfSync:
                        break
                    }
                    
                }
            }
        }
        
        // Later – schedule a mid-roll
        
    }
    
    deinit {
        print("Deinit called from ", #file)
    }
    
    public func load(media: AKMedia, autoPlay: Bool) {
        self.lastLoadedMedia = media
        media.delegate = self
        player.load(media: media, autoPlay: autoPlay)
    }
    
    // MARK: - Track Selection via AKTrackSelectionService
    
    @MainActor
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
                          !group.options.isEmpty else { return }
                    
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
    
    @MainActor
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
    
    public func play() { player.play() }
    public func pause() { player.pause() }
    public func stop() { player.stop() }
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
    
    public func loadAndObserveCurrentTime() {
        if let token = timeObserverToken {
            player.player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.currentTime = time.seconds
                if let dur = self.player.currentItem?.duration.seconds, dur.isFinite {
                    self.duration = dur
                }
            }
        }
    }
    
    
    // MARK: - Setup PiP
    
    public func setupPip(with playerLayer: AVPlayerLayer) {
        // Initialize AKPictureInPictureController with the player layer[cite: 3]
        guard let controller = AKPictureInPictureController(playerLayer: playerLayer) else { return }
        Task { @MainActor in
            controller.delegate = self
            controller.canStartAutomatically = true // Allows automatic PiP when swiping home[cite: 3]
            self.pipController = controller
            self.isPipPossible = controller.isPictureInPicturePossible
        }
        
        // Listen to AsyncStream events from AKPictureInPictureController[cite: 3]
        Task { [weak self] in
            for await event in controller.events {
                guard let self else { return }
                switch event {
                case .willStart:
                    break
                case .didStart:
                    self.isPipActive = true
                case .failedToStart(let reason):
                    print("PiP failed: \(reason)")
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

extension SimpleVideoPlayerViewModel: AKPlayerDelegate {
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        DispatchQueue.main.async {
            self.stateDescription = state.description
            self.isLoading = (state == .waitingForNetwork || state == .buffering || state == .loading)
        }
    }
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeCurrentTimeTo currentTime: CMTime, for media: any AKPlayable) {
        DispatchQueue.main.async { self.currentTime = currentTime.seconds }
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
    nonisolated public func akPlayer(_ player: AKPlayer, didFailWith error: AKPlayerError) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeVolumeTo volume: Float) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeMutedStatusTo isMuted: Bool) {}
}

extension SimpleVideoPlayerViewModel: AKMediaDelegate {
    
    public func akMedia(_ media: any AKPlayable, didChangeState state: AKPlayableState) {
        switch state {
            
        case .idle:
            break
        case .assetLoaded:
            break
        case .playerItemLoaded:
            let url = URL(string: "http://127.0.0.1:8000/IMG_1828.mp4")!

            interstitialService.schedule(at: CMTime(seconds: 0, preferredTimescale: 600), templateItems: [AVPlayerItem(url: url)])
            
            interstitialService.schedule(at: CMTime(seconds: 8, preferredTimescale: 600), templateItems: [AVPlayerItem(url: url)])
            
            interstitialService.schedule(at: CMTime(seconds: 14, preferredTimescale: 600), templateItems: [AVPlayerItem(url: url)])
        case .readyToPlay:
            
           
break
        case .failed:
            break
        }
    }
    
    public func akMedia(_ media: any AKPlayable, didChangeItemDurationTo itemDuration: CMTime) {
        DispatchQueue.main.async {
            if itemDuration.isNumeric && itemDuration.seconds.isFinite {
                self.duration = itemDuration.seconds
            }
        }
    }
}

// MARK: - AKPictureInPictureDelegate

extension SimpleVideoPlayerViewModel: AKPictureInPictureDelegate {
    public func pictureInPicture(
        _ controller: AKPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWith completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        // Handle UI restoration if necessary when user taps restore button in PiP window[cite: 1]
        completionHandler(true)
    }
}

extension SimpleVideoPlayerViewModel: @preconcurrency AKPlayerInterstitialDelegate {
    public func player(_ monitor: AVPlayerInterstitialEventMonitor, didStartInterstitial event: AVPlayerInterstitialEvent) {
       // print(event.description)
    }
    
    public func player(_ monitor: AVPlayerInterstitialEventMonitor, didUpdateInterstitialProgress progress: AKPlayerInterstitialProgress) {
       // print(progress)
    }
    
    public func player(_ monitor: AVPlayerInterstitialEventMonitor, didFinishInterstitial event: AVPlayerInterstitialEvent) {
       // print(event.description)
    }
    
    
}
