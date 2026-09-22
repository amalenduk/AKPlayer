//
//   AKAudioTimePitchAlgorithm.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKAudioTimePitchAlgorithm

/// Processing algorithms used to control voice pitch preservation and time-stretching quality
/// when playing media at non-standard rates (e.g., 0.5x, 1.25x, 1.5x, 2.0x, 3.0x).
public enum AKAudioTimePitchAlgorithm: String, Sendable, CaseIterable, Equatable, Hashable, Codable,
    CustomStringConvertible
{
    // MARK: - Cases

    /// Highest quality spectral processing that preserves voice pitch naturally across variable
    /// speeds. Recommended for podcasts, audiobooks, and dialog.
    case spectral

    /// Computationally lightweight time-domain processing suitable for speech and brief scrubbing.
    case timeDomain

    /// High quality pitch scaling that alters pitch proportionally to playback speed (tape/vinyl
    /// style).
    case varispeed

    // MARK: - AVFoundation Bridge

    /// The matching `AVAudioTimePitchAlgorithm` representation in AVFoundation.
    public var avAlgorithm: AVAudioTimePitchAlgorithm {
        switch self {
        case .spectral:
            .spectral
        case .timeDomain:
            .timeDomain
        case .varispeed:
            .varispeed
        }
    }

    /// Initializes an `AKAudioTimePitchAlgorithm` from an AVFoundation `AVAudioTimePitchAlgorithm`.
    /// - Parameter avAlgorithm: The AVFoundation time-pitch algorithm.
    public init(avAlgorithm: AVAudioTimePitchAlgorithm) {
        switch avAlgorithm {
        case .spectral:
            self = .spectral
        case .timeDomain:
            self = .timeDomain
        case .varispeed:
            self = .varispeed
        default:
            self = .spectral
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .spectral:
            "Spectral (Natural Pitch)"
        case .timeDomain:
            "Time Domain (Speech / Low CPU)"
        case .varispeed:
            "Varispeed (Pitch Shifts with Speed)"
        }
    }
}
