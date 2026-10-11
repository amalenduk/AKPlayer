//
//   AKQueuePlayerObservable.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Observation

/// An observable player model that adds queue state and controls to ``AKPlayerObservable``.
///
/// Playback, media, and track state is inherited from ``AKPlayerObservable``. Queue state is
/// synchronized from the underlying ``AKQueuePlayer``, including changes made directly to it.
@MainActor
@Observable
public final class AKQueuePlayerObservable: AKPlayerObservable {
    /// The queue-capable player observed by this model.
    public let queuePlayer: AKQueuePlayer

    /// The latest queue event received by this wrapper.
    public private(set) var latestQueueEvent: AKPlayerQueueEvent?

    /// The items in the queue, in their original queue order.
    public private(set) var items: [any AKPlayable]

    /// Index of the active item in the player's current queue representation.
    public private(set) var currentIndex: Int?

    /// Repeat mode governing queue iteration behavior.
    public var repeatMode: AKRepeatMode {
        didSet {
            guard repeatMode != oldValue else { return }
            queuePlayer.repeatMode = repeatMode
            synchronizeQueueState()
        }
    }

    /// Whether shuffle mode is active.
    public var isShuffleEnabled: Bool {
        didSet {
            guard isShuffleEnabled != oldValue else { return }
            queuePlayer.isShuffleEnabled = isShuffleEnabled
            synchronizeQueueState()
        }
    }

    /// Whether the player can advance to the next queue item.
    public private(set) var canPlayNext: Bool

    /// Whether the player can move to the previous queue item.
    public private(set) var canPlayPrevious: Bool

    @ObservationIgnored private var queueEventTask: Task<Void, Never>?
    @ObservationIgnored private var playerEventTask: Task<Void, Never>?

    /// Creates an observable model for an existing queue player.
    /// - Parameters:
    ///   - player: The queue player to observe.
    ///   - timelineSource: The timeline used for observable playback progress.
    public init(
        player: AKQueuePlayer = AKQueuePlayer(),
        timelineSource: AKPlayerTimelineSource = .normal
    ) {
        queuePlayer = player
        items = player.items
        currentIndex = player.currentIndex
        repeatMode = player.repeatMode
        isShuffleEnabled = player.isShuffleEnabled
        canPlayNext = player.canPlayNext
        canPlayPrevious = player.canPlayPrevious
        super.init(player: player, timelineSource: timelineSource)

        let queueEvents = player.queueEvents
        let playerEvents = player.events
        queueEventTask = Task { [weak self] in
            for await event in queueEvents {
                guard !Task.isCancelled, let self else { break }
                latestQueueEvent = event
                synchronizeQueueState()
            }
        }
        playerEventTask = Task { [weak self] in
            for await event in playerEvents {
                guard !Task.isCancelled, let self else { break }
                switch event {
                case .timeDidChange, .stateDidChange:
                    synchronizeQueueState()
                default:
                    break
                }
            }
        }
    }

    deinit {
        queueEventTask?.cancel()
        playerEventTask?.cancel()
    }

    /// Loads items into the queue and starts at the selected index.
    public func load(
        items: [any AKPlayable],
        startIndex: Int = 0,
        autoPlay: Bool = true
    ) {
        queuePlayer.load(items: items, startIndex: startIndex, autoPlay: autoPlay)
        synchronizeQueueState()
    }

    /// Advances playback to the next item in the queue.
    public func next() {
        queuePlayer.next()
        synchronizeQueueState()
    }

    /// Moves playback to the previous item or restarts the current item.
    public func previous() {
        queuePlayer.previous()
        synchronizeQueueState()
    }

    /// Starts playback of the item at the specified queue index.
    public func jumpTo(index: Int) {
        queuePlayer.jumpTo(index: index)
        synchronizeQueueState()
    }

    /// Appends an item to the queue.
    public func append(_ item: any AKPlayable) {
        queuePlayer.append(item)
        synchronizeQueueState()
    }

    /// Inserts an item at the specified queue index.
    public func insert(_ item: any AKPlayable, at index: Int) {
        queuePlayer.insert(item, at: index)
        synchronizeQueueState()
    }

    /// Removes the item at the specified queue index.
    public func remove(at index: Int) {
        queuePlayer.remove(at: index)
        synchronizeQueueState()
    }

    /// Moves an item from one queue index to another.
    public func move(from sourceIndex: Int, to destinationIndex: Int) {
        queuePlayer.move(from: sourceIndex, to: destinationIndex)
        synchronizeQueueState()
    }

    private func synchronizeQueueState() {
        items = queuePlayer.items
        currentIndex = queuePlayer.currentIndex
        repeatMode = queuePlayer.repeatMode
        isShuffleEnabled = queuePlayer.isShuffleEnabled
        canPlayNext = queuePlayer.canPlayNext
        canPlayPrevious = queuePlayer.canPlayPrevious
    }
}
