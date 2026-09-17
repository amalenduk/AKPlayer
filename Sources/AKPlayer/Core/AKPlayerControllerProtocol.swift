//
//   AKPlayerControllerProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKPlayerControllerPerforming

/// Defines raw low-level driver actions executed directly on the underlying
/// playback pipeline.
@MainActor
public protocol AKPlayerControllerPerforming {
    /// Executes low-level playback initialization and unpauses the underlying
    /// player.
    func performPlay()
    
    /// Executes low-level playback at a specified speed rate.
    /// - Parameter rate: The target playback rate multiplier.
    func performPlay(at rate: AKPlaybackRate)
    
    /// Halts underlying playback pipeline without tearing down loaded assets.
    func performPause()
    
    /// Completely stops playback and resets internal player engine contexts.
    func performStop()
    
    /// Dispatches low-level seek operations to the underlying media item.
    /// - Parameter targetSeek: The seek target descriptor containing target
    /// position and tolerances.
    func performSeek(to targetSeek: AKSeek)
    
    /// Steps video playback by a fixed number of frames forward or backward.
    /// - Parameter count: Frame offset (positive for forward, negative for
    /// backward).
    func performStep(by count: Int)
}

// MARK: - AKPlayerControllerProtocol

/// Primary interface representing the core player controller driving playback
/// engine, state transitions, and configuration.
@MainActor
public protocol AKPlayerControllerProtocol: AnyObject, Sendable, AKPlayerProtocol, AKPlayerControllerPerforming {
    /// Configuration options specifying playback policies and default rates.
    var configuration: any AKPlayerConfigurationProtocol { get }
    
    /// The active player state machine controller handling command validation.
    var controller: any AKPlayerStateControllerProtocol { get }
    
    /// Internal service handling media seek calculations and boundaries.
    var playerSeekingThroughMediaService: any AKPlayerSeekingThroughMediaServiceProtocol { get }
    
    var interstitialService: any AKPlayerInterstitialServiceProtocol { get }
    
    /// Network monitor monitoring active connectivity status for media
    /// streaming.
    var networkStatusMonitor: any AKNetworkStatusMonitorProtocol { get }
    
    /// Prepares internal audio/video playback engines and system resources for
    /// playback.
    /// - Throws: An `AKPlayerError` if pipeline preparation fails.
    func prepare() throws
    
    /// Transitions the active state machine handler to a new target state
    /// controller.
    /// - Parameter controller: The new state machine controller instance.
    func change(_ controller: any AKPlayerStateControllerProtocol)
    
    /// Notifies the controller to re-process state logic after state
    /// transitions complete.
    func processStateChange()
    
    /// Single entry point for dispatching all player events across the
    /// framework.
    /// Broadcasts the event to the delegate and forwards it to event listeners
    /// (`AsyncStream`).
    /// - Parameter event: The player event that occurred.
    func emit(_ event: AKPlayerEvent)
}
