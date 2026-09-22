//
//   AKQueuePlayer.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import MediaPlayer

// MARK: - AKQueuePlayer

/// A playlist and queue-capable player subclass supporting sequential playback,
/// repeat modes, track shuffling, and Now Playing queue info integration.
@MainActor
public class AKQueuePlayer: AKPlayer, AKQueuePlayerProtocol {
    // MARK: - Properties

    /// The current list of items in the queue.
    public private(set) var items: [any AKPlayable] = []

    /// Index of the active media item in the current queue representation.
    public var currentIndex: Int? {
        guard let currentMedia else { return nil }
        return activeItems.firstIndex(where: { $0.url == currentMedia.url })
    }

    /// Repeat mode governing queue iteration behavior. Defaults to `.off`.
    public var repeatMode: AKRepeatMode = .off

    /// Indicates whether shuffle mode is active.
    public var isShuffleEnabled: Bool = false {
        didSet {
            guard oldValue != isShuffleEnabled else { return }
            updateShuffleQueue()
        }
    }

    /// Indicates whether a valid next item exists to play.
    public var canPlayNext: Bool {
        guard !activeItems.isEmpty, let currentIndex else { return false }
        if repeatMode == .one || repeatMode == .all { return true }
        return currentIndex < activeItems.count - 1
    }

    /// Indicates whether a valid previous item exists to play.
    public var canPlayPrevious: Bool {
        guard !activeItems.isEmpty, let currentIndex else { return false }
        if repeatMode == .one || repeatMode == .all { return true }
        return currentIndex > 0 || currentTime.seconds > 3.0
    }

    // MARK: - Private State

    private var shuffledItems: [any AKPlayable] = []

    private var activeItems: [any AKPlayable] {
        isShuffleEnabled ? shuffledItems : items
    }

    private var queueEventsTask: Task<Void, Never>?

    // MARK: - Initialization & Deinitialization

    /// Initializes a new queue player instance.
    /// - Parameters:
    ///   - player: The underlying `AVPlayer` instance. Defaults to a new player.
    ///   - configuration: Configuration options. Defaults to `AKPlayerConfiguration.default`.
    ///   - audioSessionService: Audio session service. Defaults to `AKAudioSessionService()`.
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

    /// Configures audio sessions and registers remote queue command presets.
    public override func prepare() async throws {
        try await super.prepare()
        await setupQueueNowPlayingCommands()
    }

    // MARK: - Queue Management

    /// Loads a list of media items into the queue and starts playback at the specified index.
    /// - Parameters:
    ///   - items: The collection of playable media items to enqueue.
    ///   - startIndex: The initial item index to play. Defaults to `0`.
    ///   - autoPlay: Whether playback begins automatically. Defaults to `true`.
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

    /// Advances playback to the next item in the queue.
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

    /// Moves playback to the previous item or restarts the current track based on position.
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

    /// Jumps directly to the item at the specified queue index.
    /// - Parameter index: Target 0-based queue index.
    public func jumpTo(index: Int) {
        guard activeItems.indices.contains(index) else { return }
        load(media: activeItems[index], autoPlay: true, at: nil)
    }

    /// Appends a new item to the end of the queue.
    /// - Parameter item: The playable media item to append.
    public func append(_ item: any AKPlayable) {
        items.append(item)
        if isShuffleEnabled {
            shuffledItems.append(item)
        }
        nowPlayingManager?.updateNowPlayingInfo()
    }

    /// Inserts an item into the queue at the designated index.
    /// - Parameters:
    ///   - item: The playable media item to insert.
    ///   - index: The 0-based target index position.
    public func insert(_ item: any AKPlayable, at index: Int) {
        guard items.indices.contains(index) || index == items.count else { return }
        items.insert(item, at: index)
        if isShuffleEnabled {
            shuffledItems.append(item)
        }
        nowPlayingManager?.updateNowPlayingInfo()
    }

    /// Removes an item from the queue at the designated index.
    /// - Parameter index: The 0-based index of the item to remove.
    public func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        let removedItem = items.remove(at: index)

        if isShuffleEnabled {
            shuffledItems.removeAll(where: { $0.url == removedItem.url })
        }
        nowPlayingManager?.updateNowPlayingInfo()
    }

    /// Moves an item from one index to another in the queue.
    /// - Parameters:
    ///   - sourceIndex: Source 0-based index.
    ///   - destinationIndex: Destination 0-based index.
    public func move(from sourceIndex: Int, to destinationIndex: Int) {
        guard items.indices.contains(sourceIndex),
              items.indices.contains(destinationIndex)
        else { return }

        let item = items.remove(at: sourceIndex)
        items.insert(item, at: destinationIndex)
        nowPlayingManager?.updateNowPlayingInfo()
    }

    // MARK: - Private Queue Helpers

    /// Rebuilds the internal randomized queue order when shuffle mode is toggled or current item changes.
    private func updateShuffleQueue() {
        guard let currentMedia else {
            shuffledItems = items.shuffled()
            return
        }

        var remaining = items.filter { $0.url != currentMedia.url }
        remaining.shuffle()
        shuffledItems = [currentMedia] + remaining
    }

    /// Attaches an observation task to the events stream to detect natural end of track playback.
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

    /// Handles automatic advancing or stopping when the active track finishes playing.
    private func handleTrackEnded() {
        if canPlayNext {
            next()
        } else {
            stop()
        }
    }

    // MARK: - Private Remote Command Handlers

    /// Configures Now Playing remote command handlers for playlist actions (Next, Previous, Repeat, Shuffle).
    private func setupQueueNowPlayingCommands() async {
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

// MARK: - AKNowPlayingQueueInfoProvider Conformance

extension AKQueuePlayer: AKNowPlayingQueueInfoProvider {
    /// Total count of active items in the queue.
    public var queueCount: Int {
        activeItems.count
    }

    /// The 0-based index of the currently active media item.
    public var currentQueueIndex: Int? {
        currentIndex
    }
}

