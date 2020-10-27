//
//  AKPlayerUnavailableActionReason.swift
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

public enum AKPlayerUnavailableActionReason {
    case alreadyPaused
    case alreadyPlaying
    case alreadyStopped
    case alreadyTryingToPlay
    case seekPositionNotAvailable
    case loadMediaFirst
    case waitingForEstablishedNetwork
    case waitTillMediaLoaded
}

extension AKPlayerUnavailableActionReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .alreadyPaused:
            return "Already Paused"
        case .alreadyPlaying:
            return "Already Playing"
        case .alreadyStopped:
            return "Already Stopped"
        case .alreadyTryingToPlay:
            return "Wait a moment, already trying to play"
        case .seekPositionNotAvailable:
            return "Seek position not available"
        case .loadMediaFirst:
            return "Load a media first"
        case .waitingForEstablishedNetwork:
            return "Wait network to be established before"
        case .waitTillMediaLoaded:
            return "Wait media to be loaded before"
        }
    }
}
