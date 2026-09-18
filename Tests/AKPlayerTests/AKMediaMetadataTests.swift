//
//  AKMediaMetadataTests.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 18/09/26.
//

import AVFoundation
import Testing
@testable import AKPlayer

struct AKMediaMetadataTests {
    
    @Test func testMediaStaticMetadataPropertiesAndMerging() {
        let meta1 = AKMediaStaticMetadata(
            title: "Song Title",
            artist: "Artist Name",
            albumTitle: "Album Name",
            trackNumber: 3,
            trackCount: 12
        )
        
        #expect(meta1.title == "Song Title")
        #expect(meta1.artist == "Artist Name")
        #expect(meta1.albumTitle == "Album Name")
        #expect(meta1.trackNumber == 3)
        #expect(meta1.trackCount == 12)
        
        // Convert to NowPlayable static metadata
        let url = URL(string: "https://example.com/audio.mp3")!
        let nowPlayable = meta1.toNowPlayableStaticMetadata(defaultURL: url, defaultMediaType: .audio, isLive: false)
        
        #expect(nowPlayable.title == "Song Title")
        #expect(nowPlayable.artist == "Artist Name")
        #expect(nowPlayable.albumTitle == "Album Name")
        #expect(nowPlayable.assetURL == url)
        #expect(nowPlayable.mediaType == .audio)
        #expect(!nowPlayable.isLiveStream)
    }
    
    @Test func testMediaMetadataProviderLifecycleAndUpdates() async {
        let media = AKMedia(url: URL(string: "https://example.com/audio.mp3")!, type: .clip)
        let provider = AKMediaMetadataProvider(mediaManager: media.manager)
        
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
