//
//   AKSubtitleOutputServiceProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKSubtitleOutputServiceProtocol

/// Protocol defining real-time subtitle and closed-caption interception, state queries, and output
/// control.
public protocol AKSubtitleOutputServiceProtocol: AnyObject, Sendable {
    // MARK: - Properties

    /// Whether the subtitle output service is actively intercepting and emitting subtitle cues.
    var isRunning: Bool { get }

    /// The latest active subtitle or caption cue (or nil if between cues).
    var currentCue: AKSubtitleCue? { get }

    /// Whether player rendering of subtitles on the underlying video canvas is suppressed.
    /// When `true`, default AVPlayer subtitle overlays are suppressed so custom UI views can render
    /// them.
    var suppressesPlayerRendering: Bool { get set }

    // MARK: - Async Stream

    /// Asynchronous stream emitting live subtitle cues and running state changes.
    var events: AsyncStream<AKSubtitleEvent> { get }

    // MARK: - Control Methods

    /// Starts intercepting subtitle cues from the active media player item.
    func start()

    /// Stops intercepting subtitle cues and clears any active cue.
    func stop()
}

// MARK: - Internal Lifecycle Protocol

protocol AKSubtitleOutputLifecycleManaging: AnyObject, Sendable {
    func attach(to playerItem: AVPlayerItem)
    func detach(from playerItem: AVPlayerItem?)
    func resetSession()
}
