//
//   AKMediaEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreGraphics

// MARK: - AKMediaCapability

/// Capabilities that express what playback actions an AVPlayerItem currently supports.
public enum AKMediaCapability: String, CaseIterable, Equatable, Hashable, Sendable {
    /// Capability to play in reverse.
    case playReverse
    /// Capability to fast-forward at accelerated rates.
    case playFastForward
    /// Capability to rewind at accelerated rates.
    case playFastReverse
    /// Capability to play forward at slow-motion rates.
    case playSlowForward
    /// Capability to play in reverse at slow-motion rates.
    case playSlowReverse
    /// Capability to step forward frame by frame.
    case stepForward
    /// Capability to step backward frame by frame.
    case stepBackward
}

// MARK: - AKMediaEvent

/// Events emitted by an active media item (`AKPlayable`) as its state, tracks,
/// or AVPlayerItem observations update.
public enum AKMediaEvent: Sendable {
    // MARK: - State & Duration

    /// The media's internal lifecycle state updated (e.g., loading, readyToPlay, failed).
    case stateDidChange(AKPlayableState)

    /// The media duration updated or became known.
    case durationDidChange(CMTime)

    /// The underlying CMTimebase updated or was invalidated.
    case timebaseDidChange(CMTimebase?)

    // MARK: - Capabilities

    /// A specific playback capability status changed (e.g., fast-forward becoming available or
    /// restricted).
    case capabilityDidChange(AKMediaCapability, isSupported: Bool)

    // MARK: - Range Updates

    /// The buffered time ranges loaded by AVPlayerItem updated.
    case loadedTimeRangesDidChange([CMTimeRange])

    /// The seekable time ranges of the AVPlayerItem updated.
    case seekableTimeRangesDidChange([CMTimeRange])

    // MARK: - Asset Attributes

    /// The native video pixel/presentation resolution updated.
    case presentationSizeDidChange(CGSize)
}

// MARK: - Equatable Conformance

extension AKMediaEvent: Equatable {
    public static func == (lhs: AKMediaEvent, rhs: AKMediaEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.stateDidChange(l), .stateDidChange(r)):
            l == r
        case let (.durationDidChange(l), .durationDidChange(r)):
            l == r
        case let (.timebaseDidChange(l), .timebaseDidChange(r)):
            l == r
        case let (.capabilityDidChange(lCap, lSup), .capabilityDidChange(rCap, rSup)):
            lCap == rCap && lSup == rSup
        case let (.loadedTimeRangesDidChange(l), .loadedTimeRangesDidChange(r)):
            l == r
        case let (.seekableTimeRangesDidChange(l), .seekableTimeRangesDidChange(r)):
            l == r
        case let (.presentationSizeDidChange(l), .presentationSizeDidChange(r)):
            l == r
        default:
            false
        }
    }
}
