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
import UIKit

// MARK: - AKChapterService

/// Thread-safe service responsible for extracting, querying, and observing media chapters.
public final class AKChapterService: AKChapterServiceProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Weak reference to the parent media manager.
    private weak var mediaManager: (any AKMediaManagerProtocol)?
    
    private struct State {
        var chapters: [AKChapter] = []
        var currentChapter: AKChapter?
        var loadTask: Task<Void, Never>?
    }
    
    private let state = Mutex(State())
    
    public var chapters: [AKChapter] {
        state.withLock { $0.chapters }
    }
    
    public var chapterCount: Int {
        state.withLock { $0.chapters.count }
    }
    
    public var currentChapter: AKChapter? {
        state.withLock { $0.currentChapter }
    }
    
    public var creditsStartTime: Double? {
        chapters.first(where: {
            let title = $0.title.lowercased()
            return title.contains("credit") || title.contains("outro") || title.contains("closing")
        })?.startTime
    }
    
    // MARK: - Async Streams
    
    public var chaptersUpdates: AsyncStream<[AKChapter]> {
        chaptersBroadcaster.makeStream()
    }
    
    public var currentChapterUpdates: AsyncStream<AKChapter?> {
        currentChapterBroadcaster.makeStream()
    }
    
    // MARK: - Broadcasters
    
    private let chaptersBroadcaster = AKEventBroadcaster<[AKChapter]>()
    private let currentChapterBroadcaster = AKEventBroadcaster<AKChapter?>()
    
    // MARK: - Initialization
    
    public init(mediaManager: any AKMediaManagerProtocol) {
        self.mediaManager = mediaManager
    }
    
    deinit {
        state.withLock { $0.loadTask?.cancel() }
        chaptersBroadcaster.finish()
        currentChapterBroadcaster.finish()
    }
    
    // MARK: - Chapter Queries
    
    public func currentChapter(at time: CMTime) -> AKChapter? {
        let currentChapters = chapters
        guard !currentChapters.isEmpty, time.isValid, !time.isIndefinite else { return nil }
        return currentChapters.first { $0.contains(time: time) }
    }
    
    public func currentChapterNumber(at time: CMTime) -> Int? {
        currentChapter(at: time)?.id
    }
    
    public func chapterTitle(at time: CMTime) -> String? {
        currentChapter(at: time)?.title
    }
    
    public func chapter(at index: Int) -> AKChapter? {
        let currentChapters = chapters
        guard index >= 0, index < currentChapters.count else { return nil }
        return currentChapters[index]
    }
    
    public func chapter(byNumber number: Int) -> AKChapter? {
        let currentChapters = chapters
        return currentChapters.first { $0.id == number }
    }
    
    public func nextChapter(from time: CMTime) -> AKChapter? {
        let currentChapters = chapters
        guard !currentChapters.isEmpty,
              let active = currentChapter(at: time),
              active.index + 1 < currentChapters.count
        else { return nil }
        return currentChapters[active.index + 1]
    }
    
    public func previousChapter(from time: CMTime) -> AKChapter? {
        let currentChapters = chapters
        guard !currentChapters.isEmpty,
              let active = currentChapter(at: time),
              active.index - 1 >= 0
        else { return nil }
        return currentChapters[active.index - 1]
    }
    
    // MARK: - Playback Tracking
    
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
    
    public func loadChapters() async {
        guard let asset = mediaManager?.asset else { return }
        
        let task = Task { [weak self] in
            guard let self else { return }
            await self.extractChapters(from: asset)
        }
        
        state.withLock {
            $0.loadTask?.cancel()
            $0.loadTask = task
        }
        
        await task.value
    }
    
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
        
        if rawGroups.isEmpty && languages.isEmpty {
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
                        if item.commonKey == .commonKeyTitle || item.identifier == .commonIdentifierTitle {
                            chapterTitle = try? await item.load(.stringValue)
                        } else if item.commonKey == .commonKeyArtwork || item.identifier == .commonIdentifierArtwork {
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
