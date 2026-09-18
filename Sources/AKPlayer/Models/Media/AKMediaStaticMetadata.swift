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

/// A model representing static container metadata extracted from media files or supplied by the caller.
public struct AKMediaStaticMetadata: Equatable, @unchecked Sendable {
    
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
    public var isExplicit: Bool?
    public var assetURL: URL?
    public var mediaType: MPNowPlayingInfoMediaType?
    public var descriptionText: String?
    public var copyrights: String?
    public var publisher: String?
    public var creationDate: String?
    public var language: String?
    public var isLiveStream: Bool?
    public var chapterCount: Int?
    public var creditsStartTime: Double?
    public var serviceIdentifier: String?
    
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
        isExplicit: Bool? = nil,
        assetURL: URL? = nil,
        mediaType: MPNowPlayingInfoMediaType? = nil,
        descriptionText: String? = nil,
        copyrights: String? = nil,
        publisher: String? = nil,
        creationDate: String? = nil,
        language: String? = nil,
        isLiveStream: Bool? = nil,
        chapterCount: Int? = nil,
        creditsStartTime: Double? = nil,
        serviceIdentifier: String? = nil
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
        self.isExplicit = isExplicit
        self.assetURL = assetURL
        self.mediaType = mediaType
        self.descriptionText = descriptionText
        self.copyrights = copyrights
        self.publisher = publisher
        self.creationDate = creationDate
        self.language = language
        self.isLiveStream = isLiveStream
        self.chapterCount = chapterCount
        self.creditsStartTime = creditsStartTime
        self.serviceIdentifier = serviceIdentifier
    }
    
    // MARK: - Now Playing Bridge
    
    /// Converts this static metadata payload into an `AKNowPlayableStaticMetadata` instance.
    public func toNowPlayableStaticMetadata(
        defaultURL: URL? = nil,
        defaultMediaType: MPNowPlayingInfoMediaType = .audio,
        isLive: Bool = false,
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
            assetURL: assetURL ?? defaultURL ?? URL(fileURLWithPath: ""),
            mediaType: mediaType ?? defaultMediaType,
            isLiveStream: isLiveStream ?? isLive,
            title: title ?? "Unknown Title",
            artist: artist,
            artwork: artworkPayload,
            albumArtist: albumArtist,
            albumTitle: albumTitle,
            chapterCount: chapterCount ?? defaultChapterCount,
            creditsStartTime: creditsStartTime ?? defaultCreditsStartTime,
            serviceIdentifier: serviceIdentifier ?? defaultServiceIdentifier
        )
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: AKMediaStaticMetadata, rhs: AKMediaStaticMetadata) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.albumTitle == rhs.albumTitle &&
        lhs.albumArtist == rhs.albumArtist &&
        lhs.genre == rhs.genre &&
        lhs.composer == rhs.composer &&
        lhs.artwork == rhs.artwork &&
        lhs.artworkImage == rhs.artworkImage &&
        lhs.trackNumber == rhs.trackNumber &&
        lhs.trackCount == rhs.trackCount &&
        lhs.discNumber == rhs.discNumber &&
        lhs.discCount == rhs.discCount &&
        lhs.releaseDate == rhs.releaseDate &&
        lhs.isExplicit == rhs.isExplicit &&
        lhs.assetURL == rhs.assetURL &&
        lhs.mediaType == rhs.mediaType &&
        lhs.descriptionText == rhs.descriptionText &&
        lhs.copyrights == rhs.copyrights &&
        lhs.publisher == rhs.publisher &&
        lhs.creationDate == rhs.creationDate &&
        lhs.language == rhs.language &&
        lhs.isLiveStream == rhs.isLiveStream &&
        lhs.chapterCount == rhs.chapterCount &&
        lhs.creditsStartTime == rhs.creditsStartTime &&
        lhs.serviceIdentifier == rhs.serviceIdentifier
    }
}
