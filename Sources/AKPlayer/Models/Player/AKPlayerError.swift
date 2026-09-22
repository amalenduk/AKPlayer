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

    /// Indicates that no media item is loaded or available to play.
    case noItemToPlay
    /// Indicates that the current player item has not yet reached the `.readyToPlay` status.
    case playerItemNotReady
    /// Indicates that the media item failed to play to completion, typically due to network dropouts.
    case itemFailedToPlayToEndTime
    /// Indicates that the underlying player failed into an unrecoverable state.
    case playerCanNoLongerPlay(error: Error?)

    /// Indicates that an underlying `AVAsset` failed to load with the specified failure reason.
    case assetLoadingFailed(reason: AssetLoadingFailureReason)
    /// Indicates that an `AVPlayerItem` failed to load or initialize with the specified failure reason.
    case playerItemLoadingFailed(reason: PlayerItemLoadingFailureReason)
    /// Indicates that an `AVPlayerItem` encountered a runtime failure during playback.
    case playerItemFailedToPlay(reason: PlayerItemFailedToPlayReason)

    /// Indicates that configuring or activating the audio session failed.
    case audioSessionFailure(reason: AudioSessionFailureReason)
    /// Indicates that activating the system Now Playing session failed.
    case nowPlayingSessionFailure
    /// Indicates that selecting or inspecting audio/subtitle/closed-caption tracks failed.
    case trackSelectionFailure(reason: TrackSelectionFailureReason)

    // MARK: - Sub-Reason Enumerations

    /// Reasons for audio session configuration failures.
    public enum AudioSessionFailureReason: @unchecked Sendable {
        /// Audio session activation failed.
        case failedToActivate(error: Error)
        /// Audio session deactivation failed.
        case failedToDeactivate(error: Error)
        /// Setting the audio session category, mode, or options failed.
        case failedToSetCategory(error: Error)
    }

    /// Reasons for asset loading failures.
    public enum AssetLoadingFailureReason: @unchecked Sendable {
        /// The asset format or container is not playable.
        case notPlayable
        /// The asset contains DRM-protected content that cannot be authorized or played.
        case protectedContent
        /// Asynchronous loading of asset property keys failed.
        case propertyKeyLoadingFailed(error: Error)
        /// Asset loading failed due to lack of network connectivity.
        case notConnectedToInternet(error: Error)
        /// Initializing the underlying asset failed.
        case assetInitializationFailed(error: Error)
    }

    /// Reasons for player item loading failures.
    public enum PlayerItemLoadingFailureReason: @unchecked Sendable {
        /// The player item status transitioned to `.failed`.
        case statusLoadingFailed(error: Error)
        /// The underlying asset was invalid or could not produce a playable item.
        case invalidAsset
    }

    /// Reasons for player item execution failures.
    public enum PlayerItemFailedToPlayReason: @unchecked Sendable {
        /// The player item failed to play to its end time.
        case failedToPlayToEndTime(error: Error?)
    }

    /// Reasons for track selection and media group failures.
    public enum TrackSelectionFailureReason: @unchecked Sendable {
        /// Attempted to deselect all tracks in a group where empty selection is forbidden.
        case emptySelectionForbidden(AKTrackType)
        /// Loading the media selection group for the track type failed.
        case groupLoadFailed(AKTrackType, error: Error?)
    }
}

// MARK: - LocalizedError Conformances

extension AKPlayerError.AudioSessionFailureReason: LocalizedError {
    /// A localized message describing what error occurred.
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

    /// A localized description of the error.
    public var errorDescription: String? {
        localizedDescription
    }

    /// A localized explanation of the reason for the failure.
    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError.PlayerItemLoadingFailureReason: LocalizedError {
    /// A localized message describing what error occurred.
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

    /// A localized description of the error.
    public var errorDescription: String? {
        localizedDescription
    }

    /// A localized explanation of the reason for the failure.
    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError.PlayerItemFailedToPlayReason: LocalizedError {
    /// A localized message describing what error occurred.
    public var localizedDescription: String {
        switch self {
        case let .failedToPlayToEndTime(error):
            NSLocalizedString(
                "AVPlayerItem failed to play to end time with error: \(error?.localizedDescription)",
                comment: "Item failed to finish playing"
            )
        }
    }

    /// A localized description of the error.
    public var errorDescription: String? {
        localizedDescription
    }

    /// A localized explanation of the reason for the failure.
    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError.AssetLoadingFailureReason: LocalizedError {
    /// A localized message describing what error occurred.
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

    /// A localized description of the error.
    public var errorDescription: String? {
        localizedDescription
    }

    /// A localized explanation of the reason for the failure.
    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError.TrackSelectionFailureReason: LocalizedError {
    /// A localized message describing what error occurred.
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

    /// A localized description of the error.
    public var errorDescription: String? {
        localizedDescription
    }

    /// A localized explanation of the reason for the failure.
    public var failureReason: String? {
        localizedDescription
    }
}

extension AKPlayerError: LocalizedError {
    /// A localized message describing what error occurred.
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

    /// A localized description of the error.
    public var errorDescription: String? {
        localizedDescription
    }

    /// A localized explanation of the reason for the failure.
    public var failureReason: String? {
        localizedDescription
    }
}

// MARK: - Underlying Errors

public extension AKPlayerError.AudioSessionFailureReason {
    /// The underlying system error that caused the audio session failure, if applicable.
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
    /// The underlying system error that caused the asset loading failure, if applicable.
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
    /// The underlying system error that caused the player item loading failure, if applicable.
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
    /// The underlying system error that caused the playback failure, if applicable.
    var underlyingError: Error? {
        switch self {
        case let .failedToPlayToEndTime(error):
            error
        }
    }
}

public extension AKPlayerError.TrackSelectionFailureReason {
    /// The underlying system error that caused the track selection failure, if applicable.
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
    /// The underlying system error associated with this error, if applicable.
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

/// Returns a boolean value indicating whether two player errors are equal.
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
    /// Returns a boolean value indicating whether two audio session failure reasons are equal.
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
    /// Returns a boolean value indicating whether two asset loading failure reasons are equal.
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
    /// Returns a boolean value indicating whether two player item loading failure reasons are equal.
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
    /// Returns a boolean value indicating whether two playback failure reasons are equal.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.failedToPlayToEndTime, .failedToPlayToEndTime):
            true
        }
    }
}

extension AKPlayerError.TrackSelectionFailureReason: Equatable {
    /// Returns a boolean value indicating whether two track selection failure reasons are equal.
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
