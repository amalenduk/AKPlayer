//
//   AKChapterEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKChapterEvent

/// Events emitted when media chapters are extracted.
public enum AKChapterEvent: Sendable, Equatable {
    /// The complete collection of extracted chapters changed.
    case chaptersDidChange([AKChapter])
}
