//
//   AKSharePlayCoordinatorProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import GroupActivities

// MARK: - AKSharePlayCoordinatorProtocol

/// Protocol defining operations and state tracking for Apple SharePlay (`GroupActivities`)
/// media playback synchronization.
@MainActor
public protocol AKSharePlayCoordinatorProtocol: AnyObject, Sendable {
    // MARK: - Properties

    /// The current state of SharePlay synchronization.
    var state: AKSharePlayState { get }

    /// Indicates whether the current device is eligible to initiate or join a SharePlay group
    /// session.
    var isEligibleForGroupSession: Bool { get }

    /// The currently active `GroupSession`, if joined and coordinating.
    var activeSession: GroupSession<AKGroupActivity>? { get }

    /// The number of participants currently active in the group session.
    var participantCount: Int { get }

    /// SharePlay configuration settings driving auto-coordination and suspension timeouts.
    var configuration: AKSharePlayConfiguration { get set }

    // MARK: - Session Lifecycle

    /// Begins monitoring for incoming SharePlay sessions initiated over FaceTime / Messages.
    func startObservingSessions()

    /// Stops monitoring for incoming SharePlay sessions.
    func stopObservingSessions()

    /// Prepares and activates a SharePlay session for the specified playable media item.
    /// - Parameter media: The playable media item to share.
    /// - Returns: A boolean indicating whether activation was initiated.
    @discardableResult
    func activate(for media: any AKPlayable) async throws -> Bool

    /// Prepares and activates a SharePlay session with an explicit `AKGroupActivity`.
    /// - Parameter activity: The custom group activity to activate.
    /// - Returns: A boolean indicating whether activation was initiated.
    @discardableResult
    func activate(activity: AKGroupActivity) async throws -> Bool

    /// Prepares the group activity for activation, displaying system SharePlay confirmation if
    /// required.
    /// - Parameter media: The playable media item to prepare.
    /// - Returns: The system activation result.
    func prepareForActivation(for media: any AKPlayable) async -> GroupActivityActivationResult

    /// Coordinates the underlying `AVPlayer` with the specified `GroupSession`.
    /// - Parameter session: The group session to coordinate with.
    func coordinate(with session: GroupSession<AKGroupActivity>)

    /// Leaves the active SharePlay session for the local user without ending it for other
    /// participants.
    func leave()

    /// Terminates the active SharePlay session for all participants in the group.
    func end()
}
