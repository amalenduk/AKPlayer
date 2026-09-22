//
//   TestMedia.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import Foundation

// MARK: - TestMediaKind

public enum TestMediaKind: String, Codable {
    case clip
    case live
}

// MARK: - TestMedia

public struct TestMedia: Identifiable, Codable {
    public var id = UUID()
    public let name: String
    public let subtitle: String?
    public let url: URL?
    public let kind: TestMediaKind
    public let isPlayable: Bool
    public let note: String?
    public let testCapabilities: [String]?
    public let audioLanguages: [String]?
    public let subtitleLanguages: [String]?

    public init(
        name: String,
        subtitle: String? = nil,
        url: URL?,
        kind: TestMediaKind = .clip,
        isPlayable: Bool = true,
        note: String? = nil,
        testCapabilities: [String]? = nil,
        audioLanguages: [String]? = nil,
        subtitleLanguages: [String]? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.url = url
        self.kind = kind
        self.isPlayable = isPlayable
        self.note = note
        self.testCapabilities = testCapabilities
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
    }
}

// MARK: - TestMediaKind + AKMediaType

public extension TestMediaKind {
    var akMediaType: AKMediaType {
        switch self {
        case .clip:
            .clip
        case .live:
            .stream(isLive: true)
        }
    }
}

// MARK: - Sample Test Media Catalog

@MainActor
public var sampleVideoMedia: [TestMedia] {
    sampleTestMedia.filter { media in
        media
            .kind == .clip &&
            !(media.name.localizedCaseInsensitiveContains("Audiobook") || media.name
                .localizedCaseInsensitiveContains("SoundHelix") || media.name
                .localizedCaseInsensitiveContains("Audio-Only"))
    }
}

@MainActor
public var sampleLiveMedia: [TestMedia] {
    sampleTestMedia.filter { $0.kind == .live }
}

@MainActor
public var sampleAudiobookMedia: [TestMedia] {
    sampleTestMedia.filter { media in
        media.name.localizedCaseInsensitiveContains("Audiobook") || media.name
            .localizedCaseInsensitiveContains("SoundHelix") || media.name
            .localizedCaseInsensitiveContains("Audio-Only")
    }
}

@MainActor
public var sampleQueueMedia: [TestMedia] {
    sampleTestMedia
}

@MainActor
public let sampleTestMedia: [TestMedia] = [
    // 1. Apple TV Trailer Advanced Stream
    TestMedia(
        name: "Apple TV Trailer Advanced",
        subtitle: "Dolby Vision + Dolby Atmos + Multi-tier H.264",
        url: URL(
            string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"
        ),
        kind: .clip,
        isPlayable: true,
        note: """
        AVC, HEVC and Dolby Vision variants with subtitles and audio renditions.

        📺 Video Specifications:
        • Format: H.264 Video variants, 24 fps
        • Aspect Ratio: 16:9
        • HDR: Dolby Vision Profile 5
        • Tier 1: 1920x1080 @ 8 Mbps
        • Tier 2: 1280x720 @ 4 Mbps
        • Tier 3: 960x540 @ 2 Mbps

        🔊 Audio Specifications:
        • Format: Dolby Atmos, 48 kHz
        • Fallback: AAC-LC, Stereo, 128 Kbps
        • Languages: English
        """,
        testCapabilities: [
            "Dolby Vision Profile 5 HDR rendering",
            "Dolby Atmos / Spatial Audio output",
            "Adaptive bitrate & resolution switching (1080p / 720p / 540p)",
            "AVPlayer layer rendering & aspect ratio fitting",
            "Audio session routing & route changes",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: ["en"]
    ),

    // 2. Apple TV Trailer Interstitial Stream
    TestMedia(
        name: "Apple TV Trailer Interstitials",
        subtitle: "HLS Interstitials (Ads at 00:10, 00:25, 00:55) + Multi-Audio + Multi-Subtitle",
        url: URL(
            string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/interstitial-sample/mvp_interstitial_sample.m3u8"
        ),
        kind: .clip,
        isPlayable: true,
        note: """
        AVC and HEVC primary with Bip bop streams as Interstitials.

        ⏱️ Interstitial Ad Schedule:
        • ad1: Start offset 00:10 | Playout Limit: 5.0s | Restrict: JUMP
        • ad2: Start offset 00:25 | Uses Asset list ads.json | Playout Limit: 23.0s (Midroll-1 & Midroll-2)
        • ad3: Start offset 00:55 | Playout Limit: 10.0s

        📺 Primary Video Specifications:
        • AVC 1024x576 @ 2.1 Mbps
        • HEVC 1920x1080 @ 2.7 Mbps
        • HEVC, Dolby Vision Profile 5, 3840x2160 @ 24 Mbps

        🔊 Primary Audio Specifications:
        • HE-AAC, stereo, 44.1 kHz @ 69 kbps
        • Dolby Digital, 5.1, 48 kHz @ 384 kbps
        • Dolby Atmos, 7.1, 48 kHz @ 768 kbps
        • Languages: English

        💬 Primary Subtitle Renditions:
        • English
        • Español (España)
        • ID3 Metadata via 'emsg'

        🎬 Interstitial Specifications:
        • ad1: HEVC 720p up to 4K (3840x2160 @ 2.1 Mbps), AAC LC 48 kHz 128 kbps
        • ad2 (Midroll-1): HEVC 720p up to 4K @ 2.2 Mbps, AAC LC 48 kHz 128 kbps
        • ad2 (Midroll-2): HEVC 720p up to 4K @ 2.3 Mbps, AAC LC 48 kHz 128 kbps
        • ad3: AVC 540p / HEVC 720p & 1080p @ 6 Mbps, AAC LC 48 kHz 128 kbps
        """,
        testCapabilities: [
            "HLS Server/Client Interstitials lifecycle & events",
            "Ad cue point transitions (at 10s, 25s, 55s)",
            "Playout limits & JUMP restrictions handling",
            "Multi-audio track switching (HE-AAC, Dolby Digital 5.1, Dolby Atmos 7.1)",
            "Subtitle track switching (English, Spanish)",
            "ID3 / emsg timed metadata observation",
            "Timeline integration & snapshot synchronization",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: ["en", "es"]
    ),

    // 3. Bip Bop Stream
    TestMedia(
        name: "Bip Bop Advanced Stream",
        subtitle: "Burned-in Timecode Display + HEVC & H.264 Fallback Variants",
        url: URL(
            string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8"
        ),
        kind: .clip,
        isPlayable: true,
        note: """
        Bip bop AVC and HEVC variants with subtitles and audio renditions.

        📺 Video Specifications:
        • Format: HEVC variants with H.264 fallback
        • Frame Rate: 30 fps
        • Aspect Ratio: 16:9
        • Tier 1: 1920x1080 @ 6 Mbps (HEVC)
        • Tier 2: 1280x720 @ 3 Mbps (HEVC)
        • Tier 3: 960x540 @ 1.5 Mbps (H.264)

        🔊 Audio Specifications:
        • Format: AAC-LC, Stereo, 48 kHz, 128 Kbps
        • Languages: English
        """,
        testCapabilities: [
            "Visual timecode verification with burned-in display",
            "Accurate scrubbing & seek precision",
            "Variable playback rates (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x)",
            "Picture-in-Picture (PiP) playback and background transitions",
            "Adaptive bitrate variant switching (HEVC & H.264)",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: ["en"]
    ),

    // 4. iReplay 24/7 Live Stream
    TestMedia(
        name: "iReplay 24/7 Live Stream",
        subtitle: "Continuous Live Broadcast + fMP4 + Sliding Window DVR",
        url: URL(string: "https://ireplay.tv/test/blender.m3u8"),
        kind: .live,
        isPlayable: true,
        note: """
        Continuous 24/7 live HLS broadcast stream with live sliding window DVR.

        📺 Video Specifications:
        • Format: H.264 Video variants (Live Sliding Window, fMP4)
        • Aspect Ratio: 16:9
        • Multi-bitrate: 540p / 720p / 1080p up to 3.1 Mbps
        • Metadata: #EXT-X-PROGRAM-DATE-TIME wall-clock timestamps

        🔊 Audio Specifications:
        • Format: AAC-LC, Stereo, 48 kHz
        • Languages: English
        """,
        testCapabilities: [
            "24/7 live stream playback & sliding window buffer",
            "Jump to Live UI & live seek head management",
            "Live stream pausing & seek-to-live recovery",
            "Live drift calculation & catch-up playback",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: nil
    ),

    // 5. Bloomberg Originals Live Stream
    TestMedia(
        name: "Bloomberg Originals Live",
        subtitle: "24/7 Live Financial News Broadcast • 1080p HD",
        url: URL(
            string: "https://86fdc85a.wurl.com/master/f36d25e7e52f1ba8d7e56eb859c636563214f541/TEctZ2JfQmxvb21iZXJnT3JpZ2luYWxzX0hMUw/playlist.m3u8"
        ),
        kind: .live,
        isPlayable: true,
        note: """
        Continuous 24/7 live news broadcast stream from Bloomberg Originals.

        📺 Video Specifications:
        • Format: H.264 Video variants (1080p / 540p / 360p / 216p)
        • Closed Captions: English CC

        🔊 Audio Specifications:
        • Format: AAC-LC, Stereo, 48 kHz
        • Languages: English
        """,
        testCapabilities: [
            "24/7 live broadcast stream playback",
            "Live head tracking & DVR buffer window",
            "Live indicator UI & Jump to Live action",
            "Closed captioning in live streams",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: ["en"]
    ),

    // 5. Big Buck Bunny (Progressive MP4)
    TestMedia(
        name: "Big Buck Bunny",
        subtitle: "1080p Progressive MP4 Clip",
        url: URL(
            string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        ),
        kind: .clip,
        isPlayable: true,
        note: """
        High-definition progressive MP4 animation clip by Blender Foundation.

        📺 Video Specifications:
        • Format: H.264 Baseline Profile, 1920x1080 @ 30 fps
        • Aspect Ratio: 16:9
        • Bitrate: ~2.5 Mbps

        🔊 Audio Specifications:
        • Format: AAC-LC, Stereo, 44.1 kHz, 128 kbps
        • Languages: English (Soundtrack)
        """,
        testCapabilities: [
            "Progressive MP4 download & caching",
            "Frame stepping forward and backward",
            "Accurate seek tolerance and scrubbing",
            "Full-screen scaling modes (.fit, .fill)",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: nil
    ),

    // 6. For Bigger Blazes (Nature Clip)
    TestMedia(
        name: "For Bigger Blazes (Nature Clip)",
        subtitle: "720p MP4 Short Form Clip",
        url: URL(
            string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
        ),
        kind: .clip,
        isPlayable: true,
        note: """
        Short progressive MP4 video clip for fast loading and playback testing.

        📺 Video Specifications:
        • Format: H.264, 1280x720 @ 30 fps
        • Aspect Ratio: 16:9

        🔊 Audio Specifications:
        • Format: AAC-LC, Stereo, 44.1 kHz
        • Languages: English
        """,
        testCapabilities: [
            "Fast asset initialization & quick start playback",
            "Looping and repeat mode verification",
            "Playback rate controls and audio pitch correction",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: nil
    ),

    // 7. Apple HLS Audio-Only Stream
    TestMedia(
        name: "Apple HLS Audio-Only Stream",
        subtitle: "HLS Audio Stream • AAC-LC 48 kHz @ 128 kbps",
        url: URL(
            string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/a1/prog_index.m3u8"
        ),
        kind: .clip,
        isPlayable: true,
        note: """
        Multi-segment HLS audio stream from Apple developer streaming catalog.

        🔊 Audio Specifications:
        • Format: AAC-LC (MPEG-4 Audio), Stereo
        • Sampling Rate: 48 kHz
        • Bitrate: 128 kbps
        • Container: HLS (.m3u8) audio rendition
        • Languages: English
        """,
        testCapabilities: [
            "HLS audio-only segment streaming & buffering",
            "Background audio playback with lock screen controls",
            "Now Playing metadata updates and cover art",
            "Audio route changes (Headphones / Bluetooth / AirPlay)",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: nil
    ),

    // 8. SoundHelix Song 1 (Progressive MP3)
    TestMedia(
        name: "SoundHelix Song 1",
        subtitle: "Progressive MP3 Instrumental (Duration: 6:12)",
        url: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"),
        kind: .clip,
        isPlayable: true,
        note: """
        High-quality synthesizer-generated instrumental track in standard MP3 format.

        🔊 Audio Specifications:
        • Format: MP3 (MPEG-1 Audio Layer III)
        • Sampling Rate: 44.1 kHz, Stereo
        • Bitrate: 192 kbps CBR
        • Duration: 6 minutes 12 seconds
        """,
        testCapabilities: [
            "Progressive MP3 audio streaming and playback",
            "Accurate audio timeline scrubbing and seeking",
            "Remote command center play/pause/skip commands",
            "Audio session ducking and phone call interruptions",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: nil
    ),

    // 9. SoundHelix Song 2 (Progressive MP3)
    TestMedia(
        name: "SoundHelix Song 2",
        subtitle: "Progressive MP3 Instrumental (Duration: 7:05)",
        url: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"),
        kind: .clip,
        isPlayable: true,
        note: """
        Progressive MP3 audio track for playlist queueing and track switching tests.

        🔊 Audio Specifications:
        • Format: MP3 (MPEG-1 Audio Layer III)
        • Sampling Rate: 44.1 kHz, Stereo
        • Bitrate: 192 kbps CBR
        • Duration: 7 minutes 5 seconds
        """,
        testCapabilities: [
            "Sequential audio track switching and queue transitions",
            "Audio pitch preservation at variable playback speeds",
            "Lock screen playback rate manipulation (0.5x, 1.0x, 2.0x)",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: nil
    ),

    // 10. The Art of War (Chaptered M4B Audiobook)
    TestMedia(
        name: "The Art of War (Audiobook)",
        subtitle: "LibriVox M4B Audiobook with 13 Embedded Chapters",
        url: URL(
            string: "https://archive.org/download/art_of_war_librivox/art_of_war_librivox.m4b"
        ),
        kind: .clip,
        isPlayable: true,
        note: """
        Complete M4B Audiobook containing 13 chapters by Sun Tzu, recorded by LibriVox.

        📖 Embedded Chapter Markers:
        • Chapter 1: Laying Plans
        • Chapter 2: Waging War
        • Chapter 3: Attack by Stratagem
        • Chapter 4: Tactical Dispositions
        • Chapter 5: Energy
        • Chapter 6: Weak Points & Strong
        • Chapter 7: Maneuvering
        • Chapter 8: Variation in Tactics
        • Chapter 9: The Army on the March
        • Chapter 10: Terrain
        • Chapter 11: The Nine Situations
        • Chapter 12: The Attack by Fire
        • Chapter 13: The Use of Spies

        🔊 Audio Specifications:
        • Format: AAC-LC in M4B Container
        • Sampling Rate: 44.1 kHz, Mono/Stereo
        • Duration: ~1 hour 12 minutes
        """,
        testCapabilities: [
            "AKChapterService chapter extraction & parsing",
            "Chapter boundary jumping (nextChapter / previousChapter)",
            "Now Playing chapter title & artwork sync",
            "Audiobook resume & bookmarking",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: nil
    ),

    // 11. Alice's Adventures in Wonderland (Chaptered M4B Audiobook)
    TestMedia(
        name: "Alice in Wonderland (Audiobook)",
        subtitle: "LibriVox M4B Audiobook with 12 Embedded Chapters",
        url: URL(
            string: "https://archive.org/download/alices_adventures_1005_librivox/AlicesAdventuresInWonderlandV5_librivox.m4b"
        ),
        kind: .clip,
        isPlayable: true,
        note: """
        Classic M4B Audiobook by Lewis Carroll with embedded chapter markers.

        📖 Embedded Chapter Markers:
        • Chapter 1: Down the Rabbit-Hole
        • Chapter 2: The Pool of Tears
        • Chapter 3: A Caucus-Race and a Long Tale
        • Chapter 4: The Rabbit Sends in a Little Bill
        • Chapter 5: Advice from a Caterpillar
        • Chapter 6: Pig and Pepper
        • Chapter 7: A Mad Tea-Party
        • Chapter 8: The Queen's Croquet-Ground
        • Chapter 9: The Mock Turtle's Story
        • Chapter 10: The Lobster Quadrille
        • Chapter 11: Who Stole the Tarts?
        • Chapter 12: Alice's Evidence

        🔊 Audio Specifications:
        • Format: AAC-LC in M4B Container
        • Duration: ~2 hours 40 minutes
        """,
        testCapabilities: [
            "Multi-chapter navigation and chapter index lookup",
            "Long-form audio playback stability & background suspension",
            "Periodic time updates and timeline scrubber chapter indicators",
        ],
        audioLanguages: ["en"],
        subtitleLanguages: nil
    ),
]
