//
//   AKSharePlayCoordinator.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import GroupActivities

// MARK: - AKSharePlayCoordinator

/// Concrete coordinator managing Apple SharePlay (`GroupActivities`) lifecycle,
/// `AVPlayerPlaybackCoordinator` synchronization, and participant state observation.
@MainActor
public final class AKSharePlayCoordinator: NSObject, AKSharePlayCoordinatorProtocol,
    AVPlayerPlaybackCoordinatorDelegate
{
    // MARK: - Properties

    /// The underlying `AVPlayer` driving playback.
    private unowned let player: AVPlayer

    /// Optional weak reference to the player controller for event dispatching.
    private weak var playerController: (any AKPlayerControllerProtocol)?

    /// SharePlay configuration settings.
    public var configuration: AKSharePlayConfiguration

    /// The current state of SharePlay synchronization.
    public private(set) var state: AKSharePlayState = .inactive {
        didSet {
            guard oldValue != state else { return }
            playerController?.emit(.sharePlayStateDidChange(state))
        }
    }

    /// The active `GroupSession`, if joined and coordinating.
    public private(set) var activeSession: GroupSession<AKGroupActivity>?

    /// The number of participants currently active in the group session.
    public var participantCount: Int {
        activeSession?.activeParticipants.count ?? 0
    }

    /// Indicates whether the current device is eligible to initiate or join a SharePlay group
    /// session.
    public var isEligibleForGroupSession: Bool {
        GroupStateObserver().isEligibleForGroupSession
    }

    // MARK: - Private Tasks

    private var sessionObservationTask: Task<Void, Never>?
    private var sessionStateTask: Task<Void, Never>?
    private var participantsTask: Task<Void, Never>?

    // MARK: - Initialization & Deinitialization

    /// Initializes a new SharePlay coordinator for the specified player.
    /// - Parameters:
    ///   - player: The underlying `AVPlayer` instance.
    ///   - playerController: Optional player controller for event forwarding.
    ///   - configuration: Configuration options. Defaults to `.default`.
    public init(
        player: AVPlayer,
        playerController: (any AKPlayerControllerProtocol)? = nil,
        configuration: AKSharePlayConfiguration = .default
    ) {
        self.player = player
        self.playerController = playerController
        self.configuration = configuration
        super.init()

        player.playbackCoordinator.delegate = self
        AKLogger.logInit(self)
    }

    /// Attaches a player controller instance for event broadcasting.
    /// - Parameter playerController: The parent player controller.
    public func attach(playerController: any AKPlayerControllerProtocol) {
        self.playerController = playerController
    }

    deinit {
        sessionObservationTask?.cancel()
        sessionStateTask?.cancel()
        participantsTask?.cancel()
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - Session Observation

    /// Begins monitoring for incoming SharePlay sessions initiated over FaceTime / Messages.
    public func startObservingSessions() {
        sessionObservationTask?.cancel()
        sessionObservationTask = Task { [weak self] in
            for await session in AKGroupActivity.sessions() {
                guard let self, !Task.isCancelled else { break }
                if self.configuration.autoCoordinateIncomingSessions {
                    self.coordinate(with: session)
                }
            }
        }
    }

    /// Stops monitoring for incoming SharePlay sessions.
    public func stopObservingSessions() {
        sessionObservationTask?.cancel()
        sessionObservationTask = nil
    }

    // MARK: - Session Activation

    /// Prepares and activates a SharePlay session for the specified playable media item.
    /// - Parameter media: The playable media item to share.
    /// - Returns: A boolean indicating whether activation was initiated.
    @discardableResult
    public func activate(for media: any AKPlayable) async throws -> Bool {
        let activity = AKGroupActivity(
            from: media,
            fallbackURL: configuration.fallbackWebURL
        )
        return try await activate(activity: activity)
    }

    /// Prepares and activates a SharePlay session with an explicit `AKGroupActivity`.
    /// - Parameter activity: The custom group activity to activate.
    /// - Returns: A boolean indicating whether activation was initiated.
    @discardableResult
    public func activate(activity: AKGroupActivity) async throws -> Bool {
        guard isEligibleForGroupSession else {
            throw AKSharePlayError.notEligibleForSharePlay
        }

        state = .connecting
        let success = try await activity.activate()

        if !success {
            state = .inactive
            throw AKSharePlayError
                .sessionActivationFailed(
                    "SharePlay activation was cancelled or disabled by the user."
                )
        }

        return success
    }

    /// Prepares the group activity for activation, displaying system SharePlay confirmation if
    /// required.
    /// - Parameter media: The playable media item to prepare.
    /// - Returns: The system activation result.
    public func prepareForActivation(for media: any AKPlayable) async
        -> GroupActivityActivationResult
    {
        let activity = AKGroupActivity(
            from: media,
            fallbackURL: configuration.fallbackWebURL
        )
        return await activity.prepareForActivation()
    }

    // MARK: - Session Coordination

    /// Coordinates the underlying `AVPlayer` with the specified `GroupSession`.
    /// - Parameter session: The group session to coordinate with.
    public func coordinate(with session: GroupSession<AKGroupActivity>) {
        cleanUpCurrentSession()

        activeSession = session
        state = .connecting

        // Connect AVPlayer to the group activity session
        player.playbackCoordinator.coordinateWithSession(session)

        // Observe session state transitions
        sessionStateTask = Task { [weak self, weak session] in
            guard let session else { return }
            for await sessionState in session.$state.values {
                guard let self, !Task.isCancelled else { break }
                switch sessionState {
                case .waiting:
                    self.state = .connecting
                case .joined:
                    self.state = .active(participantCount: session.activeParticipants.count)
                case .invalidated:
                    self.cleanUpCurrentSession()
                    self.state = .ended
                @unknown default:
                    break
                }
            }
        }

        // Observe participant count changes
        participantsTask = Task { [weak self, weak session] in
            guard let session else { return }
            for await participants in session.$activeParticipants.values {
                guard let self, !Task.isCancelled else { break }
                if case .active = self.state {
                    self.state = .active(participantCount: participants.count)
                }
            }
        }

        // Join the session
        session.join()
    }

    /// Leaves the active SharePlay session for the local user without ending it for other
    /// participants.
    public func leave() {
        activeSession?.leave()
        cleanUpCurrentSession()
        state = .ended
    }

    /// Terminates the active SharePlay session for all participants in the group.
    public func end() {
        activeSession?.end()
        cleanUpCurrentSession()
        state = .ended
    }

    // MARK: - Helpers

    private func cleanUpCurrentSession() {
        sessionStateTask?.cancel()
        sessionStateTask = nil
        participantsTask?.cancel()
        participantsTask = nil
        activeSession = nil
    }

    // MARK: - AVPlayerPlaybackCoordinatorDelegate

    public func playbackCoordinator(
        _: AVPlayerPlaybackCoordinator,
        didIssue _: AVCoordinatedPlaybackSuspension
    ) {
        state = .suspended(reason: .waitingForParticipants)
    }
}
