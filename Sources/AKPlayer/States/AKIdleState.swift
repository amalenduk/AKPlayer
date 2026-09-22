//
//   AKIdleState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - AKIdleState

/// Concrete state representing an idle player machine before any media item has
/// been initialized or loaded.
@MainActor
public class AKIdleState: AKBaseState {
    // MARK: - Initialization & Deinitialization

    /// Initializes an idle state instance associated with the specified player
    /// controller.
    /// - Parameter playerController: The target player controller executing
    /// playback commands.
    public init(playerController: any AKPlayerControllerProtocol) {
        super.init(playerController: playerController, state: .idle)
    }

    deinit {
       
            AKLogger.logDeinit(
                String(describing: Self.self),
                pointer: Unmanaged.passUnretained(self)
            )
        
    }

    // MARK: - Availability Overrides

    /// Evaluates preflight permission and unavailable reasons for a given
    /// player action when in the idle state.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.loadMediaFirst` for all
    /// actions in idle state.
    override public func availability(for _: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        (allowed: false, reason: .loadMediaFirst)
    }
}
