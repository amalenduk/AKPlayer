# Getting Started with AKPlayer

Learn how to integrate and control media playback in your iOS application using AKPlayer.

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
        case let .periodicTimeDidChange(time):
            print("Current playback time: \(time.seconds)s")
        case let .mediaLoaded(media):
            print("Loaded media item: \(media)")
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

### Using Delegates

If your app uses delegate callbacks instead of `AsyncStream`, set `player.delegate`:

```swift
class MyPlaybackHandler: AKPlayerDelegate {
    func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        // Handle state change
    }
}

player.delegate = myHandler
```
