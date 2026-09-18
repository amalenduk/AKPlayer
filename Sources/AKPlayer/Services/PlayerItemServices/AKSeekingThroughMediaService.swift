//
//   AKSeekingThroughMediaService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKSeekingThroughMediaServiceProtocol

/// A protocol defining media boundary validation checks for seek targets.
public protocol AKSeekingThroughMediaServiceProtocol: AnyObject, Sendable {
    /// Evaluates whether a given target is within seekable bounds.
    /// - Parameter target: The target seek position.
    /// - Returns: `true` if seeking to the target is permitted, `false` otherwise.
    func canSeek(to target: AKSeekTarget) -> Bool
    
    /// Evaluates whether a given target is within seekable bounds and provides an explicit failure reason if blocked.
    /// - Parameter target: The target seek position.
    /// - Returns: A tuple containing a boolean flag and an optional unavailability reason.
    func canSeek(to target: AKSeekTarget) -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?)
    
    /// Checks whether a given target falls within any of the provided time ranges.
    /// - Parameters:
    ///   - target: The target seek position.
    ///   - ranges: An array of `CMTimeRange` instances representing valid playback bounds.
    /// - Returns: `true` if the target falls within at least one range.
    func isTargetInRanges(_ target: AKSeekTarget, _ ranges: [CMTimeRange]) -> Bool
    
    /// Retrieves all available seekable and loaded time ranges for the active player item.
    /// - Returns: An array of `CMTimeRange` representing valid playback bounds.
    func getRangesAvailable() -> [CMTimeRange]
}

// MARK: - AKSeekingThroughMediaService

/// A stateless verification service providing boundary validation for seek actions on an `AVPlayerItem`.
public final class AKSeekingThroughMediaService: AKSeekingThroughMediaServiceProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// A weak reference to the owner media manager.
    private weak var mediaManager: (any AKMediaManagerProtocol)?
    
    /// Convenience accessor for the current `AVPlayerItem`.
    private var playerItem: AVPlayerItem? {
        mediaManager?.playerItem
    }
    
    // MARK: - Initialization
    
    /// Initializes a new seeking verification service bound to a media manager.
    /// - Parameter mediaManager: The parent media manager instance providing access to the player item.
    public init(mediaManager: any AKMediaManagerProtocol) {
        self.mediaManager = mediaManager
    }
    
    // MARK: - Public API
    
    /// Evaluates whether a given target is within seekable bounds.
    public func canSeek(to target: AKSeekTarget) -> Bool {
        canSeek(to: target).flag
    }
    
    /// Evaluates whether a given target is within seekable bounds and provides an explicit failure reason if blocked.
    public func canSeek(to target: AKSeekTarget) -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?) {
        guard let playerItem else {
            return (false, .waitTillMediaLoaded)
        }
        
        // Handle wall-clock date targets (HLS Live streams)
        if case let .date(targetDate) = target {
            return validateDateSeek(targetDate, playerItem: playerItem)
        }
        
        let timescale = playerItem.duration.timescale > 0 ? playerItem.duration.timescale : 600
        
        // Resolve target to CMTime using unified AKSeekTarget resolve
        guard let targetCMTime = target.resolve(
            currentTime: playerItem.currentTime(),
            duration: playerItem.duration,
            preferredTimescale: timescale,
            clampToDuration: false
        ) else {
            return (false, .seekPositionNotAvailable)
        }
        
        // Validate CMTime validity and non-negative value
        guard targetCMTime.isValid, targetCMTime.isNumeric, targetCMTime >= .zero else {
            return (false, .seekPositionNotAvailable)
        }
        
        let duration = playerItem.duration
        
        // Handle dynamic/live streams without a fixed numeric duration
        guard duration.isNumeric, duration > .zero else {
            let ranges = getRangesAvailable()
            let isInRanges = isTimeInRanges(targetCMTime, ranges)
            return isInRanges ? (true, nil) : (false, .seekPositionNotAvailable)
        }
        
        // Check if seek position exceeds media duration
        guard targetCMTime <= duration else {
            return (false, .seekOverstepPosition)
        }
        
        return (true, nil)
    }
    
    /// Checks whether a given target falls within any of the provided time ranges.
    public func isTargetInRanges(_ target: AKSeekTarget, _ ranges: [CMTimeRange]) -> Bool {
        guard let playerItem else { return false }
        
        let timescale = playerItem.duration.timescale > 0 ? playerItem.duration.timescale : 600
        guard let time = target.resolve(
            currentTime: playerItem.currentTime(),
            duration: playerItem.duration,
            preferredTimescale: timescale,
            clampToDuration: false
        ) else {
            return false
        }
        
        return isTimeInRanges(time, ranges)
    }
    
    /// Retrieves all available seekable and loaded time ranges for the active player item.
    public func getRangesAvailable() -> [CMTimeRange] {
        guard let playerItem else { return [] }
        
        let seekableRanges = playerItem.seekableTimeRanges.map(\.timeRangeValue)
        if !seekableRanges.isEmpty {
            return seekableRanges
        }
        
        return playerItem.loadedTimeRanges.map(\.timeRangeValue)
    }
    
    // MARK: - Private Helpers
    
    /// Validates whether a target date falls within the seekable date ranges of an AVPlayerItem.
    private func validateDateSeek(_ date: Date, playerItem: AVPlayerItem) -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?) {
        guard let currentDate = playerItem.currentDate(),
              let seekableRange = playerItem.seekableTimeRanges.first?.timeRangeValue
        else {
            return (false, .seekPositionNotAvailable)
        }
        
        let currentTime = playerItem.currentTime()
        let elapsedFromStart = CMTimeSubtract(currentTime, seekableRange.start)
        
        guard elapsedFromStart.isValid && elapsedFromStart.isNumeric else {
            return (false, .seekPositionNotAvailable)
        }
        
        let startSeconds = CMTimeGetSeconds(elapsedFromStart)
        let durationSeconds = CMTimeGetSeconds(seekableRange.duration)
        
        let streamStartDate = currentDate.addingTimeInterval(-startSeconds)
        let streamEndDate = streamStartDate.addingTimeInterval(durationSeconds)
        
        let isWithinBounds = (streamStartDate ... streamEndDate).contains(date)
        return isWithinBounds ? (true, nil) : (false, .seekPositionNotAvailable)
    }
    
    /// Checks whether a specific `CMTime` falls within an array of ranges.
    private func isTimeInRanges(_ time: CMTime, _ ranges: [CMTimeRange]) -> Bool {
        ranges.contains { range in
            range.containsTime(time) || (time >= range.start && time <= range.end)
        }
    }
}
