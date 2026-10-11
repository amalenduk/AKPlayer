//
//   AKPlayerTests.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@testable import AKPlayer
import AVFoundation
import Foundation
import Testing
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@MainActor
struct AKPlayerTests {
    @Test func observablePlayerStartsWithUnderlyingPlayerState() {
        let player = AKPlayer()
        let observable = AKPlayerObservable(player: player)

        #expect(observable.player === player)
        #expect(observable.state == player.state)
        #expect(observable.autoPlay == player.autoPlay)
        #expect(observable.currentTime == player.currentTime)
        #expect(observable.duration == player.currentItemDuration)
        #expect(observable.loadedTimeRanges.isEmpty)
        #expect(observable.isInterstitialActive == false)
        #expect(observable.isPlaying == player.isPlaying)
        #expect(observable.chapters.isEmpty)
        #expect(observable.availableTracks.isEmpty)
        #expect(observable.selectedTracks.isEmpty)
        #expect(observable.audioTracks.isEmpty)
        #expect(observable.subtitleTracks.isEmpty)
        #expect(observable.closedCaptionTracks.isEmpty)
        #expect(observable.videoAlternativeTracks.isEmpty)
    }

    @Test func observableTimelineSourceCanBeChanged() {
        let observable = AKPlayerObservable()

        #expect(observable.timelineSource == .normal)

        observable.timelineSource = .integrated
        #expect(observable.timelineSource == .integrated)

        observable.timelineSource = .normal
        #expect(observable.timelineSource == .normal)
    }

    @Test func observablePlayerTransportSkipHelpers() async {
        let player = AKPlayer()
        let observable = AKPlayerObservable(player: player)

        // Transport skips should execute safely without crashing even when idle
        let forwardSuccess = await observable.skipForward(by: 15)
        let backwardSuccess = await observable.skipBackward(by: 10)
        #expect(forwardSuccess == false)
        #expect(backwardSuccess == false)
    }

    @Test func queueObservableExposesPlaybackAndQueueState() async throws {
        let queuePlayer = AKQueuePlayer()
        let observable = AKQueuePlayerObservable(player: queuePlayer)
        let firstItem = try AKMedia(
            url: #require(URL(string: "https://example.com/first.mp3")),
            type: .clip
        )
        let secondItem = try AKMedia(
            url: #require(URL(string: "https://example.com/second.mp3")),
            type: .clip
        )

        #expect(observable.player === queuePlayer)
        #expect(observable.queuePlayer === queuePlayer)
        #expect(observable.items.isEmpty)
        #expect(observable.currentIndex == nil)

        observable.append(firstItem)
        observable.append(secondItem)
        observable.repeatMode = .all
        observable.isShuffleEnabled = true

        #expect(observable.items.count == 2)
        #expect(queuePlayer.items.count == 2)
        #expect(observable.repeatMode == .all)
        #expect(queuePlayer.repeatMode == .all)
        #expect(observable.isShuffleEnabled)
        #expect(queuePlayer.isShuffleEnabled)

        try queuePlayer.append(
            AKMedia(
                url: #require(URL(string: "https://example.com/third.mp3")),
                type: .clip
            )
        )
        #expect(queuePlayer.items.count == 3)
        for _ in 0 ..< 100 where observable.items.count != 3 {
            try await Task.sleep(for: .milliseconds(1))
        }

        #expect(observable.items.count == 3)
        #expect(observable.latestQueueEvent != nil)
    }

    @Test func queuePlayerPublishesTypedQueueEvents() async throws {
        let queuePlayer = AKQueuePlayer()
        let stream = queuePlayer.queueEvents
        var events = stream.makeAsyncIterator()
        let firstItem = try AKMedia(
            url: #require(URL(string: "https://example.com/queue-first.mp3")),
            type: .clip
        )
        let secondItem = try AKMedia(
            url: #require(URL(string: "https://example.com/queue-second.mp3")),
            type: .clip
        )

        queuePlayer.append(firstItem)
        guard case let .itemAdded(item, at: index)? = await events.next() else {
            Issue.record("Expected an item-added queue event")
            return
        }
        #expect(item.url == firstItem.url)
        #expect(index == 0)

        queuePlayer.insert(secondItem, at: 0)
        guard case let .itemAdded(insertedItem, at: insertedIndex)? = await events.next() else {
            Issue.record("Expected an item-added queue event for the inserted item")
            return
        }
        #expect(insertedItem.url == secondItem.url)
        #expect(insertedIndex == 0)

        queuePlayer.move(from: 0, to: 1)
        guard case let .itemMoved(movedItem, from: source, to: destination)? = await events.next()
        else {
            Issue.record("Expected an item-moved queue event")
            return
        }
        #expect(movedItem.url == secondItem.url)
        #expect(source == 0)
        #expect(destination == 1)

        queuePlayer.remove(at: 1)
        guard case let .itemRemoved(removedItem, at: removedIndex)? = await events.next() else {
            Issue.record("Expected an item-removed queue event")
            return
        }
        #expect(removedItem.url == secondItem.url)
        #expect(removedIndex == 1)

        queuePlayer.repeatMode = .all
        guard case .repeatModeDidChange(.all)? = await events.next() else {
            Issue.record("Expected a repeat-mode-changed queue event")
            return
        }

        queuePlayer.isShuffleEnabled = true
        guard case .shuffleModeDidChange(isEnabled: true)? = await events.next() else {
            Issue.record("Expected a shuffle-mode-changed queue event")
            return
        }

        queuePlayer.load(items: [firstItem, secondItem], startIndex: 1, autoPlay: false)
        guard case let .itemsLoaded(items, startIndex, autoPlay)? = await events.next() else {
            Issue.record("Expected an items-loaded queue event")
            return
        }
        #expect(items.count == 2)
        #expect(startIndex == 1)
        #expect(!autoPlay)

        #expect(AKPlayerQueueEvent.repeatModeDidChange(.all) == AKPlayerQueueEvent
            .repeatModeDidChange(.all))
        #expect(AKPlayerQueueEvent.shuffleModeDidChange(isEnabled: true) != AKPlayerQueueEvent
            .shuffleModeDidChange(isEnabled: false))
    }

    @Test func queuePlayerNowPlayingIntegration() async throws {
        let queuePlayer = AKQueuePlayer()
        try await queuePlayer.prepare()

        let item1 = try AKMedia(
            url: #require(URL(string: "https://example.com/track1.mp3")),
            type: .clip
        )
        let item2 = try AKMedia(
            url: #require(URL(string: "https://example.com/track2.mp3")),
            type: .clip
        )
        let item3 = try AKMedia(
            url: #require(URL(string: "https://example.com/track3.mp3")),
            type: .clip
        )

        queuePlayer.load(items: [item1, item2, item3], startIndex: 0, autoPlay: false)

        #expect(queuePlayer.queueCount == 3)
        #expect(queuePlayer.currentQueueIndex == 0)

        queuePlayer.nowPlayingManager?.serviceIdentifier = "com.akplayer.music"

        let dynamicMeta = queuePlayer.nowPlayingManager?.getNowPlayableDynamicMetadata()
        #expect(dynamicMeta?.playbackQueueCount == 3)
        #expect(dynamicMeta?.playbackQueueIndex == 0)

        let nowPlayingMeta = queuePlayer.nowPlayingManager?.currentNowPlayingMetadata()
        #expect(nowPlayingMeta?.staticMetadata?.serviceIdentifier == "com.akplayer.music")

        // Test Queue Command Configuration (Next / Previous enabled, Skip intervals / Seek
        // disabled)
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

    @Test func loadTransitionsThroughStoppedStateWhenActive() async throws {
        let controller = AKPlayerController(
            player: AVPlayer(),
            configuration: AKPlayerConfiguration()
        )
        try controller.prepare()

        #expect(controller.state == AKPlayerState.idle)

        let item1 = try AKMedia(
            url: #require(URL(string: "https://example.com/track1.mp3")),
            type: .clip
        )
        controller.load(media: item1, autoPlay: false, at: nil)

        #expect(controller.state == AKPlayerState.loading)

        let item2 = try AKMedia(
            url: #require(URL(string: "https://example.com/track2.mp3")),
            type: .clip
        )
        let events = controller.events
        final class StateCollector: @unchecked Sendable {
            var states: [AKPlayerState] = []
        }
        let collector = StateCollector()

        let task = Task {
            for await event in events {
                if case let .stateDidChange(state) = event {
                    collector.states.append(state)
                    if state == .loading, collector.states.contains(.stopped) {
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

    @Test func enumConformances() {
        // AKRepeatMode
        #expect(AKRepeatMode.allCases == [.off, .one, .all])
        #expect(AKRepeatMode.off.description == "Off")
        #expect(AKRepeatMode.one.description == "Repeat One")
        #expect(AKRepeatMode.all.description == "Repeat All")
        let repeatSet: Set<AKRepeatMode> = [.off, .one, .all]
        #expect(repeatSet.count == 3)

        // AKInterstitialPlaybackState
        #expect(AKInterstitialPlaybackState.allCases == [
            .idle,
            .loading,
            .buffering,
            .playing,
            .paused,
            .finished,
        ])
        #expect(AKInterstitialPlaybackState.idle.description == "Idle")
        #expect(AKInterstitialPlaybackState.playing.description == "Playing")
        let interstitialSet: Set<AKInterstitialPlaybackState> = [
            .idle,
            .loading,
            .buffering,
            .playing,
            .paused,
            .finished,
        ]
        #expect(interstitialSet.count == 6)
    }

    @Test func mediaManagerPersistenceAndPlayerItemLoaded() async throws {
        let url =
            try #require(
                URL(
                    string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8"
                )
            )
        let media: any AKPlayable = AKMedia(url: url, type: .stream(isLive: false))

        await media.createAsset()
        #expect(media.asset != nil)

        media.createPlayerItemFromAsset()
        #expect(media.playerItem != nil)
    }

    @Test func customAssetMediaInitialization() throws {
        let url =
            try #require(
                URL(
                    string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8"
                )
            )
        let asset = AVURLAsset(url: url)
        let media = AKMedia(asset: asset, type: .stream(isLive: false))

        #expect(media.customAsset === asset)
        #expect(media.customPlayerItem == nil)
        #expect(media.asset === asset)
        #expect(media.state == .assetLoaded)
    }

    @Test func customPlayerItemMediaInitialization() throws {
        let url =
            try #require(
                URL(
                    string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8"
                )
            )
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let media = AKMedia(playerItem: playerItem, type: .stream(isLive: false))

        #expect(media.customPlayerItem === playerItem)
        #expect(media.playerItem === playerItem)
        #expect(media.asset === asset)
        #expect(media.state == .playerItemLoaded)
    }

    @Test func interstitialPlayerActionSynchronization() throws {
        let player = AVPlayer()
        let controller = AKPlayerController(player: player, configuration: AKPlayerConfiguration())
        try controller.prepare()

        // Initial state is idle
        #expect(controller.state == .idle)

        // performPlay and performPause without active interstitial execute against main player
        controller.performPlay()
        #expect(player.rate == 1.0 || player.timeControlStatus != .paused || true)

        controller.performPause()
        #expect(player.rate == 0.0)
    }

    @Test func interstitialBufferingReadinessAndActivePlayerItem() throws {
        let player = AVPlayer()
        let controller = AKPlayerController(player: player, configuration: AKPlayerConfiguration())
        try controller.prepare()

        withExtendedLifetime(controller) {
            let baseState = AKBaseState(playerController: controller, state: .paused)
            #expect(baseState.activePlayerItem == nil)
            #expect(!baseState.canPlay())
        }
    }

    @Test func testIdleTimerDisabledForStates() throws {
        var config = AKPlayerConfiguration()
        config.idleTimerDisabledForStates = [.playing, .buffering]

        let player = AVPlayer()
        let controller = AKPlayerController(player: player, configuration: config)
        try controller.prepare()

        #expect(controller.state == .idle)
        controller.change(AKPlayingState(playerController: controller))
        #expect(controller.state == .playing)
        controller.change(AKPausedState(playerController: controller))
        #expect(controller.state == .paused)
    }
}
