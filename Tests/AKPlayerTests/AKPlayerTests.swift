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
        var receivedStates: [AKPlayerState] = []
        
        let task = Task {
            for await event in events {
                if case let .stateDidChange(state) = event {
                    receivedStates.append(state)
                    if state == .loading && receivedStates.contains(.stopped) {
                        break
                    }
                }
            }
        }
        
        controller.load(media: item2, autoPlay: false, at: nil)
        #expect(controller.state == AKPlayerState.loading)
        
        // Wait briefly for event stream processing
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        
        #expect(receivedStates.contains(.stopped))
        #expect(receivedStates.contains(.loading))
    }
}
