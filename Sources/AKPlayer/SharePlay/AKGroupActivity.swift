//
//   AKGroupActivity.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation
import GroupActivities

// MARK: - AKGroupActivityType

/// The activity classification type for a SharePlay session.
public enum AKGroupActivityType: String, Sendable, Codable, Hashable, Equatable {
    /// Standard generic shared activity.
    case generic

    /// Audio, music, or podcast shared listening activity.
    case listenTogether

    /// Video or movie shared watching activity.
    case watchTogether

    /// The matching `GroupActivityMetadata.ActivityType` representation in `GroupActivities`.
    public var systemActivityType: GroupActivityMetadata.ActivityType {
        switch self {
        case .generic:
            .generic
        case .listenTogether:
            .listenTogether
        case .watchTogether:
            .watchTogether
        }
    }
}

// MARK: - AKGroupActivity

/// Concrete `GroupActivity` representing shared media playback over FaceTime and Messages
/// SharePlay.
public struct AKGroupActivity: GroupActivity, Sendable, Codable, Hashable, Equatable {
    // MARK: - GroupActivity Conformance

    /// Unique activity identifier used by the system to identify the activity.
    public static let activityIdentifier = "com.akplayer.shareplay.activity"

    /// Metadata describing the media activity displayed in FaceTime UI and Control Center.
    public var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = title
        if let subtitle {
            meta.subtitle = subtitle
        }
        meta.type = activityType.systemActivityType
        if let fallbackURL {
            meta.fallbackURL = fallbackURL
        }
        return meta
    }

    // MARK: - Properties

    /// Unique identifier for this activity instance.
    public let id: UUID

    /// The remote or local media URL being synchronized.
    public let url: URL

    /// The title of the shared media item.
    public let title: String

    /// Optional subtitle or artist description of the media item.
    public let subtitle: String?

    /// Optional fallback web URL for participants without the app installed.
    public let fallbackURL: URL?

    /// The activity classification type (`.watchTogether`, `.listenTogether`, `.generic`).
    public let activityType: AKGroupActivityType

    /// Whether the media is a live broadcast stream.
    public let isLive: Bool

    /// Optional custom metadata dictionary passed between participants.
    public let customAttributes: [String: String]?

    // MARK: - Initialization

    /// Initializes a new SharePlay media group activity.
    /// - Parameters:
    ///   - id: Unique activity identifier. Defaults to a new UUID.
    ///   - url: The media URL destination.
    ///   - title: The media title.
    ///   - subtitle: Optional subtitle or artist information.
    ///   - fallbackURL: Optional fallback URL for non-app users.
    ///   - activityType: Group activity classification. Defaults to `.generic`.
    ///   - isLive: Whether the media is a live stream. Defaults to `false`.
    ///   - customAttributes: Optional custom string attributes.
    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        subtitle: String? = nil,
        fallbackURL: URL? = nil,
        activityType: AKGroupActivityType = .generic,
        isLive: Bool = false,
        customAttributes: [String: String]? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.fallbackURL = fallbackURL
        self.activityType = activityType
        self.isLive = isLive
        self.customAttributes = customAttributes
    }

    /// Initializes a SharePlay media group activity from an `AKPlayable` item.
    /// - Parameters:
    ///   - media: The playable media item.
    ///   - fallbackURL: Optional fallback URL.
    ///   - customAttributes: Optional custom key-value pairs.
    public init(
        from media: any AKPlayable,
        fallbackURL: URL? = nil,
        customAttributes: [String: String]? = nil
    ) {
        self.id = UUID()
        self.url = media.url
        self.title = media.staticMetadata?.title ?? media.url.deletingPathExtension()
            .lastPathComponent
        self.subtitle = media.staticMetadata?.artist ?? media.staticMetadata?.albumArtist
        self.fallbackURL = fallbackURL
        self.isLive = media.isLive()
        self.customAttributes = customAttributes

        switch media.type {
        case .clip:
            self.activityType = .watchTogether
        case .stream:
            self.activityType = .watchTogether
        }
    }
}
