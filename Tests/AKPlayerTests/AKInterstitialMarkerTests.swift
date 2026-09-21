//
//  AKInterstitialMarkerTests.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar. All rights reserved.
//  Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Testing
@testable import AKPlayer

struct AKInterstitialMarkerTests {
    
    @Test func testInterstitialMarkerInitializationAndProperties() {
        let marker = AKInterstitialMarker(
            id: "ad-1",
            time: 30.0,
            duration: 15.0,
            occupancy: .singlePoint,
            restrictions: [.constrainsSeekingForwardInPrimaryContent, .requiresPlaybackAtPreferredRateForAdvancement],
            isPlayed: false,
            isCurrent: false,
            templateItemCount: 2,
            title: "Mid-Roll 1"
        )
        
        #expect(marker.id == "ad-1")
        #expect(marker.time == 30.0)
        #expect(marker.duration == 15.0)
        #expect(marker.occupancy == .singlePoint)
        #expect(marker.isSinglePoint)
        #expect(!marker.isFill)
        #expect(!marker.canSeek)
        #expect(!marker.canFastForward)
        #expect(!marker.isPlayed)
        #expect(!marker.isCurrent)
        #expect(marker.templateItemCount == 2)
        #expect(marker.title == "Mid-Roll 1")
    }
    
    @Test func testInterstitialMarkerFillAndUnrestrictedProperties() {
        let fillMarker = AKInterstitialMarker(
            id: "ad-fill",
            time: 60.0,
            duration: 30.0,
            occupancy: .fill,
            restrictions: [],
            isPlayed: true,
            isCurrent: true
        )
        
        #expect(fillMarker.isFill)
        #expect(!fillMarker.isSinglePoint)
        #expect(fillMarker.canSeek)
        #expect(fillMarker.canFastForward)
        #expect(fillMarker.isPlayed)
        #expect(fillMarker.isCurrent)
    }
    
    @MainActor
    @Test func testInterstitialMarkerSynthesisAndServiceQueries() {
        let player = AVPlayer()
        let service = AKPlayerInterstitialService(with: player)
        
        #expect(service.markers.isEmpty)
        #expect(service.marker(at: 10.0, tolerance: 1.0) == nil)
        #expect(service.nextUnplayedMarker(after: 0.0) == nil)
        
        let url = URL(string: "https://example.com/ad.m3u8")!
        let primaryItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: primaryItem)
        
        let adItem = AVPlayerItem(url: url)
        service.schedule(
            at: CMTime(seconds: 15, preferredTimescale: 600),
            templateItems: [adItem],
            identifier: "ad-midroll-15",
            restrictions: [.constrainsSeekingForwardInPrimaryContent]
        )
        
        service.schedule(
            at: CMTime(seconds: 45, preferredTimescale: 600),
            templateItems: [adItem],
            identifier: "ad-midroll-45",
            restrictions: []
        )
        
        #expect(service.markers.count == 2)
        #expect(service.markers[0].id == "ad-midroll-15")
        #expect(service.markers[0].time == 15.0)
        #expect(!service.markers[0].canSeek)
        
        #expect(service.markers[1].id == "ad-midroll-45")
        #expect(service.markers[1].time == 45.0)
        #expect(service.markers[1].canSeek)
        
        // Query helpers
        let found = service.marker(at: 15.2, tolerance: 0.5)
        #expect(found?.id == "ad-midroll-15")
        
        let next = service.nextUnplayedMarker(after: 20.0)
        #expect(next?.id == "ad-midroll-45")
    }
    
    @Test func testSegmentMappedInterstitialMarker() {
        let event = AVPlayerInterstitialEvent(
            primaryItem: AVPlayerItem(url: URL(string: "https://example.com/stream.m3u8")!),
            identifier: "ad-seg",
            date: Date(),
            templateItems: [AVPlayerItem(url: URL(string: "https://example.com/ad.m3u8")!)],
            restrictions: [.constrainsSeekingForwardInPrimaryContent],
            resumptionOffset: .zero,
            playoutLimit: CMTime(seconds: 10, preferredTimescale: 600)
        )
        
        // Without segment, date-based event defaults to 0.0 until timeline segment maps it
        let unmapped = AKInterstitialMarker(event: event)
        #expect(unmapped.id == "ad-seg")
        #expect(unmapped.time == 0.0)
        #expect(unmapped.duration == 10.0)
    }
}
