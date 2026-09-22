//
//   AKChapterTests.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@testable import AKPlayer
import AVFoundation
import Testing

struct AKChapterTests {
    @Test func chapterModelPropertiesAndCalculations() {
        let start = CMTime(seconds: 10, preferredTimescale: 600)
        let duration = CMTime(seconds: 30, preferredTimescale: 600)
        let range = CMTimeRange(start: start, duration: duration)

        let chapter = AKChapter(
            id: 1,
            index: 0,
            title: "Chapter 1: Arrival",
            timeRange: range
        )

        #expect(chapter.id == 1)
        #expect(chapter.index == 0)
        #expect(chapter.title == "Chapter 1: Arrival")
        #expect(chapter.startTime == 10.0)
        #expect(chapter.duration == 30.0)
        #expect(chapter.endTime == 40.0)

        // Time containment
        #expect(chapter.contains(time: CMTime(seconds: 15, preferredTimescale: 600)))
        #expect(chapter.contains(time: CMTime(seconds: 10, preferredTimescale: 600)))
        #expect(!chapter.contains(time: CMTime(seconds: 40, preferredTimescale: 600)))
        #expect(!chapter.contains(time: CMTime(seconds: 5, preferredTimescale: 600)))

        #expect(chapter.contains(seconds: 25.0))
        #expect(!chapter.contains(seconds: 45.0))

        // Progress & Time Remaining
        let midTime = CMTime(seconds: 25, preferredTimescale: 600)
        #expect(chapter.progress(at: midTime) == 0.5)
        #expect(chapter.timeRemaining(at: midTime) == 15.0)
    }

    @Test func chapterServiceQueries() throws {
        let media = try AKMedia(
            url: #require(URL(string: "https://example.com/audiobook.m4b")),
            type: .clip
        )
        let service = media.chapterService

        #expect(service.chapters.isEmpty)
        #expect(service.chapterCount == 0)
        #expect(service.currentChapter == nil)

        // Query non-existent chapters
        #expect(service.chapter(at: 0) == nil)
        #expect(service.chapter(byNumber: 1) == nil)
        #expect(service.currentChapter(at: CMTime(seconds: 5, preferredTimescale: 600)) == nil)
        #expect(service
            .currentChapterNumber(at: CMTime(seconds: 5, preferredTimescale: 600)) == nil)
        #expect(service.chapterTitle(at: CMTime(seconds: 5, preferredTimescale: 600)) == nil)

        service.resetSession()
        #expect(service.chapters.isEmpty)
    }
}
