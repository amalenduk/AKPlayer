//
//   AKMediaType.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKMediaType

/// Defines the underlying structural type of a media asset.
public enum AKMediaType: Sendable, Equatable {
    /// Standard finite media clip (e.g., MP4, MP3, VOD asset).
    case clip

    /// Streaming media asset with an indicator for whether it is a live
    /// broadcast or a replay stream.
    case stream(isLive: Bool)
}

// MARK: - CustomStringConvertible

extension AKMediaType: CustomStringConvertible {
    /// A human-readable description of the media type.
    public var description: String {
        switch self {
        case .clip:
            "Clip"
        case let .stream(isLive):
            isLive ? "Live Stream" : "Replay Stream"
        }
    }
}
