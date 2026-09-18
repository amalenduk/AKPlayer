//
//   AKInterstitialPlaybackState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKInterstitialPlaybackState

/// Represents the active playback state of an interstitial ad or clip.
public enum AKInterstitialPlaybackState: String, CaseIterable, Sendable, Equatable, Hashable, CustomStringConvertible {
    case idle
    case loading
    case buffering
    case playing
    case paused
    case finished

    // MARK: - CustomStringConvertible

    public var description: String {
        rawValue.capitalized
    }
}
