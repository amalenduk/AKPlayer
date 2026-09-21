//
//  LivePlayerViewModel.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 18/09/26.
//

import SwiftUI
import AKPlayer
import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
public class LivePlayerViewModel: NSObject, ObservableObject {
    
    public lazy var player: AKPlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let p = AKPlayer(
            configuration: configuration,
            audioSessionService: audioSession
        )
        p.player.appliesMediaSelectionCriteriaAutomatically = true
        p.delegate = self
        return p
    }()
    
    static let session = AVAudioSession.sharedInstance()
    let audioSession = AKAudioSessionService(audioSession: session)
    
    // MARK: - Published Live Playback State
    
    @Published public var media: AKMedia?
    @Published public var stateDescription: String = "Idle"
    @Published public var isLoading: Bool = false
    @Published public var isLive: Bool = true
    @Published public var isAtLiveEdge: Bool = true
    @Published public var liveOffset: Double = 0.0 // Seconds behind live head
    @Published public var currentTime: Double = 0.0
    @Published public var dvrWindowStart: Double = 0.0
    @Published public var dvrWindowEnd: Double = 0.0
    @Published public var dvrWindowDuration: Double = 0.0
    @Published public var playbackRate: AKPlaybackRate = .normal
    @Published public var volume: Float = 1.0
    @Published public var isMuted: Bool = false
    @Published public var unavailableMessage: String?
    @Published public var presentationSize: CGSize = .zero
    @Published public var isPipPossible: Bool = false
    @Published public var isPipActive: Bool = false
    
    // MARK: - Private State & Observers
    
    public private(set) var pipController: AKPictureInPictureController?
    private nonisolated(unsafe) var pipEventsTask: Task<Void, Never>?
    private nonisolated(unsafe) var mediaEventsTask: Task<Void, Never>?
    private var clearUnavailableWorkItem: DispatchWorkItem?
    
    /// Threshold in seconds to consider the player at the live edge.
    public var liveEdgeThreshold: Double {
        media?.liveEdgeThreshold ?? 4.0
    }
    
    // MARK: - Initialization & Teardown
    
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
    }
    
    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
        pipEventsTask?.cancel()
        mediaEventsTask?.cancel()
    }
    
    // MARK: - Media Loading
    
    public func load(media: AKMedia, autoPlay: Bool = true) {
        self.media = media
        self.isLive = media.isLive()
        self.isAtLiveEdge = true
        self.liveOffset = 0.0
        
        observeMediaEvents(for: media)
        player.load(media: media, autoPlay: autoPlay)
        
        self.stateDescription = player.state.description
        self.isLoading = (player.state == .waitingForNetwork || player.state == .buffering || player.state == .loading)
    }
    
    // MARK: - Live Navigation & "Jump to Live" Actions
    
    /// Jumps directly to the live edge (head) of the stream and resumes normal 1.0x playback.
    public func jumpToLive() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        Task {
            await player.jumpToLive()
            await MainActor.run {
                self.updateDVRWindowAndDrift()
            }
        }
    }
    
    /// Scrubs within the DVR sliding window relative to the live edge.
    /// - Parameter offsetFromLive: A negative number or 0 representing seconds behind the live head (e.g. -30.0).
    public func scrubDVR(offsetFromLive: Double) {
        guard dvrWindowDuration > 0 else { return }
        
        // If close to live edge, trigger jump to live
        if abs(offsetFromLive) <= liveEdgeThreshold {
            jumpToLive()
            return
        }
        
        let targetSeconds = max(dvrWindowStart, min(dvrWindowEnd, dvrWindowEnd + offsetFromLive))
        Task {
            await player.seek(to: .seconds(targetSeconds))
            await MainActor.run {
                self.currentTime = targetSeconds
                self.updateDVRWindowAndDrift()
            }
        }
    }
    
    /// Rewinds backward by a fixed number of seconds in the DVR buffer.
    public func seekBackward(seconds: Double = 15.0) {
        let target = max(dvrWindowStart, currentTime - seconds)
        Task {
            await player.seek(to: .seconds(target))
            await MainActor.run {
                self.currentTime = target
                self.updateDVRWindowAndDrift()
            }
        }
    }
    
    /// Skips forward by a fixed number of seconds toward the live edge.
    public func seekForward(seconds: Double = 15.0) {
        if liveOffset <= seconds + 1.0 {
            jumpToLive()
        } else {
            let target = min(dvrWindowEnd, currentTime + seconds)
            Task {
                await player.seek(to: .seconds(target))
                await MainActor.run {
                    self.currentTime = target
                    self.updateDVRWindowAndDrift()
                }
            }
        }
    }
    
    /// Switches playback speed (e.g. 1.25x or 1.5x) to catch up smoothly with the live edge.
    public func setPlaybackRate(_ rate: AKPlaybackRate) {
        player.play(at: rate)
    }
    
    // MARK: - Playback Controls
    
    public func play() { player.play() }
    public func pause() { player.pause() }
    public func togglePlayPause() { player.togglePlayPause() }
    
    public func stop() {
        player.stop()
        pipEventsTask?.cancel()
        pipEventsTask = nil
        mediaEventsTask?.cancel()
        mediaEventsTask = nil
    }
    
    public func setVolume(_ v: Float) { player.volume = v; volume = v }
    public func toggleMute() { player.isMuted = !player.isMuted; isMuted = player.isMuted }
    
    // MARK: - Time & Drift Calculation
    
    private func updateDVRWindowAndDrift() {
        self.isLive = player.isLive
        
        let atEdge = player.isAtLiveEdge
        if self.isAtLiveEdge != atEdge {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.isAtLiveEdge = atEdge
            }
        }
        
        self.liveOffset = media?.liveDrift ?? 0.0
        
        if let dvr = media?.dvrWindow {
            let start = dvr.start.seconds
            let duration = dvr.duration.seconds
            let end = dvr.end.seconds
            if start.isFinite && duration.isFinite && end.isFinite {
                self.dvrWindowStart = start
                self.dvrWindowDuration = duration
                self.dvrWindowEnd = end
            }
        }
    }
    
    // MARK: - Media Events Observation
    
    private func observeMediaEvents(for media: AKMedia) {
        mediaEventsTask?.cancel()
        mediaEventsTask = Task { [weak self] in
            for await event in media.events {
                guard !Task.isCancelled, let self else { break }
                switch event {
                case .presentationSizeDidChange(let size):
                    self.presentationSize = size
                case .seekableTimeRangesDidChange:
                    self.updateDVRWindowAndDrift()
                case .stateDidChange(let state):
                    self.isLoading = (state == .idle || state == .assetLoaded || state == .playerItemLoaded)
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Picture in Picture
    
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
                case .didStart:
                    self.isPipActive = true
                case .didStop, .failedToStart:
                    self.isPipActive = false
                default:
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

extension LivePlayerViewModel: AKPlayerDelegate {
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        DispatchQueue.main.async {
            self.stateDescription = state.description
            self.isLoading = (state == .waitingForNetwork || state == .buffering || state == .loading)
            self.updateDVRWindowAndDrift()
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeMediaTo media: any AKPlayable) {
        DispatchQueue.main.async {
            self.media = media as? AKMedia
            self.isLive = media.isLive()
            self.currentTime = player.currentTime.seconds
            self.updateDVRWindowAndDrift()
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeCurrentTimeTo currentTime: CMTime, for media: any AKPlayable) {
        DispatchQueue.main.async {
            self.currentTime = currentTime.seconds
            self.updateDVRWindowAndDrift()
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
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeVolumeTo volume: Float) {
        DispatchQueue.main.async { self.volume = volume }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeMutedStatusTo isMuted: Bool) {
        DispatchQueue.main.async { self.isMuted = isMuted }
    }
}

// MARK: - AKPictureInPictureDelegate

extension LivePlayerViewModel: AKPictureInPictureDelegate {
    public func pictureInPicture(
        _ controller: AKPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWith completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
