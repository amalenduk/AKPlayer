//
//  AKMediaMetadata.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import MediaPlayer

public struct AKMediaMetadata: AKPlayableMetadata {
    
    // MARK: - Properties
    
    public var staticMetadata: AKPlayableStaticMetadata?
    public var dynamicMetadata: AKPlayableDynamicMetadata?
    
    // MARK: - Init
    
    public init(staticMetadata: AKPlayableStaticMetadata?,
                dynamicMetadata: AKPlayableDynamicMetadata?
    ) {
        self.staticMetadata = staticMetadata
        self.dynamicMetadata = dynamicMetadata
    }
}

/* `AKMediaStaticMetadata` contains static properties of a playable item that don't depend on the state of the player for their value. */
public struct AKMediaStaticMetadata: AKPlayableStaticMetadata {
    
    // MARK: - Properties
    
    public var assetURL: URL                            // MPNowPlayingInfoPropertyAssetURL
    public var mediaType: MPNowPlayingInfoMediaType     // MPNowPlayingInfoPropertyMediaType
    public var isLiveStream: Bool                       // MPNowPlayingInfoPropertyIsLiveStream
    
    public var title: String                            // MPMediaItemPropertyTitle
    public var artist: String?                          // MPMediaItemPropertyArtist
    public var artwork: MPMediaItemArtwork?             // MPMediaItemPropertyArtwork
    
    public var albumArtist: String?                     // MPMediaItemPropertyAlbumArtist
    public var albumTitle: String?                      // MPMediaItemPropertyAlbumTitle
    
    // MARK: - Init
    
    public init(assetURL: URL,
                mediaType: MPNowPlayingInfoMediaType,
                isLiveStream: Bool,
                title: String,
                artist: String?,
                artwork: MPMediaItemArtwork?,
                albumArtist: String?,
                albumTitle: String?
    ) {
        self.assetURL = assetURL
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
    }
}

/* `AKMediaDynamicMetadata` contains dynamic properties of a playable item that depend on the state of the player for their value. */
public struct AKMediaDynamicMetadata: AKPlayableDynamicMetadata {
    
    // MARK: - Properties
    
    public var rate: Float                             // MPNowPlayingInfoPropertyPlaybackRate
    public var position: Float                         // MPNowPlayingInfoPropertyElapsedPlaybackTime
    public var duration: Float?                        // MPMediaItemPropertyPlaybackDuration
    
    public var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]     // MPNowPlayingInfoPropertyCurrentLanguageOptions
    public var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]     // MPNowPlayingInfoPropertyAvailableLanguageOptions
    
    // MARK: - Init
    
    public init(rate: Float,
                position: Float,
                duration: Float?,
                currentLanguageOptions: [MPNowPlayingInfoLanguageOption],
                availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]
    ) {
        self.rate = rate
        self.position = position
        self.duration = duration
        self.currentLanguageOptions = currentLanguageOptions
        self.availableLanguageOptionGroups = availableLanguageOptionGroups
    }
}
