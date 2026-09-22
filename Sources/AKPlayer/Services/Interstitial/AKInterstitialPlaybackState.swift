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
    /// Interstitial playback has not started or has reset.
    case idle
    /// Interstitial asset is actively loading.
    case loading
    /// Interstitial playback is buffering media data.
    case buffering
    /// Interstitial is actively playing.
    case playing
    /// Interstitial playback is paused.
    case paused
    /// Interstitial has completed playback or skipped.
    case finished

    // MARK: - CustomStringConvertible

    /// A textual description of the interstitial playback state.
    public var description: String {
        rawValue.capitalized
    }
}
