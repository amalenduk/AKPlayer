//
//   AKPlayerActionsProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia
import Foundation

// MARK: - AKPlayerActionsProtocol

/// Protocol defining core player user action interface commands, including
/// media loading, playback state controls, seeking, and frame navigation.
@MainActor
public protocol AKPlayerActionsProtocol: Sendable {
    // MARK: - Loading Media

    /// Loads a playable media item into the player pipeline with optional
    /// immediate auto-playback and initial seek target settings.
    /// - Parameters:
    ///   - media: The playable media item conforming to `AKPlayable`.
    ///   - autoPlay: Specifies whether playback automatically begins after
    /// media loading completes.
    ///   - position: An optional starting target seek position to apply once
    /// loaded.
    func load(
        media: any AKPlayable,
        autoPlay: Bool,
        at position: AKSeekTarget?
    )

    // MARK: - Controlling Playback

    /// Commands the player to start or resume media playback using the default
    /// rate.
    func play()

    /// Commands the player to begin media playback at a specified speed
    /// multiplier.
    /// - Parameter rate: The target playback speed rate multiplier.
    func play(at rate: AKPlaybackRate)

    /// Commands the player to pause active media playback.
    func pause()

    /// Toggles active playback state between playing and paused.
    func togglePlayPause()

    /// Stops media playback and tears down active player state.
    func stop()

    // MARK: - Seeking Through Media

    /// Asynchronously seeks to a designated target position within the active
    /// media.
    /// - Parameter target: The destination position target (`.time`,
    /// `.seconds`, `.offset`, `.percentage`, or `.date`).
    /// - Returns: `true` if the seek operation completed successfully without
    /// being superseded; `false` otherwise.
    @discardableResult
    func seek(to target: AKSeekTarget) async -> Bool

    /// Asynchronously seeks to a designated target position with custom
    /// tolerance boundary constraints.
    /// - Parameters:
    ///   - target: The destination position target (`.time`, `.seconds`,
    /// `.offset`, `.percentage`, or `.date`).
    ///   - toleranceBefore: The allowable target offset tolerance boundary
    /// before the target time.
    ///   - toleranceAfter: The allowable target offset tolerance boundary after
    /// the target time.
    /// - Returns: `true` if the seek operation completed successfully without
    /// being superseded; `false` otherwise.
    @discardableResult
    func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool

    /// Seeks to a designated target position using a completion callback.
    /// - Parameters:
    ///   - target: The destination position target (`.time`, `.seconds`,
    /// `.offset`, `.percentage`, or `.date`).
    ///   - completionHandler: A callback invoked when the seek operation
    /// finishes or is canceled, receiving a boolean indicating success.
    func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    )

    /// Seeks to a designated target position with custom tolerance boundary
    /// constraints using a completion callback.
    /// - Parameters:
    ///   - target: The destination position target (`.time`, `.seconds`,
    /// `.offset`, `.percentage`, or `.date`).
    ///   - toleranceBefore: The allowable target offset tolerance boundary
    /// before the target time.
    ///   - toleranceAfter: The allowable target offset tolerance boundary after
    /// the target time.
    ///   - completionHandler: A callback invoked when the seek operation
    /// finishes or is canceled, receiving a boolean indicating success.
    func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    )

    // MARK: - Media Navigation

    /// Steps frame-by-frame through video media by a specified frame count
    /// offset.
    /// - Parameter count: The frame offset count (positive for forward,
    /// negative for reverse).
    func step(by count: Int)

    /// Fast-forwards playback using the default fast-forward speed defined in
    /// player configuration.
    func fastForward()

    /// Fast-forwards playback at a custom speed multiplier rate.
    /// - Parameter rate: The target fast-forward speed rate multiplier.
    func fastForward(at rate: AKPlaybackRate)

    /// Rewinds playback using the default rewind speed defined in player
    /// configuration.
    func rewind()

    /// Rewinds playback at a custom speed multiplier rate.
    /// - Parameter rate: The target rewind speed rate multiplier.
    func rewind(at rate: AKPlaybackRate)
}

// MARK: - Default Parameters Extension

public extension AKPlayerActionsProtocol {
    /// Loads a playable media item without auto-playback and without an initial
    /// seek target.
    /// - Parameter media: The playable media item conforming to `AKPlayable`.
    func load(media: any AKPlayable) {
        load(media: media, autoPlay: false, at: nil)
    }

    /// Loads a playable media item with explicit auto-play setting and without
    /// an initial seek target.
    /// - Parameters:
    ///   - media: The playable media item conforming to `AKPlayable`.
    ///   - autoPlay: Specifies whether playback automatically begins after
    /// media loading completes.
    func load(media: any AKPlayable, autoPlay: Bool) {
        load(media: media, autoPlay: autoPlay, at: nil)
    }
}
