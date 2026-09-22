# Apple SharePlay (GroupActivities) Integration

Synchronize video, music, and audiobook playback with friends across FaceTime using Apple SharePlay.

## Overview

AKPlayer integrates with Apple's `GroupActivities` framework and `AVPlayerPlaybackCoordinator`. It handles group sessions, timeline synchronization, suspension events, participant counts, and automatic activity coordination.

### Automatic Coordination

By default, ``AKPlayer`` automatically observes incoming SharePlay group sessions initiated over FaceTime. When an activity starts, playback synchronizes seamlessly without extra code.

### Initiating a SharePlay Session

Call ``AKPlayerProtocol/startSharePlay(for:)`` on your player instance:

```swift
import AKPlayer

do {
    try await player.startSharePlay()
    print("SharePlay initiated!")
} catch {
    print("SharePlay activation error: \(error.localizedDescription)")
}
```

### Observing SharePlay State

Listen for ``AKPlayerEvent/sharePlayStateDidChange(_:)`` events from the player stream:

```swift
Task { @MainActor in
    for await event in player.events {
        if case let .sharePlayStateDidChange(state) = event {
            switch state {
            case .inactive:
                print("SharePlay inactive")
            case .connecting:
                print("Connecting to group session...")
            case let .active(count):
                print("Syncing playback with \(count) participants")
            case let .suspended(reason):
                print("Playback suspended: \(reason.description)")
            case .ended:
                print("SharePlay session ended")
            }
        }
    }
}
```

### Leaving or Ending a Session

```swift
// Leave session for local participant only
player.leaveSharePlay()

// End session for all participants in FaceTime group
player.endSharePlay()
```
