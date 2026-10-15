//
//   AKSubtitleCue.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia
import Foundation

// MARK: - AKSubtitleCue

/// Represents a single subtitle or closed caption cue with plain text and styled attributed text.
public struct AKSubtitleCue: Sendable, Equatable, Hashable {
    /// The raw plain text representation of the subtitle cue.
    public let text: String

    /// The attributed text representation of the subtitle cue (preserving styling like italics,
    /// color).
    public let attributedText: AttributedString?

    /// The presentation timestamp corresponding to this subtitle cue.
    public let itemTime: CMTime

    /// Whether this cue contains no displayable characters.
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        text: String,
        attributedText: AttributedString? = nil,
        itemTime: CMTime = .zero
    ) {
        self.text = text
        self.attributedText = attributedText
        self.itemTime = itemTime
    }
}
