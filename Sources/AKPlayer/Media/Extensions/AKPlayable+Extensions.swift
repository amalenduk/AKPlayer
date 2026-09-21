//
//   AKPlayable+Extensions.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import MediaPlayer

private nonisolated(unsafe) var managerKey: UInt8 = 0

// MARK: - Manager & Observation Extensions

extension AKPlayable {
    /// The backing media manager instance associated with this playable item (internal to AKPlayer SDK).
    var manager: any AKMediaManagerProtocol {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if let existingManager: any AKMediaManagerProtocol = getAssociatedObject(self, &managerKey) {
            return existingManager
        }
        let newManager = AKMediaManager(media: self)
        setRetainedAssociatedObject(self, &managerKey, newManager)
        return newManager
    }
    
    /// Observes key-path updates on the underlying `AVPlayerItem` using native Foundation KVO.
    /// - Parameters:
    ///   - keyPath: Key path on `AVPlayerItem` to observe.
    ///   - options: Key-value observing options governing initial and change notifications.
    ///   - action: Closure executed when the observed value updates.
    /// - Returns: An `NSKeyValueObservation` instance managing the observation lifetime, or `nil` if `playerItem` is unavailable.
    @discardableResult
    public func observe<Value>(
        _ keyPath: KeyPath<AVPlayerItem, Value>,
        options: NSKeyValueObservingOptions = [.initial, .new],
        action: @escaping @Sendable (any AKMediaManagerProtocol, Value) -> Void
    ) -> NSKeyValueObservation? {
        guard let item = manager.playerItem else { return nil }
        
        return item.observe(keyPath, options: options) { [weak manager] observedItem, _ in
            guard let manager else { return }
            action(manager, observedItem[keyPath: keyPath])
        }
    }
}

// MARK: - Direct Delegation via Manager (Properties)

public extension AKPlayable {
    /// The loaded URL asset generated from the media item.
    var asset: AVURLAsset? {
        manager.asset ?? customAsset
    }
    
    /// The instantiated player item constructed from the asset.
    var playerItem: AVPlayerItem? {
        manager.playerItem ?? customPlayerItem
    }
    
    /// The current state of the playable media item.
    var state: AKPlayableState {
        manager.state
    }
    
    /// The current player error, if media loading or playback failed.
    var error: AKPlayerError? {
        manager.error
    }
    
    var events: AsyncStream<AKMediaEvent> {
        get { manager.events }
    }
}

// MARK: - Direct Delegation via Manager (Operations)

public extension AKPlayable {
    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    func createAsset() async {
        await manager.createAsset()
    }
    
    /// Asynchronously validates key asset properties.
    /// - Throws: An error if asset playability validation fails.
    func validateAssetPlayability() async throws {
        try await manager.validateAssetPlayability()
    }
    
    /// Constructs an `AVPlayerItem` from the initialized `AVURLAsset`.
    func createPlayerItemFromAsset() {
        manager.createPlayerItemFromAsset()
    }
    
    /// Aborts active asset property loading and cancels pending asynchronous
    /// tasks.
    func abortAssetInitialization() {
        manager.abortAssetInitialization()
    }
}

// MARK: - Direct Delegation via Manager (Preflight Command Checks)

public extension AKPlayable {
    /// Evaluates if the player item can step forward or backward by a given
    /// frame count.
    /// - Parameter count: Number of frames to step (positive for forward,
    /// negative for backward).
    /// - Returns: A Boolean value indicating whether the step action is
    /// supported.
    func canStep(by count: Int) -> Bool {
        manager.canStep(by: count)
    }
    
    /// Evaluates whether the player item supports playback at a specified rate.
    /// - Parameter rate: The target playback rate value.
    /// - Returns: A Boolean value indicating whether playback at the specified
    /// rate is supported.
    func canPlay(at rate: AKPlaybackRate) -> Bool {
        manager.canPlay(at: rate)
    }
    
    /// Evaluates whether seeking to a target position is permitted.
    /// - Parameter target: The target seek position.
    /// - Returns: A Boolean value indicating whether the seek target can be
    /// reached.
    func canSeek(to target: AKSeekTarget) -> Bool {
        manager.canSeek(to: target)
    }
}

// MARK: - Direct Delegation via Manager (Services & Observers)

public extension AKPlayable {
    /// Subtitle and audio track selection management service.
    var trackSelection: any AKTrackSelectionServiceProtocol {
        manager.trackSelectionService
    }
    
    /// Seek feasibility checks and execution service.
    var seekingThroughMedia: any AKSeekingThroughMediaServiceProtocol {
        manager.seekingThroughMediaService
    }
    
    /// Notification observer for player item playback lifecycle events.
    ///
    /// Available once `createPlayerItemFromAsset()` initializes the
    /// `playerItem`.
    var playerItemNotifications: any AKPlayerItemNotificationsObserverProtocol {
        manager.playerItemNotificationsObserver
    }
    
    var metadataProvider: any AKMediaMetadataProviderProtocol {
        manager.metadataProvider
    }
    
    var chapterService: any AKChapterServiceProtocol {
        manager.chapterService
    }
}

// MARK: - Live Stream & DVR Extensions

public extension AKPlayable {
    /// The active seekable sliding DVR buffer window of this media item.
    var dvrWindow: CMTimeRange? {
        manager.playerItem?.seekableTimeRanges.last?.timeRangeValue
    }
    
    /// Wall-clock date from #EXT-X-PROGRAM-DATE-TIME for this media item, if available.
    var currentLiveDate: Date? {
        manager.playerItem?.currentDate()
    }
    
    /// Current playback drift latency in seconds behind the live head for this item.
    var liveDrift: TimeInterval? {
        guard let dvrWindow, let item = manager.playerItem else { return nil }
        return max(0.0, dvrWindow.end.seconds - item.currentTime().seconds)
    }
    
    /// Indicates whether playback of this media item is currently synced with the live edge (drift <= threshold).
    var isAtLiveEdge: Bool {
        guard isLive() else { return false }
        guard let liveDrift else { return true }
        guard let threshold = liveEdgeThreshold else { return true }
        return liveDrift <= threshold
    }
}

// MARK: - Comparable Helpers

extension Comparable {
    /// Clamps the value within a specified closed boundary range.
    /// - Parameter range: The closed boundary range to clamp the value within.
    /// - Returns: The value clamped to the specified range limits.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
