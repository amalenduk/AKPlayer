//
//   AKPlayerError.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKPlayerError

/// An enumeration representing all potential error states encountered during
/// playback, asset loading, track management, or audio session configuration.
public enum AKPlayerError: Error, Equatable, @unchecked Sendable {
    // MARK: - Cases

    case noItemToPlay
    case playerItemNotReady
    case itemFailedToPlayToEndTime
    case playerCanNoLongerPlay(error: Error?)

    case assetLoadingFailed(reason: AssetLoadingFailureReason)
    case playerItemLoadingFailed(reason: PlayerItemLoadingFailureReason)
    case playerItemFailedToPlay(reason: PlayerItemFailedToPlayReason)

    case audioSessionFailure(reason: AudioSessionFailureReason)
    case nowPlayingSessionFailure
    case trackSelectionFailure(reason: TrackSelectionFailureReason)

    // MARK: - Sub-Reason Enumerations

    /// Reasons for audio session configuration failures.
    public enum AudioSessionFailureReason: @unchecked Sendable {
        case failedToActivate(error: Error)
        case failedToDeactivate(error: Error)
        case failedToSetCategory(error: Error)
    }

    /// Reasons for asset loading failures.
    public enum AssetLoadingFailureReason: @unchecked Sendable {
        case notPlayable
        case protectedContent
        case propertyKeyLoadingFailed(error: Error)
        case notConnectedToInternet(error: Error)
        case assetInitializationFailed(error: Error)
    }

    /// Reasons for player item loading failures.
    public enum PlayerItemLoadingFailureReason: @unchecked Sendable {
        case statusLoadingFailed(error: Error)
        case invalidAsset
    }

    /// Reasons for player item execution failures.
    public enum PlayerItemFailedToPlayReason: @unchecked Sendable {
        case failedToPlayToEndTime(error: Error?)
    }

    /// Reasons for track selection and media group failures.
    public enum TrackSelectionFailureReason: @unchecked Sendable {
        case emptySelectionForbidden(AKTrackType)
        case groupLoadFailed(AKTrackType, error: Error?)
    }
}

// MARK: - LocalizedError Conformances

extension AKPlayerError.AudioSessionFailureReason: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case let .failedToActivate(error):
            NSLocalizedString(
                "Failed to activate audio session with error: \(error.localizedDescription)",
                comment: "Error description for failedToActivate"
            )
        case let .failedToDeactivate(error):
            NSLocalizedString(
                "Failed to deactivate audio session with error: \(error.localizedDescription)",
                comment: "Error description for failedToDeactivate"
            )
        case let .failedToSetCategory(error):
            NSLocalizedString(
                "Failed to set category for audio session with error: \(error.localizedDescription)",
                comment: "Error description for failedToSetCategory"
            )
        }
    }

    public var errorDescription: String? {
        localizedDescription
    }

    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError.PlayerItemLoadingFailureReason: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case let .statusLoadingFailed(error):
            NSLocalizedString(
                "The AVPlayerItem status failed with error: \(error.localizedDescription)",
                comment: "Error when AVPlayerItem status transitions to .failed"
            )
        case .invalidAsset:
            NSLocalizedString(
                "Not a valid asset",
                comment: "Asset provided is invalid"
            )
        }
    }

    public var errorDescription: String? {
        localizedDescription
    }

    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError.PlayerItemFailedToPlayReason: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case let .failedToPlayToEndTime(error):
            NSLocalizedString(
                "AVPlayerItem failed to play to end time with error: \(error?.localizedDescription)",
                comment: "Item failed to finish playing"
            )
        }
    }

    public var errorDescription: String? {
        localizedDescription
    }

    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError.AssetLoadingFailureReason: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case .notPlayable:
            NSLocalizedString(
                "Asset is not playable",
                comment: "The asset cannot be played because it is unsupported or corrupted."
            )
        case .protectedContent:
            NSLocalizedString(
                "Asset has protected content",
                comment: "The asset cannot be played because it is protected by DRM."
            )
        case let .propertyKeyLoadingFailed(error):
            NSLocalizedString(
                "The asset property key failed to load with error: \(error.localizedDescription)",
                comment: "Asset key loading failed"
            )
        case let .notConnectedToInternet(error):
            NSLocalizedString(
                "The asset failed to load due to network connection error: \(error.localizedDescription)",
                comment: "Asset network failure"
            )
        case let .assetInitializationFailed(error):
            NSLocalizedString(
                "The asset initialization failed with error: \(error.localizedDescription)",
                comment: "Asset initialization failed"
            )
        }
    }

    public var errorDescription: String? {
        localizedDescription
    }

    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError.TrackSelectionFailureReason: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case let .emptySelectionForbidden(type):
            return NSLocalizedString(
                "Attempted to clear selection for \(type), but the media content forbids empty selection.",
                comment: "Error description for emptySelectionForbidden"
            )
        case let .groupLoadFailed(type, error):
            let details = error?.localizedDescription ?? "Unknown error"
            return NSLocalizedString(
                "Failed to load media selection group for \(type): \(details)",
                comment: "Error description for groupLoadFailed"
            )
        }
    }

    public var errorDescription: String? {
        localizedDescription
    }

    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case .noItemToPlay:
            return NSLocalizedString(
                "No player item available to play",
                comment: "Current player item is nil"
            )
        case .playerItemNotReady:
            return NSLocalizedString(
                "The player item is not ready for playback",
                comment: "Player item status is not readyToPlay"
            )
        case .itemFailedToPlayToEndTime:
            return NSLocalizedString(
                "Unable to play the item to end, possibly due to network issues",
                comment: "Item failed to reach end time"
            )
        case let .playerCanNoLongerPlay(error):
            let details = error?.localizedDescription ?? "No reason available"
            return NSLocalizedString(
                "Player can no longer play media due to an error: \(details)",
                comment: "Player unrecoverable state"
            )
        case let .assetLoadingFailed(reason):
            return reason.localizedDescription
        case let .playerItemLoadingFailed(reason):
            return reason.localizedDescription
        case let .playerItemFailedToPlay(reason):
            return reason.localizedDescription
        case let .audioSessionFailure(reason):
            return reason.localizedDescription
        case .nowPlayingSessionFailure:
            return NSLocalizedString(
                "Failed to activate Now Playing session",
                comment: "Now Playing session error"
            )
        case let .trackSelectionFailure(reason):
            return reason.localizedDescription
        }
    }

    public var errorDescription: String? {
        localizedDescription
    }

    public var failureReason: String? {
        localizedDescription
    }
}

// MARK: - Underlying Errors

public extension AKPlayerError.AudioSessionFailureReason {
    var underlyingError: Error? {
        switch self {
        case let .failedToActivate(error),
             let .failedToDeactivate(error),
             let .failedToSetCategory(error):
            error
        }
    }
}

public extension AKPlayerError.AssetLoadingFailureReason {
    var underlyingError: Error? {
        switch self {
        case .notPlayable, .protectedContent:
            nil
        case let .propertyKeyLoadingFailed(error),
             let .notConnectedToInternet(error),
             let .assetInitializationFailed(error):
            error
        }
    }
}

public extension AKPlayerError.PlayerItemLoadingFailureReason {
    var underlyingError: Error? {
        switch self {
        case let .statusLoadingFailed(error):
            error
        case .invalidAsset:
            nil
        }
    }
}

public extension AKPlayerError.PlayerItemFailedToPlayReason {
    var underlyingError: Error? {
        switch self {
        case let .failedToPlayToEndTime(error):
            error
        }
    }
}

public extension AKPlayerError.TrackSelectionFailureReason {
    var underlyingError: Error? {
        switch self {
        case .emptySelectionForbidden:
            nil
        case let .groupLoadFailed(_, error):
            error
        }
    }
}

public extension AKPlayerError {
    var underlyingError: Error? {
        switch self {
        case .noItemToPlay, .playerItemNotReady, .itemFailedToPlayToEndTime,
             .nowPlayingSessionFailure:
            nil
        case let .playerCanNoLongerPlay(error):
            error
        case let .assetLoadingFailed(reason):
            reason.underlyingError
        case let .playerItemLoadingFailed(reason):
            reason.underlyingError
        case let .playerItemFailedToPlay(reason):
            reason.underlyingError
        case let .audioSessionFailure(reason):
            reason.underlyingError
        case let .trackSelectionFailure(reason):
            reason.underlyingError
        }
    }
}

// MARK: - Equatable Conformances

public func == (lhs: AKPlayerError, rhs: AKPlayerError) -> Bool {
    switch (lhs, rhs) {
    case (.noItemToPlay, .noItemToPlay),
         (.playerItemNotReady, .playerItemNotReady),
         (.itemFailedToPlayToEndTime, .itemFailedToPlayToEndTime),
         (.nowPlayingSessionFailure, .nowPlayingSessionFailure):
        true

    case (.playerCanNoLongerPlay, .playerCanNoLongerPlay):
        true

    case let (.assetLoadingFailed(lReason), .assetLoadingFailed(rReason)):
        lReason == rReason

    case let (
        .playerItemLoadingFailed(lReason),
        .playerItemLoadingFailed(rReason)
    ):
        lReason == rReason

    case let (
        .playerItemFailedToPlay(lReason),
        .playerItemFailedToPlay(rReason)
    ):
        lReason == rReason

    case let (.audioSessionFailure(lReason), .audioSessionFailure(rReason)):
        lReason == rReason

    case let (.trackSelectionFailure(lReason), .trackSelectionFailure(rReason)):
        lReason == rReason

    default:
        false
    }
}

extension AKPlayerError.AudioSessionFailureReason: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.failedToActivate, .failedToActivate),
             (.failedToDeactivate, .failedToDeactivate),
             (.failedToSetCategory, .failedToSetCategory):
            true
        default:
            false
        }
    }
}

extension AKPlayerError.AssetLoadingFailureReason: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.notPlayable, .notPlayable),
             (.protectedContent, .protectedContent),
             (.propertyKeyLoadingFailed, .propertyKeyLoadingFailed),
             (.notConnectedToInternet, .notConnectedToInternet),
             (.assetInitializationFailed, .assetInitializationFailed):
            true
        default:
            false
        }
    }
}

extension AKPlayerError.PlayerItemLoadingFailureReason: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.statusLoadingFailed, .statusLoadingFailed),
             (.invalidAsset, .invalidAsset):
            true
        default:
            false
        }
    }
}

extension AKPlayerError.PlayerItemFailedToPlayReason: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.failedToPlayToEndTime, .failedToPlayToEndTime):
            true
        }
    }
}

extension AKPlayerError.TrackSelectionFailureReason: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (
            .emptySelectionForbidden(lType),
            .emptySelectionForbidden(rType)
        ):
            lType == rType

        case let (.groupLoadFailed(lType, _), .groupLoadFailed(rType, _)):
            lType == rType

        default:
            false
        }
    }
}
