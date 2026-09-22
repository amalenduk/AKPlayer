# FairPlay Streaming (DRM) Integration

Protect your premium media playback using Apple FairPlay Streaming DRM in AKPlayer.

## Overview

``AKFairPlayHandler`` coordinates with Apple's `AVContentKeySession` to request Server Playback Contexts (SPC) and exchange them for Content Key Contexts (CKC) from your Key Server Module (KSM).

### Configuration

Create an ``AKFairPlayConfiguration`` with certificate and license providers:

```swift
import AKPlayer
import Foundation

let fairPlayConfig = AKFairPlayConfiguration(
    certificateProvider: {
        // Fetch your FairPlay Application Certificate data
        let certURL = URL(string: "https://example.com/fairplay.cer")!
        let (data, _) = try await URLSession.shared.data(from: certURL)
        return data
    },
    licenseProvider: { spcData, assetID in
        // Exchange SPC data for CKC data with your Key Server (KSM)
        var request = URLRequest(url: URL(string: "https://example.com/fps/license")!)
        request.httpMethod = "POST"
        request.httpBody = spcData
        request.setValue(assetID, forHTTPHeaderField: "X-Asset-ID")
        let (ckcData, _) = try await URLSession.shared.data(for: request)
        return ckcData
    }
)
```

### Attaching FairPlay to Media

Assign the FairPlay configuration or handler directly to your ``AKMedia`` instance:

```swift
let protectedURL = URL(string: "https://example.com/protected/master.m3u8")!
var media = AKMedia(url: protectedURL)
media.fairPlayConfiguration = fairPlayConfig

player.load(media: media, autoPlay: true)
```

### Offline & Persistable Keys

`AKFairPlayHandler` supports persistable content keys for offline playback storage, key renewal, and server playback context verification.
