//
//   AKPlayerSeekingThroughMediaService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayerSeekingThroughMediaServiceProtocol

/// A protocol defining the service interface for managing sequential media
/// seeking operations.
@MainActor
public protocol AKPlayerSeekingThroughMediaServiceProtocol: AnyObject, Sendable {
    /// The underlying `AVPlayer` executing media playback and underlying seek operations.
    var player: AVPlayer { get }
    
    /// An ordered collection of pending seek requests queued for execution.
    var pendingSeeks: [AKSeek] { get }
    
    /// The target position of the most recent seek request, if one is pending or active.
    var lastRequestedSeekTarget: AKSeekTarget? { get }
    
    /// Indicates whether a seek operation is currently active or queued.
    var isSeeking: Bool { get }
    
    /// Queues or executes a seek operation for the given request target.
    func seek(to seek: AKSeek)
    
    /// Cancels all pending and currently active seek operations, notifying callbacks of cancellation.
    func cancelAll()
}

// MARK: - AKPlayerSeekingThroughMediaService

/// A service class managing queued media seek operations for an `AVPlayer`.
@MainActor
public final class AKPlayerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol {
    // MARK: - Properties
    
    public let player: AVPlayer
    public private(set) var pendingSeeks = [AKSeek]()
    
    private var activeSeek: AKSeek?
    private var requestedSeekTarget: AKSeekTarget?
    
    public var lastRequestedSeekTarget: AKSeekTarget? {
        requestedSeekTarget
    }
    
    public var isSeeking: Bool {
        activeSeek != nil || !pendingSeeks.isEmpty
    }
    
    // MARK: - Initialization
    
    public init(with player: AVPlayer) {
        self.player = player
    }
    
    // MARK: - Public API
    
    public func seek(to seek: AKSeek) {
        guard player.currentItem != nil else {
            requestedSeekTarget = nil
            seek.complete(with: false)
            return
        }
        
        requestedSeekTarget = seek.target
        
        if !pendingSeeks.contains(seek) {
            pendingSeeks.append(seek)
        }
        
        if activeSeek == nil {
            performNextSeek()
        }
    }
    
    public func cancelAll() {
        player.currentItem?.cancelPendingSeeks()
        
        let currentActive = activeSeek
        activeSeek = nil
        currentActive?.complete(with: false)
        
        let pending = pendingSeeks
        pendingSeeks.removeAll()
        for seek in pending {
            seek.complete(with: false)
        }
        
        requestedSeekTarget = nil
    }
    
    // MARK: - Private Pipeline
    
    private func performNextSeek() {
        guard let latestSeek = pendingSeeks.last else {
            activeSeek = nil
            requestedSeekTarget = nil
            return
        }
        
        // Cancel intermediate skipped seeks
        let intermediateSeeks = pendingSeeks.dropLast()
        pendingSeeks.removeAll()
        
        for seekToCancel in intermediateSeeks {
            seekToCancel.complete(with: false)
        }
        
        activeSeek = latestSeek
        enqueue(seek: latestSeek)
    }
    
    private func enqueue(seek: AKSeek) {
        guard let currentItem = player.currentItem else {
            activeSeek = nil
            requestedSeekTarget = nil
            seek.complete(with: false)
            return
        }
        
        let completion: @Sendable (Bool) -> Void = { [weak self, weak seek] finished in
            Task { @MainActor in
                guard let seek else { return }
                self?.handleSeekCompletion(for: seek, finished: finished)
            }
        }
        
        // Handle wall-clock date targets (HLS Live streams)
        if case let .date(targetDate) = seek.target {
            player.seek(to: targetDate, completionHandler: completion)
            return
        }
        
        // Handle live broadcast head seek target
        if case .live = seek.target {
            let seekableRanges = currentItem.seekableTimeRanges.map(\.timeRangeValue)
            let liveEdge = seekableRanges.last?.end ?? currentItem.duration
            if liveEdge.isValid && liveEdge.isNumeric {
                player.seek(
                    to: liveEdge,
                    toleranceBefore: seek.toleranceBefore,
                    toleranceAfter: seek.toleranceAfter,
                    completionHandler: completion
                )
                return
            }
        }
        
        let timescale = currentItem.duration.timescale > 0 ? currentItem.duration.timescale : 600
        
        // Resolve target to CMTime using unified AKSeekTarget resolve
        guard let targetCMTime = seek.target.resolve(
            currentTime: player.currentTime(),
            duration: currentItem.duration,
            preferredTimescale: timescale,
            clampToDuration: true
        ) else {
            activeSeek = nil
            requestedSeekTarget = nil
            seek.complete(with: false)
            return
        }
        
        player.seek(
            to: targetCMTime,
            toleranceBefore: seek.toleranceBefore,
            toleranceAfter: seek.toleranceAfter,
            completionHandler: completion
        )
    }
    
    private func handleSeekCompletion(
        for completedSeek: AKSeek,
        finished: Bool
    ) {
        if activeSeek == completedSeek {
            activeSeek = nil
        }
        completedSeek.complete(with: finished)
        
        if !pendingSeeks.isEmpty {
            performNextSeek()
        } else if activeSeek == nil {
            requestedSeekTarget = nil
        }
    }
}
