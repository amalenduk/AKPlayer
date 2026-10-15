//
//   AKSubtitleOutputServiceTests.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@testable import AKPlayer
import AVFoundation
import Testing

struct AKSubtitleOutputServiceTests {
    @Test func subtitleCuePropertiesAndCalculations() {
        let cue = AKSubtitleCue(
            text: "Hello, world!",
            attributedText: AttributedString("Hello, world!"),
            itemTime: CMTime(seconds: 12.5, preferredTimescale: 600)
        )

        #expect(cue.text == "Hello, world!")
        #expect(cue.attributedText != nil)
        #expect(cue.itemTime.seconds == 12.5)
        #expect(!cue.isEmpty)

        let emptyCue = AKSubtitleCue(
            text: "   \n  \t  ",
            itemTime: .zero
        )
        #expect(emptyCue.isEmpty)
    }

    @Test func subtitleOutputServiceStartAndStop() throws {
        let media = try AKMedia(
            url: #require(URL(string: "https://example.com/video.mp4")),
            type: .clip
        )
        let service = media.subtitleOutput

        #expect(!service.isRunning)
        #expect(service.currentCue == nil)
        #expect(service.suppressesPlayerRendering == true)

        // Start service
        service.start()
        #expect(service.isRunning == true)

        // Calling start again is idempotent
        service.start()
        #expect(service.isRunning == true)

        // Stop service
        service.stop()
        #expect(service.isRunning == false)
        #expect(service.currentCue == nil)

        // Calling stop again is idempotent
        service.stop()
        #expect(service.isRunning == false)
    }

    @Test func subtitleOutputServiceEvents() async throws {
        let media = try AKMedia(
            url: #require(URL(string: "https://example.com/video.mp4")),
            type: .clip
        )
        let service = media.subtitleOutput
        let stream = service.events

        service.start()
        service.stop()

        var events: [AKSubtitleEvent] = []
        for await event in stream {
            events.append(event)
            if events.count >= 3 {
                break
            }
        }

        #expect(events.contains(.isRunningDidChange(true)))
        #expect(events.contains(.isRunningDidChange(false)))
        #expect(events.contains(.cueDidChange(nil)))
    }

    @Test @MainActor func observablePlayerSubtitleControls() async throws {
        let player = AKPlayer()
        let observable = AKPlayerObservable(player: player)

        #expect(observable.currentSubtitleCue == nil)
        #expect(observable.currentSubtitleText == nil)
        #expect(observable.isSubtitleOutputRunning == false)

        let media = try AKMedia(
            url: #require(URL(string: "https://example.com/video.mp4")),
            type: .clip
        )
        let events = player.events
        player.load(media: media)

        for await event in events {
            if case .mediaDidChange = event {
                try? await Task.sleep(nanoseconds: 50_000_000)
                break
            }
        }

        #expect(observable.currentMedia != nil)
        observable.startSubtitleOutput()
        #expect(media.subtitleOutput.isRunning == true)

        observable.stopSubtitleOutput()
        #expect(media.subtitleOutput.isRunning == false)
    }
}
