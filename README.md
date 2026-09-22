# AKPlayer

[![CI](https://github.com/amalenduk/AKPlayerSPM/actions/workflows/ci.yml/badge.svg)](https://github.com/amalenduk/AKPlayerSPM/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018.0%2B-blue.svg?style=flat)](https://developer.apple.com/ios/)
[![SwiftPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](LICENSE)
[![Concurrency](https://img.shields.io/badge/Concurrency-Strict%20Swift%206%20Safe-purple.svg?style=flat)](https://swift.org)

**AKPlayer** is a modern, enterprise-grade AVPlayer playback engine built from the ground up in **Swift 6** for **iOS 18+**. It combines a robust finite-state machine with structured async concurrency, first-class HLS live stream & interstitial ad support, automatic Lock Screen Now Playing integration, and SwiftUI components.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
  - [SwiftUI](#swiftui-quick-start)
  - [UIKit](#uikit-quick-start)
- [Architecture & State Machine](#architecture--state-machine)
- [Key Feature Guides](#key-feature-guides)
  - [1. Playback Controls & Seeking](#1-playback-controls--seeking)
  - [2. Queue & Playlist Playback](#2-queue--playlist-playback)
  - [3. Live Streams & Catch-Up](#3-live-streams--catch-up)
  - [4. Interstitial Ads & Progress Bar](#4-interstitial-ads--progress-bar)
  - [5. Lock Screen & Now Playing](#5-lock-screen--now-playing)
  - [6. Subtitles & Audio Track Selection](#6-subtitles--audio-track-selection)
  - [7. Chapters & Media Metadata](#7-chapters--media-metadata)
  - [8. Audio Session & Interruption Handling](#8-audio-session--interruption-handling)
  - [9. Picture-in-Picture (PiP)](#9-picture-in-picture-pip)
- [Configuration](#configuration)
- [Observing Events](#observing-events)
- [Demo App](#demo-app)
- [License](#license)

---

## Features

- ⚡️ **Swift 6 Strict Concurrency**: 100% thread-safe with `@MainActor`, `Sendable`, and native `Synchronization.Mutex`.
- 🔄 **Deterministic State Machine**: Clear lifecycle transitions (`idle`, `loading`, `loaded`, `buffering`, `playing`, `paused`, `waitingForNetwork`, `failed`, `stopped`).
- 🌐 **Automatic Network Recovery**: Seamless reconnect and resume on network recovery via `NWPathMonitor`.
- 📺 **HLS Interstitial Ads**: Full support for `AVPlayerInterstitialEventController`, cue point markers, fill ranges, and seek restrictions.
- 🔴 **Live Stream & DVR Engine**: Automatic live detection, low latency tracking, and 1-tap "Jump to Live Edge".
- 📑 **Playlist & Queue Management**: Built-in `AKQueuePlayer` with loop modes (`.off`, `.one`, `.all`), shuffle, and next/previous transitions.
- 🎛️ **Now Playing & Remote Commands**: Zero-boilerplate Control Center, Lock Screen, Dynamic Island, and Apple Watch media control integration.
- 💬 **Subtitles & Multi-Audio**: Discovery and selection of audio tracks, subtitles (CC / SDH), and accessibility descriptions matching system preferences.
- 🏷️ **Chapters & Metadata Provider**: Async extraction of ID3/HLS static and timed metadata along with chapter timelines.
- 🎧 **Smart Audio Session**: Automatic headphone disconnect pause, audio interruption recovery (calls, Siri), and spatial audio observers.
- 🖼️ **Picture-in-Picture (PiP)**: Full lifecycle control with UI restoration callbacks.
- 🎨 **SwiftUI & UIKit Ready**: Drop-in `AKPlayerView` and customizable `AKProgressBar`.

---

## Requirements

| Platform | Minimum Deployment Target | Swift Version | Xcode Version |
| :--- | :--- | :--- | :--- |
| **iOS** | **iOS 18.0+** | **Swift 6.0+** | **Xcode 16.0+** |

---

## Installation

### Swift Package Manager (SPM)

Add AKPlayer directly to your project in Xcode:

1. Go to **File** > **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/amalenduk/AKPlayerSPM.git`
3. Select **Up to Next Major Version** with `1.0.0` or your desired branch.

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/amalenduk/AKPlayerSPM.git", from: "1.0.0")
]
```

---

## Quick Start

### SwiftUI Quick Start

Play video in SwiftUI in under 15 lines of code:

```swift
import SwiftUI
import AKPlayer

struct ContentView: View {
    @State private var player = AKPlayer()
    
    var body: some View {
        VStack {
            // Video display view
            AKPlayerView(player: player.player)
                .aspectRatio(16/9, contentMode: .fit)
                .background(Color.black)
            
            // Playback controls
            HStack(spacing: 20) {
                Button("Play") { player.play() }
                Button("Pause") { player.pause() }
                Button("Jump 15s") { player.step(by: 15) }
            }
            .padding()
        }
        .task {
            // Load and automatically play a media URL
            if let url = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4") {
                let media = AKMedia(url: url)
                player.load(media: media, autoPlay: true)
            }
        }
    }
}
```

---

### UIKit Quick Start

Integrate with a UIViewController:

```swift
import UIKit
import AKPlayer

final class PlayerViewController: UIViewController {
    private let player = AKPlayer()
    private let playerView = AKPlayerView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Setup player view
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.player = player.player
        view.addSubview(playerView)

        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9.0/16.0)
        ])

        // Load media
        guard let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8") else { return }
        let media = AKMedia(url: url)
        player.load(media: media, autoPlay: true)
    }
}
```

---

## Architecture & State Machine

AKPlayer is powered by a deterministic, event-driven state machine. Every playback command is evaluated against the current state, preventing illegal operations and race conditions:

```
                      ┌───────────────┐
                      │     idle      │
                      └───────┬───────┘
                              │ load(media)
                              ▼
                      ┌───────────────┐
                      │    loading    │
                      └───────┬───────┘
                              │ readyToPlay
                              ▼
                      ┌───────────────┐
                      │    loaded     │
                      └───────┬───────┘
                              │
               ┌──────────────┴──────────────┐
               ▼                             ▼
       ┌───────────────┐             ┌───────────────┐
       │   buffering   │◄────────────┤    playing    │
       └───────┬───────┘             └───────┬───────┘
               │                             │
       ┌───────┴───────┐                     ▼
       ▼               ▼             ┌───────────────┐
┌──────────────┐┌──────────────┐     │    paused     │
│waitingNetwork││    failed    │     └───────────────┘
└──────────────┘└──────────────┘
```

You can inspect the state at any time via `player.state` or subscribe to asynchronous state transitions:

```swift
Task {
    for await event in player.events {
        if case .stateDidChange(let state) = event {
            print("Player transitioned to: \(state)")
        }
    }
}
```

---

## Key Feature Guides

### 1. Playback Controls & Seeking

AKPlayer provides precise, high-level control over playback rate and seeking targets:

```swift
// Play, pause, stop
player.play()
player.pause()
player.stop()

// Change playback speed
player.play(at: .fast2x) // or custom: AKPlaybackRate(rate: 1.75)

// Seeking to time, percentage, or live broadcast
player.seek(to: .seconds(45))       // 45 seconds from start
player.seek(to: .percentage(50))    // 50% into the duration
player.seek(to: .offset(-10))       // Rewind 10 seconds
player.step(by: 15)                 // Skip forward 15 seconds
```

---

### 2. Queue & Playlist Playback

Manage playlists effortlessly using `AKQueuePlayer`:

```swift
let queuePlayer = AKQueuePlayer()

let item1 = AKMedia(url: url1)
let item2 = AKMedia(url: url2)
let item3 = AKMedia(url: url3)

// Load playlist
queuePlayer.load(media: [item1, item2, item3], autoPlay: true)

// Playlist navigation
queuePlayer.next()
queuePlayer.previous()
queuePlayer.jumpTo(at: 2)

// Playlist modes
queuePlayer.repeatMode = .all // .off, .one, .all
queuePlayer.shuffleMode = true

// Reorder queue
queuePlayer.move(from: 0, to: 2)
queuePlayer.remove(at: 1)
```

---

### 3. Live Streams & Catch-Up

AKPlayer automatically detects live and HLS DVR streams:

```swift
let liveMedia = AKMedia(url: liveStreamURL)
player.load(media: liveMedia, autoPlay: true)

// Check live stream capabilities
if player.isLive {
    print("Broadcasting Live. Duration: \(player.duration)")
    
    // Jump straight to the live broadcast head
    player.jumpToLive()
}

// Observe player events for live status & time updates
Task {
    for await event in player.events {
        switch event {
        case .timeDidChange(let time):
            print("Current playback time: \(time.seconds), isAtLiveEdge: \(player.isAtLiveEdge)")
        default:
            break
        }
    }
}
```

---

### 4. Interstitial Ads & Progress Bar

Schedule pre-rolls, mid-rolls, and post-rolls with `AVPlayerInterstitialEventController` integration and render them using SwiftUI's `AKProgressBar`:

```swift
// Schedule a mid-roll ad break at 30 seconds
let adEvent = AKInterstitialScheduleConfig(
    identifier: "midroll-1",
    time: 30.0,
    templateItems: [AVPlayerItem(url: adVideoURL)],
    restrictions: [.constrainsSeekingForwardInPrimaryContent] // non-skippable
)
player.interstitialService.schedule(adEvent)

// SwiftUI interactive progress bar with Ad cue markers
struct PlayerControlsView: View {
    @ObservedObject var viewModel: SimpleVideoPlayerViewModel

    var body: some View {
        AKProgressBar(
            currentTime: viewModel.currentTime,
            duration: viewModel.duration,
            bufferProgress: viewModel.bufferProgress,
            markers: viewModel.player.interstitialService.markers,
            configuration: AKProgressBarConfiguration(
                activeMarkerColor: .yellow,
                playedMarkerColor: .gray,
                unplayedMarkerColor: .orange,
                enforceRestrictions: true // Prevents scrubbing past unplayed mandatory ads
            ),
            onSeek: { targetSeconds in
                viewModel.player.seek(to: .seconds(targetSeconds))
            }
        )
    }
}
```

---

### 5. Lock Screen & Now Playing

AKPlayer automatically manages metadata, artwork, and playback controls in Control Center, Lock Screen, Dynamic Island, and Apple Watch:

```swift
var config = AKPlayerConfiguration()
config.isNowPlayingEnabled = true
let player = AKPlayer(configuration: config)

// Attach rich metadata to your media
let metadata = AKMediaStaticMetadata(
    title: "WWDC Keynote",
    artist: "Apple Inc.",
    albumTitle: "Special Events",
    artworkImage: UIImage(named: "keynote_cover")
)
let media = AKMedia(url: videoURL, metadata: metadata)
player.load(media: media, autoPlay: true)
```

---

### 6. Subtitles & Audio Track Selection

Query available tracks, observe external accessibility changes, and select preferred languages:

```swift
// Fetch available audio tracks and subtitles
let audioTracks = try await player.currentMedia?.trackSelection.availableTracks(for: .audio)
let subtitles = try await player.currentMedia?.trackSelection.availableTracks(for: .subtitle)

// Select a specific subtitle option or turn off
if let spanish = subtitles?.first(where: { $0.displayName == "Spanish" }) {
    try await player.currentMedia?.trackSelection.select(spanish, for: .subtitle)
} else {
    try await player.currentMedia?.trackSelection.select(.off, for: .subtitle)
}

// Automatically choose based on user's system accessibility preferences
try await player.currentMedia?.trackSelection.selectPreferredTrack(for: .closedCaption)
```

---

### 7. Chapters & Media Metadata

Extract chapter markers and metadata on the fly:

```swift
// Observe chapters
Task {
    if let chapters = try? await player.currentMedia?.chapterService.chapters() {
        for chapter in chapters {
            print("Chapter: \(chapter.title), Time: \(chapter.timeRange.start.seconds)")
        }
    }
}

// Current active chapter
if let currentChapter = player.currentMedia?.chapterService.currentChapter {
    print("Now watching: \(currentChapter.title)")
}
```

---

### 8. Audio Session & Interruption Handling

`AKAudioSessionService` handles audio interruptions and route changes cleanly:

```swift
let audioService = AKAudioSessionService(audioSession: .sharedInstance())
let player = AKPlayer(audioSessionService: audioService)

// Observe audio route changes (e.g. headphones unplugged -> pause)
Task {
    for await event in audioService.routeChangesObserver.events {
        if case .routeChanged(let reason, _) = event, reason == .oldDeviceUnavailable {
            print("Headphones disconnected; auto-paused.")
        }
    }
}
```

---

### 9. Picture-in-Picture (PiP)

Effortlessly support Picture-in-Picture:

```swift
let pipController = AKPictureInPictureController(playerLayer: playerView.playerLayer)
pipController.delegate = self

// Toggle PiP
if pipController.isPictureInPicturePossible {
    pipController.startPictureInPicture()
}
```

---

## Configuration

Customize player behaviors with `AKPlayerConfiguration`:

```swift
var config = AKPlayerConfiguration()

// Network & Buffer Settings
config.bufferObservingTimeout = 15.0       // Buffer timeout in seconds before stall escalation
config.bufferObservingTimeInterval = 0.5    // Polling rate for buffer checks
config.maxBufferRetryCount = 3             // Auto-retry attempts before marking failed

// Features
config.isNowPlayingEnabled = true           // Enable Lock Screen / Control Center integration
config.isIdleTimerDisabledForPlaying = true // Prevent device from sleeping during playback
config.automaticallyPreservesTimeOffsetFromLive = true

let player = AKPlayer(configuration: config)
```

---

## Observing Events

AKPlayer supports both **Swift Modern Concurrency (`AsyncStream`)** and the **Delegate Pattern (`AKPlayerDelegate`)**.

### Using AsyncStream (`player.events`)

Subscribe to the unified `player.events` stream:

```swift
Task {
    for await event in player.events {
        switch event {
        case .stateDidChange(let state):
            print("State: \(state)")
            
        case .timeDidChange(let time):
            print("Current time: \(time.seconds)")
            
        case .playbackRateDidChange(let newRate, let previousRate):
            print("Playback rate changed from \(previousRate) to \(newRate)")
            
        case .mediaDidChange(let newMedia):
            print("Active media updated: \(newMedia)")
            
        case .didReachEnd(let time):
            print("Media played to end at: \(time.seconds)")
            
        case .boundaryReached(let time):
            print("Boundary time crossed at: \(time.seconds)")
            
        case .volumeDidChange(let volume):
            print("Volume changed: \(volume)")
            
        case .muteStatusDidChange(let isMuted):
            print("Mute status changed: \(isMuted)")
            
        case .commandUnavailable(let reason):
            print("Command unavailable: \(reason)")
            
        case .didFail(let error):
            print("Playback error: \(error)")
        }
    }
}
```

### Using AKPlayerDelegate

```swift
class MyPlayerCoordinator: AKPlayerDelegate {
    func player(_ player: any AKPlayerProtocol, didChangeState state: AKPlayerState) {
        print("Delegate state update: \(state)")
    }

    func player(_ player: any AKPlayerProtocol, didChangeTime time: CMTime) {
        // Handle periodic time
    }

    func player(_ player: any AKPlayerProtocol, didFailWith error: AKPlayerError) {
        print("Playback failed: \(error.localizedDescription)")
    }
}

player.delegate = myCoordinator
```

---

## Demo App

An interactive sample project demonstrating Simple Playback, Playlists / Queue, HLS Interstitials, and Live DVR streaming is included under [`Examples/AKPlayerDemo`](Examples/AKPlayerDemo).

To run the demo:
1. Open `Examples/AKPlayerDemo/AKPlayerDemo.xcodeproj` in **Xcode 16+**.
2. Select an **iOS 18+ Simulator** (e.g., iPhone 16).
3. Press **Run** (⌘R).

---

## License

AKPlayer is released under the **MIT License**. See [LICENSE](LICENSE) for details.
