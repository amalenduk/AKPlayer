//
//   AVPictureInPictureController.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVKit
import Foundation

// MARK: - AKPictureInPictureController

/// Manages Picture-in-Picture (PiP) lifecycle, automatic backgrounding transitions, and event
/// broadcasting.
@MainActor
public class AKPictureInPictureController: NSObject {
    // MARK: - Public Properties

    /// Indicates whether the current device hardware and OS support Picture-in-Picture.
    public static var isPictureInPictureSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    /// Indicates whether PiP is currently possible with the active media and layer state.
    public var isPictureInPicturePossible: Bool {
        pipController?.isPictureInPicturePossible ?? false
    }

    /// Indicates whether PiP is actively displaying in a floating window.
    public var isPictureInPictureActive: Bool {
        pipController?.isPictureInPictureActive ?? false
    }

    /// When `true`, swiping up to the Home Screen automatically transitions the video into PiP.
    public var canStartAutomatically: Bool {
        get { pipController?.canStartPictureInPictureAutomaticallyFromInline ?? false }
        set { pipController?.canStartPictureInPictureAutomaticallyFromInline = newValue }
    }

    /// Delegate receiver for UIKit PiP events.
    public weak var delegate: AKPictureInPictureDelegate?

    /// Asynchronous stream of PiP events for Swift Concurrency (`for await event in pip.events`).
    public var events: AsyncStream<AKPictureInPictureEvent> {
        eventBroadcaster.makeStream()
    }

    // MARK: - Private Properties

    /// The underlying UIKit `AVPictureInPictureController` instance.
    private var pipController: AVPictureInPictureController?
    /// Multicast broadcaster distributing Picture-in-Picture lifecycle events.
    private let eventBroadcaster = AKEventBroadcaster<AKPictureInPictureEvent>()

    // MARK: - Initialization

    /// Initializes a Picture-in-Picture controller bound to a target `AVPlayerLayer`.
    /// - Parameter playerLayer: The `AVPlayerLayer` rendering video frames (e.g.
    /// `playerView.playerLayer`).
    public init?(playerLayer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return nil
        }

        super.init()

        guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
            return nil
        }

        pipController = controller
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
    }

    deinit {
        eventBroadcaster.finish()
    }

    // MARK: - Public Controls

    /// Commands the player to enter Picture-in-Picture mode.
    public func start() {
        guard let pipController, pipController.isPictureInPicturePossible else { return }
        pipController.startPictureInPicture()
    }

    /// Commands the player to exit Picture-in-Picture mode.
    public func stop() {
        guard let pipController, pipController.isPictureInPictureActive else { return }
        pipController.stopPictureInPicture()
    }

    /// Toggles between starting and stopping Picture-in-Picture.
    public func toggle() {
        if isPictureInPictureActive {
            stop()
        } else {
            start()
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension AKPictureInPictureController: AVPictureInPictureControllerDelegate {
    /// Responds to the system indicating Picture-in-Picture is about to start.
    public nonisolated func pictureInPictureControllerWillStartPictureInPicture(
        _: AVPictureInPictureController
    ) {
        Task { @MainActor in
            delegate?.pictureInPictureWillStart(self)
            eventBroadcaster.send(.willStart)
        }
    }

    /// Responds to the system indicating Picture-in-Picture has started.
    public nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _: AVPictureInPictureController
    ) {
        Task { @MainActor in
            delegate?.pictureInPictureDidStart(self)
            eventBroadcaster.send(.didStart)
        }
    }

    /// Responds to the system indicating Picture-in-Picture failed to start.
    public nonisolated func pictureInPictureController(
        _: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor in
            delegate?.pictureInPicture(self, failedToStartWithError: error)
            eventBroadcaster.send(.failedToStart(error.localizedDescription))
        }
    }

    /// Responds to the system indicating Picture-in-Picture is about to stop.
    public nonisolated func pictureInPictureControllerWillStopPictureInPicture(
        _: AVPictureInPictureController
    ) {
        Task { @MainActor in
            delegate?.pictureInPictureWillStop(self)
            eventBroadcaster.send(.willStop)
        }
    }

    /// Responds to the system indicating Picture-in-Picture has stopped.
    public nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _: AVPictureInPictureController
    ) {
        Task { @MainActor in
            delegate?.pictureInPictureDidStop(self)
            eventBroadcaster.send(.didStop)
        }
    }

    /// Responds to user request to restore the application user interface when stopping
    /// Picture-in-Picture.
    public nonisolated func pictureInPictureController(
        _: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (
            Bool
        )
            -> Void
    ) {
        // 1. Wrap the non-sendable closure inside an @unchecked Sendable container
        struct SendableCompletion: @unchecked Sendable {
            let handler: (Bool) -> Void
            func callAsFunction(_ result: Bool) {
                handler(result)
            }
        }

        let wrapped = SendableCompletion(handler: completionHandler)

        Task { @MainActor in
            self.eventBroadcaster.send(.restoreUserInterface)

            if let delegate = self.delegate {
                // 2. Call the delegate using a @Sendable closure that forwards to the wrapped
                // struct
                delegate.pictureInPicture(
                    self,
                    restoreUserInterfaceForPictureInPictureStopWith: { result in
                        wrapped(result)
                    }
                )
            } else {
                wrapped(true)
            }
        }
    }
}
