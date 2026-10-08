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

    /// Asynchronous stream of media events for Swift Concurrency (`for await event in
    /// manager.events`).
    public var events: AsyncStream<AKMediaEvent> {
        eventBroadcaster.makeStream()
    }

    private let eventBroadcaster = AKEventBroadcaster<AKMediaEvent>()

    // MARK: - Child Services

    /// Service responsible for managing seek feasibility checks and execution.
    public var seekingThroughMediaService: any AKSeekingThroughMediaServiceProtocol {
        _seekingThroughMediaService
    }

    /// Service responsible for subtitle and audio track selection management.
    public var trackSelectionService: any AKTrackSelectionServiceProtocol {
        _trackSelectionService
    }

    /// Service responsible for extracting asset and item metadata.
    public var metadataProvider: any AKMediaMetadataProviderProtocol {
        _metadataProvider
    }

    /// Service responsible for extracting and tracking media chapters.
    public var chapterService: any AKChapterServiceProtocol {
        _chapterService
    }

    /// Notification observer for player item playback lifecycle events.
    public var playerItemNotificationsObserver: any AKPlayerItemNotificationsObserverProtocol {
        _playerItemNotificationsObserver
    }

    // MARK: - Private Storage

    private var observations: [NSKeyValueObservation] = []

    private let playerItemInitService: any AKPlayerItemInitServiceProtocol
    private var _seekingThroughMediaService: (any AKSeekingThroughMediaServiceProtocol)!
    private var _trackSelectionService: AKTrackSelectionService!
    private var _metadataProvider: AKMediaMetadataProvider!
    private var _chapterService: AKChapterService!
    private var _playerItemNotificationsObserver: AKPlayerItemNotificationsObserver!

    // MARK: - Initialization & Cleanup

    /// Initializes a new media manager instance for the specified media item.
    /// - Parameters:
    ///   - media: The target playable media item.
    ///   - playerItemInitService: The asset & item creation service.
    public init(
        media: any AKPlayable,
        playerItemInitService: any AKPlayerItemInitServiceProtocol = AKPlayerItemInitService()
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.media = media
        self.playerItemInitService = playerItemInitService
        asset = media.customAsset
        playerItem = media.customPlayerItem
        super.init()

        // Direct initialization of child services
        _seekingThroughMediaService = AKSeekingThroughMediaService(mediaManager: self)
        _trackSelectionService = AKTrackSelectionService(mediaManager: self)
        _metadataProvider = AKMediaMetadataProvider(mediaManager: self)
        _chapterService = AKChapterService(mediaManager: self)
        _playerItemNotificationsObserver = AKPlayerItemNotificationsObserver(mediaManager: self)

        // Configure initial lifecycle state for pre-configured media items (playerItem or asset)
        if let customItem = media.customPlayerItem {
            state = .playerItemLoaded

            // 1. Bind item KVO observers (duration, status, tracks, timebase)
            bindObservers(to: customItem)

            // 2. Attach live timed metadata output
            attachMetadataOutput(to: customItem)

            // 3. Start observing tracks and notifications
            _trackSelectionService.startObserving()
            _playerItemNotificationsObserver.startObserving(playerItem: customItem)

            // 4. Load metadata and chapters in parallel (extracting asset if not explicitly
            // provided)
            loadMetadataAndChapters(extractAssetFrom: customItem)
        } else if media.customAsset != nil {
            state = .assetLoaded

            // Load metadata and chapters in parallel
            loadMetadataAndChapters()
        } else {
            state = .idle
        }
    }

    deinit {
        observations.removeAll()
        eventBroadcaster.finish()
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - Asset Lifecycle Operations

    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    public func createAsset() async {
        if !state.isIdle, !state.isFailed {
            abortAssetInitialization()
        }
        guard let media else { return }
        error = nil
        asset = await playerItemInitService.createAsset(for: media)
        state = .assetLoaded

        // Asynchronously load container metadata and chapters in parallel
        loadMetadataAndChapters()
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
        try await playerItemInitService.validatePlayability(of: asset, for: media)
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
        playerItem = newItem

        // Attach live stream timed metadata output
        attachMetadataOutput(to: newItem)

        bindObservers(to: newItem)
        state = .playerItemLoaded

        // Start observing track changes and selections on the active player item
        _trackSelectionService.startObserving()

        // Start observing system notifications on the active player item
        _playerItemNotificationsObserver.startObserving(playerItem: newItem)
    }

    /// Aborts active asset property loading and cancels pending operations.
    public func abortAssetInitialization() {
        observations.removeAll()
        asset?.cancelLoading()
        asset = nil
        playerItem = nil
        state = .idle
        _metadataProvider.resetSession()
        _chapterService.resetSession()
        _trackSelectionService.resetSession()
        _playerItemNotificationsObserver.stopObserving()
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

    /// Evaluates whether seeking is generally supported for the media item.
    public var canSeek: Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else { return false }
        return seekingThroughMediaService.canSeek
    }

    /// The current seekable time range for the active media asset.
    public var seekableWindow: CMTimeRange? {
        seekingThroughMediaService.seekableWindow
    }

    /// Evaluates whether seeking to a target seek target position is permitted.
    public func canSeek(to target: AKSeekTarget) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else { return false }
        return seekingThroughMediaService.canSeek(to: target)
    }

    /// Evaluates whether seeking to a target seek target is permitted and returns an unavailability
    /// reason if disallowed.
    public func canSeek(to target: AKSeekTarget)
        -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?)
    {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else {
            if state.isIdle || state.isFailed {
                return (false, .loadMediaFirst)
            } else {
                return (false, .waitTillMediaLoaded)
            }
        }
        return seekingThroughMediaService.canSeek(to: target)
    }

    /// Checks if a specific playback capability is currently supported by the active player item.
    /// - Parameter capability: The playback capability to evaluate.
    /// - Returns: `true` if supported, `false` otherwise.
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

    // MARK: - Player Item Property Observation (Foundation KVO)

    private func bindObservers(to item: AVPlayerItem) {
        // 1. Readiness & Status Observer
        observations.append(
            item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    state = .readyToPlay
                case .failed:
                    let underlyingError = observedItem.error ?? NSError(
                        domain: "AKPlayer",
                        code: -1,
                        userInfo: nil
                    )
                    error =
                        .playerItemLoadingFailed(
                            reason: .statusLoadingFailed(error: underlyingError)
                        )
                    state = .failed
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
                emit(.durationDidChange(duration))
            }
        )

        // 3. Presentation Resolution Size
        observations.append(
            item.observe(\.presentationSize, options: [
                .initial,
                .new,
            ]) { [weak self] observedItem, _ in
                guard let self else { return }
                let size = observedItem.presentationSize
                emit(.presentationSizeDidChange(size))
            }
        )

        // 4. Timebase
        observations.append(
            item.observe(\.timebase, options: [.initial, .new]) { [weak self] observedItem, _ in
                guard let self else { return }
                let timebase = observedItem.timebase
                emit(.timebaseDidChange(timebase))
            }
        )

        // 6. Loaded Time Ranges
        observations.append(
            item.observe(\.loadedTimeRanges, options: [
                .initial,
                .new,
            ]) { [weak self] observedItem, _ in
                guard let self else { return }
                let ranges = observedItem.loadedTimeRanges.map(\.timeRangeValue)
                emit(.loadedTimeRangesDidChange(ranges))
            }
        )

        // 7. Seekable Time Ranges
        observations.append(
            item.observe(\.seekableTimeRanges, options: [
                .initial,
                .new,
            ]) { [weak self] observedItem, _ in
                guard let self else { return }
                let ranges = observedItem.seekableTimeRanges.map(\.timeRangeValue)
                emit(.seekableTimeRangesDidChange(ranges))
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
                emit(.capabilityDidChange(capability, isSupported: isSupported))
            }
        )
    }

    // MARK: - Metadata & Chapter Loading

    private func loadMetadataAndChapters(extractAssetFrom customItem: AVPlayerItem? = nil) {
        Task { [weak self] in
            guard let self else { return }
            if asset == nil, let customItem {
                asset = await MainActor.run { customItem.asset as? AVURLAsset }
            }
            async let meta: () = _metadataProvider.loadMetadata()
            async let chapters: () = _chapterService.loadChapters()
            _ = await (meta, chapters)
        }
    }

    // MARK: - Timed Metadata Output Attachment

    private func attachMetadataOutput(to item: AVPlayerItem) {
        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        let queue = DispatchQueue(label: "com.akplayer.timedMetadataOutputQueue")
        metadataOutput.setDelegate(self, queue: queue)
        Task { @MainActor in
            item.add(metadataOutput)
        }
    }
}

// MARK: - AVPlayerItemMetadataOutputPushDelegate

extension AKMediaManager: AVPlayerItemMetadataOutputPushDelegate {
    /// Receives timed metadata groups pushed from the media stream and forwards them to the
    /// metadata provider.
    ///
    /// - Parameters:
    ///   - output: The metadata output pushing new timed metadata groups.
    ///   - groups: The list of timed metadata groups encountered in playback.
    ///   - track: The player item track from which metadata was read, if applicable.
    public func metadataOutput(
        _: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from _: AVPlayerItemTrack?
    ) {
        let items = groups.flatMap(\.items)
        guard !items.isEmpty else { return }
        _metadataProvider.handleTimedMetadata(items)
    }
}
