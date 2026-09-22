//
//   AKSharePlayConfiguration.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation
import GroupActivities

// MARK: - AKSharePlayConfiguration

/// Configuration governing Apple SharePlay (`GroupActivities`) lifecycle, auto-coordination,
/// and suspension handling.
public struct AKSharePlayConfiguration: Sendable, Equatable, Hashable {
    // MARK: - Properties

    /// Whether incoming SharePlay group sessions received over FaceTime should automatically
    /// coordinate with the active player. Defaults to `true`.
    public var autoCoordinateIncomingSessions: Bool

    /// Optional fallback web URL presented to participants who do not have the app installed.
    public var fallbackWebURL: URL?

    /// The default group activity type (e.g., watch together for video, listen together for audio).
    public var activityType: AKGroupActivityType

    /// Timeout in seconds to wait for buffering participants before resuming or alerting. Defaults
    /// to `10.0`s.
    public var suspensionWaitTimeout: TimeInterval

    // MARK: - Static Default

    /// A default SharePlay configuration instance.
    public static let `default` = AKSharePlayConfiguration()

    // MARK: - Initialization

    /// Initializes a new SharePlay configuration.
    /// - Parameters:
    ///   - autoCoordinateIncomingSessions: Whether incoming sessions should auto-coordinate.
    /// Defaults to `true`.
    ///   - fallbackWebURL: Optional fallback web URL for participants without the app.
    ///   - activityType: The group activity type classification. Defaults to `.generic`.
    ///   - suspensionWaitTimeout: Timeout duration in seconds during participant suspensions.
    /// Defaults to `10.0`.
    public init(
        autoCoordinateIncomingSessions: Bool = true,
        fallbackWebURL: URL? = nil,
        activityType: AKGroupActivityType = .generic,
        suspensionWaitTimeout: TimeInterval = 10.0
    ) {
        self.autoCoordinateIncomingSessions = autoCoordinateIncomingSessions
        self.fallbackWebURL = fallbackWebURL
        self.activityType = activityType
        self.suspensionWaitTimeout = suspensionWaitTimeout
    }
}
