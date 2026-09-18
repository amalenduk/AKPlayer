//
//   AKSeekTarget.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia
import Foundation

// MARK: - AKSeekTarget

/// A single seek destination, replacing overloaded `seek(to:)` methods with a
/// unified, type-safe target.
///
/// Percentage values use `0...100` (percent of duration), matching standard
/// AVFoundation/player semantics.
public enum AKSeekTarget: Equatable, Sendable {
    // MARK: - Cases

    /// Absolute media time.
    case time(CMTime)

    /// Absolute position in seconds.
    case seconds(Double)

    /// Offset from the current playhead in seconds. Negative values seek
    /// backward.
    case offset(Double)

    /// Position as a percentage of duration in `0...100`.
    case percentage(Double)

    /// Absolute wall-clock date (used primarily for live HLS streams).
    case date(Date)

    // MARK: - Methods

    /// Resolves this target to a valid absolute `CMTime`.
    ///
    /// - Parameters:
    ///   - currentTime: The player's current playhead position.
    ///   - duration: The duration of the current media asset.
    ///   - preferredTimescale: The timescale to use when constructing new
    /// `CMTime` instances (e.g., `600` or `1000`).
    ///   - clampToDuration: If `true`, clamps the resulting time between
    /// `.zero` and `duration` (if `duration` is numeric). Defaults to `true`.
    /// - Returns: A valid `CMTime` target, or `nil` if inputs are
    /// invalid/non-finite, if a percentage is requested when duration is
    /// unknown, or if the target is `.date`.
    public func resolve(
        currentTime: CMTime,
        duration: CMTime,
        preferredTimescale: CMTimeScale,
        clampToDuration: Bool = true
    ) -> CMTime? {
        let resolvedTime: CMTime?

        switch self {
        case let .time(time):
            // Return time only if valid; reject .invalid or .indefinite times.
            resolvedTime = time.isValid ? time : nil

        case let .seconds(seconds):
            // Guard against NaN or Infinity from calculations/UI controls.
            guard seconds.isFinite else { return nil }
            resolvedTime = CMTime(
                seconds: seconds,
                preferredTimescale: preferredTimescale
            )

        case let .offset(offset):
            // Guard against NaN or Infinity offset inputs.
            guard offset.isFinite, currentTime.isValid else { return nil }
            let offsetTime = CMTime(
                seconds: offset,
                preferredTimescale: preferredTimescale
            )
            resolvedTime = CMTimeAdd(currentTime, offsetTime)

        case let .percentage(percentage):
            // Percentage requires a finite input and a valid, numeric, non-zero
            // duration.
            guard percentage.isFinite, duration.isNumeric,
                  duration > .zero
            else { return nil }

            // Clamp percentage input to valid bounds (0%...100%).
            let clampedPercentage = min(max(percentage, 0.0), 100.0)
            let totalSeconds = CMTimeGetSeconds(duration)
            let targetSeconds = totalSeconds * (clampedPercentage / 100.0)

            resolvedTime = CMTime(
                seconds: targetSeconds,
                preferredTimescale: preferredTimescale
            )

        case .date:
            // Date-based targets cannot be resolved to a relative CMTime and
            // must be dispatched to AVPlayer.seek(to: Date) directly.
            return nil
        }

        // Optionally clamp the output time between CMTime.zero and asset
        // duration.
        guard let targetTime = resolvedTime else { return nil }

        if clampToDuration, duration.isNumeric, duration > .zero {
            return min(max(targetTime, .zero), duration)
        }

        return targetTime
    }
}
