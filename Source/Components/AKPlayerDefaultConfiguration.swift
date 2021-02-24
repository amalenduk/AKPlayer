//
//  AKPlayerDefaultConfiguration.swift
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

import AVFoundation

public struct AKPlayerDefaultConfiguration: AKPlayerConfiguration {
    
    // MARK: - Properties
    
    public let periodicPlayingTimeInSecond: Double
    public let preferredTimescale: CMTimeScale
    public let itemLoadedAssetKeys: [String]
    public let boundaryTimeObserverMultiplier: Double
    public let bufferObservingTimeout: TimeInterval
    public let bufferObservingTimeInterval: TimeInterval
    public let audioSessionCategory: AVAudioSession.Category
    public let audioSessionMode: AVAudioSession.Mode
    public let audioSessionCategoryOptions: AVAudioSession.CategoryOptions
    public let isNowPlayingEnabled: Bool
    
    // MARK: - Init
    
    public init(periodicPlayingTimeInSecond: Double = 0.5,
                preferredTimescale: CMTimeScale = CMTimeScale(NSEC_PER_SEC),
                itemLoadedAssetKeys: [String] = ["playable", "duration", "commonMetadata", "metadata", "availableMetadataFormats", "lyrics"],
                boundaryTimeObserverMultiplier: Double = 0.20,
                bufferObservingTimeout: TimeInterval = 10,
                bufferObservingTimeInterval: TimeInterval = 0.3,
                audioSessionCategory: AVAudioSession.Category = .playback,
                audioSessionMode: AVAudioSession.Mode = .moviePlayback,
                audioSessionCategoryOptions: AVAudioSession.CategoryOptions = [],
                isNowPlayingEnabled: Bool = true) {
        self.periodicPlayingTimeInSecond = periodicPlayingTimeInSecond
        self.preferredTimescale = preferredTimescale
        self.itemLoadedAssetKeys = itemLoadedAssetKeys
        self.boundaryTimeObserverMultiplier = boundaryTimeObserverMultiplier
        self.bufferObservingTimeout = bufferObservingTimeout
        self.bufferObservingTimeInterval = bufferObservingTimeInterval
        self.audioSessionCategory = audioSessionCategory
        self.audioSessionMode = audioSessionMode
        self.audioSessionCategoryOptions = audioSessionCategoryOptions
        self.isNowPlayingEnabled = isNowPlayingEnabled
    }
}
