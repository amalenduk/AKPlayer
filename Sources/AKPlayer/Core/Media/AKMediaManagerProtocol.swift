//
//   AKMediaManagerProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKMediaManagerProtocol

/// Protocol defining media asset lifecycle management, validation, observation,
/// and capability checks.
@MainActor
public protocol AKMediaManagerProtocol: AnyObject, NSObjectProtocol {
    // MARK: - Properties

    /// The weak reference to the backing playable media item.
    var media: (any AKPlayable)? { get }

    /// The loaded URL asset generated from the media item.
    var asset: AVURLAsset? { get }

    /// The instantiated player item constructed from the asset.
    var playerItem: AVPlayerItem? { get }

    /// The current player error, if media loading or playback failed.
    var error: AKPlayerError? { get }

    /// The current state of the playable media item.
    var state: AKPlayableState { get }

    /// Publisher emitting updates when the media state transitions.
    var statePublisher: AnyPublisher<AKPlayableState, Never> { get }

    /// Asynchronous stream of media item events for Swift Concurrency.
    var events: AsyncStream<AKMediaEvent> { get }

    var delegate: AKMediaDelegate? { get set }

    /// Service responsible for managing seek feasibility checks and execution.
    var seekingThroughMediaService: any AKSeekingThroughMediaServiceProtocol { get }

    /// Service responsible for subtitle and audio track selection management.
    var trackSelectionService: any AKTrackSelectionServiceProtocol { get }
    
    var metadataProvider: any AKMediaMetadataProviderProtocol { get }
    
    /// Notification observer for player item playback lifecycle events.
    var playerItemNotificationsObserver: AKPlayerItemNotificationsObserverProtocol { get }

    // MARK: - Lifecycle Hooks & Asset Operations

    /// Instantiates the underlying `AVURLAsset` for the media item.
    func createAsset() async

    /// Constructs the `AVPlayerItem` from the initialized `AVURLAsset`.
    func createPlayerItemFromAsset()

    /// Asynchronously validates key asset properties (e.g., playability and DRM
    /// restrictions).
    /// - Throws: `AKPlayerError` or `CancellationError` if validation fails or
    /// is cancelled.
    func validateAssetPlayability() async throws

    /// Aborts active asset property loading and cancels pending asynchronous
    /// operations.
    func abortAssetInitialization()

    // MARK: - Preflight Capability Checks

    /// Evaluates if the player item can step forward or backward by a given
    /// frame count.
    /// - Parameter count: The frame offset count (positive for forward,
    /// negative for backward).
    /// - Returns: `true` if stepping by the specified count is supported.
    func canStep(by count: Int) -> Bool

    /// Evaluates whether the player item supports playback at a specified rate.
    /// - Parameter rate: The target playback rate multiplier.
    /// - Returns: `true` if playback at the specified rate is supported.
    func canPlay(at rate: AKPlaybackRate) -> Bool

    /// Evaluates whether seeking to a given target timestamp is permitted.
    /// - Parameter time: The target CMTime position.
    /// - Returns: `true` if the seek command is supported.
    func canSeek(to time: AKSeekTarget) -> Bool

    /// Evaluates whether seeking to a target time is permitted and returns an
    /// unavailability reason if disallowed.
    /// - Parameter time: The target CMTime position.
    /// - Returns: A tuple containing a boolean flag indicating permission and
    /// an optional unavailability reason.
    func canSeek(to time: AKSeekTarget)
        -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?)

    /// Emits a media event to active listeners.
    func emit(_ event: AKMediaEvent)
}
