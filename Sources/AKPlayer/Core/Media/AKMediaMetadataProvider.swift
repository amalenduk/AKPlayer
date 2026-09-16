//
//  AKMediaMetadataProvider.swift.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 15/09/26.
//

import AVFoundation
import Combine
import MediaPlayer

// Sources/AKPlayer/Core/Media/AKMediaMetadataProviderProtocol.swift

import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
public protocol AKMediaMetadataProviderProtocol: AnyObject {
    
    // MARK: - Static Metadata
    
    var staticMetadata: AKMediaStaticMetadata { get }
    
    /// Manually override / merge static metadata (e.g. from your own model)
    func updateStaticMetadata(_ metadata: AKMediaStaticMetadata)
    
    // MARK: - Chapters
    
    var chapters: [AVTimedMetadataGroup] { get }
    var chapterCount: Int? { get }
    
    func currentChapterNumber(at time: CMTime) -> Int?
    func chapterTitle(at time: CMTime) -> String?
    
    // MARK: - Publishers
    
    var staticMetadataPublisher: AnyPublisher<AKMediaStaticMetadata, Never> { get }
    var chaptersPublisher: AnyPublisher<[AVTimedMetadataGroup], Never> { get }
    
    // MARK: - Lifecycle (called by MediaManager)
    
    /// Load metadata from the current player item’s asset.
    /// Safe to call multiple times – previous load is cancelled.
    func loadMetadata() async
    
    /// Clear everything when media is replaced or aborted.
    func resetSession()
}

@MainActor
public final class AKMediaMetadataProvider: AKMediaMetadataProviderProtocol {
    
    // MARK: - Properties
    
    /// Weak reference to the parent media manager (same pattern as TrackSelectionService)
    private weak var mediaManager: (any AKMediaManagerProtocol)?
    
    public private(set) var staticMetadata = AKMediaStaticMetadata()
    public private(set) var chapters: [AVTimedMetadataGroup] = []
    
    public var chapterCount: Int? {
        chapters.isEmpty ? nil : chapters.count
    }
    
    public var staticMetadataPublisher: AnyPublisher<AKMediaStaticMetadata, Never> {
        staticMetadataSubject.eraseToAnyPublisher()
    }
    
    public var chaptersPublisher: AnyPublisher<[AVTimedMetadataGroup], Never> {
        chaptersSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private
    
    private let staticMetadataSubject = CurrentValueSubject<AKMediaStaticMetadata, Never>(.init())
    private let chaptersSubject = CurrentValueSubject<[AVTimedMetadataGroup], Never>([])
    
    private var loadTask: Task<Void, Never>?
    
    private var playerItem: AVPlayerItem? {
        mediaManager?.playerItem
    }
    
    private var subscriptions: Set<AnyCancellable>?
    
    // MARK: - Initialization
    
    public init(mediaManager: any AKMediaManagerProtocol) {
        self.mediaManager = mediaManager
    }
    
    deinit {
        loadTask?.cancel()
    }
    
    // MARK: - Public API
    
    public func updateStaticMetadata(_ metadata: AKMediaStaticMetadata) {
        var merged = staticMetadata
        
        if let v = metadata.title { merged.title = v }
        if let v = metadata.artist { merged.artist = v }
        if let v = metadata.albumTitle { merged.albumTitle = v }
        if let v = metadata.albumArtist { merged.albumArtist = v }
        if let v = metadata.genre { merged.genre = v }
        if let v = metadata.composer { merged.composer = v }
        if let v = metadata.artwork { merged.artwork = v }
        if let v = metadata.artworkImage { merged.artworkImage = v }
        if let v = metadata.trackNumber { merged.trackNumber = v }
        if let v = metadata.trackCount { merged.trackCount = v }
        if let v = metadata.discNumber { merged.discNumber = v }
        if let v = metadata.discCount { merged.discCount = v }
        if let v = metadata.releaseDate { merged.releaseDate = v }
        if let v = metadata.isExplicit { merged.isExplicit = v }
        if let v = metadata.assetURL { merged.assetURL = v }
        if let v = metadata.mediaType { merged.mediaType = v }
        
        // Create MPMediaItemArtwork if we only received a UIImage
        if merged.artwork == nil, let image = merged.artworkImage {
            merged.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        staticMetadata = merged
        staticMetadataSubject.send(merged)
    }
    
    public func currentChapterNumber(at time: CMTime) -> Int? {
        guard !chapters.isEmpty, time.isValid, !time.isIndefinite else { return nil }
        
        for (index, group) in chapters.enumerated() {
            if group.timeRange.containsTime(time) {
                return index + 1          // 1-based
            }
        }
        return nil
    }
    
    public func chapterTitle(at time: CMTime) -> String? {
        guard !chapters.isEmpty else { return nil }
        
        for group in chapters where group.timeRange.containsTime(time) {
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
        
    }
    
    public func resetSession() {
        loadTask?.cancel()
        loadTask = nil
        
        chapters = []
        staticMetadata = AKMediaStaticMetadata()
        
        chaptersSubject.send([])
        staticMetadataSubject.send(staticMetadata)
    }
    
    // MARK: - Private loading
    
    private func loadCommonMetadata(from asset: AVAsset) async {
        
    }
    
    private func loadChapters(from asset: AVAsset) async {
        
    }
}
