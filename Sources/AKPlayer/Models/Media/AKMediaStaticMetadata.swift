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
    
    public var title: String?
    public var artist: String?
    public var albumTitle: String?
    public var albumArtist: String?
    public var genre: String?
    public var composer: String?
    public var artwork: MPMediaItemArtwork?
    public var artworkImage: UIImage?
    public var trackNumber: Int?
    public var trackCount: Int?
    public var discNumber: Int?
    public var discCount: Int?
    public var releaseDate: Date?
    public var creationDate: String?
    public var descriptionText: String?
    public var copyrights: String?
    public var publisher: String?
    public var language: String?
    
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
    public func toNowPlayableStaticMetadata(
        defaultURL: URL? = nil,
        defaultMediaType: MPNowPlayingInfoMediaType = .audio,
        isLive: Bool = false,
        defaultChapterCount: Int? = nil,
        defaultCreditsStartTime: Double? = nil,
        defaultServiceIdentifier: String? = nil,
        defaultCollectionIdentifier: String? = nil,
        defaultExternalContentIdentifier: String? = nil,
        defaultExternalUserProfileIdentifier: String? = nil,
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
            adTimeRanges: defaultAdTimeRanges,
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
}
