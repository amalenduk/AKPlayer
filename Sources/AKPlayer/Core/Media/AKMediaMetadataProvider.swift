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
import UIKit

extension AVMetadataItem: @retroactive @unchecked Sendable {}
extension AVTimedMetadataGroup: @retroactive @unchecked Sendable {}

// MARK: - AKMediaMetadataProviderProtocol

/// Protocol defining static container metadata extraction, live stream timed metadata, and updates.
public protocol AKMediaMetadataProviderProtocol: AnyObject, Sendable {
    
    // MARK: - Static Metadata
    
    /// The currently loaded static container metadata.
    var staticMetadata: AKMediaStaticMetadata { get }
    
    /// Manually updates / merges static metadata (e.g. from backend API or custom models).
    func updateStaticMetadata(_ metadata: AKMediaStaticMetadata)
    
    // MARK: - Timed Stream Metadata
    
    /// The latest timed metadata items received from live streams or HLS broadcasts.
    var timedMetadata: [AVMetadataItem] { get }
    
    /// Ingests dynamic timed metadata groups received from player item outputs.
    func handleTimedMetadata(_ items: [AVMetadataItem])
    
    // MARK: - Async Streams
    
    /// Stream emitting updates whenever static metadata is loaded or manually updated.
    var staticMetadataUpdates: AsyncStream<AKMediaStaticMetadata> { get }
    
    /// Stream emitting dynamic timed metadata updates from live streams (e.g. radio song changes).
    var timedMetadataUpdates: AsyncStream<[AVMetadataItem]> { get }
    
    // MARK: - Lifecycle
    
    /// Asynchronously extracts common and format-specific metadata from the active asset.
    func loadMetadata() async
    
    /// Clears all loaded metadata and cancels active tasks.
    func resetSession()
}

// MARK: - AKMediaMetadataProvider

/// Thread-safe provider extracting Common, ID3, and iTunes metadata from media assets and streams.
public final class AKMediaMetadataProvider: AKMediaMetadataProviderProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Weak reference to the parent media manager.
    private weak var mediaManager: (any AKMediaManagerProtocol)?
    
    private struct State {
        var staticMetadata = AKMediaStaticMetadata()
        var timedMetadata: [AVMetadataItem] = []
        var loadTask: Task<Void, Never>?
    }
    
    private let state = Mutex(State())
    
    public var staticMetadata: AKMediaStaticMetadata {
        state.withLock { $0.staticMetadata }
    }
    
    public var timedMetadata: [AVMetadataItem] {
        state.withLock { $0.timedMetadata }
    }
    
    public var staticMetadataUpdates: AsyncStream<AKMediaStaticMetadata> {
        staticMetadataBroadcaster.makeStream()
    }
    
    public var timedMetadataUpdates: AsyncStream<[AVMetadataItem]> {
        timedMetadataBroadcaster.makeStream()
    }
    
    // MARK: - Broadcasters
    
    private let staticMetadataBroadcaster = AKEventBroadcaster<AKMediaStaticMetadata>()
    private let timedMetadataBroadcaster = AKEventBroadcaster<[AVMetadataItem]>()
    
    // MARK: - Initialization
    
    public init(mediaManager: any AKMediaManagerProtocol) {
        self.mediaManager = mediaManager
    }
    
    deinit {
        state.withLock { $0.loadTask?.cancel() }
        staticMetadataBroadcaster.finish()
        timedMetadataBroadcaster.finish()
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
            if let v = metadata.descriptionText { updated.descriptionText = v }
            if let v = metadata.copyrights { updated.copyrights = v }
            if let v = metadata.publisher { updated.publisher = v }
            if let v = metadata.creationDate { updated.creationDate = v }
            if let v = metadata.language { updated.language = v }
            if let v = metadata.isLiveStream { updated.isLiveStream = v }
            if let v = metadata.chapterCount { updated.chapterCount = v }
            if let v = metadata.creditsStartTime { updated.creditsStartTime = v }
            if let v = metadata.serviceIdentifier { updated.serviceIdentifier = v }
            
            // Generate MPMediaItemArtwork if image is present without artwork
            if updated.artwork == nil, let image = updated.artworkImage {
                let size = (image.size.width > 0 && image.size.height > 0) ? image.size : CGSize(width: 300, height: 300)
                updated.artwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
            }
            
            s.staticMetadata = updated
            return updated
        }
        
        staticMetadataBroadcaster.send(merged)
    }
    
    public func handleTimedMetadata(_ items: [AVMetadataItem]) {
        state.withLock { $0.timedMetadata = items }
        timedMetadataBroadcaster.send(items)
        
        // Auto-extract real-time title / artist changes for live streams (e.g. Internet radio ID3)
        Task { [weak self] in
            guard let self else { return }
            var streamTitle: String?
            var streamArtist: String?
            
            for item in items {
                if item.commonKey == .commonKeyTitle || item.identifier == .commonIdentifierTitle {
                    streamTitle = try? await item.load(.stringValue)
                } else if item.commonKey == .commonKeyArtist || item.identifier == .commonIdentifierArtist {
                    streamArtist = try? await item.load(.stringValue)
                } else if let key = item.key as? String {
                    if key == "TIT2" || key == "©nam" {
                        streamTitle = try? await item.load(.stringValue)
                    } else if key == "TPE1" || key == "©ART" {
                        streamArtist = try? await item.load(.stringValue)
                    }
                }
            }
            
            if streamTitle != nil || streamArtist != nil {
                var update = AKMediaStaticMetadata()
                update.title = streamTitle
                update.artist = streamArtist
                self.updateStaticMetadata(update)
            }
        }
    }
    
    // MARK: - Lifecycle
    
    public func loadMetadata() async {
        guard let asset = mediaManager?.asset else { return }
        
        let task = Task { [weak self] in
            guard let self else { return }
            await self.loadCommonMetadata(from: asset)
            await self.loadFormatSpecificMetadata(from: asset)
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
            $0.staticMetadata = AKMediaStaticMetadata()
            $0.timedMetadata = []
        }
        
        staticMetadataBroadcaster.send(AKMediaStaticMetadata())
        timedMetadataBroadcaster.send([])
    }
    
    // MARK: - Private Loading
    
    private func loadCommonMetadata(from asset: AVAsset) async {
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
            case .commonKeyArtwork:
                if let data = try? await item.load(.dataValue), let image = UIImage(data: data) {
                    meta.artworkImage = image
                    let size = (image.size.width > 0 && image.size.height > 0) ? image.size : CGSize(width: 300, height: 300)
                    meta.artwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
                }
            case .commonKeySubject:
                meta.genre = try? await item.load(.stringValue)
            case .commonKeyDescription:
                meta.descriptionText = try? await item.load(.stringValue)
            case .commonKeyCreationDate:
                if let date = try? await item.load(.dateValue) {
                    meta.releaseDate = date
                } else if let str = try? await item.load(.stringValue) {
                    meta.creationDate = str
                }
            case .commonKeyCopyrights:
                meta.copyrights = try? await item.load(.stringValue)
            case .commonKeyPublisher:
                meta.publisher = try? await item.load(.stringValue)
            case .commonKeyLanguage:
                meta.language = try? await item.load(.stringValue)
            default:
                break
            }
        }
        
        guard !Task.isCancelled else { return }
        updateStaticMetadata(meta)
    }
    
    private func loadFormatSpecificMetadata(from asset: AVAsset) async {
        guard let items = try? await asset.load(.metadata) else { return }
        guard !Task.isCancelled else { return }
        
        var meta = AKMediaStaticMetadata()
        
        for item in items {
            guard !Task.isCancelled else { return }
            
            let keySpace = item.keySpace
            let keyString = item.key as? String ?? item.identifier?.rawValue
            
            if keySpace == .id3 || keySpace?.rawValue == "org.id3" {
                await parseID3Item(item, keyString: keyString, into: &meta)
            } else if keySpace == .iTunes || keySpace?.rawValue == "itsk" {
                await parseITunesItem(item, keyString: keyString, into: &meta)
            } else if keySpace == .quickTimeUserData || keySpace == .quickTimeMetadata {
                await parseQuickTimeItem(item, keyString: keyString, into: &meta)
            }
        }
        
        guard !Task.isCancelled else { return }
        updateStaticMetadata(meta)
    }
    
    // MARK: - Format Parsers
    
    private func parseID3Item(_ item: AVMetadataItem, keyString: String?, into meta: inout AKMediaStaticMetadata) async {
        guard let key = keyString else { return }
        
        switch key {
        case "TIT2" where meta.title == nil:
            meta.title = try? await item.load(.stringValue)
        case "TPE1" where meta.artist == nil:
            meta.artist = try? await item.load(.stringValue)
        case "TPE2" where meta.albumArtist == nil:
            meta.albumArtist = try? await item.load(.stringValue)
        case "TALB" where meta.albumTitle == nil:
            meta.albumTitle = try? await item.load(.stringValue)
        case "TCOM" where meta.composer == nil:
            meta.composer = try? await item.load(.stringValue)
        case "TCON" where meta.genre == nil:
            meta.genre = try? await item.load(.stringValue)
        case "TRCK" where meta.trackNumber == nil:
            if let trackString = try? await item.load(.stringValue) {
                let parts = trackString.split(separator: "/")
                if let first = parts.first, let num = Int(first.trimmingCharacters(in: .whitespaces)) {
                    meta.trackNumber = num
                }
                if parts.count > 1, let total = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    meta.trackCount = total
                }
            }
        case "TPOS" where meta.discNumber == nil:
            if let discString = try? await item.load(.stringValue) {
                let parts = discString.split(separator: "/")
                if let first = parts.first, let num = Int(first.trimmingCharacters(in: .whitespaces)) {
                    meta.discNumber = num
                }
                if parts.count > 1, let total = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    meta.discCount = total
                }
            }
        case "TYER", "TDRC":
            if meta.releaseDate == nil {
                if let date = try? await item.load(.dateValue) {
                    meta.releaseDate = date
                } else if let yearString = try? await item.load(.stringValue) {
                    meta.creationDate = yearString
                }
            }
        case "COMM" where meta.descriptionText == nil:
            meta.descriptionText = try? await item.load(.stringValue)
        case "APIC" where meta.artworkImage == nil:
            if let data = try? await item.load(.dataValue), let image = UIImage(data: data) {
                meta.artworkImage = image
                let size = (image.size.width > 0 && image.size.height > 0) ? image.size : CGSize(width: 300, height: 300)
                meta.artwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
            }
        default:
            break
        }
    }
    
    private func parseITunesItem(_ item: AVMetadataItem, keyString: String?, into meta: inout AKMediaStaticMetadata) async {
        guard let key = keyString else { return }
        
        switch key {
        case "©nam", "@nam":
            if meta.title == nil {
                meta.title = try? await item.load(.stringValue)
            }
        case "©ART", "@ART":
            if meta.artist == nil {
                meta.artist = try? await item.load(.stringValue)
            }
        case "aART" where meta.albumArtist == nil:
            meta.albumArtist = try? await item.load(.stringValue)
        case "©alb", "@alb":
            if meta.albumTitle == nil {
                meta.albumTitle = try? await item.load(.stringValue)
            }
        case "©gen", "@gen":
            if meta.genre == nil {
                meta.genre = try? await item.load(.stringValue)
            }
        case "©wrt", "@wrt":
            if meta.composer == nil {
                meta.composer = try? await item.load(.stringValue)
            }
        case "©day", "@day":
            if meta.releaseDate == nil {
                if let date = try? await item.load(.dateValue) {
                    meta.releaseDate = date
                } else if let str = try? await item.load(.stringValue) {
                    meta.creationDate = str
                }
            }
        case "desc" where meta.descriptionText == nil:
            meta.descriptionText = try? await item.load(.stringValue)
        case "cprt" where meta.copyrights == nil:
            meta.copyrights = try? await item.load(.stringValue)
        case "covr" where meta.artworkImage == nil:
            if let data = try? await item.load(.dataValue), let image = UIImage(data: data) {
                meta.artworkImage = image
                let size = (image.size.width > 0 && image.size.height > 0) ? image.size : CGSize(width: 300, height: 300)
                meta.artwork = MPMediaItemArtwork(boundsSize: size) { _ in image }
            }
        case "trkn" where meta.trackNumber == nil:
            if let data = try? await item.load(.dataValue), data.count >= 6 {
                // Bytes 2-3 are track number, bytes 4-5 are track count (big-endian 16-bit integers)
                let trackNum = Int(data[2]) << 8 | Int(data[3])
                let trackTotal = Int(data[4]) << 8 | Int(data[5])
                if trackNum > 0 { meta.trackNumber = trackNum }
                if trackTotal > 0 { meta.trackCount = trackTotal }
            }
        case "disk" where meta.discNumber == nil:
            if let data = try? await item.load(.dataValue), data.count >= 6 {
                let discNum = Int(data[2]) << 8 | Int(data[3])
                let discTotal = Int(data[4]) << 8 | Int(data[5])
                if discNum > 0 { meta.discNumber = discNum }
                if discTotal > 0 { meta.discCount = discTotal }
            }
        default:
            break
        }
    }
    
    private func parseQuickTimeItem(_ item: AVMetadataItem, keyString: String?, into meta: inout AKMediaStaticMetadata) async {
        guard let key = keyString else { return }
        
        switch key {
        case "©nam" where meta.title == nil:
            meta.title = try? await item.load(.stringValue)
        case "©ART" where meta.artist == nil:
            meta.artist = try? await item.load(.stringValue)
        case "©alb" where meta.albumTitle == nil:
            meta.albumTitle = try? await item.load(.stringValue)
        case "©gen" where meta.genre == nil:
            meta.genre = try? await item.load(.stringValue)
        case "©des", "dscp":
            if meta.descriptionText == nil {
                meta.descriptionText = try? await item.load(.stringValue)
            }
        case "cprt" where meta.copyrights == nil:
            meta.copyrights = try? await item.load(.stringValue)
        default:
            break
        }
    }
}
