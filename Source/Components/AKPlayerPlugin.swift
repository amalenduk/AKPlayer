//
//  AKPlayerPlugin.swift
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

public protocol AKPlayerPlugin {
    func playerPlugin(didInit player: AVPlayer)
    func playerPlugin(willStartLoading media: AKPlayable)
    func playerPlugin(didStartLoading media: AKPlayable)
    func playerPlugin(didStartBuffering media: AKPlayable)
    func playerPlugin(didChanged media: AKPlayable, with previousMedia: AKPlayable?)
    func playerPlugin(didLoad media: AKPlayable, with duration: CMTime)
    func playerPlugin(willStartPlaying media: AKPlayable, at position: CMTime)
    func playerPlugin(didStartPlaying media: AKPlayable)
    func playerPlugin(didPaused media: AKPlayable, at position: CMTime)
    func playerPlugin(didStopped media: AKPlayable, at position: CMTime)
    func playerPlugin(didStartWaitingForNetwork media: AKPlayable)
    func playerPlugin(didFailed media: AKPlayable, with error: AKPlayerError)
    func playerPlugin(didPlayToEnd media: AKPlayable, at endTime: CMTime)
}

extension AKPlayerPlugin {
    func playerPlugin(didInit player: AVPlayer) { }
    func playerPlugin(willStartLoading media: AKPlayable) { }
    func playerPlugin(didStartLoading media: AKPlayable) { }
    func playerPlugin(didStartBuffering media: AKPlayable) { }
    func playerPlugin(didChanged media: AKPlayable, with previousMedia: AKPlayable?) { }
    func playerPlugin(didLoad media: AKPlayable, with duration: CMTime) { }
    func playerPlugin(willStartPlaying media: AKPlayable, at position: CMTime) { }
    func playerPlugin(didStartPlaying media: AKPlayable) { }
    func playerPlugin(didPaused media: AKPlayable, at position: CMTime) { }
    func playerPlugin(didStopped media: AKPlayable, at position: CMTime) { }
    func playerPlugin(didStartWaitingForNetwork media: AKPlayable) { }
    func playerPlugin(didFailed media: AKPlayable, with error: AKPlayerError) { }
    func playerPlugin(didPlayToEnd media: AKPlayable, at endTime: CMTime) { }
}
