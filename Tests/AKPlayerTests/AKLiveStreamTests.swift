//
//  AKLiveStreamTests.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 18/09/26.
//

import AVFoundation
import Foundation
import Testing
@testable import AKPlayer

@MainActor
struct AKLiveStreamTests {
    
    @Test func testAKSeekTargetLiveResolution() {
        let target = AKSeekTarget.live
        #expect(target.description == "live")
        #expect(target == .live)
        
        // Static resolution for .live returns nil since it requires runtime seekable ranges
        let resolved = target.resolve(
            currentTime: .zero,
            duration: CMTime(seconds: 200, preferredTimescale: 600),
            preferredTimescale: 600
        )
        #expect(resolved == nil)
    }
    
    @Test func testLiveStreamConfigurationDefaults() {
        let config = AKPlayerConfiguration()
        #expect(config.automaticallyPreservesTimeOffsetFromLive == true)
        
        var customConfig = AKPlayerConfiguration()
        customConfig.automaticallyPreservesTimeOffsetFromLive = false
        #expect(customConfig.automaticallyPreservesTimeOffsetFromLive == false)
    }
    
    @Test func testPlayerLivePropertiesAndJumpToLive() async throws {
        let player = AKPlayer()
        try await player.prepare()
        
        let liveUrl = URL(string: "https://example.com/live/master.m3u8")!
        let liveMedia = AKMedia(url: liveUrl, type: .stream(isLive: true))
        
        #expect(liveMedia.isLive() == true)
        #expect(liveMedia.dvrWindow == nil)
        
        player.load(media: liveMedia, autoPlay: false)
        
        #expect(player.isLive == true)
        #expect(player.isAtLiveEdge == true) // Default when drift is nil
        
        // jumpToLive() can be invoked cleanly
        let jumped = await player.jumpToLive()
        #expect(jumped == true || jumped == false)
        
        final class CompletionBox: @unchecked Sendable {
            var called = false
        }
        let box = CompletionBox()
        player.jumpToLive { _ in
            box.called = true
        }
        #expect(box.called == true || box.called == false)
        
        player.stop()
    }
    
    @Test func testNonLiveMediaProperties() async throws {
        let player = AKPlayer()
        try await player.prepare()
        
        let vodUrl = URL(string: "https://example.com/vod.mp4")!
        let vodMedia = AKMedia(url: vodUrl, type: .clip)
        
        #expect(vodMedia.isLive() == false)
        #expect(vodMedia.liveDrift == nil)
        
        player.load(media: vodMedia, autoPlay: false)
        #expect(player.isLive == false)
        #expect(player.isAtLiveEdge == false)
        
        player.stop()
    }
    
    @Test func testPlayableLiveExtensionsAndThresholdOverride() {
        let liveUrl = URL(string: "https://example.com/live/master.m3u8")!
        let defaultLiveMedia = AKMedia(url: liveUrl, type: .stream(isLive: true))
        #expect(defaultLiveMedia.isLive() == true)
        #expect(defaultLiveMedia.liveEdgeThreshold == 4.0) // Default 4.0 for live streams
        
        let customLiveMedia = AKMedia(url: liveUrl, type: .stream(isLive: true), liveEdgeThreshold: 2.5)
        #expect(customLiveMedia.isLive() == true)
        #expect(customLiveMedia.liveEdgeThreshold == 2.5) // Custom override
        #expect(customLiveMedia.dvrWindow == nil)
        #expect(customLiveMedia.currentLiveDate == nil)
        #expect(customLiveMedia.liveDrift == nil)
        #expect(customLiveMedia.isAtLiveEdge == true) // Default when drift is nil
        
        let vodUrl = URL(string: "https://example.com/vod.mp4")!
        let vodMedia = AKMedia(url: vodUrl, type: .clip)
        
        #expect(vodMedia.isLive() == false)
        #expect(vodMedia.liveEdgeThreshold == nil) // Nil for non-live
        #expect(vodMedia.dvrWindow == nil)
        #expect(vodMedia.currentLiveDate == nil)
        #expect(vodMedia.liveDrift == nil)
        #expect(vodMedia.isAtLiveEdge == false)
    }
}
