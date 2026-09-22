//
//   AKChapter.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import UIKit

// MARK: - AKChapter

/// A domain model representing a time-indexed chapter within audiobooks, podcasts, or video media.
public struct AKChapter: Equatable, Identifiable, Sendable {
    // MARK: - Properties

    /// The 1-based chapter number (e.g. 1, 2, 3...).
    public let id: Int

    /// The 0-based chapter index (e.g. 0, 1, 2...).
    public let index: Int

    /// The chapter title (e.g. "Chapter 1: The Beginning").
    public let title: String

    /// The playback time range of this chapter.
    public let timeRange: CMTimeRange

    /// Chapter thumbnail or visual artwork image.
    public let artworkImage: UIImage?

    /// Raw binary data of the chapter artwork image.
    public let artworkData: Data?

    // MARK: - Computed Properties

    /// The start time of the chapter in seconds.
    public var startTime: Double {
        let sec = timeRange.start.seconds
        return sec.isFinite && !sec.isNaN ? max(0, sec) : 0
    }

    /// The total duration of the chapter in seconds.
    public var duration: Double {
        let sec = timeRange.duration.seconds
        return sec.isFinite && !sec.isNaN ? max(0, sec) : 0
    }

    /// The end time of the chapter in seconds.
    public var endTime: Double {
        let sec = timeRange.end.seconds
        return sec.isFinite && !sec.isNaN ? max(0, sec) : startTime + duration
    }

    // MARK: - Initialization

    /// Initializes a new media chapter domain model.
    /// - Parameters:
    ///   - id: The 1-based chapter number.
    ///   - index: The 0-based chapter index.
    ///   - title: The chapter title.
    ///   - timeRange: The playback time range of the chapter.
    ///   - artworkImage: Optional chapter artwork image.
    ///   - artworkData: Optional raw binary artwork data.
    public init(
        id: Int,
        index: Int,
        title: String,
        timeRange: CMTimeRange,
        artworkImage: UIImage? = nil,
        artworkData: Data? = nil
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.timeRange = timeRange
        self.artworkData = artworkData
        self.artworkImage = artworkImage ?? artworkData.flatMap { UIImage(data: $0) }
    }

    // MARK: - Helper Methods

    /// Returns whether the specified `CMTime` falls within this chapter's time range.
    public func contains(time: CMTime) -> Bool {
        guard time.isValid, !time.isIndefinite else { return false }
        return timeRange.containsTime(time)
    }

    /// Returns whether the specified timestamp in seconds falls within this chapter's range.
    public func contains(seconds: Double) -> Bool {
        guard seconds.isFinite, !seconds.isNaN else { return false }
        return seconds >= startTime && seconds < endTime
    }

    /// Calculates normalized playback progress (0.0 to 1.0) within this chapter for a given time.
    public func progress(at time: CMTime) -> Double {
        guard duration > 0, time.isValid, !time.isIndefinite else { return 0 }
        let currentSeconds = time.seconds
        guard currentSeconds.isFinite, !currentSeconds.isNaN else { return 0 }
        let elapsed = max(0, currentSeconds - startTime)
        return min(max(elapsed / duration, 0.0), 1.0)
    }

    /// Returns the remaining playback duration in seconds for this chapter from a given time.
    public func timeRemaining(at time: CMTime) -> Double {
        guard duration > 0, time.isValid, !time.isIndefinite else { return duration }
        let currentSeconds = time.seconds
        guard currentSeconds.isFinite, !currentSeconds.isNaN else { return duration }
        let remaining = endTime - currentSeconds
        return max(0, remaining)
    }

    // MARK: - Equatable

    /// Returns a boolean value indicating whether two chapters are identical.
    public static func == (lhs: AKChapter, rhs: AKChapter) -> Bool {
        lhs.id == rhs.id &&
            lhs.index == rhs.index &&
            lhs.title == rhs.title &&
            lhs.timeRange == rhs.timeRange &&
            lhs.artworkData == rhs.artworkData
    }
}
