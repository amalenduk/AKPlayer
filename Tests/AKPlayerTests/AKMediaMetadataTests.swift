//
//  AKMediaMetadataTests.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 18/09/26.
//

import AVFoundation
import Foundation
import MediaPlayer
import Testing
@testable import AKPlayer

struct AKMediaMetadataTests {
    
    @Test func testMediaStaticMetadataPropertiesAndMerging() {
        let releaseDate = Date(timeIntervalSince1970: 1600000000)
        let meta1 = AKMediaStaticMetadata(
            title: "Song Title",
            artist: "Artist Name",
            albumTitle: "Album Name",
            albumArtist: "Album Artist",
            genre: "Rock",
            composer: "Composer Name",
            trackNumber: 3,
            trackCount: 12,
            discNumber: 1,
            discCount: 2,
            releaseDate: releaseDate,
            descriptionText: "Great song"
        )
        
        #expect(meta1.title == "Song Title")
        #expect(meta1.artist == "Artist Name")
        #expect(meta1.albumTitle == "Album Name")
        #expect(meta1.genre == "Rock")
        #expect(meta1.composer == "Composer Name")
        #expect(meta1.trackNumber == 3)
        #expect(meta1.trackCount == 12)
        #expect(meta1.discNumber == 1)
        #expect(meta1.discCount == 2)
        #expect(meta1.releaseDate == releaseDate)
        #expect(meta1.descriptionText == "Great song")
        
        // Convert to NowPlayable static metadata
        let url = URL(string: "https://example.com/audio.mp3")!
        let nowPlayable = meta1.toNowPlayableStaticMetadata(defaultURL: url, defaultMediaType: .audio, isLive: false)
        
        #expect(nowPlayable.title == "Song Title")
        #expect(nowPlayable.artist == "Artist Name")
        #expect(nowPlayable.albumTitle == "Album Name")
        #expect(nowPlayable.genre == "Rock")
        #expect(nowPlayable.composer == "Composer Name")
        #expect(nowPlayable.trackNumber == 3)
        #expect(nowPlayable.trackCount == 12)
        #expect(nowPlayable.discNumber == 1)
        #expect(nowPlayable.discCount == 2)
        #expect(nowPlayable.releaseDate == releaseDate)
        #expect(nowPlayable.descriptionText == "Great song")
        #expect(nowPlayable.assetURL == url)
        #expect(nowPlayable.mediaType == .audio)
        #expect(!nowPlayable.isLiveStream)
        
        // Check dictionary generation
        let dict = nowPlayable.getNowPlayableStaticMetadata()
        #expect(dict[MPMediaItemPropertyTitle] as? String == "Song Title")
        #expect(dict[MPMediaItemPropertyArtist] as? String == "Artist Name")
        #expect(dict[MPMediaItemPropertyGenre] as? String == "Rock")
        #expect(dict[MPMediaItemPropertyComposer] as? String == "Composer Name")
        #expect(dict[MPMediaItemPropertyAlbumTrackNumber] as? Int == 3)
        #expect(dict[MPMediaItemPropertyAlbumTrackCount] as? Int == 12)
        #expect(dict[MPMediaItemPropertyDiscNumber] as? Int == 1)
        #expect(dict[MPMediaItemPropertyDiscCount] as? Int == 2)
        #expect(dict[MPMediaItemPropertyComments] as? String == "Great song")
    }
    
    @Test func testMediaMetadataProviderLifecycleAndUpdates() async {
        let media = AKMedia(url: URL(string: "https://example.com/audio.mp3")!, type: .clip)
        let provider = media.metadataProvider
        
        #expect(provider.staticMetadata.title == nil)
        #expect(provider.timedMetadata.isEmpty)
        
        // Manual update
        var update = AKMediaStaticMetadata()
        update.title = "Updated Title"
        update.artist = "Updated Artist"
        update.genre = "Rock"
        
        provider.updateStaticMetadata(update)
        
        #expect(provider.staticMetadata.title == "Updated Title")
        #expect(provider.staticMetadata.artist == "Updated Artist")
        #expect(provider.staticMetadata.genre == "Rock")
        
        // Reset session
        provider.resetSession()
        #expect(provider.staticMetadata.title == nil)
        #expect(provider.timedMetadata.isEmpty)
    }
}
