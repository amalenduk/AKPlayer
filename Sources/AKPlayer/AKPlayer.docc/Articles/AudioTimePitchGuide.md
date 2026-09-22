# Voice Pitch & Time-Stretch Processing

Configure high-fidelity audio pitch preservation and time stretching for spoken word and podcast audio.

## Overview

When playing media at accelerated speeds (such as 1.5x, 2.0x, or 3.0x), standard time-stretching can produce pitch distortion or unnatural robotic artifacts. AKPlayer provides full control over Apple's `AVAudioTimePitchAlgorithm` at the player, queue, configuration, and individual media levels.

### Pitch Algorithms

- ``AKAudioTimePitchAlgorithm/spectral``: Highest acoustic quality. Preserves pitch with great clarity across broad speed ranges. Recommended for podcasts and audiobooks.
- ``AKAudioTimePitchAlgorithm/timeDomain``: Low computational overhead. Suitable for modest speed adjustments with reduced CPU impact.
- ``AKAudioTimePitchAlgorithm/varispeed``: Changes pitch proportionally with rate (classic vinyl/tape effect).

### Setting the Pitch Algorithm

#### Player-Wide Configuration
```swift
var config = AKPlayerConfiguration()
config.audioTimePitchAlgorithm = .spectral
let player = AKPlayer(configuration: config)
```

#### Dynamic Runtime Adjustment
```swift
player.audioTimePitchAlgorithm = .spectral
```

#### Per-Media Override
```swift
var media = AKMedia(url: podcastURL)
media.audioTimePitchAlgorithm = .spectral
player.load(media: media)
```
