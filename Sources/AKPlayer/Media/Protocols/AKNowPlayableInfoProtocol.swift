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
    /// Generates a consolidated dictionary suitable for populating
    /// `MPNowPlayingInfoCenter.nowPlayingInfo`.
    /// - Returns: A merged dictionary containing both static and dynamic metadata keys, or `nil` if
    /// both are empty.
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

    /// Total chapter count (`MPNowPlayingInfoPropertyChapterCount`).
    var chapterCount: Int? { get set }

    /// Start offset for credits (`MPNowPlayingInfoPropertyCreditsStartTime`).
    var creditsStartTime: Double? { get set }

    /// Unique service identifier (`MPNowPlayingInfoPropertyServiceIdentifier`).
    var serviceIdentifier: String? { get set }

    /// Time ranges for advertisements (`MPNowPlayingInfoPropertyAdTimeRanges`).
    var adTimeRanges: [MPAdTimeRange]? { get set }

    /// Music / item genre (`MPMediaItemPropertyGenre`).
    var genre: String? { get set }

    /// Composer name (`MPMediaItemPropertyComposer`).
    var composer: String? { get set }

    /// Track number in album (`MPMediaItemPropertyAlbumTrackNumber`).
    var trackNumber: Int? { get set }

    /// Total track count in album (`MPMediaItemPropertyAlbumTrackCount`).
    var trackCount: Int? { get set }

    /// Disc number (`MPMediaItemPropertyDiscNumber`).
    var discNumber: Int? { get set }

    /// Total disc count (`MPMediaItemPropertyDiscCount`).
    var discCount: Int? { get set }

    /// Explicit content flag (`MPMediaItemPropertyIsExplicit`).
    var isExplicit: Bool? { get set }

    /// Release date (`MPMediaItemPropertyReleaseDate`).
    var releaseDate: Date? { get set }

    /// Comments or description (`MPMediaItemPropertyComments`).
    var descriptionText: String? { get set }
}

/// Default Optional Property Stubs
public extension AKNowPlayableStaticMetadataProtocol {
    /// The default artist name (returns `nil`).
    var artist: String? {
        get { nil } set {}
    }

    /// The default artwork representation (returns `nil`).
    var artwork: Artwork? {
        get { nil } set {}
    }

    /// The default album artist name (returns `nil`).
    var albumArtist: String? {
        get { nil } set {}
    }

    /// The default album title (returns `nil`).
    var albumTitle: String? {
        get { nil } set {}
    }

    /// The default collection identifier (returns `nil`).
    var collectionIdentifier: String? {
        get { nil } set {}
    }

    /// The default external content identifier (returns `nil`).
    var externalContentIdentifier: String? {
        get { nil } set {}
    }

    /// The default external user profile identifier (returns `nil`).
    var externalUserProfileIdentifier: String? {
        get { nil } set {}
    }

    /// The default total chapter count (returns `nil`).
    var chapterCount: Int? {
        get { nil } set {}
    }

    /// The default credits start time (returns `nil`).
    var creditsStartTime: Double? {
        get { nil } set {}
    }

    /// The default service identifier (returns `nil`).
    var serviceIdentifier: String? {
        get { nil } set {}
    }

    /// The default ad time ranges (returns `nil`).
    var adTimeRanges: [MPAdTimeRange]? {
        get { nil } set {}
    }

    /// The default genre name (returns `nil`).
    var genre: String? {
        get { nil } set {}
    }

    /// The default composer name (returns `nil`).
    var composer: String? {
        get { nil } set {}
    }

    /// The default track number (returns `nil`).
    var trackNumber: Int? {
        get { nil } set {}
    }

    /// The default total track count (returns `nil`).
    var trackCount: Int? {
        get { nil } set {}
    }

    /// The default disc number (returns `nil`).
    var discNumber: Int? {
        get { nil } set {}
    }

    /// The default total disc count (returns `nil`).
    var discCount: Int? {
        get { nil } set {}
    }

    /// The default explicit content flag (returns `nil`).
    var isExplicit: Bool? {
        get { nil } set {}
    }

    /// The default original release date (returns `nil`).
    var releaseDate: Date? {
        get { nil } set {}
    }

    /// The default description text (returns `nil`).
    var descriptionText: String? {
        get { nil } set {}
    }
}

public extension AKNowPlayableStaticMetadataProtocol {
    /// Computes or retrieves the standard `MPMediaItemArtwork` representation.
    var itemArtwork: MPMediaItemArtwork? {
        guard let artwork else { return nil }
        switch artwork {
        case let .image(image):
            let boundsSize = (image.size.width > 0 && image.size.height > 0) ? image.size : CGSize(
                width: 300,
                height: 300
            )
            return MPMediaItemArtwork(boundsSize: boundsSize) { _ in image }
        case let .data(data):
            guard let image = UIImage(data: data) else { return nil }
            let boundsSize = (image.size.width > 0 && image.size.height > 0) ? image.size : CGSize(
                width: 300,
                height: 300
            )
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
        nowPlayingInfo[MPNowPlayingInfoPropertyExternalContentIdentifier] =
            externalContentIdentifier
        nowPlayingInfo[MPNowPlayingInfoPropertyExternalUserProfileIdentifier] =
            externalUserProfileIdentifier

        if let chapterCount {
            nowPlayingInfo[MPNowPlayingInfoPropertyChapterCount] = chapterCount
        }

        if let creditsStartTime {
            nowPlayingInfo[MPNowPlayingInfoPropertyCreditsStartTime] = creditsStartTime
        }

        if let serviceIdentifier {
            nowPlayingInfo[MPNowPlayingInfoPropertyServiceIdentifier] = serviceIdentifier
        }

        if let adTimeRanges {
            nowPlayingInfo[MPNowPlayingInfoPropertyAdTimeRanges] = adTimeRanges
        }

        if let genre {
            nowPlayingInfo[MPMediaItemPropertyGenre] = genre
        }

        if let composer {
            nowPlayingInfo[MPMediaItemPropertyComposer] = composer
        }

        if let trackNumber {
            nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = trackNumber
        }

        if let trackCount {
            nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = trackCount
        }

        if let discNumber {
            nowPlayingInfo[MPMediaItemPropertyDiscNumber] = discNumber
        }

        if let discCount {
            nowPlayingInfo[MPMediaItemPropertyDiscCount] = discCount
        }

        if let isExplicit {
            nowPlayingInfo[MPMediaItemPropertyIsExplicit] = isExplicit
        }

        if let releaseDate {
            nowPlayingInfo[MPMediaItemPropertyReleaseDate] = releaseDate
        }

        if let descriptionText {
            nowPlayingInfo[MPMediaItemPropertyComments] = descriptionText
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

    /// Current chapter index (`MPNowPlayingInfoPropertyChapterNumber`).
    var chapterNumber: Int? { get set }

    /// Current wall-clock playback timestamp (`MPNowPlayingInfoPropertyCurrentPlaybackDate`).
    var currentPlaybackDate: Date? { get set }

    /// Playback completion percentage (`MPNowPlayingInfoPropertyPlaybackProgress`).
    var playbackProgress: Float? { get set }

    /// Total items in queue (`MPNowPlayingInfoPropertyPlaybackQueueCount`).
    var playbackQueueCount: Int? { get set }

    /// Current index within queue (`MPNowPlayingInfoPropertyPlaybackQueueIndex`).
    var playbackQueueIndex: Int? { get set }
}

/// Default Optional Property Stubs
public extension AKNowPlayableDynamicMetadataProtocol {
    /// The default elapsed playback position in seconds (returns `nil`).
    var position: Double? {
        get { nil } set {}
    }

    /// The default media duration in seconds (returns `nil`).
    var duration: Float? {
        get { nil } set {}
    }

    /// The default active language options (returns `nil`).
    var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]? {
        get { nil } set {}
    }

    /// The default available language option groups (returns `nil`).
    var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]? {
        get { nil } set {}
    }

    /// The default active chapter index number (returns `nil`).
    var chapterNumber: Int? {
        get { nil } set {}
    }

    /// The default live playback reference date (returns `nil`).
    var currentPlaybackDate: Date? {
        get { nil } set {}
    }

    /// The default playback progress fraction (returns `nil`).
    var playbackProgress: Float? {
        get { nil } set {}
    }

    /// The default playback queue count (returns `nil`).
    var playbackQueueCount: Int? {
        get { nil } set {}
    }

    /// The default playback queue index (returns `nil`).
    var playbackQueueIndex: Int? {
        get { nil } set {}
    }
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
        nowPlayingInfo[MPNowPlayingInfoPropertyAvailableLanguageOptions] =
            availableLanguageOptionGroups
        nowPlayingInfo[MPNowPlayingInfoPropertyChapterNumber] = chapterNumber
        nowPlayingInfo[MPNowPlayingInfoPropertyCurrentPlaybackDate] = currentPlaybackDate
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] = playbackProgress
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = playbackQueueCount
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = playbackQueueIndex

        return nowPlayingInfo
    }
}
