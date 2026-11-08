//
//   AKLoopRangeTests.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@testable import AKPlayer
import AVFoundation
import Foundation
import Testing

@MainActor
struct AKLoopRangeTests {
    @Test func loopRangeModelCalculations() {
        let start = CMTime(seconds: 5.0, preferredTimescale: 600)
        let end = CMTime(seconds: 15.0, preferredTimescale: 600)
        let loop = AKLoopRange(start: start, end: end)

        #expect(loop.startSeconds == 5.0)
        #expect(loop.endSeconds == 15.0)
        #expect(loop.duration.seconds == 10.0)
        #expect(loop.durationSeconds == 10.0)

        #expect(loop.contains(time: CMTime(seconds: 5.0, preferredTimescale: 600)))
        #expect(loop.contains(time: CMTime(seconds: 10.0, preferredTimescale: 600)))
        #expect(loop.contains(time: CMTime(seconds: 15.0, preferredTimescale: 600)))
        #expect(!loop.contains(time: CMTime(seconds: 15.01, preferredTimescale: 600)))
        #expect(!loop.contains(time: CMTime(seconds: 4.99, preferredTimescale: 600)))

        #expect(loop.contains(seconds: 5.0))
        #expect(loop.contains(seconds: 12.0))
        #expect(loop.contains(seconds: 15.0))
        #expect(!loop.contains(seconds: 15.1))
        #expect(!loop.contains(seconds: 2.0))
    }

    @Test func loopRangeEquality() {
        let loop1 = AKLoopRange(
            start: CMTime(seconds: 10, preferredTimescale: 600),
            end: CMTime(seconds: 20, preferredTimescale: 600)
        )
        let loop2 = AKLoopRange(
            start: CMTime(seconds: 10, preferredTimescale: 600),
            end: CMTime(seconds: 20, preferredTimescale: 600)
        )
        let loop3 = AKLoopRange(
            start: CMTime(seconds: 12, preferredTimescale: 600),
            end: CMTime(seconds: 20, preferredTimescale: 600)
        )

        #expect(loop1 == loop2)
        #expect(loop1 != loop3)
    }

    @Test func loopRejectsWhenNoItemLoaded() async throws {
        let player = AKPlayer()
        try await player.prepare()

        // No item loaded yet
        let success = player.setLoopRange(
            startSeconds: 5.0,
            endSeconds: 15.0
        )
        #expect(success == false)
        #expect(player.loopRange == nil)
        #expect(player.isLoopActive == false)
    }

    @Test func loopRejectsForLiveStreams() async throws {
        let player = AKPlayer()
        try await player.prepare()

        let liveUrl = try #require(URL(string: "https://example.com/live/master.m3u8"))
        let liveMedia = AKMedia(url: liveUrl, type: .stream(isLive: true))

        player.load(media: liveMedia, autoPlay: false)

        let success = player.setLoopRange(
            startSeconds: 5.0,
            endSeconds: 15.0
        )
        #expect(success == false)
        #expect(player.loopRange == nil)
        #expect(player.isLoopActive == false)
    }

    @Test func loopClearing() {
        let player = AKPlayer()
        player.clearLoop()
        #expect(player.loopRange == nil)
        #expect(player.isLoopActive == false)
    }
}
