//
//   AKPictureInPictureDelegate.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKPictureInPictureDelegate

/// Delegate protocol for receiving Picture-in-Picture lifecycle notifications and UI restoration
/// callbacks.
@MainActor
public protocol AKPictureInPictureDelegate: AnyObject {
    /// Called when Picture-in-Picture is about to begin.
    func pictureInPictureWillStart(_ controller: AKPictureInPictureController)

    /// Called when Picture-in-Picture has started.
    func pictureInPictureDidStart(_ controller: AKPictureInPictureController)

    /// Called when Picture-in-Picture fails to start.
    func pictureInPicture(
        _ controller: AKPictureInPictureController,
        failedToStartWithError error: Error
    )

    /// Called when Picture-in-Picture is about to stop.
    func pictureInPictureWillStop(_ controller: AKPictureInPictureController)

    /// Called when Picture-in-Picture has completely stopped.
    func pictureInPictureDidStop(_ controller: AKPictureInPictureController)

    /// Called when the user taps the restore button in the floating PiP window.
    /// - Parameter completionHandler: Call with `true` once your UI navigation is restored.
    func pictureInPicture(
        _ controller: AKPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWith completionHandler: @escaping @Sendable (
            Bool
        )
            -> Void
    )
}

// MARK: - Default Implementations

public extension AKPictureInPictureDelegate {
    func pictureInPictureWillStart(_: AKPictureInPictureController) {}
    func pictureInPictureDidStart(_: AKPictureInPictureController) {}
    func pictureInPicture(_: AKPictureInPictureController, failedToStartWithError _: Error) {}
    func pictureInPictureWillStop(_: AKPictureInPictureController) {}
    func pictureInPictureDidStop(_: AKPictureInPictureController) {}
    func pictureInPicture(
        _: AKPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWith completionHandler: @escaping @Sendable (
            Bool
        )
            -> Void
    ) {
        completionHandler(true)
    }
}
