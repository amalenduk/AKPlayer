//
//   AKChapterServiceProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKChapterServiceProtocol

/// Protocol defining chapter extraction, queries, active chapter tracking, and navigation.
public protocol AKChapterServiceProtocol: AnyObject, Sendable {
    // MARK: - Properties

    /// All parsed chapters for the current media asset.
    var chapters: [AKChapter] { get }

    /// Total count of chapters available.
    var chapterCount: Int { get }

    /// The start time in seconds of the credits chapter if present (e.g. titled "Credits" or
    /// "Outro").
    var creditsStartTime: Double? { get }

    // MARK: - Async Stream

    /// Asynchronous stream emitting chapter collection and active chapter updates.
    var events: AsyncStream<AKChapterEvent> { get }

    // MARK: - Chapter Queries

    /// Finds the chapter containing the specified playback time.
    /// - Parameter time: The target playback timestamp.
    /// - Returns: The matching `AKChapter`, or `nil` if out of bounds.
    func currentChapter(at time: CMTime) -> AKChapter?

    /// Returns the 1-based chapter number for the specified playback time.
    /// - Parameter time: The target playback timestamp.
    /// - Returns: 1-based chapter number, or `nil` if not found.
    func currentChapterNumber(at time: CMTime) -> Int?

    /// Returns the chapter title for the specified playback time.
    /// - Parameter time: The target playback timestamp.
    /// - Returns: The chapter title string, or `nil` if not found.
    func chapterTitle(at time: CMTime) -> String?

    /// Returns the chapter at the given 0-based index.
    /// - Parameter index: 0-based index.
    /// - Returns: The `AKChapter` at index, or `nil` if out of range.
    func chapter(at index: Int) -> AKChapter?

    /// Returns the chapter with the given 1-based chapter number.
    /// - Parameter number: 1-based chapter number.
    /// - Returns: The `AKChapter` with matching number, or `nil` if not found.
    func chapter(byNumber number: Int) -> AKChapter?

    /// Returns the next chapter relative to the given time.
    /// - Parameter time: Current playback timestamp.
    /// - Returns: The subsequent `AKChapter`, or `nil` if already on the final chapter.
    func nextChapter(from time: CMTime) -> AKChapter?

    /// Returns the previous chapter relative to the given time.
    /// - Parameter time: Current playback timestamp.
    /// - Returns: The previous `AKChapter`, or `nil` if already on the first chapter.
    func previousChapter(from time: CMTime) -> AKChapter?

    // MARK: - Lifecycle

    /// Loads chapter metadata asynchronously from the underlying media asset.
    func loadChapters() async

    /// Resets all chapter state and cancels pending loading tasks.
    func resetSession()
}
