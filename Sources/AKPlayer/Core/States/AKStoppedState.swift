//
//   AKStoppedState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKStoppedState

/// Concrete state representing a state where media playback is stopped and item
/// resources are torn down.
@MainActor
public class AKStoppedState: AKBaseState {
    // MARK: - Properties
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a stopped state instance associated with the specified
    /// player controller.
    /// - Parameter playerController: The underlying player controller driving
    /// execution.
    public init(playerController: any AKPlayerControllerProtocol) {
        defer {
            AKLogger.logInit(self)
        }
        super.init(playerController: playerController, state: .stopped)
    }
    
    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Entry point for stopped state processing. Halts playback, cancels
    /// pending seeks, and replaces current item with nil.
    override public func processStateChange() {
        super.processStateChange()
        
        playerController.performStop()
    }
    
    // MARK: - Private Helper Functions
    
    public override func handlePlayerStatusChange(_ status: AVPlayer.Status) {
        guard status == .failed else { return }
        let controller = AKFailedState(
            playerController: playerController,
            error: .playerCanNoLongerPlay(
                error: playerController.player
                    .error
            )
        )
        change(controller)
    }
    
    // MARK: - Availability Overrides
    
    /// Evaluates preflight permission and unavailable reasons for a given
    /// player action when in stopped state.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.loadMediaFirst` for
    /// playback/seeking actions; base availability otherwise.
    override public func availability(for action: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        switch action {
        case .play, .pause, .stop, .seek, .fastForward, .rewind, .step:
            (false, .loadMediaFirst)
        default:
            super.availability(for: action)
        }
    }
}
