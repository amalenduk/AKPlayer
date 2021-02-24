//
//  AKPlayerDelegate.swift
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

public protocol AKPlayerDelegate: AnyObject {
    func akPlayer(_ player: AKPlayer, didStateChange state: AKPlayer.State)
    func akPlayer(_ player: AKPlayer, didCurrentMediaChange media: AKPlayable)
    func akPlayer(_ player: AKPlayer, didCurrentTimeChange currentTime: CMTime)
    func akPlayer(_ player: AKPlayer, didItemDurationChange itemDuration: CMTime)
    func akPlayer(_ player: AKPlayer, unavailableAction reason: AKPlayerUnavailableActionReason)
    func akPlayer(_ player: AKPlayer, didItemPlayToEndTime endTime: CMTime)
    func akPlayer(_ player: AKPlayer, didFailedWith error: AKPlayerError)
    func akPlayer(_ player: AKPlayer, didPlaybackRateChange playbackRate: AKPlaybackRate)
}
