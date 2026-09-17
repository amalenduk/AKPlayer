//
//  AKMediaMetadataProvider.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 15/09/26.
//

@preconcurrency import AVFoundation
import Foundation
import MediaPlayer
import Synchronization

extension AVTimedMetadataGroup: @unchecked Sendable {}

public protocol AKMediaMetadataProviderProtocol: AnyObject, Sendable {
    
    // MARK: - Static Metadata
    
    var staticMetadata: AKMediaStaticMetadata { get }
    
    /// Manually override / merge static metadata (e.g. from your own model)
    func updateStaticMetadata(_ metadata: AKMediaStaticMetadata)
    
    // MARK: - Chapters
    
    var chapters: [AVTimedMetadataGroup] { get }
    var chapterCount: Int? { get }
    
    func currentChapterNumber(at time: CMTime) -> Int?
    func chapterTitle(at time: CMTime) -> String?
    
    // MARK: - Async Streams
    
    var staticMetadataUpdates: AsyncStream<AKMediaStaticMetadata> { get }
    var chaptersUpdates: AsyncStream<[AVTimedMetadataGroup]> { get }
    
    // MARK: - Lifecycle (called by MediaManager)
    
    /// Load metadata from the current player item’s asset.
    /// Safe to call multiple times – previous load is cancelled.
    func loadMetadata() async
    
    /// Clear everything when media is replaced or aborted.
    func resetSession()
}

public final class AKMediaMetadataProvider: AKMediaMetadataProviderProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Weak reference to the parent media manager
    private weak var mediaManager: (any AKMediaManagerProtocol)?
    
    private struct State {
        var staticMetadata = AKMediaStaticMetadata()
        var chapters: [AVTimedMetadataGroup] = []
        var loadTask: Task<Void, Never>?
    }
    
    private let state = Mutex(State())
    
    public var staticMetadata: AKMediaStaticMetadata {
        state.withLock { $0.staticMetadata }
    }
    
    public var chapters: [AVTimedMetadataGroup] {
        state.withLock { $0.chapters }
    }
    
    public var chapterCount: Int? {
        state.withLock { $0.chapters.isEmpty ? nil : $0.chapters.count }
    }
    
    public var staticMetadataUpdates: AsyncStream<AKMediaStaticMetadata> {
        staticMetadataBroadcaster.makeStream()
    }
    
    public var chaptersUpdates: AsyncStream<[AVTimedMetadataGroup]> {
        chaptersBroadcaster.makeStream()
    }
    
    // MARK: - Broadcasters
    
    private let staticMetadataBroadcaster = AKEventBroadcaster<AKMediaStaticMetadata>()
    private let chaptersBroadcaster = AKEventBroadcaster<[AVTimedMetadataGroup]>()
    
    private var playerItem: AVPlayerItem? {
        mediaManager?.playerItem
    }
    
    // MARK: - Initialization
    
    public init(mediaManager: any AKMediaManagerProtocol) {
        self.mediaManager = mediaManager
    }
    
    deinit {
        state.withLock { $0.loadTask?.cancel() }
        staticMetadataBroadcaster.finish()
        chaptersBroadcaster.finish()
    }
    
    // MARK: - Public API
    
    public func updateStaticMetadata(_ metadata: AKMediaStaticMetadata) {
        let merged = state.withLock { s -> AKMediaStaticMetadata in
            var updated = s.staticMetadata
            if let v = metadata.title { updated.title = v }
            if let v = metadata.artist { updated.artist = v }
            if let v = metadata.albumTitle { updated.albumTitle = v }
            if let v = metadata.albumArtist { updated.albumArtist = v }
            if let v = metadata.genre { updated.genre = v }
            if let v = metadata.composer { updated.composer = v }
            if let v = metadata.artwork { updated.artwork = v }
            if let v = metadata.artworkImage { updated.artworkImage = v }
            if let v = metadata.trackNumber { updated.trackNumber = v }
            if let v = metadata.trackCount { updated.trackCount = v }
            if let v = metadata.discNumber { updated.discNumber = v }
            if let v = metadata.discCount { updated.discCount = v }
            if let v = metadata.releaseDate { updated.releaseDate = v }
            if let v = metadata.isExplicit { updated.isExplicit = v }
            if let v = metadata.assetURL { updated.assetURL = v }
            if let v = metadata.mediaType { updated.mediaType = v }
            
            // Create MPMediaItemArtwork if we only received a UIImage
            if updated.artwork == nil, let image = updated.artworkImage {
                updated.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
            
            s.staticMetadata = updated
            return updated
        }
        
        staticMetadataBroadcaster.send(merged)
    }
    
    public func currentChapterNumber(at time: CMTime) -> Int? {
        let currentChapters = chapters
        guard !currentChapters.isEmpty, time.isValid, !time.isIndefinite else { return nil }
        
        for (index, group) in currentChapters.enumerated() {
            if group.timeRange.containsTime(time) {
                return index + 1          // 1-based
            }
        }
        return nil
    }
    
    public func chapterTitle(at time: CMTime) -> String? {
        let currentChapters = chapters
        guard !currentChapters.isEmpty else { return nil }
        
        for group in currentChapters where group.timeRange.containsTime(time) {
            let titles = AVMetadataItem.metadataItems(
                from: group.items,
                filteredByIdentifier: .commonIdentifierTitle
            )
            return titles.first?.stringValue
        }
        return nil
    }
    
    // MARK: - Lifecycle (called by MediaManager)
    
    public func loadMetadata() async {
        guard let asset = mediaManager?.asset else { return }
        
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadCommonMetadata(from: asset)
            await self.loadChapters(from: asset)
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
            $0.staticMetadata = AKMediaStaticMetadata()
        }
        
        chaptersBroadcaster.send([])
        staticMetadataBroadcaster.send(AKMediaStaticMetadata())
    }
    
    // MARK: - Private loading
    
    private func loadCommonMetadata(from asset: AVAsset) async {
        // Asynchronously load common metadata items
        guard let items = try? await asset.load(.commonMetadata) else { return }
        guard !Task.isCancelled else { return }
        
        var meta = AKMediaStaticMetadata()
        for item in items {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                meta.title = try? await item.load(.stringValue)
            case .commonKeyArtist:
                meta.artist = try? await item.load(.stringValue)
            case .commonKeyAlbumName:
                meta.albumTitle = try? await item.load(.stringValue)
            case .commonKeyAuthor:
                meta.composer = try? await item.load(.stringValue)
            default:
                break
            }
        }
        
        updateStaticMetadata(meta)
    }
    
    private func loadChapters(from asset: AVAsset) async {
        guard let languages = try? await asset.load(.availableChapterLocales) else { return }
        guard !Task.isCancelled else { return }
        
        if let preferred = languages.first,
           let chapterGroups = try? await asset.loadChapterMetadataGroups(withTitleLocale: preferred, containingItemsWithCommonKeys: [.commonKeyTitle]) {
            state.withLock { $0.chapters = chapterGroups }
            chaptersBroadcaster.send(chapterGroups)
        }
    }
}
