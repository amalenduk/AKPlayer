//
//  AKPlayerTests.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 18/09/26.
//

import AVFoundation
import Foundation
import Testing
@testable import AKPlayer

@MainActor
struct AKPlayerTests {
    
    @Test func testQueuePlayerNowPlayingIntegration() async throws {
        let queuePlayer = AKQueuePlayer()
        try await queuePlayer.prepare()
        
        let item1 = AKMedia(url: URL(string: "https://example.com/track1.mp3")!, type: .clip)
        let item2 = AKMedia(url: URL(string: "https://example.com/track2.mp3")!, type: .clip)
        let item3 = AKMedia(url: URL(string: "https://example.com/track3.mp3")!, type: .clip)
        
        queuePlayer.load(items: [item1, item2, item3], startIndex: 0, autoPlay: false)
        
        #expect(queuePlayer.queueCount == 3)
        #expect(queuePlayer.currentQueueIndex == 0)
        
        queuePlayer.nowPlayingManager?.serviceIdentifier = "com.akplayer.music"
        
        let dynamicMeta = queuePlayer.nowPlayingManager?.getNowPlayableDynamicMetadata()
        #expect(dynamicMeta?.playbackQueueCount == 3)
        #expect(dynamicMeta?.playbackQueueIndex == 0)
        
        let nowPlayingMeta = queuePlayer.nowPlayingManager?.currentNowPlayingMetadata()
        #expect(nowPlayingMeta?.staticMetadata?.serviceIdentifier == "com.akplayer.music")
        
        // Test Queue Command Configuration (Next / Previous enabled, Skip intervals / Seek disabled)
        let queueConfig = AKNowPlayingCommandPresets.queue()
        #expect(queueConfig.isEnabled(.nextTrack))
        #expect(queueConfig.isEnabled(.previousTrack))
        #expect(queueConfig.isEnabled(.changeRepeatMode))
        #expect(queueConfig.isEnabled(.changeShuffleMode))
        #expect(queueConfig.isEnabled(.changePlaybackPosition))
        #expect(!queueConfig.isEnabled(.skipForward(preferredIntervals: [15.0])))
        #expect(!queueConfig.isEnabled(.skipBackward(preferredIntervals: [15.0])))
        #expect(!queueConfig.isEnabled(.seekForward))
        #expect(!queueConfig.isEnabled(.seekBackward))
        
        await queuePlayer.configureNowPlaying(with: queueConfig)
        if let session = queuePlayer.nowPlayingManager?.session {
            #expect(session.isCommandEnabled(.nextTrack))
            #expect(session.isCommandEnabled(.previousTrack))
            #expect(!session.isCommandEnabled(.skipForward(preferredIntervals: [15.0])))
            #expect(!session.isCommandEnabled(.skipBackward(preferredIntervals: [15.0])))
        }
    }
    
    @Test func testLoadTransitionsThroughStoppedStateWhenActive() async throws {
        let controller = AKPlayerController(
            player: AVPlayer(),
            configuration: AKPlayerConfiguration()
        )
        try controller.prepare()
        
        #expect(controller.state == AKPlayerState.idle)
        
        let item1 = AKMedia(url: URL(string: "https://example.com/track1.mp3")!, type: .clip)
        controller.load(media: item1, autoPlay: false, at: nil)
        
        #expect(controller.state == AKPlayerState.loading)
        
        let item2 = AKMedia(url: URL(string: "https://example.com/track2.mp3")!, type: .clip)
        let events = controller.events
        final class StateCollector: @unchecked Sendable {
            var states: [AKPlayerState] = []
        }
        let collector = StateCollector()
        
        let task = Task {
            for await event in events {
                if case let .stateDidChange(state) = event {
                    collector.states.append(state)
                    if state == .loading && collector.states.contains(.stopped) {
                        break
                    }
                }
            }
        }
        
        controller.load(media: item2, autoPlay: false, at: nil)
        #expect(controller.state == AKPlayerState.loading)
        
        _ = await task.value
        
        #expect(collector.states.contains(.stopped))
        #expect(collector.states.contains(.loading))
    }
    
    @Test func testEnumConformances() {
        // AKRepeatMode
        #expect(AKRepeatMode.allCases == [.off, .one, .all])
        #expect(AKRepeatMode.off.description == "Off")
        #expect(AKRepeatMode.one.description == "Repeat One")
        #expect(AKRepeatMode.all.description == "Repeat All")
        let repeatSet: Set<AKRepeatMode> = [.off, .one, .all]
        #expect(repeatSet.count == 3)
        
        // AKInterstitialPlaybackState
        #expect(AKInterstitialPlaybackState.allCases == [.idle, .loading, .buffering, .playing, .paused, .finished])
        #expect(AKInterstitialPlaybackState.idle.description == "Idle")
        #expect(AKInterstitialPlaybackState.playing.description == "Playing")
        let interstitialSet: Set<AKInterstitialPlaybackState> = [.idle, .loading, .buffering, .playing, .paused, .finished]
        #expect(interstitialSet.count == 6)
    }
    
    @Test func testMediaManagerPersistenceAndPlayerItemLoaded() async throws {
        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8")!
        let media: any AKPlayable = AKMedia(url: url, type: .stream(isLive: false))
        
        await media.createAsset()
        #expect(media.asset != nil)
        
        media.createPlayerItemFromAsset()
        #expect(media.playerItem != nil)
    }
    
    @Test func testCustomAssetMediaInitialization() async throws {
        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8")!
        let asset = AVURLAsset(url: url)
        let media = AKMedia(asset: asset, type: .stream(isLive: false))
        
        #expect(media.customAsset === asset)
        #expect(media.customPlayerItem == nil)
        #expect(media.asset === asset)
        #expect(media.state == .assetLoaded)
    }
    
    @Test func testCustomPlayerItemMediaInitialization() async throws {
        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8")!
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let media = AKMedia(playerItem: playerItem, type: .stream(isLive: false))
        
        #expect(media.customPlayerItem === playerItem)
        #expect(media.playerItem === playerItem)
        #expect(media.asset === asset)
        #expect(media.state == .playerItemLoaded)
    }
}
