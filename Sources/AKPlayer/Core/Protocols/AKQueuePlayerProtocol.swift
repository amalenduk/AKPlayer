//
//  AKQueuePlayerProtocol.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar. All rights reserved.
//  Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

@MainActor
public protocol AKQueuePlayerProtocol: AKPlayerProtocol {
    /// The current list of items in the queue.
    var items: [any AKPlayable] { get }

    /// Index of the active media item in the current queue representation.
    var currentIndex: Int? { get }

    /// Repeat mode governing queue iteration behavior.
    var repeatMode: AKRepeatMode { get set }

    /// Indicates whether shuffle mode is active.
    var isShuffleEnabled: Bool { get set }

    /// Indicates whether a valid next item exists to play.
    var canPlayNext: Bool { get }

    /// Indicates whether a valid previous item exists to play.
    var canPlayPrevious: Bool { get }

    /// Loads a list of media items into the queue and starts playback at the specified index.
    func load(
        items: [any AKPlayable],
        startIndex: Int,
        autoPlay: Bool
    )

    /// Advances playback to the next item in the queue.
    func next()

    /// Moves playback to the previous item or restarts the current track based on position.
    func previous()

    /// Jumps directly to the item at the specified queue index.
    func jumpTo(index: Int)

    /// Appends a new item to the end of the queue.
    func append(_ item: any AKPlayable)

    /// Inserts an item into the queue at the designated index.
    func insert(_ item: any AKPlayable, at index: Int)

    /// Removes an item from the queue at the designated index.
    func remove(at index: Int)

    /// Moves an item from one index to another in the queue.
    func move(from sourceIndex: Int, to destinationIndex: Int)
}
