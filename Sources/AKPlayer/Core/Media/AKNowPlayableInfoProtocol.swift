//
//   AKNowPlayableInfoProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation
import MediaPlayer
import UIKit

// MARK: - Now Playable Info Protocol

/// A protocol bridging static and dynamic metadata payload sources for `MPNowPlayingInfoCenter`.
public protocol AKNowPlayableInfoProtocol: Sendable {
    /// The static metadata describing the media asset (e.g., title, artist, artwork).
    var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? { get set }
    
    /// The dynamic metadata reflecting live playback state (e.g., position, rate, duration).
    var dynamicMetadata: (any AKNowPlayableDynamicMetadataProtocol)? { get set }
}

public extension AKNowPlayableInfoProtocol {
    /// Generates a consolidated dictionary suitable for populating `MPNowPlayingInfoCenter.nowPlayingInfo`.
    /// - Returns: A merged dictionary containing both static and dynamic metadata keys, or `nil` if both are empty.
    func getNowPlayingInfo() -> [String: Any]? {
        let staticInfo = staticMetadata?.getNowPlayableStaticMetadata()
        let dynamicInfo = dynamicMetadata?.getNowPlayableDynamicMetadata()
        
        guard staticInfo != nil || dynamicInfo != nil else { return nil }
        
        var merged = staticInfo ?? [:]
        if let dynamicInfo {
            merged.merge(dynamicInfo) { _, new in new }
        }
        return merged
    }
}

// MARK: - Artwork Payload

/// Represents the visual artwork source associated with a media item.
public enum Artwork: Equatable, @unchecked Sendable {
    /// Standard `UIImage` asset.
    case image(UIImage)
    
    /// Raw binary image data.
    case data(Data)
    
    /// An explicit system `MPMediaItemArtwork` instance.
    case artwork(MPMediaItemArtwork)
}

// MARK: - Static Metadata Protocol

/// A protocol defining immutable or rarely changed metadata properties for Now Playing displays.
public protocol AKNowPlayableStaticMetadataProtocol: Sendable {
    /// Destination asset URL (`MPNowPlayingInfoPropertyAssetURL`).
    var assetURL: URL { get set }
    
    /// Media type classification (`MPNowPlayingInfoPropertyMediaType`).
    var mediaType: MPNowPlayingInfoMediaType { get set }
    
    /// Indicates if the item is a live stream (`MPNowPlayingInfoPropertyIsLiveStream`).
    var isLiveStream: Bool { get set }
    
    /// The primary title (`MPMediaItemPropertyTitle`).
    var title: String { get set }
    
    /// The primary artist (`MPMediaItemPropertyArtist`).
    var artist: String? { get set }
    
    /// Associated media artwork source (`MPMediaItemPropertyArtwork`).
    var artwork: Artwork? { get set }
    
    /// The album artist (`MPMediaItemPropertyAlbumArtist`).
    var albumArtist: String? { get set }
    
    /// The album title (`MPMediaItemPropertyAlbumTitle`).
    var albumTitle: String? { get set }
    
    /// Collection identifier (`MPNowPlayingInfoCollectionIdentifier`).
    var collectionIdentifier: String? { get set }
    
    /// External content identifier (`MPNowPlayingInfoPropertyExternalContentIdentifier`).
    var externalContentIdentifier: String? { get set }
    
    /// External user profile identifier (`MPNowPlayingInfoPropertyExternalUserProfileIdentifier`).
    var externalUserProfileIdentifier: String? { get set }
    
    /// Time ranges for advertisements (`MPNowPlayingInfoPropertyAdTimeRanges`).
    var adTimeRanges: [MPAdTimeRange]? { get set }
}

// Default Optional Property Stubs
public extension AKNowPlayableStaticMetadataProtocol {
    var artist: String? { get { nil } set {} }
    var artwork: Artwork? { get { nil } set {} }
    var albumArtist: String? { get { nil } set {} }
    var albumTitle: String? { get { nil } set {} }
    var collectionIdentifier: String? { get { nil } set {} }
    var externalContentIdentifier: String? { get { nil } set {} }
    var externalUserProfileIdentifier: String? { get { nil } set {} }
    var adTimeRanges: [MPAdTimeRange]? { get { nil } set {} }
}

public extension AKNowPlayableStaticMetadataProtocol {
    /// Computes or retrieves the standard `MPMediaItemArtwork` representation.
    var itemArtwork: MPMediaItemArtwork? {
        guard let artwork else { return nil }
        switch artwork {
        case let .image(image):
            let boundsSize = (image.size.width > 0 && image.size.height > 0) ? image.size : CGSize(width: 300, height: 300)
            return MPMediaItemArtwork(boundsSize: boundsSize) { _ in image }
        case let .data(data):
            guard let image = UIImage(data: data) else { return nil }
            let boundsSize = (image.size.width > 0 && image.size.height > 0) ? image.size : CGSize(width: 300, height: 300)
            return MPMediaItemArtwork(boundsSize: boundsSize) { _ in image }
        case let .artwork(artwork):
            return artwork
        }
    }
    
    /// Converts all static metadata properties into key-value pairs for `MPNowPlayingInfoCenter`.
    func getNowPlayableStaticMetadata() -> [String: Any] {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = assetURL
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = mediaType.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = isLiveStream
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyAlbumArtist] = albumArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
        nowPlayingInfo[MPNowPlayingInfoCollectionIdentifier] = collectionIdentifier
        nowPlayingInfo[MPNowPlayingInfoPropertyExternalContentIdentifier] = externalContentIdentifier
        nowPlayingInfo[MPNowPlayingInfoPropertyExternalUserProfileIdentifier] = externalUserProfileIdentifier
        
        if let adTimeRanges {
            nowPlayingInfo[MPNowPlayingInfoPropertyAdTimeRanges] = adTimeRanges
        }
        
        if let itemArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = itemArtwork
        }
        
        return nowPlayingInfo
    }
}

// MARK: - Dynamic Metadata Protocol

/// A protocol defining real-time changeable metadata properties for Now Playing displays.
public protocol AKNowPlayableDynamicMetadataProtocol: Sendable {
    /// Current playback speed multiplier (`MPNowPlayingInfoPropertyPlaybackRate`).
    var rate: Double { get set }
    
    /// Default intended playback rate (`MPNowPlayingInfoPropertyDefaultPlaybackRate`).
    var defaultRate: Double { get set }
    
    /// Elapsed playback time in seconds (`MPNowPlayingInfoPropertyElapsedPlaybackTime`).
    var position: Double? { get set }
    
    /// Total duration of the media in seconds (`MPMediaItemPropertyPlaybackDuration`).
    var duration: Float? { get set }
    
    /// Active language options (`MPNowPlayingInfoPropertyCurrentLanguageOptions`).
    var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]? { get set }
    
    /// Available language options (`MPNowPlayingInfoPropertyAvailableLanguageOptions`).
    var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]? { get set }
    
    /// Total chapter count (`MPNowPlayingInfoPropertyChapterCount`).
    var chapterCount: Int? { get set }
    
    /// Current chapter index (`MPNowPlayingInfoPropertyChapterNumber`).
    var chapterNumber: Int? { get set }
    
    /// Start offset for credits (`MPNowPlayingInfoPropertyCreditsStartTime`).
    var creditsStartTime: Double? { get set }
    
    /// Current wall-clock playback timestamp (`MPNowPlayingInfoPropertyCurrentPlaybackDate`).
    var currentPlaybackDate: Date? { get set }
    
    /// Playback completion percentage (`MPNowPlayingInfoPropertyPlaybackProgress`).
    var playbackProgress: Float? { get set }
    
    /// Total items in queue (`MPNowPlayingInfoPropertyPlaybackQueueCount`).
    var playbackQueueCount: Int? { get set }
    
    /// Current index within queue (`MPNowPlayingInfoPropertyPlaybackQueueIndex`).
    var playbackQueueIndex: Int? { get set }
    
    /// Unique service identifier (`MPNowPlayingInfoPropertyServiceIdentifier`).
    var serviceIdentifier: String? { get set }
}

// Default Optional Property Stubs
public extension AKNowPlayableDynamicMetadataProtocol {
    var position: Double? { get { nil } set {} }
    var duration: Float? { get { nil } set {} }
    var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]? { get { nil } set {} }
    var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]? { get { nil } set {} }
    var chapterCount: Int? { get { nil } set {} }
    var chapterNumber: Int? { get { nil } set {} }
    var creditsStartTime: Double? { get { nil } set {} }
    var currentPlaybackDate: Date? { get { nil } set {} }
    var playbackProgress: Float? { get { nil } set {} }
    var playbackQueueCount: Int? { get { nil } set {} }
    var playbackQueueIndex: Int? { get { nil } set {} }
    var serviceIdentifier: String? { get { nil } set {} }
}

// MARK: - Dynamic Metadata Serialization Extension

public extension AKNowPlayableDynamicMetadataProtocol {
    /// Converts all dynamic metadata properties into key-value pairs for `MPNowPlayingInfoCenter`.
    func getNowPlayableDynamicMetadata() -> [String: Any] {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = defaultRate
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        
        if let duration, duration.isNormal {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyCurrentLanguageOptions] = currentLanguageOptions
        nowPlayingInfo[MPNowPlayingInfoPropertyAvailableLanguageOptions] = availableLanguageOptionGroups
        nowPlayingInfo[MPNowPlayingInfoPropertyChapterCount] = chapterCount
        nowPlayingInfo[MPNowPlayingInfoPropertyChapterNumber] = chapterNumber
        nowPlayingInfo[MPNowPlayingInfoPropertyCreditsStartTime] = creditsStartTime
        nowPlayingInfo[MPNowPlayingInfoPropertyCurrentPlaybackDate] = currentPlaybackDate
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] = playbackProgress
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = playbackQueueCount
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = playbackQueueIndex
        nowPlayingInfo[MPNowPlayingInfoPropertyServiceIdentifier] = serviceIdentifier
        
        return nowPlayingInfo
    }
}
