//
//  AudiobookPlayerViewModel.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 22/09/26.
//

import SwiftUI
import AKPlayer
import AVFoundation
import Combine
import Foundation

@MainActor
public class AudiobookPlayerViewModel: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    public lazy var player: AKPlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        configuration.idleTimerDisabledForStates = [.buffering, .playing]
        let p = AKPlayer(configuration: configuration, audioSessionService: audioSession)
        p.delegate = self
        return p
    }()
    
    static let session = AVAudioSession.sharedInstance()
    let audioSession = AKAudioSessionService(audioSession: session)
    
    // Playback State
    @Published public var media: AKMedia?
    @Published public var isPlaying: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var stateDescription: String = "Idle"
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var playbackRate: AKPlaybackRate = .normal
    @Published public var volume: Float = 1.0
    @Published public var isMuted: Bool = false
    
    // Chapter Navigation
    @Published public var chapters: [AKChapter] = []
    @Published public var currentChapter: AKChapter?
    @Published public var currentChapterIndex: Int = 0
    
    // Sleep Timer
    public enum SleepTimerOption: String, CaseIterable, Identifiable {
        case off = "Off"
        case min15 = "15 Minutes"
        case min30 = "30 Minutes"
        case min45 = "45 Minutes"
        case min60 = "60 Minutes"
        case endOfChapter = "End of Chapter"
        
        public var id: String { rawValue }
        
        public var seconds: TimeInterval? {
            switch self {
            case .off: return nil
            case .min15: return 15 * 60
            case .min30: return 30 * 60
            case .min45: return 45 * 60
            case .min60: return 60 * 60
            case .endOfChapter: return nil
            }
        }
    }
    
    @Published public var sleepTimerOption: SleepTimerOption = .off
    @Published public var sleepTimerRemainingSeconds: Int = 0
    private nonisolated(unsafe) var sleepTimerTask: Task<Void, Never>?
    private nonisolated(unsafe) var chaptersTask: Task<Void, Never>?
    
    // MARK: - Init & Deinit
    
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
        chaptersTask?.cancel()
        sleepTimerTask?.cancel()
    }
    
    // MARK: - Media Loading
    
    public func load(media: AKMedia, autoPlay: Bool = true) {
        self.media = media
        self.currentTime = 0.0
        self.duration = 0.0
        self.chapters = []
        self.currentChapter = nil
        self.isLoading = true
        
        player.load(media: media, autoPlay: autoPlay)
        observeChapters(for: media)
    }
    
    // MARK: - Observation
    
    private func observeChapters(for media: AKMedia) {
        chaptersTask?.cancel()
        chapters = media.chapterService.chapters
        currentChapter = media.chapterService.currentChapter(at: player.currentTime)
        
        chaptersTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await updatedChapters in media.chapterService.chaptersUpdates {
                guard !Task.isCancelled else { break }
                self.chapters = updatedChapters
                self.currentChapter = media.chapterService.currentChapter(
                    at: self.player.currentTime
                )
                if let current = self.currentChapter, let idx = self.chapters.firstIndex(where: { $0.title == current.title }) {
                    self.currentChapterIndex = idx
                }
            }
        }
    }
    
    private func updateCurrentChapter(for seconds: Double) {
        guard !chapters.isEmpty else { return }
        for (index, chapter) in chapters.enumerated() {
            let start = chapter.timeRange.start.seconds
            let end = chapter.timeRange.end.seconds
            if seconds >= start && seconds < end {
                if currentChapter?.title != chapter.title {
                    currentChapter = chapter
                    currentChapterIndex = index
                }
                return
            }
        }
    }
    
    // MARK: - Playback Controls
    
    public func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    public func seek(to seconds: Double) {
        Task {
            await player.seek(to: .seconds(seconds))
        }
    }
    
    public func skipBackward15() {
        Task {
            await player.seek(to: .offset(-15))
        }
    }
    
    public func skipForward30() {
        Task {
            await player.seek(to: .offset(30))
        }
    }
    
    public func setRate(_ rate: AKPlaybackRate) {
        player.play(at: rate)
    }
    
    // MARK: - Chapter Navigation
    
    public func jumpTo(chapter: AKChapter) {
        let startSec = chapter.timeRange.start.seconds
        if startSec.isFinite && !startSec.isNaN {
            seek(to: startSec)
        }
    }
    
    public func nextChapter() {
        guard !chapters.isEmpty, currentChapterIndex + 1 < chapters.count else { return }
        let next = chapters[currentChapterIndex + 1]
        jumpTo(chapter: next)
    }
    
    public func previousChapter() {
        guard !chapters.isEmpty else { return }
        // If more than 3 seconds into chapter, restart current; otherwise go to previous
        if let current = currentChapter, currentTime > current.timeRange.start.seconds + 3.0 {
            jumpTo(chapter: current)
        } else if currentChapterIndex > 0 {
            let prev = chapters[currentChapterIndex - 1]
            jumpTo(chapter: prev)
        }
    }
    
    // MARK: - Sleep Timer
    
    public func setSleepTimer(_ option: SleepTimerOption) {
        self.sleepTimerOption = option
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        
        guard let seconds = option.seconds else {
            sleepTimerRemainingSeconds = 0
            return
        }
        
        sleepTimerRemainingSeconds = Int(seconds)
        
        sleepTimerTask = Task { @MainActor [weak self] in
            while let self, self.sleepTimerRemainingSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                self.sleepTimerRemainingSeconds -= 1
            }
            
            guard let self, !Task.isCancelled, self.sleepTimerOption != .off else { return }
            self.player.pause()
            self.sleepTimerOption = .off
            self.sleepTimerRemainingSeconds = 0
        }
    }
    
    private func checkEndOfChapterSleepTimer(currentSeconds: Double) {
        guard sleepTimerOption == .endOfChapter, let chapter = currentChapter else { return }
        let chapterEnd = chapter.timeRange.end.seconds
        if currentSeconds >= chapterEnd - 0.5 {
            player.pause()
            sleepTimerOption = .off
        }
    }
    
    public func stop() {
        player.stop()
        chaptersTask?.cancel()
        chaptersTask = nil
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
    }
}

// MARK: - AKPlayerDelegate

extension AudiobookPlayerViewModel: AKPlayerDelegate {
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        DispatchQueue.main.async {
            self.stateDescription = state.description
            self.isPlaying = (state == .playing)
            self.isLoading = (state == .waitingForNetwork || state == .buffering || state == .loading)
            let dur = player.currentItemDuration.seconds
            if dur.isFinite && dur > 0 {
                self.duration = dur
            }
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeMediaTo media: any AKPlayable) {
        DispatchQueue.main.async {
            self.currentTime = player.currentTime.seconds
            let dur = player.currentItemDuration.seconds
            self.duration = (dur.isFinite && dur > 0) ? dur : 0
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeCurrentTimeTo currentTime: CMTime, for media: any AKPlayable) {
        let sec = currentTime.seconds
        DispatchQueue.main.async {
            if sec.isFinite && !sec.isNaN {
                self.currentTime = sec
                self.updateCurrentChapter(for: sec)
                self.checkEndOfChapterSleepTimer(currentSeconds: sec)
            }
            let dur = player.currentItemDuration.seconds
            if dur.isFinite && dur > 0 && self.duration != dur {
                self.duration = dur
            }
            self.currentChapter = media.chapterService.currentChapter(at: currentTime)
            if self.chapters.isEmpty && !media.chapterService.chapters.isEmpty {
                self.chapters = media.chapterService.chapters
            }
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didChangePlaybackRateTo newRate: AKPlaybackRate, from oldRate: AKPlaybackRate) {
        DispatchQueue.main.async {
            self.playbackRate = newRate
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didReachEndAt time: CMTime, for media: any AKPlayable) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    nonisolated public func akPlayer(_ player: AKPlayer, didFailWith error: AKPlayerError) {
        DispatchQueue.main.async {
            self.stateDescription = "Failed: \(error.localizedDescription)"
            self.isLoading = false
            self.isPlaying = false
        }
    }
}
