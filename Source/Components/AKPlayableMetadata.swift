//
//  AKPlayableMetadata.swift
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

public protocol AKPlayableMetadata {
    var staticMetadata: AKPlayableStaticMetadata? { get set}
    var dynamicMetadata: AKPlayableDynamicMetadata? { get set}
}

/* `AKPlayableStaticMetadata` contains static properties of a playable item that don't depend on the state of the player for their value. */
public protocol AKPlayableStaticMetadata {
    var assetURL: URL { get set}                            // MPNowPlayingInfoPropertyAssetURL
    var mediaType: MPNowPlayingInfoMediaType { get set}     // MPNowPlayingInfoPropertyMediaType
    var isLiveStream: Bool { get set}                       // MPNowPlayingInfoPropertyIsLiveStream
    
    var title: String { get set}                            // MPMediaItemPropertyTitle
    var artist: String? { get set}                          // MPMediaItemPropertyArtist
    var artwork: MPMediaItemArtwork? { get set}             // MPMediaItemPropertyArtwork
    
    var albumArtist: String? { get set}                     // MPMediaItemPropertyAlbumArtist
    var albumTitle: String? { get set}                      // MPMediaItemPropertyAlbumTitle
}

/* `AKPlayableDynamicMetadata` contains dynamic properties of a playable item that depend on the state of the player for their value. */
public protocol AKPlayableDynamicMetadata {
    var rate: Float { get set}                             // MPNowPlayingInfoPropertyPlaybackRate
    var position: Float { get set}                         // MPNowPlayingInfoPropertyElapsedPlaybackTime
    var duration: Float? { get set}                         // MPMediaItemPropertyPlaybackDuration
    
    var currentLanguageOptions: [MPNowPlayingInfoLanguageOption] { get set}     // MPNowPlayingInfoPropertyCurrentLanguageOptions
    var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup] { get set}     // MPNowPlayingInfoPropertyAvailableLanguageOptions
}
