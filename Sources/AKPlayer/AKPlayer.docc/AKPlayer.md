# ``AKPlayer``

A modern, highly modular, Swift 6 concurrency-ready audio/video playback framework for iOS and Apple platforms.

@Metadata {
    @TechnologyRoot
}

## Overview

**AKPlayer** provides an extensible, production-ready playback foundation built on top of Apple's AVFoundation framework. It features state machine architecture, stream caching, boundary time observers, audio session interruptions, Picture-in-Picture, Now Playing metadata sync, FairPlay Streaming (DRM), Apple SharePlay (`GroupActivities`), live edge synchronization, interstitial marker tracking, and high-fidelity pitch preservation for variable-speed audio.

### Key Highlights

- **Modern Concurrency**: Full Swift 6 strict concurrency compliance (`Sendable`, `@MainActor`, `AsyncStream`).
- **Apple SharePlay Integration**: Synchronize playback with friends across FaceTime using Apple's `GroupActivities` framework and `AVPlayerPlaybackCoordinator`.
- **FairPlay Streaming (DRM)**: Built-in `AKFairPlayHandler` to securely manage certificate loading and content key context (CKC) requests.
- **Audio Pitch & Time-Stretching**: Configurable `AVAudioTimePitchAlgorithm` algorithms (`.spectral`, `.timeDomain`, `.varispeed`) to preserve natural voice pitch during podcast/audiobook fast playback.
- **Live Stream Edge Synchronization**: Monitor live stream drift and jump directly to the live edge with `jumpToLive()`.
- **Timed Interstitials & Ads**: Parse HLS interstitials or synthesize local ad markers with custom action policies (`.skip`, `.freeze`, `.playAd`).
- **Rich Media & Chapters**: Integrated chapter navigation, static artwork/metadata, and dynamic Now Playing info synchronization.
- **Customizable UI**: Includes ready-to-use SwiftUI and UIKit progress bar components (`AKProgressBar`).

## Topics

### Getting Started

- <doc:GettingStarted>
- ``AKPlayer``
- ``AKPlayerController``
- ``AKPlayerManager``
- ``AKQueuePlayer``

### Core Protocols

- ``AKPlayerProtocol``
- ``AKPlayerActionsProtocol``
- ``AKPlayerControllerProtocol``
- ``AKPlayerDelegate``

### Playback States & Events

- ``AKPlayerState``
- ``AKPlayerEvent``
- ``AKPlayerError``
- ``AKPlaybackRate``
- ``AKSeekTarget``
- ``AKSeekScope``
- ``AKSeek``

### Configuration

- ``AKPlayerConfigurationProtocol``
- ``AKPlayerConfiguration``
- ``AKAudioSessionConfiguration``
- ``AKTimeEventFrequency``
- ``AKNetworkStatusMonitorProtocol``

### Media & Chapters

- ``AKPlayable``
- ``AKMedia``
- ``AKMediaItemProtocol``
- ``AKMediaLoadedNotification``
- ``AKChapter``
- ``AKMediaStaticMetadata``
- ``AKMediaMetadataProviderProtocol``

### Apple SharePlay (`GroupActivities`)

- <doc:SharePlayGuide>
- ``AKGroupActivity``
- ``AKGroupActivityType``
- ``AKSharePlayCoordinatorProtocol``
- ``AKSharePlayCoordinator``
- ``AKSharePlayConfiguration``
- ``AKSharePlayState``
- ``AKSharePlaySuspensionReason``
- ``AKSharePlayError``

### FairPlay Streaming (DRM)

- <doc:FairPlayStreaming>
- ``AKFairPlayHandler``
- ``AKFairPlayConfiguration``
- ``AKFairPlayCertificateProvider``
- ``AKFairPlayLicenseProvider``
- ``AKFairPlayError``

### Live Streaming

- <doc:LiveStreamingGuide>
- ``AKLiveStreamConfiguration``

### Voice Pitch & Time-Stretching

- <doc:AudioTimePitchGuide>
- ``AKAudioTimePitchAlgorithm``

### Interstitials & Ad Markers

- ``AKInterstitialMarker``
- ``AKPlayerInterstitialServiceProtocol``

### UI Components

- ``AKProgressBar``
- ``AKProgressBarDelegate``
- ``AKTimeFormattingUtility``
