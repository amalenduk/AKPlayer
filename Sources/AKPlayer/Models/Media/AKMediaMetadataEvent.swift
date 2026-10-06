//
//   AKMediaMetadataEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@preconcurrency import AVFoundation
import Foundation

// MARK: - AKMediaMetadataEvent

/// Events emitted when media container static metadata or stream timed metadata updates.
public enum AKMediaMetadataEvent: @unchecked Sendable {
    /// Static container metadata loaded or updated.
    case staticMetadataDidChange(AKMediaStaticMetadata)

    /// Dynamic timed metadata arrived (e.g. ID3 tags, ICY stream title).
    case timedMetadataDidChange([AVMetadataItem])
}

// MARK: - Equatable Conformance

extension AKMediaMetadataEvent: Equatable {
    public static func == (lhs: AKMediaMetadataEvent, rhs: AKMediaMetadataEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.staticMetadataDidChange(l), .staticMetadataDidChange(r)):
            l.title == r.title && l.artist == r.artist && l.albumTitle == r.albumTitle
        case let (.timedMetadataDidChange(l), .timedMetadataDidChange(r)):
            l.count == r.count
        default:
            false
        }
    }
}
