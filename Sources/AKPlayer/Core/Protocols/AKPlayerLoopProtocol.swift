//
//   AKPlayerLoopProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia
import Foundation

// MARK: - AKPlayerLoopProtocol

/// Protocol defining properties and control actions for segment and A-B playback looping.
@MainActor
public protocol AKPlayerLoopProtocol: AnyObject, Sendable {
    // MARK: - Loop Properties

    /// Active loop range if segment/A-B looping is enabled, or `nil` if looping is disabled.
    var loopRange: AKLoopRange? { get }

    /// Indicates whether segment/A-B looping is currently active.
    var isLoopActive: Bool { get }

    // MARK: - Loop Commands

    /// Enables continuous playback looping between specified start and end time boundaries within
    /// a targeted timeline coordinate space.
    /// - Parameters:
    ///   - startTime: The loop start boundary as `CMTime`.
    ///   - endTime: The loop end boundary as `CMTime`.
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    /// - Returns: `true` if the loop was valid and successfully activated; `false` otherwise.
    @discardableResult
    func setLoopRange(startTime: CMTime, endTime: CMTime, scope: AKSeekScope) -> Bool

    /// Enables continuous playback looping between specified start and end seconds within
    /// a targeted timeline coordinate space.
    /// - Parameters:
    ///   - startSeconds: The loop start boundary in seconds.
    ///   - endSeconds: The loop end boundary in seconds.
    ///   - scope: The timeline coordinate space targeted (`.primary` or `.integrated`).
    /// - Returns: `true` if the loop was valid and successfully activated; `false` otherwise.
    @discardableResult
    func setLoopRange(startSeconds: TimeInterval, endSeconds: TimeInterval, scope: AKSeekScope)
        -> Bool

    /// Disables active segment looping.
    func clearLoop()
}

// MARK: - Default Implementations

public extension AKPlayerLoopProtocol {
    /// Indicates whether segment/A-B looping is currently active.
    var isLoopActive: Bool {
        loopRange != nil
    }

    /// Enables continuous playback looping between specified start and end time boundaries within
    /// the primary playback timeline.
    /// - Parameters:
    ///   - startTime: The loop start boundary as `CMTime`.
    ///   - endTime: The loop end boundary as `CMTime`.
    /// - Returns: `true` if the loop was valid and successfully activated; `false` otherwise.
    @discardableResult
    func setLoopRange(startTime: CMTime, endTime: CMTime) -> Bool {
        setLoopRange(startTime: startTime, endTime: endTime, scope: .primary)
    }

    /// Enables continuous playback looping between specified start and end seconds within
    /// the primary playback timeline.
    /// - Parameters:
    ///   - startSeconds: The loop start boundary in seconds.
    ///   - endSeconds: The loop end boundary in seconds.
    /// - Returns: `true` if the loop was valid and successfully activated; `false` otherwise.
    @discardableResult
    func setLoopRange(startSeconds: TimeInterval, endSeconds: TimeInterval) -> Bool {
        setLoopRange(startSeconds: startSeconds, endSeconds: endSeconds, scope: .primary)
    }

    /// Enables continuous playback looping between specified start and end seconds within
    /// a targeted timeline coordinate space.
    @discardableResult
    func setLoopRange(
        startSeconds: TimeInterval,
        endSeconds: TimeInterval,
        scope: AKSeekScope
    ) -> Bool {
        setLoopRange(
            startTime: CMTime(seconds: startSeconds, preferredTimescale: 600),
            endTime: CMTime(seconds: endSeconds, preferredTimescale: 600),
            scope: scope
        )
    }
}
