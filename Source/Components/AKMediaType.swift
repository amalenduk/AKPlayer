//
//  AKMediaType.swift
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

public enum AKMediaType {
    case clip
    case stream(isLive: Bool)
}

extension AKMediaType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .clip:
            return "Clip"
        case let .stream(isLive):
            return isLive ? "Live Stream" : "Replay Stream"
        }
    }
}

extension AKMediaType: Equatable { }

public func == (lhs: AKMediaType, rhs: AKMediaType) -> Bool {
    switch (lhs, rhs) {
    case (.clip, .clip):
        return true
    case (.stream, .clip):
        return false
    case (.clip, .stream):
        return false
    case (.stream(let isLiveLeft), .stream(let isLiveRight)):
        return isLiveLeft == isLiveRight
    }
}
