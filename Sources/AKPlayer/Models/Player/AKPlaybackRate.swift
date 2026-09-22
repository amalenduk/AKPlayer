//
//   AKPlaybackRate.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

/// Represents playback speed presets and custom multiplier rates for media
/// playback.
public enum AKPlaybackRate: CaseIterable, Sendable, Hashable {
    /// 0.25x speed.
    case slowest
    /// 0.50x speed.
    case slower
    /// 0.75x speed.
    case slow
    /// 1.00x normal speed.
    case normal
    /// 1.25x speed.
    case fast
    /// 1.50x speed.
    case faster
    /// 1.75x speed.
    case fastest
    /// 2.00x speed.
    case superfast
    /// 0.00x (paused) speed.
    case paused
    /// Custom playback rate multiplier.
    case custom(Float)

    /// A collection of standard predefined playback speed presets excluding
    /// `.paused` and `.custom`.
    public static let allCases: [AKPlaybackRate] = [
        .slowest, .slower, .slow, .normal, .fast, .faster, .fastest, .superfast,
    ]

    /// Initializes a playback rate matching a floating-point multiplier value.
    /// - Parameter rate: The float value representing speed (e.g., `1.0` for
    /// normal).
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
        case 0: self = .paused
        default: self = .custom(rate)
        }
    }

    /// The numeric floating-point playback speed value.
    public var rate: Float {
        switch self {
        case .slowest: 0.25
        case .slower: 0.5
        case .slow: 0.75
        case .normal: 1.0
        case .fast: 1.25
        case .faster: 1.5
        case .fastest: 1.75
        case .superfast: 2.00
        case .paused: 0
        case let .custom(value): value
        }
    }

    /// A string representation of the numeric rate formatted with a 'x'
    /// multiplier suffix (e.g., "1.5x").
    public var rateTitle: String {
        "\(rate)x"
    }

    /// A human-readable title describing the current rate preset.
    public var title: String {
        switch self {
        case .slowest: "Slowest"
        case .slower: "Slower"
        case .slow: "Slow"
        case .normal: "Normal"
        case .fast: "Fast"
        case .faster: "Faster"
        case .fastest: "Fastest"
        case .superfast: "Super Fast"
        case .paused: "Paused"
        case let .custom(value): "\(value)x"
        }
    }

    /// Returns the next sequential playback rate in the rotation sequence,
    /// wrapping around at max speed.
    public var next: AKPlaybackRate {
        switch self {
        case .slowest: .slower
        case .slower: .slow
        case .slow: .normal
        case .normal: .fast
        case .fast: .faster
        case .faster: .fastest
        case .fastest: .superfast
        case .superfast: .slowest
        case .paused: .normal
        case .custom: .normal
        }
    }
}

// MARK: - Equatable & Hashable Conformance

extension AKPlaybackRate: Equatable {
    /// Compares two `AKPlaybackRate` instances for equality.
    public static func == (lhs: AKPlaybackRate, rhs: AKPlaybackRate) -> Bool {
        switch (lhs, rhs) {
        case (.slowest, .slowest),
             (.slower, .slower),
             (.slow, .slow),
             (.normal, .normal),
             (.fast, .fast),
             (.faster, .faster),
             (.fastest, .fastest),
             (.superfast, .superfast),
             (.paused, .paused):
            true
        case let (.custom(lhs), .custom(rhs)):
            lhs == rhs
        default:
            false
        }
    }
    
    /// Hashes the essential components of this playback rate into the given hasher.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rate)
    }
}
