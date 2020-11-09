//
//  AKPlaybackRate.swift
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

public enum AKPlaybackRate {
    case slowest
    case slower
    case slow
    case normal
    case fast
    case faster
    case fastest
    case superfast
    case custom(Float)
    
    public static let allCases: [AKPlaybackRate] = [.slowest, .slower, .slow, .normal, .fast, .faster, .fastest, .superfast]
    
    public init(rate: Float) {
        switch rate {
        case 0.25: self = .slowest
        case 0.50: self = .slower
        case 0.75: self = .slow
        case 1.00: self = .normal
        case 1.25: self = .fast
        case 1.50: self = .faster
        case 1.75: self = .fastest
        case 2.00: self = .superfast
        default: self = .custom(rate)
        }
    }
    
    public var rate: Float {
        switch self {
        case .slowest: return 0.25
        case .slower: return 0.5
        case .slow: return 0.75
        case .normal: return 1.0
        case .fast: return 1.25
        case .faster: return 1.5
        case .fastest: return 1.75
        case .superfast: return 2.00
        case .custom(let value): return value
        }
    }
    
    public var rateTitle: String { "\(rate)x" }
    
    public var title: String {
        switch self {
        case .slowest:   return "Slowest"
        case .slower:   return "Slower"
        case .slow:     return "Slow"
        case .normal:   return "Normal"
        case .fast:     return "Fast"
        case .faster:   return "Faster"
        case .fastest:   return "Fastest"
        case .superfast: return "Super Fast"
        case .custom(let value): return "\(value)x"
        }
    }
    
    public var next: AKPlaybackRate {
        switch self {
        case .slowest:   return .slower
        case .slower:   return .slow
        case .slow:     return .normal
        case .normal:   return .fast
        case .fast:     return .faster
        case .faster:   return .fastest
        case .fastest:   return .superfast
        case .superfast: return .slowest
        case .custom:   return .normal
        }
    }
}

extension AKPlaybackRate: Equatable {
    public static func ==(lhs: AKPlaybackRate, rhs: AKPlaybackRate) -> Bool {
        switch (lhs, rhs) {
        case (.slowest, .slowest), (.slower, .slower), (.slow, .slow), (.normal, .normal), (.fast, .fast), (.faster, .faster), (.fastest, .fastest), (.superfast, .superfast) :
            return true
        case (.custom(let lhs), .custom(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}
