//
//   AKPlayableState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKPlayableState

/// Represents the lifecycle loading state of a playable media item.
public enum AKPlayableState: Int, CustomStringConvertible, CaseIterable, Equatable, Sendable {
    /// Initial uninitialized state before asset loading begins.
    case idle = 0

    /// The underlying `AVURLAsset` has been successfully created and validated.
    case assetLoaded

    /// The `AVPlayerItem` has been instantiated from the media asset.
    case playerItemLoaded

    /// The player item status has transitioned to ready for playback.
    case readyToPlay

    /// Media initialization or asset loading encountered a fatal error.
    case failed

    /// A textual description of the state.
    public var description: String {
        switch self {
        case .idle: "Idle"
        case .assetLoaded: "Asset Loaded"
        case .playerItemLoaded: "Player Item Loaded"
        case .readyToPlay: "Ready To Play"
        case .failed: "Failed"
        }
    }

    /// Returns `true` if the state is ``idle``.
    public var isIdle: Bool {
        self == .idle
    }

    /// Returns `true` if the state is ``assetLoaded``.
    public var isAssetLoaded: Bool {
        self == .assetLoaded
    }

    /// Returns `true` if the state is ``playerItemLoaded``.
    public var isPlayerItemLoaded: Bool {
        self == .playerItemLoaded
    }

    /// Returns `true` if the state is ``readyToPlay``.
    public var isReadyToPlay: Bool {
        self == .readyToPlay
    }

    /// Returns `true` if the state is ``failed``.
    public var isFailed: Bool {
        self == .failed
    }
}
