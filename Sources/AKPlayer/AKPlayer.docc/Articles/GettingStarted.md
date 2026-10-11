# Getting Started with AKPlayer

Learn how to integrate and control media playback in your iOS, iPadOS, tvOS, or macOS application using AKPlayer.

## Overview

``AKPlayer`` is the primary, high-level interface for loading media, managing playback state, seeking, and receiving asynchronous events.

### Basic Setup

To initialize a player and begin playback:

```swift
import AKPlayer
import Foundation

@MainActor
func setupPlayer() {
    let player = AKPlayer()
    
    // Create a playable media item
    guard let url = URL(string: "https://example.com/stream.m3u8") else { return }
    let media = AKMedia(url: url)
    
    // Load and automatically start playback
    player.load(media: media, autoPlay: true)
}
```

### Observing Playback Events

AKPlayer publishes lifecycle and playback changes via Swift Concurrency `AsyncStream`:

```swift
Task { @MainActor in
    for await event in player.events {
        switch event {
        case let .stateDidChange(state):
            print("Player state changed to: \(state)")
        case let .autoPlayDidChange(isAutoPlay):
            print("AutoPlay status changed to: \(isAutoPlay)")
        case let .timeDidChange(time):
            print("Current playback time: \(time.seconds)s")
        case let .mediaDidChange(media):
            print("Active media item: \(media)")
        case let .playbackRateDidChange(newRate, previousRate):
            print("Playback rate changed from \(previousRate) to \(newRate)")
        case let .didReachEnd(time):
            print("Reached end of media at: \(time.seconds)s")
        case let .didFail(error):
            print("Playback failed with error: \(error)")
        default:
            break
        }
    }
}
```

### Playback Controls

```swift
// Basic controls
player.play()
player.pause()
player.togglePlayPause()
player.stop()

// Variable speed playback
player.play(at: .custom(1.5))

// Seeking
await player.seek(to: .seconds(45.0))
```

### SwiftUI & Observation

For SwiftUI applications, use ``AKPlayerObservable`` to bind state directly to views:

```swift
import AKPlayer
import SwiftUI

struct PlayerControls: View {
    @State private var model = AKPlayerObservable()

    var body: some View {
        VStack {
            Text("State: \(model.state.rawValue)")
            Text("Time: \(model.currentTimeSeconds) / \(model.durationSeconds)")

            Button(model.isPlaying ? "Pause" : "Play") {
                model.togglePlayPause()
            }
        }
        .task {
            if let url = URL(string: "https://example.com/stream.m3u8") {
                model.load(media: AKMedia(url: url), autoPlay: true)
            }
        }
    }
}
```
