# Live Streaming & Edge Synchronization

Monitor live stream playback, detect live edge drift, and navigate directly to the broadcast head.

## Overview

Live broadcasts have dynamically shifting timelines. AKPlayer provides built-in detection for live streams, live edge drift calculation, and convenience methods to jump to the live edge.

### Detecting Live Streams

Check ``AKPlayerProtocol/isLive`` and ``AKPlayerProtocol/isAtLiveEdge``:

```swift
if player.isLive {
    print("Currently playing a live stream.")
    if player.isAtLiveEdge {
        print("Player is synced with the live edge.")
    } else {
        print("Player has drifted behind the live edge.")
    }
}
```

### Jumping to the Live Edge

Use ``AKPlayerActionsProtocol/jumpToLive()`` to immediately seek to the latest broadcast head and resume playback at normal speed:

```swift
let success = await player.jumpToLive()
if success {
    print("Synchronized with live broadcast head.")
}
```

### Customizing Live Drift Thresholds

Configure drift tolerances in ``AKPlayerConfiguration/liveStream``:

```swift
var config = AKPlayerConfiguration()
config.liveStream.liveEdgeDriftThreshold = 8.0 // seconds
let player = AKPlayer(configuration: config)
```
