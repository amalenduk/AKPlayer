//
//   AKChapterService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@preconcurrency import AVFoundation
import Foundation
import Synchronization
#if canImport(UIKit)
    import UIKit
#endif

// MARK: - AKChapterService

/// Thread-safe service responsible for extracting, querying, and observing media chapters.
public final class AKChapterService: AKChapterServiceProtocol, @unchecked Sendable {
    // MARK: - Properties

    /// Weak reference to the parent media manager.
    private weak var mediaManager: (any AKMediaManagerProtocol)?

    private struct State {
        /// Cached list of extracted chapters.
        var chapters: [AKChapter] = []
        /// The currently active chapter matching playback position.
        var currentChapter: AKChapter?
        /// The asynchronous task loading chapter metadata.
        var loadTask: Task<Void, Never>?
    }

    private let state = Mutex(State())

    /// The complete ordered collection of chapters extracted from the media item.
    public var chapters: [AKChapter] {
        state.withLock { $0.chapters }
    }

    /// The total number of chapters currently available.
    public var chapterCount: Int {
        state.withLock { $0.chapters.count }
    }

    /// The chapter corresponding to the current playback position, if any.
    public var currentChapter: AKChapter? {
        state.withLock { $0.currentChapter }
    }

    /// The start time in seconds of the end credits or outro chapter if present, or `nil`.
    public var creditsStartTime: Double? {
        chapters.first(where: {
            let title = $0.title.lowercased()
            return title.contains("credit") || title.contains("outro") || title.contains("closing")
        })?.startTime
    }

    // MARK: - Async Streams

    /// An asynchronous stream emitting updates whenever the collection of chapters changes.
    public var chaptersUpdates: AsyncStream<[AKChapter]> {
        chaptersBroadcaster.makeStream()
    }

    /// An asynchronous stream emitting updates whenever the active playback chapter changes.
    public var currentChapterUpdates: AsyncStream<AKChapter?> {
        currentChapterBroadcaster.makeStream()
    }

    // MARK: - Broadcasters

    private let chaptersBroadcaster = AKEventBroadcaster<[AKChapter]>()
    private let currentChapterBroadcaster = AKEventBroadcaster<AKChapter?>()

    // MARK: - Initialization

    /// Initializes a chapter service instance for extracting and tracking chapters for the given
    /// media manager.
    /// - Parameter mediaManager: The media manager managing the active asset.
    public init(mediaManager: any AKMediaManagerProtocol) {
        defer {
            AKLogger.logInit(self)
        }
        self.mediaManager = mediaManager
    }

    deinit {
        state.withLock { $0.loadTask?.cancel() }
        chaptersBroadcaster.finish()
        currentChapterBroadcaster.finish()
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - Chapter Queries

    /// Finds the chapter encompassing the specified playback timestamp.
    /// - Parameter time: The playback timestamp to inspect.
    /// - Returns: The matching `AKChapter`, or `nil` if not found.
    public func currentChapter(at time: CMTime) -> AKChapter? {
        let currentChapters = chapters
        guard !currentChapters.isEmpty, time.isValid, !time.isIndefinite else { return nil }
        return currentChapters.first { $0.contains(time: time) }
    }

    /// Returns the 1-based chapter number at the specified playback timestamp.
    /// - Parameter time: The playback timestamp to inspect.
    /// - Returns: The 1-based chapter number, or `nil` if not found.
    public func currentChapterNumber(at time: CMTime) -> Int? {
        currentChapter(at: time)?.id
    }

    /// Returns the title of the chapter at the specified playback timestamp.
    /// - Parameter time: The playback timestamp to inspect.
    /// - Returns: The chapter title, or `nil` if not found.
    public func chapterTitle(at time: CMTime) -> String? {
        currentChapter(at: time)?.title
    }

    /// Returns the chapter at the specified zero-based index.
    /// - Parameter index: The zero-based chapter index.
    /// - Returns: The `AKChapter` at the index, or `nil` if out of bounds.
    public func chapter(at index: Int) -> AKChapter? {
        let currentChapters = chapters
        guard index >= 0, index < currentChapters.count else { return nil }
        return currentChapters[index]
    }

    /// Returns the chapter matching the specified 1-based chapter number.
    /// - Parameter number: The 1-based chapter number.
    /// - Returns: The matching `AKChapter`, or `nil` if not found.
    public func chapter(byNumber number: Int) -> AKChapter? {
        let currentChapters = chapters
        return currentChapters.first { $0.id == number }
    }

    /// Returns the chapter immediately following the one at the specified timestamp.
    /// - Parameter time: The reference playback timestamp.
    /// - Returns: The next sequential `AKChapter`, or `nil` if at the last chapter.
    public func nextChapter(from time: CMTime) -> AKChapter? {
        let currentChapters = chapters
        guard !currentChapters.isEmpty,
              let active = currentChapter(at: time),
              active.index + 1 < currentChapters.count
        else { return nil }
        return currentChapters[active.index + 1]
    }

    /// Returns the chapter immediately preceding the one at the specified timestamp.
    /// - Parameter time: The reference playback timestamp.
    /// - Returns: The previous sequential `AKChapter`, or `nil` if at the first chapter.
    public func previousChapter(from time: CMTime) -> AKChapter? {
        let currentChapters = chapters
        guard !currentChapters.isEmpty,
              let active = currentChapter(at: time),
              active.index - 1 >= 0
        else { return nil }
        return currentChapters[active.index - 1]
    }

    // MARK: - Playback Tracking

    /// Updates the active chapter state for the specified playback timestamp and notifies observers
    /// if it changed.
    /// - Parameter time: The current playback timestamp.
    public func updateCurrentTime(_ time: CMTime) {
        let matchingChapter = currentChapter(at: time)

        let shouldBroadcast: Bool = state.withLock { s in
            if s.currentChapter != matchingChapter {
                s.currentChapter = matchingChapter
                return true
            }
            return false
        }

        if shouldBroadcast {
            currentChapterBroadcaster.send(matchingChapter)
        }
    }

    // MARK: - Lifecycle

    /// Asynchronously extracts chapter metadata groups from the media asset.
    public func loadChapters() async {
        guard let asset = mediaManager?.asset else { return }

        let task = Task { [weak self] in
            guard let self else { return }
            await extractChapters(from: asset)
        }

        state.withLock {
            $0.loadTask?.cancel()
            $0.loadTask = task
        }

        await task.value
    }

    /// Clears all loaded chapters and active tracking state.
    public func resetSession() {
        state.withLock {
            $0.loadTask?.cancel()
            $0.loadTask = nil
            $0.chapters = []
            $0.currentChapter = nil
        }

        chaptersBroadcaster.send([])
        currentChapterBroadcaster.send(nil)
    }

    // MARK: - Private Extraction

    /// Asynchronously loads timed metadata groups from an `AVAsset` and builds `AKChapter` models.
    /// - Parameter asset: The `AVAsset` containing timed metadata tracks.
    private func extractChapters(from asset: AVAsset) async {
        guard let languages = try? await asset.load(.availableChapterLocales) else { return }
        guard !Task.isCancelled else { return }

        var rawGroups: [AVTimedMetadataGroup] = []

        if let preferred = languages.first {
            if let groups = try? await asset.loadChapterMetadataGroups(
                withTitleLocale: preferred,
                containingItemsWithCommonKeys: [.commonKeyTitle, .commonKeyArtwork]
            ) {
                rawGroups = groups
            }
        }

        if rawGroups.isEmpty, languages.isEmpty {
            // Fallback for assets with default locale
            if let groups = try? await asset.loadChapterMetadataGroups(
                withTitleLocale: Locale.current,
                containingItemsWithCommonKeys: [.commonKeyTitle, .commonKeyArtwork]
            ) {
                rawGroups = groups
            }
        }

        guard !rawGroups.isEmpty, !Task.isCancelled else { return }

        var parsedChapters: [AKChapter] = []
        await withTaskGroup(of: AKChapter?.self) { group in
            for (index, groupItem) in rawGroups.enumerated() {
                group.addTask {
                    guard !Task.isCancelled else { return nil }
                    var chapterTitle: String?
                    var artworkData: Data?
                    var artworkImage: UIImage?

                    for item in groupItem.items {
                        if item.commonKey == .commonKeyTitle || item
                            .identifier == .commonIdentifierTitle
                        {
                            chapterTitle = try? await item.load(.stringValue)
                        } else if item.commonKey == .commonKeyArtwork || item
                            .identifier == .commonIdentifierArtwork
                        {
                            if let data = try? await item.load(.dataValue) {
                                artworkData = data
                                artworkImage = UIImage(data: data)
                            }
                        }
                    }

                    let finalTitle = chapterTitle ?? "Chapter \(index + 1)"
                    return AKChapter(
                        id: index + 1,
                        index: index,
                        title: finalTitle,
                        timeRange: groupItem.timeRange,
                        artworkImage: artworkImage,
                        artworkData: artworkData
                    )
                }
            }

            for await chapter in group {
                if let chapter {
                    parsedChapters.append(chapter)
                }
            }
        }

        parsedChapters.sort { $0.index < $1.index }

        guard !Task.isCancelled else { return }

        state.withLock {
            $0.chapters = parsedChapters
        }

        chaptersBroadcaster.send(parsedChapters)
    }
}
