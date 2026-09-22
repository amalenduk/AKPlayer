//
//   AKMediaManagerProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKMediaManagerProtocol

/// Protocol defining media asset lifecycle management, validation, observation,
/// and capability checks.
public protocol AKMediaManagerProtocol: AnyObject, Sendable {
    // MARK: - Properties
    
    /// The weak reference to the backing playable media item.
    var media: (any AKPlayable)? { get }
    
    /// The loaded URL asset generated from the media item (Single Source of Truth).
    var asset: AVURLAsset? { get }
    
    /// The instantiated player item constructed from the asset (Single Source of Truth).
    var playerItem: AVPlayerItem? { get }
    
    /// The current player error, if media loading or playback failed.
    var error: AKPlayerError? { get }
    
    /// The current state of the playable media item.
    var state: AKPlayableState { get }
    
    /// Asynchronous stream of media item events for Swift Concurrency.
    var events: AsyncStream<AKMediaEvent> { get }
    
    /// Service responsible for managing seek feasibility checks and execution.
    var seekingThroughMediaService: any AKSeekingThroughMediaServiceProtocol { get }
    
    /// Service responsible for subtitle and audio track selection management.
    var trackSelectionService: any AKTrackSelectionServiceProtocol { get }
    
    /// Metadata extraction service for active media assets.
    var metadataProvider: any AKMediaMetadataProviderProtocol { get }
    
    /// Chapter extraction and navigation service.
    var chapterService: any AKChapterServiceProtocol { get }
    
    /// Notification observer for player item playback lifecycle events.
    var playerItemNotificationsObserver: any AKPlayerItemNotificationsObserverProtocol { get }
    
    // MARK: - Lifecycle Hooks & Asset Operations
    
    /// Instantiates the underlying `AVURLAsset` for the media item.
    func createAsset() async
    
    /// Asynchronously validates key asset properties (e.g., playability and DRM restrictions).
    /// - Throws: `AKPlayerError` or `CancellationError` if validation fails or is cancelled.
    func validateAssetPlayability() async throws
    
    /// Constructs the `AVPlayerItem` from the initialized `AVURLAsset`.
    func createPlayerItemFromAsset()
    
    /// Aborts active asset property loading and cancels pending asynchronous operations.
    func abortAssetInitialization()
    
    // MARK: - Preflight Capability Checks
    
    /// Evaluates if the player item can step forward or backward by a given frame count.
    /// - Parameter count: The frame offset count (positive for forward, negative for backward).
    /// - Returns: `true` if stepping by the specified count is supported.
    func canStep(by count: Int) -> Bool
    
    /// Evaluates whether the player item supports playback at a specified rate.
    /// - Parameter rate: The target playback rate multiplier.
    /// - Returns: `true` if playback at the specified rate is supported.
    func canPlay(at rate: AKPlaybackRate) -> Bool
    
    /// Evaluates whether seeking to a given target timestamp is permitted.
    /// - Parameter target: The target seek target position.
    /// - Returns: `true` if the seek command is supported.
    func canSeek(to target: AKSeekTarget) -> Bool
    
    /// Evaluates whether seeking to a target time is permitted and returns an unavailability reason if disallowed.
    /// - Parameter target: The target seek target position.
    /// - Returns: A tuple containing a boolean flag indicating permission and an optional unavailability reason.
    func canSeek(to target: AKSeekTarget) -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?)
    
    /// Evaluates whether the media item supports a specific playback capability.
    /// - Parameter capability: The playback capability to evaluate.
    /// - Returns: `true` if the capability is supported.
    func isSupported(_ capability: AKMediaCapability) -> Bool
    
    // MARK: - Event Dispatch
    
    /// Emits a media event to active listeners.
    func emit(_ event: AKMediaEvent)
}
