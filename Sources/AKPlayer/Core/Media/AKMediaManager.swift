//
//   AKMediaManager.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine
import Foundation

// MARK: - AKMediaManager

/// Concrete implementation responsible for managing media item asset creation,
/// status observation, and preflight capability checks.
@MainActor
public class AKMediaManager: NSObject, AKMediaManagerProtocol {
    // MARK: - Properties
    
    /// The weak reference to the backing playable media item.
    public private(set) weak var media: (any AKPlayable)?
    
    /// The loaded URL asset generated from the media item.
    public var asset: AVURLAsset? {
        playerItemInitService.asset
    }
    
    /// The instantiated player item constructed from the asset.
    public var playerItem: AVPlayerItem? {
        playerItemInitService.playerItem
    }
    
    /// The current player error, if media loading or playback failed.
    public var error: AKPlayerError?
    
    /// The current state of the playable media item.
    public private(set) var state: AKPlayableState {
        get { stateSubject.value }
        set {
            stateSubject.send(newValue)
            emit(.stateDidChange(state))
        }
    }
    
    /// Publisher emitting state updates starting with the current state upon
    /// subscription.
    public var statePublisher: AnyPublisher<AKPlayableState, Never> {
        stateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Asynchronous stream of media events for Swift Concurrency.
    public var events: AsyncStream<AKMediaEvent> {
        eventBroadcaster.makeStream()
    }
    
    public weak var delegate: AKMediaDelegate?
    
    private let eventBroadcaster = AKEventBroadcaster<AKMediaEvent>()
    
    private let stateSubject = CurrentValueSubject<
        AKPlayableState,
        Never
    >(.idle)
    
    /// Service responsible for managing seek feasibility checks and execution.
    public var seekingThroughMediaService: any AKSeekingThroughMediaServiceProtocol { _seekingThroughMediaService}
    
    /// Service responsible for subtitle and audio track selection management.
    public var trackSelectionService: any AKTrackSelectionServiceProtocol { _trackSelectionService }
    
    public var metadataProvider: any AKMediaMetadataProviderProtocol { _metadataProvider }
    
    /// Notification observer for player item playback lifecycle events.
    ///
    /// Available once `createPlayerItemFromAsset()` initializes the
    /// `playerItem`.
    public var playerItemNotificationsObserver: any AKPlayerItemNotificationsObserverProtocol { _playerItemNotificationsObserver }
    
    private var subscriptions = Set<AnyCancellable>()
    
    private var playerItemInitService: any AKPlayerItemInitServiceProtocol
    
    /// Private backing storage initialized post-super.init
    private var _seekingThroughMediaService: (any AKSeekingThroughMediaServiceProtocol)!
    private var _trackSelectionService: (any AKTrackSelectionServiceProtocol)!
    private var _metadataProvider: (any AKMediaMetadataProviderProtocol)!
    private var _playerItemNotificationsObserver: (any AKPlayerItemNotificationsObserverProtocol)!
    
    
    // MARK: - Init & Deinit
    
    /// Initializes a new media manager instance for the specified media item.
    /// - Parameter media: The target playable media item.
    public init(media: any AKPlayable) {
        self.media = media
        playerItemInitService = AKPlayerItemInitService(with: media)
        
        super.init()
        
        // Direct initialization of child services
        _seekingThroughMediaService = AKSeekingThroughMediaService(mediaManager: self)
        _trackSelectionService = AKTrackSelectionService(mediaManager: self)
        _metadataProvider = AKMediaMetadataProvider(mediaManager: self)
        _playerItemNotificationsObserver = AKPlayerItemNotificationsObserver(mediaManager: self)
    }
    
    deinit {}
    
    // MARK: - Asset Lifecycle Operations
    
    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    public func createAsset() {
        assert(
            state.isIdle || state.isFailed,
            "This function can only be called if the media is idle or has encountered an error."
        )
        error = nil
        playerItemInitService.createAsset()
        state = .assetLoaded
    }
    
    /// Asynchronously validates key asset properties (e.g., playability and DRM
    /// restrictions).
    public func validateAssetPlayability() async throws {
        assert(
            state.isAssetLoaded,
            "This function requires the asset to be loaded first."
        )
        try await playerItemInitService.validateAssetPlayability()
    }
    
    /// Constructs an `AVPlayerItem` from the initialized `AVURLAsset` and
    /// instantiates the notification observer.
    public func createPlayerItemFromAsset() {
        assert(
            state.isAssetLoaded,
            "This function requires the asset to be loaded first."
        )
        error = nil
        
        // Stop any existing notifications observer instance
        subscriptions.removeAll()
        
        let newItem = playerItemInitService.createPlayerItemFromAsset()
        
        // Instantiate notification observer targeting the newly created player
        // item
        Task {
            await trackSelectionService.resetSession()
        }
        
        bindObservers(to: newItem)
        
        state = .playerItemLoaded
    }
    
    /// Aborts active asset property loading and cancels pending asynchronous
    /// tasks.
    public func abortAssetInitialization() {
        subscriptions.removeAll()
        playerItemInitService.abortAssetInitialization()
    }
    
    // MARK: - Preflight Capability Checks
    
    /// Evaluates if the player item can step forward or backward by a given
    /// frame count.
    /// - Parameter count: The frame offset count.
    /// - Returns: `true` if stepping by the specified count is supported.
    public func canStep(by count: Int) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay,
              let playerItem
        else { return false }
        let isForward = count.signum() == 1
        return isForward
        ? playerItem.canStepForward
        : playerItem
            .canStepBackward
    }
    
    /// Evaluates whether the player item supports playback at a specified rate.
    /// - Parameter rate: The target playback rate multiplier.
    /// - Returns: `true` if playback at the specified rate is supported.
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
    /// - Parameter target: The target `AKSeekTarget` position.
    /// - Returns: `true` if the seek command is supported.
    public func canSeek(to target: AKSeekTarget) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay
        else { return false }
        return seekingThroughMediaService.canSeek(to: target)
    }
    
    /// Evaluates whether seeking to a target seek target is permitted and
    /// returns an unavailability reason if disallowed.
    /// - Parameter target: The target `AKSeekTarget` position.
    /// - Returns: A tuple containing a boolean flag indicating permission and
    /// an optional unavailability reason.
    public func canSeek(to target: AKSeekTarget) -> (
        flag: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else {
            if state.isIdle || state.isFailed {
                return (false, .loadMediaFirst)
            } else {
                return (false, .waitTillMediaLoaded)
            }
        }
        return seekingThroughMediaService.canSeek(to: target)
    }
    
    // MARK: - Player Item Property Observation
    
    /// Helper to keep capability observations DRY (Don't Repeat Yourself)
    private func observeCapability(
        _ keyPath: KeyPath<AVPlayerItem, Bool>,
        capability: AKMediaCapability,
        on item: AVPlayerItem
    ) {
        item.publisher(for: keyPath, options: [.initial, .new])
            .removeDuplicates()
            .sink { [weak self] isSupported in
                guard let self else { return }
                emit(
                    .capabilityDidChange(
                        capability,
                        isSupported: isSupported
                    )
                )
                delegate?.akMedia(
                    media!,
                    didChangeCapability: capability,
                    to: isSupported
                )
            }
            .store(in: &subscriptions)
    }
    
    private func bindObservers(to item: AVPlayerItem) {
        // 1. Readiness & Status Observer
        item.publisher(for: \.status, options: [.initial, .new])
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    state = .readyToPlay
                case .failed:
                    let underlyingError =
                    item.error
                    ?? NSError(
                        domain: "AKPlayer",
                        code: -1,
                        userInfo: nil
                    )
                    error = .playerItemLoadingFailed(
                        reason: .statusLoadingFailed(error: underlyingError)
                    )
                    state = .failed
                default:
                    break
                }
            }
            .store(in: &subscriptions)
        
        // 2. Duration
        item.publisher(for: \.duration, options: [.initial, .new])
            .removeDuplicates()
            .sink { [weak self] duration in
                guard let self, let media else { return }
                delegate?.akMedia(media, didChangeItemDurationTo: duration)
                emit(.durationDidChange(duration))
            }
            .store(in: &subscriptions)
        
        // 3. Presentation Resolution Size
        item.publisher(for: \.presentationSize, options: [.initial, .new])
            .removeDuplicates()
            .sink { [weak self] size in
                guard let self, let media else { return }
                delegate?.akMedia(media, didChangePresentationSizeTo: size)
                emit(.presentationSizeDidChange(size))
            }
            .store(in: &subscriptions)
        
        // 4. Tracks
        item.publisher(for: \.tracks, options: [.initial, .new])
            .sink { [weak self] tracks in
                guard let self, let media else { return }
                delegate?.akMedia(media, didChangeTracksTo: tracks)
                emit(.tracksDidChange(tracks))
            }
            .store(in: &subscriptions)
        
        // 5. Timebase
        item.publisher(for: \.timebase, options: [.initial, .new])
            .sink { [weak self] timebase in
                guard let self, let media else { return }
                delegate?.akMedia(media, didChangeTimebaseTo: timebase)
                emit(.timebaseDidChange(timebase))
            }
            .store(in: &subscriptions)
        
        // 6. Loaded Time Ranges
        item.publisher(for: \.loadedTimeRanges, options: [.initial, .new])
            .sink { [weak self] nsValues in
                guard let self, let media else { return }
                let ranges = nsValues.map(\.timeRangeValue)
                delegate?.akMedia(media, didChangeLoadedTimeRangesTo: ranges)
                emit(.loadedTimeRangesDidChange(ranges))
            }
            .store(in: &subscriptions)
        
        // 7. Seekable Time Ranges
        item.publisher(for: \.seekableTimeRanges, options: [.initial, .new])
            .sink { [weak self] nsValues in
                guard let self, let media else { return }
                let ranges = nsValues.map(\.timeRangeValue)
                delegate?.akMedia(media, didChangeSeekableTimeRangesTo: ranges)
                emit(.seekableTimeRangesDidChange(ranges))
            }
            .store(in: &subscriptions)
        
        // 8. Playback Capabilities (DRY Observation)
        bindCapability(\.canStepForward, capability: .stepForward, on: item)
        bindCapability(\.canStepBackward, capability: .stepBackward, on: item)
        bindCapability(\.canPlayReverse, capability: .playReverse, on: item)
        bindCapability(
            \.canPlayFastForward,
             capability: .playFastForward,
             on: item
        )
        bindCapability(
            \.canPlayFastReverse,
             capability: .playFastReverse,
             on: item
        )
        bindCapability(
            \.canPlaySlowForward,
             capability: .playSlowForward,
             on: item
        )
        bindCapability(
            \.canPlaySlowReverse,
             capability: .playSlowReverse,
             on: item
        )
    }
    
    private func bindCapability(
        _ keyPath: KeyPath<AVPlayerItem, Bool>,
        capability: AKMediaCapability,
        on item: AVPlayerItem
    ) {
        item.publisher(for: keyPath, options: [.initial, .new])
            .removeDuplicates()
            .sink { [weak self] isSupported in
                guard let self, let media else { return }
                delegate?.akMedia(
                    media,
                    didChangeCapability: capability,
                    to: isSupported
                )
                emit(.capabilityDidChange(capability, isSupported: isSupported))
            }
            .store(in: &subscriptions)
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
    
    // MARK: - Event Dispatch
    
    /// Emits a media event to active listeners.
    public func emit(_ event: AKMediaEvent) {
        eventBroadcaster.send(event)
    }
}
