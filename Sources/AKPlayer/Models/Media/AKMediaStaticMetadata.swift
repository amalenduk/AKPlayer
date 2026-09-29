//
//   AKMediaStaticMetadata.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import MediaPlayer

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - AKMediaStaticMetadata

/// A model representing static container metadata extracted directly from media asset tags (ID3,
/// QuickTime, iTunes, CommonMetadata).
public struct AKMediaStaticMetadata: @unchecked Sendable {
    /// The media title.
    public var title: String?
    /// The main artist or performer.
    public var artist: String?
    /// The title of the album or parent collection.
    public var albumTitle: String?
    /// The artist associated with the album.
    public var albumArtist: String?
    /// The musical or content genre.
    public var genre: String?
    /// The composer of the media work.
    public var composer: String?
    /// The media artwork as an `MPMediaItemArtwork` instance.
    public var artwork: MPMediaItemArtwork?
    /// The raw image artwork instance.
    public var artworkImage: AKPlatformImage?
    /// The track number within an album.
    public var trackNumber: Int?
    /// The total number of tracks in the album.
    public var trackCount: Int?
    /// The disc number in a multi-disc collection.
    public var discNumber: Int?
    /// The total number of discs in the collection.
    public var discCount: Int?
    /// The original release date.
    public var releaseDate: Date?
    /// The creation date string.
    public var creationDate: String?
    /// Textual summary or synopsis of the media content.
    public var descriptionText: String?
    /// Copyright notice string.
    public var copyrights: String?
    /// The publisher or distributor name.
    public var publisher: String?
    /// The primary spoken or written language tag.
    public var language: String?

    /// Initializes a static metadata payload with explicit property values.
    public init(
        title: String? = nil,
        artist: String? = nil,
        albumTitle: String? = nil,
        albumArtist: String? = nil,
        genre: String? = nil,
        composer: String? = nil,
        artwork: MPMediaItemArtwork? = nil,
        artworkImage: AKPlatformImage? = nil,
        trackNumber: Int? = nil,
        trackCount: Int? = nil,
        discNumber: Int? = nil,
        discCount: Int? = nil,
        releaseDate: Date? = nil,
        creationDate: String? = nil,
        descriptionText: String? = nil,
        copyrights: String? = nil,
        publisher: String? = nil,
        language: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.albumArtist = albumArtist
        self.genre = genre
        self.composer = composer
        self.artwork = artwork
        self.artworkImage = artworkImage
        self.trackNumber = trackNumber
        self.trackCount = trackCount
        self.discNumber = discNumber
        self.discCount = discCount
        self.releaseDate = releaseDate
        self.creationDate = creationDate
        self.descriptionText = descriptionText
        self.copyrights = copyrights
        self.publisher = publisher
        self.language = language
    }

    // MARK: - Now Playing Bridge

    #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        /// Converts this static metadata payload into an `AKNowPlayableStaticMetadata` instance.
        public func toNowPlayableStaticMetadata(
            defaultURL: URL? = nil,
            defaultMediaType: MPNowPlayingInfoMediaType = .audio,
            isLive: Bool = false,
            defaultCollectionIdentifier: String? = nil,
            defaultExternalContentIdentifier: String? = nil,
            defaultExternalUserProfileIdentifier: String? = nil,
            defaultChapterCount: Int? = nil,
            defaultCreditsStartTime: Double? = nil,
            defaultServiceIdentifier: String? = nil,
            defaultAdTimeRanges: [MPAdTimeRange]? = nil
        ) -> AKNowPlayableStaticMetadata {
            var artworkPayload: Artwork?
            if let artworkImage {
                artworkPayload = .image(artworkImage)
            } else if let artwork {
                artworkPayload = .artwork(artwork)
            }

            return AKNowPlayableStaticMetadata(
                assetURL: defaultURL ?? URL(fileURLWithPath: ""),
                mediaType: defaultMediaType,
                isLiveStream: isLive,
                title: title ?? "Unknown Title",
                artist: artist,
                artwork: artworkPayload,
                albumArtist: albumArtist,
                albumTitle: albumTitle,
                collectionIdentifier: defaultCollectionIdentifier,
                externalContentIdentifier: defaultExternalContentIdentifier,
                externalUserProfileIdentifier: defaultExternalUserProfileIdentifier,
                chapterCount: defaultChapterCount,
                creditsStartTime: defaultCreditsStartTime,
                serviceIdentifier: defaultServiceIdentifier,
                adTimeRanges: defaultAdTimeRanges,
                genre: genre,
                composer: composer,
                trackNumber: trackNumber,
                trackCount: trackCount,
                discNumber: discNumber,
                discCount: discCount,
                isExplicit: nil,
                releaseDate: releaseDate,
                descriptionText: descriptionText
            )
        }
    #else
        /// Converts this static metadata payload into an `AKNowPlayableStaticMetadata` instance.
        public func toNowPlayableStaticMetadata(
            defaultURL: URL? = nil,
            defaultMediaType: MPNowPlayingInfoMediaType = .audio,
            isLive: Bool = false,
            defaultCollectionIdentifier: String? = nil,
            defaultExternalContentIdentifier: String? = nil,
            defaultExternalUserProfileIdentifier: String? = nil,
            defaultChapterCount: Int? = nil,
            defaultCreditsStartTime: Double? = nil,
            defaultServiceIdentifier: String? = nil
        ) -> AKNowPlayableStaticMetadata {
            var artworkPayload: Artwork?
            if let artworkImage {
                artworkPayload = .image(artworkImage)
            } else if let artwork {
                artworkPayload = .artwork(artwork)
            }

            return AKNowPlayableStaticMetadata(
                assetURL: defaultURL ?? URL(fileURLWithPath: ""),
                mediaType: defaultMediaType,
                isLiveStream: isLive,
                title: title ?? "Unknown Title",
                artist: artist,
                artwork: artworkPayload,
                albumArtist: albumArtist,
                albumTitle: albumTitle,
                collectionIdentifier: defaultCollectionIdentifier,
                externalContentIdentifier: defaultExternalContentIdentifier,
                externalUserProfileIdentifier: defaultExternalUserProfileIdentifier,
                chapterCount: defaultChapterCount,
                creditsStartTime: defaultCreditsStartTime,
                serviceIdentifier: defaultServiceIdentifier,
                genre: genre,
                composer: composer,
                trackNumber: trackNumber,
                trackCount: trackCount,
                discNumber: discNumber,
                discCount: discCount,
                isExplicit: nil,
                releaseDate: releaseDate,
                descriptionText: descriptionText
            )
        }
    #endif
}
