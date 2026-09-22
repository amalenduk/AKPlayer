//
//   AKPlayerInterstitialProgress.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKPlayerInterstitialProgress

/// Value type representing real-time playback progress metrics for an active interstitial ad break.
public struct AKPlayerInterstitialProgress: Sendable, Equatable {
    /// The current playback elapsed time within the interstitial in seconds.
    public let currentTime: TimeInterval
    /// The total duration of the active interstitial in seconds.
    public let duration: TimeInterval
    /// The remaining duration in seconds until the interstitial completes.
    public let timeRemaining: TimeInterval

    /// Normalized playback progress percentage between 0.0 and 1.0.
    public var percentage: Double {
        duration > 0 ? min(1.0, currentTime / duration) : 0
    }

    /// Initializes an interstitial progress snapshot.
    /// - Parameters:
    ///   - currentTime: The current elapsed playback time in seconds.
    ///   - duration: The total duration in seconds.
    ///   - timeRemaining: The remaining duration in seconds.
    public init(currentTime: TimeInterval, duration: TimeInterval, timeRemaining: TimeInterval) {
        self.currentTime = currentTime
        self.duration = duration
        self.timeRemaining = timeRemaining
    }
}
