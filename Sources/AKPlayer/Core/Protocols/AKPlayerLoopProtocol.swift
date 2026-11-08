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

    /// Enables continuous playback looping between specified start and end time boundaries.
    /// - Parameters:
    ///   - startTime: The loop start boundary as `CMTime`.
    ///   - endTime: The loop end boundary as `CMTime`.
    /// - Returns: `true` if the loop was valid and successfully activated; `false` otherwise.
    @discardableResult
    func setLoopRange(startTime: CMTime, endTime: CMTime) -> Bool

    /// Enables continuous playback looping between specified start and end seconds.
    /// - Parameters:
    ///   - startSeconds: The loop start boundary in seconds.
    ///   - endSeconds: The loop end boundary in seconds.
    /// - Returns: `true` if the loop was valid and successfully activated; `false` otherwise.
    @discardableResult
    func setLoopRange(startSeconds: TimeInterval, endSeconds: TimeInterval) -> Bool

    /// Disables active segment looping.
    func clearLoop()
}

// MARK: - Default Implementations

public extension AKPlayerLoopProtocol {
    /// Indicates whether segment/A-B looping is currently active.
    var isLoopActive: Bool {
        loopRange != nil
    }

    /// Enables continuous playback looping between specified start and end seconds.
    @discardableResult
    func setLoopRange(startSeconds: TimeInterval, endSeconds: TimeInterval) -> Bool {
        setLoopRange(
            startTime: CMTime(seconds: startSeconds, preferredTimescale: 600),
            endTime: CMTime(seconds: endSeconds, preferredTimescale: 600)
        )
    }
}
