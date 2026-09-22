//
//   AKSharePlayTests.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@testable import AKPlayer
import AVFoundation
import Foundation
import GroupActivities
import Testing

@MainActor
struct AKSharePlayTests {
    @Test func groupActivityInitializationAndMetadata() throws {
        let mediaURL = try #require(URL(string: "https://example.com/video.mp4"))
        let fallbackURL = try #require(URL(string: "https://example.com/watch/123"))

        let activity = AKGroupActivity(
            url: mediaURL,
            title: "Sci-Fi Thriller Episode 1",
            subtitle: "Season 1, Ep 1",
            fallbackURL: fallbackURL,
            activityType: .watchTogether,
            isLive: false,
            customAttributes: ["episodeId": "ep_101"]
        )

        #expect(activity.url == mediaURL)
        #expect(activity.title == "Sci-Fi Thriller Episode 1")
        #expect(activity.subtitle == "Season 1, Ep 1")
        #expect(activity.fallbackURL == fallbackURL)
        #expect(activity.activityType == .watchTogether)
        #expect(activity.isLive == false)
        #expect(activity.customAttributes?["episodeId"] == "ep_101")

        // Metadata checks
        let metadata = activity.metadata
        #expect(metadata.title == "Sci-Fi Thriller Episode 1")
        #expect(metadata.subtitle == "Season 1, Ep 1")
        #expect(metadata.type == .watchTogether)
        #expect(metadata.fallbackURL == fallbackURL)
    }

    @Test func groupActivityFromPlayableMedia() throws {
        let mediaURL = try #require(URL(string: "https://example.com/stream.m3u8"))
        let media = AKMedia(url: mediaURL, type: .stream(isLive: true))

        let activity = AKGroupActivity(from: media)
        #expect(activity.url == mediaURL)
        #expect(activity.isLive == true)
        #expect(activity.activityType == .watchTogether)
    }

    @Test func groupActivityCodable() throws {
        let mediaURL = try #require(URL(string: "https://example.com/podcast.mp3"))
        let original = AKGroupActivity(
            url: mediaURL,
            title: "Tech Podcast #42",
            subtitle: "Apple Ecosystem",
            activityType: .listenTogether
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AKGroupActivity.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.url == original.url)
        #expect(decoded.title == original.title)
        #expect(decoded.subtitle == original.subtitle)
        #expect(decoded.activityType == original.activityType)
    }

    @Test func sharePlayStateAndSuspensionReasons() {
        // States
        let inactive = AKSharePlayState.inactive
        #expect(inactive.description == "Inactive")
        #expect(inactive.isActive == false)
        #expect(inactive.isCoordinating == false)

        let connecting = AKSharePlayState.connecting
        #expect(connecting.description == "Connecting")
        #expect(connecting.isCoordinating == true)

        let active = AKSharePlayState.active(participantCount: 4)
        #expect(active.description.contains("4 participants"))
        #expect(active.isActive == true)
        #expect(active.isCoordinating == true)

        let suspended = AKSharePlayState.suspended(reason: .buffering)
        #expect(suspended.description.contains("Buffering"))
        #expect(suspended.isCoordinating == true)

        let ended = AKSharePlayState.ended
        #expect(ended.description == "Ended")
        #expect(ended.isCoordinating == false)

        // Suspension Reasons
        #expect(AKSharePlaySuspensionReason.allCases.count == 5)
        #expect(AKSharePlaySuspensionReason.userAction.description == "User Action")
        #expect(AKSharePlaySuspensionReason.buffering.description == "Buffering")
        #expect(AKSharePlaySuspensionReason.networkStall.description == "Network Stall")
        #expect(AKSharePlaySuspensionReason.waitingForParticipants
            .description == "Waiting For Participants")
    }

    @Test func sharePlayConfiguration() throws {
        let defaultConfig = AKSharePlayConfiguration.default
        #expect(defaultConfig.autoCoordinateIncomingSessions == true)
        #expect(defaultConfig.fallbackWebURL == nil)
        #expect(defaultConfig.suspensionWaitTimeout == 10.0)

        let fallbackURL = try #require(URL(string: "https://example.com/fallback"))
        let customConfig = AKSharePlayConfiguration(
            autoCoordinateIncomingSessions: false,
            fallbackWebURL: fallbackURL,
            activityType: .listenTogether,
            suspensionWaitTimeout: 15.0
        )
        #expect(customConfig.autoCoordinateIncomingSessions == false)
        #expect(customConfig.fallbackWebURL == fallbackURL)
        #expect(customConfig.activityType == .listenTogether)
        #expect(customConfig.suspensionWaitTimeout == 15.0)
    }

    @Test func sharePlayErrorLocalization() {
        let notEligible = AKSharePlayError.notEligibleForSharePlay
        #expect(notEligible.errorDescription?.contains("eligible") == true)

        let activationFailed = AKSharePlayError.sessionActivationFailed("User cancelled")
        #expect(activationFailed.errorDescription?.contains("User cancelled") == true)

        let invalidated = AKSharePlayError.sessionInvalidated("Call ended")
        #expect(invalidated.errorDescription?.contains("Call ended") == true)

        let coordinationFailed = AKSharePlayError.coordinationFailed("Timebase lock failed")
        #expect(coordinationFailed.errorDescription?.contains("Timebase lock failed") == true)

        let playerError = AKPlayerError.sharePlay(reason: notEligible)
        #expect(playerError.errorDescription?.contains("eligible") == true)
    }

    @Test func playerSharePlayIntegration() {
        let player = AKPlayer()
        #expect(player.sharePlay != nil)
        #expect(player.sharePlay?.state == .inactive)
        #expect(player.sharePlay?.participantCount == 0)

        // Test startObserving / stopObserving lifecycle
        player.sharePlay?.startObservingSessions()
        player.sharePlay?.stopObservingSessions()

        // Disabled SharePlay configuration
        var disabledConfig = AKPlayerConfiguration.default
        disabledConfig.isSharePlayEnabled = false
        let disabledPlayer = AKPlayer(configuration: disabledConfig)
        #expect(disabledPlayer.sharePlay == nil)
    }
}
