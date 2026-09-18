//
//  AKQueuePlayer.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar. All rights reserved.
//  Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import MediaPlayer

@MainActor
public class AKQueuePlayer: AKPlayer, AKQueuePlayerProtocol {
    // MARK: - Properties
    
    public private(set) var items: [any AKPlayable] = []
    
    public var repeatMode: AKRepeatMode = .off
    
    public var isShuffleEnabled: Bool = false {
        didSet {
            guard oldValue != isShuffleEnabled else { return }
            updateShuffleQueue()
        }
    }
    
    public var currentIndex: Int? {
        guard let currentMedia = currentMedia else { return nil }
        return activeItems.firstIndex(where: { $0.url == currentMedia.url })
    }
    
    public var canPlayNext: Bool {
        guard !activeItems.isEmpty, let currentIndex else { return false }
        if repeatMode == .one || repeatMode == .all { return true }
        return currentIndex < activeItems.count - 1
    }
    
    public var canPlayPrevious: Bool {
        guard !activeItems.isEmpty, let currentIndex else { return false }
        if repeatMode == .one || repeatMode == .all { return true }
        return currentIndex > 0 || currentTime.seconds > 3.0
    }
    
    private var shuffledItems: [any AKPlayable] = []
    
    private var activeItems: [any AKPlayable] {
        isShuffleEnabled ? shuffledItems : items
    }
    
    private var queueEventsTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public override init(
        player: AVPlayer = AVPlayer(),
        configuration: AKPlayerConfigurationProtocol = AKPlayerConfiguration.default,
        audioSessionService: AKAudioSessionServiceProtocol = AKAudioSessionService()
    ) {
        super.init(
            player: player,
            configuration: configuration,
            audioSessionService: audioSessionService
        )
        nowPlayingManager?.queueInfoProvider = self
        startObservingQueueEvents()
    }
    
    deinit {
        queueEventsTask?.cancel()
        queueEventsTask = nil
    }
    
    // MARK: - Lifecycle Preparation
    
    public override func prepare() async throws {
        try await super.prepare()
        await setupQueueNowPlayingCommands()
    }
    
    // MARK: - Queue Management
    
    public func load(
        items: [any AKPlayable],
        startIndex: Int = 0,
        autoPlay: Bool = true
    ) {
        self.items = items
        if isShuffleEnabled {
            updateShuffleQueue()
        }
        
        guard activeItems.indices.contains(startIndex) else { return }
        let targetMedia = activeItems[startIndex]
        load(media: targetMedia, autoPlay: autoPlay, at: nil)
        nowPlayingManager?.updateNowPlayingInfo()
    }
    
    public func next() {
        guard canPlayNext, let currentIndex else { return }
        
        if repeatMode == .one {
            Task { await seek(to: .seconds(0)) }
            play()
            return
        }
        
        let nextIndex = currentIndex + 1
        if nextIndex < activeItems.count {
            load(media: activeItems[nextIndex], autoPlay: true, at: nil)
        } else if repeatMode == .all, let firstItem = activeItems.first {
            load(media: firstItem, autoPlay: true, at: nil)
        }
    }
    
    public func previous() {
        // If current position > 3 seconds, restart current track
        if currentTime.seconds > 3.0 {
            Task { await seek(to: .seconds(0)) }
            return
        }
        
        guard canPlayPrevious, let currentIndex else { return }
        
        if repeatMode == .one {
            Task { await seek(to: .seconds(0)) }
            play()
            return
        }
        
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            load(media: activeItems[previousIndex], autoPlay: true, at: nil)
        } else if repeatMode == .all, let lastItem = activeItems.last {
            load(media: lastItem, autoPlay: true, at: nil)
        }
    }
    
    public func jumpTo(index: Int) {
        guard activeItems.indices.contains(index) else { return }
        load(media: activeItems[index], autoPlay: true, at: nil)
    }
    
    public func append(_ item: any AKPlayable) {
        items.append(item)
        if isShuffleEnabled {
            shuffledItems.append(item)
        }
        nowPlayingManager?.updateNowPlayingInfo()
    }
    
    public func insert(_ item: any AKPlayable, at index: Int) {
        guard items.indices.contains(index) || index == items.count else { return }
        items.insert(item, at: index)
        if isShuffleEnabled {
            shuffledItems.append(item)
        }
        nowPlayingManager?.updateNowPlayingInfo()
    }
    
    public func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        let removedItem = items.remove(at: index)
        
        if isShuffleEnabled {
            shuffledItems.removeAll(where: { $0.url == removedItem.url })
        }
        nowPlayingManager?.updateNowPlayingInfo()
    }
    
    public func move(from sourceIndex: Int, to destinationIndex: Int) {
        guard items.indices.contains(sourceIndex),
              items.indices.contains(destinationIndex)
        else { return }
        
        let item = items.remove(at: sourceIndex)
        items.insert(item, at: destinationIndex)
        nowPlayingManager?.updateNowPlayingInfo()
    }
    
    // MARK: - Private Helpers
    
    private func updateShuffleQueue() {
        guard let currentMedia else {
            shuffledItems = items.shuffled()
            return
        }
        
        var remaining = items.filter { $0.url != currentMedia.url }
        remaining.shuffle()
        shuffledItems = [currentMedia] + remaining
    }
    
    private func startObservingQueueEvents() {
        queueEventsTask?.cancel()
        
        queueEventsTask = Task { [weak self] in
            guard let self else { return }
            
            for await event in events {
                guard !Task.isCancelled else { break }
                
                if case .didReachEnd = event {
                    handleTrackEnded()
                }
            }
        }
    }
    
    private func handleTrackEnded() {
        if canPlayNext {
            next()
        } else {
            stop()
        }
    }
}

// Conformance to AKNowPlayingQueueInfoProvider
extension AKQueuePlayer: AKNowPlayingQueueInfoProvider {
    public var queueCount: Int {
        activeItems.count
    }
    
    public var currentQueueIndex: Int? {
        currentIndex
    }
}
private extension AKQueuePlayer {
    func setupQueueNowPlayingCommands() async {
        guard let nowPlayingManager else { return }
        
        // Apply Queue command preset (enables next/prev track, disables skip intervals/seeking)
        await nowPlayingManager.applyConfiguration(AKNowPlayingCommandPresets.queue())
        
        // Wire Next Track
        await nowPlayingManager.setHandler(for: .nextTrack) { [weak self] _ in
            guard let self else { return .commandFailed }
            guard self.canPlayNext else { return .noSuchContent }
            self.next()
            return .success
        }
        
        // Wire Previous Track
        await nowPlayingManager.setHandler(for: .previousTrack) { [weak self] _ in
            guard let self else { return .commandFailed }
            guard self.canPlayPrevious else { return .noSuchContent }
            self.previous()
            return .success
        }
        
        // Wire Repeat Mode Command
        await nowPlayingManager.setHandler(for: .changeRepeatMode) { [weak self] event in
            guard let self,
                  let repeatEvent = event as? MPChangeRepeatModeCommandEvent
            else { return .commandFailed }
            
            switch repeatEvent.repeatType {
            case .off: self.repeatMode = .off
            case .one: self.repeatMode = .one
            case .all: self.repeatMode = .all
            @unknown default: break
            }
            return .success
        }
        
        // Wire Shuffle Mode Command
        await nowPlayingManager.setHandler(for: .changeShuffleMode) { [weak self] event in
            guard let self,
                  let shuffleEvent = event as? MPChangeShuffleModeCommandEvent
            else { return .commandFailed }
            
            self.isShuffleEnabled = (shuffleEvent.shuffleType != .off)
            return .success
        }
    }
}
