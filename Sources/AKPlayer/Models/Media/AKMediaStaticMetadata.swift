//
//  AKMediaStaticMetadata.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 15/09/26.
//

import AVFoundation
import MediaPlayer
import UIKit

// MARK: - AKMediaStaticMetadata

/// A model representing static container metadata extracted directly from media asset tags (ID3, QuickTime, iTunes, CommonMetadata).
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
    /// The raw `UIImage` artwork instance.
    public var artworkImage: UIImage?
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
    /// - Parameters:
    ///   - title: The media title.
    ///   - artist: The primary artist.
    ///   - albumTitle: The album title.
    ///   - albumArtist: The album artist.
    ///   - genre: The genre.
    ///   - composer: The composer.
    ///   - artwork: The media item artwork.
    ///   - artworkImage: The raw image artwork.
    ///   - trackNumber: The track number.
    ///   - trackCount: The total track count.
    ///   - discNumber: The disc number.
    ///   - discCount: The total disc count.
    ///   - releaseDate: The release date.
    ///   - creationDate: The creation date string.
    ///   - descriptionText: The description text.
    ///   - copyrights: The copyright notice.
    ///   - publisher: The publisher.
    ///   - language: The language tag.
    public init(
        title: String? = nil,
        artist: String? = nil,
        albumTitle: String? = nil,
        albumArtist: String? = nil,
        genre: String? = nil,
        composer: String? = nil,
        artwork: MPMediaItemArtwork? = nil,
        artworkImage: UIImage? = nil,
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
    
    /// Converts this static metadata payload into an `AKNowPlayableStaticMetadata` instance.
    /// - Parameters:
    ///   - defaultURL: The asset URL to use if unspecified.
    ///   - defaultMediaType: The default media type (.audio or .video).
    ///   - isLive: Whether the media is a live stream.
    ///   - defaultCollectionIdentifier: Default collection identifier.
    ///   - defaultExternalContentIdentifier: Default external content identifier.
    ///   - defaultExternalUserProfileIdentifier: Default user profile identifier.
    ///   - defaultChapterCount: Default total chapter count.
    ///   - defaultCreditsStartTime: Default credits start time.
    ///   - defaultServiceIdentifier: Default service identifier.
    ///   - defaultAdTimeRanges: Default ad time ranges.
    /// - Returns: A populated `AKNowPlayableStaticMetadata` instance.
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
}
