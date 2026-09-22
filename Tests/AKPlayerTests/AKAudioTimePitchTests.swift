//
//   AKAudioTimePitchTests.swift
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
struct AKAudioTimePitchTests {
    @Test func audioTimePitchAlgorithmCasesAndAVConversion() {
        // Test spectral mapping
        #expect(AKAudioTimePitchAlgorithm.spectral.avAlgorithm == .spectral)
        #expect(AKAudioTimePitchAlgorithm(avAlgorithm: .spectral) == .spectral)

        // Test timeDomain mapping
        #expect(AKAudioTimePitchAlgorithm.timeDomain.avAlgorithm == .timeDomain)
        #expect(AKAudioTimePitchAlgorithm(avAlgorithm: .timeDomain) == .timeDomain)

        // Test varispeed mapping
        #expect(AKAudioTimePitchAlgorithm.varispeed.avAlgorithm == .varispeed)
        #expect(AKAudioTimePitchAlgorithm(avAlgorithm: .varispeed) == .varispeed)

        // Test CaseIterable
        #expect(AKAudioTimePitchAlgorithm.allCases.count == 3)
        #expect(AKAudioTimePitchAlgorithm.allCases.contains(.spectral))
        #expect(AKAudioTimePitchAlgorithm.allCases.contains(.timeDomain))
        #expect(AKAudioTimePitchAlgorithm.allCases.contains(.varispeed))

        // Descriptions
        #expect(AKAudioTimePitchAlgorithm.spectral.description.contains("Spectral"))
        #expect(AKAudioTimePitchAlgorithm.timeDomain.description.contains("Time Domain"))
        #expect(AKAudioTimePitchAlgorithm.varispeed.description.contains("Varispeed"))
    }

    @Test func audioTimePitchAlgorithmCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for algorithm in AKAudioTimePitchAlgorithm.allCases {
            let data = try encoder.encode(algorithm)
            let decoded = try decoder.decode(AKAudioTimePitchAlgorithm.self, from: data)
            #expect(decoded == algorithm)
        }
    }

    @Test func playerConfigurationDefaultAlgorithm() {
        let defaultConfig = AKPlayerConfiguration()
        #expect(defaultConfig.audioTimePitchAlgorithm == .spectral)

        let customConfig = AKPlayerConfiguration(audioTimePitchAlgorithm: .timeDomain)
        #expect(customConfig.audioTimePitchAlgorithm == .timeDomain)
    }

    @Test func mediaCustomAlgorithmInitialization() throws {
        let url = try #require(URL(string: "https://example.com/audiobook.mp3"))

        // Default media has nil override
        let defaultMedia = AKMedia(url: url, type: .clip)
        #expect(defaultMedia.audioTimePitchAlgorithm == nil)

        // Media with explicit spectral override
        let spectralMedia = AKMedia(
            url: url,
            type: .clip,
            audioTimePitchAlgorithm: .spectral
        )
        #expect(spectralMedia.audioTimePitchAlgorithm == .spectral)

        // Media with explicit varispeed override
        let varispeedMedia = AKMedia(
            url: url,
            type: .clip,
            audioTimePitchAlgorithm: .varispeed
        )
        #expect(varispeedMedia.audioTimePitchAlgorithm == .varispeed)
    }

    @Test func playerItemInitServiceAppliesMediaAlgorithm() throws {
        let url = try #require(URL(string: "https://example.com/podcast.m4a"))
        let media = AKMedia(url: url, type: .clip, audioTimePitchAlgorithm: .timeDomain)
        let asset = AVURLAsset(url: url)

        let initService = AKPlayerItemInitService()
        let playerItem = initService.createPlayerItem(from: asset, for: media)

        #expect(playerItem.audioTimePitchAlgorithm == AVAudioTimePitchAlgorithm.timeDomain)
    }

    @Test func playerDynamicAlgorithmUpdates() throws {
        let player = AKPlayer()
        #expect(player.audioTimePitchAlgorithm == .spectral)

        // Dynamically change on player
        player.audioTimePitchAlgorithm = .timeDomain
        #expect(player.audioTimePitchAlgorithm == .timeDomain)
        #expect(player.configuration.audioTimePitchAlgorithm == .timeDomain)

        // Test with custom item
        let url = try #require(URL(string: "https://example.com/audio.mp3"))
        let item = AVPlayerItem(url: url)
        _ = AKMedia(playerItem: item, audioTimePitchAlgorithm: .varispeed)
        item.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithm.varispeed

        let avPlayer = AVPlayer(playerItem: item)
        let playerWithItem = AKPlayer(player: avPlayer)
        #expect(playerWithItem.audioTimePitchAlgorithm == .varispeed)

        // Dynamically update through playerWithItem
        playerWithItem.audioTimePitchAlgorithm = .spectral
        #expect(item.audioTimePitchAlgorithm == AVAudioTimePitchAlgorithm.spectral)
        #expect(playerWithItem.audioTimePitchAlgorithm == .spectral)
    }

    @Test func queuePlayerAudioTimePitchAlgorithm() {
        let queuePlayer = AKQueuePlayer()
        #expect(queuePlayer.audioTimePitchAlgorithm == .spectral)

        queuePlayer.audioTimePitchAlgorithm = .varispeed
        #expect(queuePlayer.audioTimePitchAlgorithm == .varispeed)
    }
}
