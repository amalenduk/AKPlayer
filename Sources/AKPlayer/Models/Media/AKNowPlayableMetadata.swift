//
//   AKNowPlayableMetadata.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation
import MediaPlayer

// MARK: - AKNowPlayableMetadata

/// A concrete container holding combined static and dynamic metadata payload
/// sources for MPNowPlayingInfoCenter.
public struct AKNowPlayableMetadata: AKNowPlayableInfoProtocol, Sendable {
    // MARK: - Properties

    /// The static metadata describing the media asset.
    public var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)?

    /// The dynamic metadata reflecting live playback state.
    public var dynamicMetadata: (any AKNowPlayableDynamicMetadataProtocol)?

    // MARK: - Init

    /// Initializes a combined metadata instance.
    /// - Parameters:
    ///   - staticMetadata: Immutable or rarely changed metadata payload.
    ///   - dynamicMetadata: Real-time changeable playback state metadata
    /// payload.
    public init(
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil,
        dynamicMetadata: (any AKNowPlayableDynamicMetadataProtocol)? = nil
    ) {
        self.staticMetadata = staticMetadata
        self.dynamicMetadata = dynamicMetadata
    }
}

// MARK: - AKNowPlayableStaticMetadata

/// A concrete struct implementing static metadata properties for Now Playing
/// displays.
public struct AKNowPlayableStaticMetadata: AKNowPlayableStaticMetadataProtocol, @unchecked Sendable {
    // MARK: - Properties

    /// Destination asset URL.
    public var assetURL: URL

    /// Media type classification.
    public var mediaType: MPNowPlayingInfoMediaType

    /// Indicates if the item is a live stream.
    public var isLiveStream: Bool

    /// The primary title.
    public var title: String

    /// The primary artist.
    public var artist: String?

    /// Associated media artwork source.
    public var artwork: Artwork?

    /// The album artist.
    public var albumArtist: String?

    /// The album title.
    public var albumTitle: String?

    /// Collection identifier.
    public var collectionIdentifier: String?

    /// External content identifier.
    public var externalContentIdentifier: String?

    /// External user profile identifier.
    public var externalUserProfileIdentifier: String?

    /// Total chapter count.
    public var chapterCount: Int?

    /// Start offset for credits.
    public var creditsStartTime: Double?

    /// Unique service identifier.
    public var serviceIdentifier: String?

    /// Time ranges for advertisements.
    public var adTimeRanges: [MPAdTimeRange]?
    
    /// Music / item genre.
    public var genre: String?
    
    /// Composer name.
    public var composer: String?
    
    /// Track number in album.
    public var trackNumber: Int?
    
    /// Total track count in album.
    public var trackCount: Int?
    
    /// Disc number.
    public var discNumber: Int?
    
    /// Total disc count.
    public var discCount: Int?
    
    /// Explicit content flag.
    public var isExplicit: Bool?
    
    /// Release date.
    public var releaseDate: Date?
    
    /// Comments or description.
    public var descriptionText: String?

    // MARK: - Init

    /// Initializes a static metadata payload container.
    /// - Parameters:
    ///   - assetURL: Destination asset URL.
    ///   - mediaType: Media type classification.
    ///   - isLiveStream: Flag indicating if the item is a live stream.
    ///   - title: Primary item title.
    ///   - artist: Primary artist name.
    ///   - artwork: Visual artwork payload.
    ///   - albumArtist: Album artist name.
    ///   - albumTitle: Album title.
    ///   - collectionIdentifier: Collection identifier.
    ///   - externalContentIdentifier: External content identifier.
    ///   - externalUserProfileIdentifier: External user profile identifier.
    ///   - chapterCount: Total chapter count.
    ///   - creditsStartTime: Start offset for credits.
    ///   - serviceIdentifier: Unique service identifier.
    ///   - adTimeRanges: Time ranges for advertisements.
    ///   - genre: Music / item genre.
    ///   - composer: Composer name.
    ///   - trackNumber: Track number in album.
    ///   - trackCount: Total track count in album.
    ///   - discNumber: Disc number.
    ///   - discCount: Total disc count.
    ///   - isExplicit: Explicit content flag.
    ///   - releaseDate: Release date.
    ///   - descriptionText: Comments or description.
    public init(
        assetURL: URL,
        mediaType: MPNowPlayingInfoMediaType,
        isLiveStream: Bool,
        title: String,
        artist: String? = nil,
        artwork: Artwork? = nil,
        albumArtist: String? = nil,
        albumTitle: String? = nil,
        collectionIdentifier: String? = nil,
        externalContentIdentifier: String? = nil,
        externalUserProfileIdentifier: String? = nil,
        chapterCount: Int? = nil,
        creditsStartTime: Double? = nil,
        serviceIdentifier: String? = nil,
        adTimeRanges: [MPAdTimeRange]? = nil,
        genre: String? = nil,
        composer: String? = nil,
        trackNumber: Int? = nil,
        trackCount: Int? = nil,
        discNumber: Int? = nil,
        discCount: Int? = nil,
        isExplicit: Bool? = nil,
        releaseDate: Date? = nil,
        descriptionText: String? = nil
    ) {
        self.assetURL = assetURL
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
        self.collectionIdentifier = collectionIdentifier
        self.externalContentIdentifier = externalContentIdentifier
        self.externalUserProfileIdentifier = externalUserProfileIdentifier
        self.chapterCount = chapterCount
        self.creditsStartTime = creditsStartTime
        self.serviceIdentifier = serviceIdentifier
        self.adTimeRanges = adTimeRanges
        self.genre = genre
        self.composer = composer
        self.trackNumber = trackNumber
        self.trackCount = trackCount
        self.discNumber = discNumber
        self.discCount = discCount
        self.isExplicit = isExplicit
        self.releaseDate = releaseDate
        self.descriptionText = descriptionText
    }
}

// MARK: - AKNowPlayableDynamicMetadata

/// A concrete struct implementing dynamic metadata properties for Now Playing
/// displays.
public struct AKNowPlayableDynamicMetadata: AKNowPlayableDynamicMetadataProtocol, @unchecked Sendable {
    // MARK: - Properties

    /// Current playback speed multiplier.
    public var rate: Double

    /// Default intended playback rate.
    public var defaultRate: Double

    /// Elapsed playback time in seconds.
    public var position: Double?

    /// Total duration of the media in seconds.
    public var duration: Float?

    /// Active language options.
    public var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]?

    /// Available language options.
    public var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]?

    /// Current chapter index.
    public var chapterNumber: Int?

    /// Current wall-clock playback timestamp.
    public var currentPlaybackDate: Date?

    /// Playback completion percentage.
    public var playbackProgress: Float?

    /// Total items in queue.
    public var playbackQueueCount: Int?

    /// Current index within queue.
    public var playbackQueueIndex: Int?

    // MARK: - Init

    /// Initializes a dynamic metadata payload container.
    /// - Parameters:
    ///   - rate: Current playback speed multiplier.
    ///   - defaultRate: Default intended playback rate.
    ///   - position: Elapsed playback time in seconds.
    ///   - duration: Total duration in seconds.
    ///   - currentLanguageOptions: Active language options.
    ///   - availableLanguageOptionGroups: Available language option groups.
    ///   - chapterNumber: Current chapter index.
    ///   - currentPlaybackDate: Current wall-clock playback timestamp.
    ///   - playbackProgress: Playback completion percentage.
    ///   - playbackQueueCount: Total items in queue.
    ///   - playbackQueueIndex: Current index within queue.
    public init(
        rate: Double,
        defaultRate: Double,
        position: Double? = nil,
        duration: Float? = nil,
        currentLanguageOptions: [MPNowPlayingInfoLanguageOption]? = nil,
        availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]? =
            nil,
        chapterNumber: Int? = nil,
        currentPlaybackDate: Date? = nil,
        playbackProgress: Float? = nil,
        playbackQueueCount: Int? = nil,
        playbackQueueIndex: Int? = nil
    ) {
        self.rate = rate
        self.defaultRate = defaultRate
        self.position = position
        self.duration = duration
        self.currentLanguageOptions = currentLanguageOptions
        self.availableLanguageOptionGroups = availableLanguageOptionGroups
        self.chapterNumber = chapterNumber
        self.currentPlaybackDate = currentPlaybackDate
        self.playbackProgress = playbackProgress
        self.playbackQueueCount = playbackQueueCount
        self.playbackQueueIndex = playbackQueueIndex
    }
}
