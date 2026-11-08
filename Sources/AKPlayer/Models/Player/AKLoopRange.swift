//
//   AKLoopRange.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia
import Foundation

// MARK: - AKLoopRange

/// Represents a validated playback loop range (A-B loop) defined by start and end timestamps.
public struct AKLoopRange: Sendable, Equatable, Hashable, CustomStringConvertible {
    // MARK: - Properties

    /// The starting boundary timestamp of the loop segment.
    public let start: CMTime

    /// The ending boundary timestamp of the loop segment.
    public let end: CMTime

    /// The loop starting boundary in fractional seconds.
    public var startSeconds: TimeInterval {
        start.seconds
    }

    /// The loop ending boundary in fractional seconds.
    public var endSeconds: TimeInterval {
        end.seconds
    }

    /// The duration span of the loop segment in fractional seconds.
    public var durationSeconds: TimeInterval {
        max(0, (end - start).seconds)
    }

    /// The duration span of the loop segment as `CMTime`.
    public var duration: CMTime {
        end - start
    }

    // MARK: - Initialization

    /// Initializes a loop range with explicit `CMTime` boundary points.
    /// - Parameters:
    ///   - start: Starting timestamp.
    ///   - end: Ending timestamp.
    public init(start: CMTime, end: CMTime) {
        self.start = start
        self.end = end
    }

    /// Initializes a loop range with starting and ending timestamps in seconds.
    /// - Parameters:
    ///   - startSeconds: Starting boundary in seconds.
    ///   - endSeconds: Ending boundary in seconds.
    ///   - timescale: The preferred CMTime timescale (default: 600).
    public init(
        startSeconds: TimeInterval,
        endSeconds: TimeInterval,
        timescale: CMTimeScale = 600
    ) {
        self.start = CMTime(seconds: max(0, startSeconds), preferredTimescale: timescale)
        self.end = CMTime(seconds: max(0, endSeconds), preferredTimescale: timescale)
    }

    // MARK: - Range Inspection

    /// Determines if a specific `CMTime` falls within this loop boundary.
    /// - Parameter time: The timestamp to test.
    /// - Returns: `true` if `time` is within `[start, end]`.
    public func contains(time: CMTime) -> Bool {
        time >= start && time <= end
    }

    /// Determines if a time in seconds falls within this loop boundary.
    /// - Parameter seconds: The timestamp in seconds to test.
    /// - Returns: `true` if `seconds` is within `[startSeconds, endSeconds]`.
    public func contains(seconds: TimeInterval) -> Bool {
        seconds >= startSeconds && seconds <= endSeconds
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        String(
            format: "AKLoopRange(start: %.2fs, end: %.2fs, duration: %.2fs)",
            startSeconds,
            endSeconds,
            durationSeconds
        )
    }
}
