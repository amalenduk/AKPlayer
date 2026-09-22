//
//   AKFailedState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - AKFailedState

/// Concrete state representing a terminal or recoverable error condition within
/// the player pipeline.
@MainActor
public class AKFailedState: AKBaseState {
    // MARK: - Properties

    /// The specific player error that triggered this failure state.
    public let error: AKPlayerError

    // MARK: - Initialization & Deinitialization

    /// Initializes a failed state instance associated with a specified player
    /// controller and error.
    /// - Parameters:
    ///   - playerController: The target player controller executing playback
    /// commands.
    ///   - error: The player error describing the underlying failure.
    public init(
        playerController: any AKPlayerControllerProtocol,
        error: AKPlayerError
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.error = error
        super.init(playerController: playerController, state: .failed)
    }

    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - State Lifecycle & Event Handlers

    /// Notifies the delegate that the player has encountered an error and
    /// transitioned into the failed state.
    override public func processStateChange() {
        super.processStateChange()
        playerController.emit(.didFail(with: error))
        AKLogger.error(error.localizedDescription, category: .player)
    }

    // MARK: - Availability Overrides

    /// Evaluates preflight permission and unavailable reasons for a given
    /// player action when in the failed state.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple containing a boolean flag indicating if allowed, and
    /// an optional unavailability reason.
    override public func availability(for action: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        switch action {
        case .load:
            let hasPlayerError = playerController.player.error != nil
            return hasPlayerError
                ? (allowed: false, reason: .playerCanNoLongerPlay)
                : (
                    allowed: true,
                    reason: nil
                )

        default:
            let hasPlayerError = playerController.player.error != nil
            return (
                allowed: false,
                reason: hasPlayerError ? .playerCanNoLongerPlay : .loadMediaFirst
            )
        }
    }
}
