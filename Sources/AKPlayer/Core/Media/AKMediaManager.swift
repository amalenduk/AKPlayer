//
//   AKMediaManager.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKMediaManager

/// Concrete implementation responsible for managing media item asset creation,
/// status observation, preflight capability checks, and event broadcasting.
public final class AKMediaManager: NSObject, AKMediaManagerProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The weak reference to the backing playable media item.
    public weak var media: (any AKPlayable)?
    
    /// The loaded URL asset generated from the media item (Single Source of Truth).
    public private(set) var asset: AVURLAsset?
    
    /// The instantiated player item constructed from the asset (Single Source of Truth).
    public private(set) var playerItem: AVPlayerItem?
    
    /// The current player error, if media loading or playback failed.
    public private(set) var error: AKPlayerError?
    
    /// The current state of the playable media item.
    public private(set) var state: AKPlayableState = .idle {
        didSet {
            guard oldValue != state else { return }
            emit(.stateDidChange(state))
        }
    }
    
    /// Asynchronous stream of media events for Swift Concurrency (`for await event in manager.events`).
    public var events: AsyncStream<AKMediaEvent> {
        eventBroadcaster.makeStream()
    }
    
    private let eventBroadcaster = AKEventBroadcaster<AKMediaEvent>()
    
    // MARK: - Child Services
    
    /// Service responsible for managing seek feasibility checks and execution.
    public var seekingThroughMediaService: any AKSeekingThroughMediaServiceProtocol { _seekingThroughMediaService }
    
    /// Service responsible for subtitle and audio track selection management.
    public var trackSelectionService: any AKTrackSelectionServiceProtocol { _trackSelectionService }
    
    /// Service responsible for extracting asset and item metadata.
    public var metadataProvider: any AKMediaMetadataProviderProtocol { _metadataProvider }
    
    /// Service responsible for extracting and tracking media chapters.
    public var chapterService: any AKChapterServiceProtocol { _chapterService }
    
    /// Notification observer for player item playback lifecycle events.
    public var playerItemNotificationsObserver: any AKPlayerItemNotificationsObserverProtocol { _playerItemNotificationsObserver }
    
    // MARK: - Private Storage
    
    private var observations: [NSKeyValueObservation] = []
    
    private let playerItemInitService: any AKPlayerItemInitServiceProtocol
    private var _seekingThroughMediaService: (any AKSeekingThroughMediaServiceProtocol)!
    private var _trackSelectionService: (any AKTrackSelectionServiceProtocol)!
    private var _metadataProvider: (any AKMediaMetadataProviderProtocol)!
    private var _chapterService: (any AKChapterServiceProtocol)!
    private var _playerItemNotificationsObserver: (any AKPlayerItemNotificationsObserverProtocol)!
    
    // MARK: - Initialization & Cleanup
    
    /// Initializes a new media manager instance for the specified media item.
    /// - Parameters:
    ///   - media: The target playable media item.
    ///   - playerItemInitService: The asset & item creation service.
    public init(
        media: any AKPlayable,
        playerItemInitService: any AKPlayerItemInitServiceProtocol = AKPlayerItemInitService()
    ) {
        self.media = media
        self.playerItemInitService = playerItemInitService
        super.init()
        
        // Direct initialization of child services
        _seekingThroughMediaService = AKSeekingThroughMediaService(mediaManager: self)
        _trackSelectionService = AKTrackSelectionService(mediaManager: self)
        _metadataProvider = AKMediaMetadataProvider(mediaManager: self)
        _chapterService = AKChapterService(mediaManager: self)
        _playerItemNotificationsObserver = AKPlayerItemNotificationsObserver(mediaManager: self)
    }
    
    deinit {
        observations.removeAll()
        eventBroadcaster.finish()
    }
    
    // MARK: - Asset Lifecycle Operations
    
    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    public func createAsset() async {
        assert(
            state.isIdle || state.isFailed,
            "This function can only be called if the media is idle or has encountered an error."
        )
        guard let media else { return }
        error = nil
        self.asset = await playerItemInitService.createAsset(for: media)
        self.state = .assetLoaded
        
        // Asynchronously load container metadata and chapters in background
        Task { [weak self] in
            guard let self else { return }
            await self.metadataProvider.loadMetadata()
            await self.chapterService.loadChapters()
        }
    }
    
    /// Asynchronously validates key asset properties (e.g., playability and DRM restrictions).
    public func validateAssetPlayability() async throws {
        assert(
            state.isAssetLoaded,
            "This function requires the asset to be loaded first."
        )
        guard let asset else {
            throw AKPlayerError.assetLoadingFailed(reason: .notPlayable)
        }
        try await playerItemInitService.validatePlayability(of: asset)
    }
    
    /// Constructs an `AVPlayerItem` from the initialized `AVURLAsset` and binds observers.
    public func createPlayerItemFromAsset() {
        assert(
            state.isAssetLoaded,
            "This function requires the asset to be loaded first."
        )
        guard let asset, let media else { return }
        error = nil
        
        // Stop any existing KVO observations
        observations.removeAll()
        
        let newItem = playerItemInitService.createPlayerItem(from: asset, for: media)
        self.playerItem = newItem
        
        // Reset track selection session targeting the new player item
        Task {
            await trackSelectionService.resetSession()
        }
        
        // Attach live stream timed metadata output
        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        let queue = DispatchQueue(label: "com.akplayer.timedMetadataOutputQueue")
        metadataOutput.setDelegate(self, queue: queue)
        Task { @MainActor in
            newItem.add(metadataOutput)
        }
        
        bindObservers(to: newItem)
        self.state = .playerItemLoaded
    }
    
    /// Aborts active asset property loading and cancels pending operations.
    public func abortAssetInitialization() {
        observations.removeAll()
        asset?.cancelLoading()
        asset = nil
        playerItem = nil
        metadataProvider.resetSession()
        chapterService.resetSession()
    }
    
    // MARK: - Preflight Capability Checks
    
    /// Evaluates if the player item can step forward or backward by a given frame count.
    public func canStep(by count: Int) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay,
              let playerItem
        else { return false }
        
        let isForward = count.signum() == 1
        return isForward ? playerItem.canStepForward : playerItem.canStepBackward
    }
    
    /// Evaluates whether the player item supports playback at a specified rate.
    public func canPlay(at rate: AKPlaybackRate) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay,
              let playerItem
        else { return false }
        
        switch rate.rate {
        case 0.0...:
            switch rate.rate {
            case 2.0...:
                return playerItem.canPlayFastForward
            case 1.0 ..< 2.0:
                return true
            case 0.0 ..< 1.0:
                return playerItem.canPlaySlowForward
            default:
                return false
            }
        case ..<0.0:
            switch rate.rate {
            case -1.0:
                return playerItem.canPlayReverse
            case -1.0 ..< 0.0:
                return playerItem.canPlaySlowReverse
            case ..<(-1.0):
                return playerItem.canPlayFastReverse
            default:
                return false
            }
        default:
            return false
        }
    }
    
    /// Evaluates whether seeking to a target seek target position is permitted.
    public func canSeek(to target: AKSeekTarget) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else { return false }
        return seekingThroughMediaService.canSeek(to: target)
    }
    
    /// Evaluates whether seeking to a target seek target is permitted and returns an unavailability reason if disallowed.
    public func canSeek(to target: AKSeekTarget) -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?) {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else {
            if state.isIdle || state.isFailed {
                return (false, .loadMediaFirst)
            } else {
                return (false, .waitTillMediaLoaded)
            }
        }
        return seekingThroughMediaService.canSeek(to: target)
    }
    
    public func isSupported(_ capability: AKMediaCapability) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay,
              let playerItem
        else { return false }
        
        switch capability {
        case .playReverse: return playerItem.canPlayReverse
        case .playFastForward: return playerItem.canPlayFastForward
        case .playFastReverse: return playerItem.canPlayFastReverse
        case .playSlowForward: return playerItem.canPlaySlowForward
        case .playSlowReverse: return playerItem.canPlaySlowReverse
        case .stepForward: return playerItem.canStepForward
        case .stepBackward: return playerItem.canStepBackward
        }
    }
    
    // MARK: - Player Item Property Observation (Foundation KVO)
    
    private func bindObservers(to item: AVPlayerItem) {
        // 1. Readiness & Status Observer
        observations.append(
            item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    self.state = .readyToPlay
                case .failed:
                    let underlyingError = observedItem.error ?? NSError(domain: "AKPlayer", code: -1, userInfo: nil)
                    self.error = .playerItemLoadingFailed(reason: .statusLoadingFailed(error: underlyingError))
                    self.state = .failed
                default:
                    break
                }
            }
        )
        
        // 2. Duration
        observations.append(
            item.observe(\.duration, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                let duration = observedItem.duration
                self.emit(.durationDidChange(duration))
            }
        )
        
        // 3. Presentation Resolution Size
        observations.append(
            item.observe(\.presentationSize, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                let size = observedItem.presentationSize
                self.emit(.presentationSizeDidChange(size))
            }
        )
        
        // 4. Tracks
        observations.append(
            item.observe(\.tracks, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                let tracks = observedItem.tracks
                self.emit(.tracksDidChange(tracks))
            }
        )
        
        // 5. Timebase
        observations.append(
            item.observe(\.timebase, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                let timebase = observedItem.timebase
                self.emit(.timebaseDidChange(timebase))
            }
        )
        
        // 6. Loaded Time Ranges
        observations.append(
            item.observe(\.loadedTimeRanges, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                let ranges = observedItem.loadedTimeRanges.map(\.timeRangeValue)
                self.emit(.loadedTimeRangesDidChange(ranges))
            }
        )
        
        // 7. Seekable Time Ranges
        observations.append(
            item.observe(\.seekableTimeRanges, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                let ranges = observedItem.seekableTimeRanges.map(\.timeRangeValue)
                self.emit(.seekableTimeRangesDidChange(ranges))
            }
        )
        
        // 8. Playback Capabilities
        bindCapability(\.canStepForward, capability: .stepForward, on: item)
        bindCapability(\.canStepBackward, capability: .stepBackward, on: item)
        bindCapability(\.canPlayReverse, capability: .playReverse, on: item)
        bindCapability(\.canPlayFastForward, capability: .playFastForward, on: item)
        bindCapability(\.canPlayFastReverse, capability: .playFastReverse, on: item)
        bindCapability(\.canPlaySlowForward, capability: .playSlowForward, on: item)
        bindCapability(\.canPlaySlowReverse, capability: .playSlowReverse, on: item)
    }
    
    private func bindCapability(
        _ keyPath: KeyPath<AVPlayerItem, Bool>,
        capability: AKMediaCapability,
        on item: AVPlayerItem
    ) {
        observations.append(
            item.observe(keyPath, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                let isSupported = observedItem[keyPath: keyPath]
                self.emit(.capabilityDidChange(capability, isSupported: isSupported))
            }
        )
    }
    
    // MARK: - Event Dispatch
    
    /// Emits a media event to active listeners.
    public func emit(_ event: AKMediaEvent) {
        eventBroadcaster.send(event)
    }
}

// MARK: - AVPlayerItemMetadataOutputPushDelegate

extension AKMediaManager: AVPlayerItemMetadataOutputPushDelegate {
    public func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        let items = groups.flatMap(\.items)
        guard !items.isEmpty else { return }
        metadataProvider.handleTimedMetadata(items)
    }
}
