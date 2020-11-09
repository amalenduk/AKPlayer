//
//  AKPlayerManageable.swift
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
import AVFoundation

public protocol AKPlayerManageableDelegate: class {
    func playerManager(didStateChange state: AKPlayer.State)
    func playerManager(didPlaybackRateChange playbackRate: AKPlaybackRate)
    func playerManager(didCurrentMediaChange media: AKPlayable)
    func playerManager(didCurrentTimeChange currentTime: CMTime)
    func playerManager(didItemDurationChange itemDuration: CMTime)
    func playerManager(unavailableAction reason: AKPlayerUnavailableActionReason)
    func playerManager(didItemPlayToEndTime endTime: CMTime)
    func playerManager(didFailedWith error: AKPlayerError)
}

public protocol AKPlayerManageable: AKPlayerExposable {
    var audioSessionService: AKAudioSessionServiceable { get }
    var playerNowPlayingMetadataService: AKPlayerNowPlayingMetadataServiceable? { get }
    var configuration: AKPlayerConfiguration { get }
    var controller: AKPlayerStateControllable! { get }
    var delegate: AKPlayerManageableDelegate? { get }
    var plugins: [AKPlayerPlugin] { get }
    
    func change(_ controller: AKPlayerStateControllable)
}
