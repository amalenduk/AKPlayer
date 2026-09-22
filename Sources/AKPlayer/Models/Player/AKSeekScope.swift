//
//   AKSeekScope.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKSeekScope

/// Specifies the timeline coordinate space targeted by a seek operation.
public enum AKSeekScope: String, Sendable, Equatable, CaseIterable {
    /// Seeks along the primary media asset's playback timeline (excluding interstitial ad
    /// durations).
    case primary

    /// Seeks along the stitched integrated timeline (inclusive of scheduled interstitial `.fill` ad
    /// breaks).
    case integrated
}
