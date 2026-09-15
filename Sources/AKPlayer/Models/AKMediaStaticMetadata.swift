//
//  AKMediaStaticMetadata.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 15/09/26.
//

import AVFoundation
import MediaPlayer
import UIKit

public struct AKMediaStaticMetadata: Equatable {
    
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
        mediaType: MPNowPlayingInfoMediaType? = nil
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
    }
}
