//
//   AKPlayable.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

/*
 https://developer.apple.com/documentation/avfoundation/avurlasset
 */

import AVFoundation
import Foundation
import MediaPlayer

// MARK: - AKPlayable Protocol

/// A protocol representing a playable media item with metadata and playback configuration.
public protocol AKPlayable: AnyObject, Equatable, CustomStringConvertible, Sendable {
    /// The media asset's destination URL (file path or remote stream).
    var url: URL { get }

    /// The type classification of the media item (e.g., audio, video, stream).
    var type: AKMediaType { get }

    /// Optional custom pre-configured asset (e.g., for FairPlay DRM or custom ResourceLoader).
    var customAsset: AVURLAsset? { get }

    /// Optional custom pre-configured player item (e.g., for custom Video Composition).
    var customPlayerItem: AVPlayerItem? { get }

    /// The loaded URL asset generated from the media item.
    var asset: AVURLAsset? { get }

    /// The instantiated player item constructed from the asset.
    var playerItem: AVPlayerItem? { get }

    /// Optional dictionary options used when initializing the underlying `AVURLAsset`.
    var assetInitializationOptions: [String: Any]? { get }

    /// Optional asset properties to automatically load asynchronously prior to playback.
    var automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? { get }

    /// Optional static Now Playing metadata associated with the media.
    var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? { get }
    
    /// The cache policy for this media item.
    var cachePolicy: AKMediaCachePolicy { get }
    
    /// Optional cache manager instance.
    var cacheManager: (any AKMediaCacheProtocol)? { get }
    
    /// The live edge threshold in seconds. Defaults to `4.0` seconds for live streams, and `nil` for non-live media.
    var liveEdgeThreshold: TimeInterval? { get }

    /// Indicates whether the media item is a live stream.
    func isLive() -> Bool

    /// Updates the static Now Playing metadata for the media item.
    func updateMetadata(_ staticMetadata: any AKNowPlayableStaticMetadataProtocol)
}

// MARK: - Default Property Implementations

public extension AKPlayable {
    var customAsset: AVURLAsset? { nil }
    var customPlayerItem: AVPlayerItem? { nil }
    var assetInitializationOptions: [String: Any]? { nil }
    var automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? { nil }
    var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? { nil }
    var cachePolicy: AKMediaCachePolicy { .useCacheIfAvailable }
    var cacheManager: (any AKMediaCacheProtocol)? { nil }
    var liveEdgeThreshold: TimeInterval? {
        isLive() ? 4.0 : nil
    }
}

// MARK: - Equatable Implementation

public extension AKPlayable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs === rhs || (lhs.url == rhs.url && lhs.type == rhs.type)
    }

    func isEqual(to other: any AKPlayable) -> Bool {
        self === other || (url == other.url && type == other.type)
    }
}

// MARK: - CustomStringConvertible Defaults

public extension AKPlayable {
    var description: String {
        "url: \(url.description) | type: \(type.description)"
    }
}

// MARK: - Live Stream Helpers

public extension AKPlayable {
    func isLive() -> Bool {
        if case let AKMediaType.stream(isLive) = type, isLive {
            return true
        }
        return playerItem?.duration.isIndefinite == true
    }
}

// MARK: - Network and Storage Helpers

public extension AKPlayable {
    func isLocal() -> Bool {
        url.isFileURL
    }

    func isOverNetwork() -> Bool {
        guard !url.isFileURL else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "rtsp", "rtmp"].contains(scheme)
    }
}
