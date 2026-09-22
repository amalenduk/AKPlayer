//
//   AKMedia.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKMedia

/// A thread-safe concrete representation of a playable media item.
public class AKMedia: NSObject, AKPlayable, @unchecked Sendable {
    // MARK: - Properties

    /// The media asset's destination URL (file path or remote stream).
    public let url: URL

    /// The type classification of the media item (e.g., audio, video, stream).
    public let type: AKMediaType

    /// Optional custom pre-configured asset (e.g., for FairPlay DRM or custom ResourceLoader).
    public let customAsset: AVURLAsset?

    /// Optional custom pre-configured player item (e.g., for custom Video Composition).
    public let customPlayerItem: AVPlayerItem?

    /// Optional dictionary options used when initializing the underlying `AVURLAsset`.
    public let assetInitializationOptions: [String: Any]?

    /// Optional asset properties to automatically load asynchronously prior to playback.
    public let automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]?

    /// Optional static Now Playing metadata associated with the media.
    public private(set) var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)?

    /// The cache policy for this media item.
    public var cachePolicy: AKMediaCachePolicy = .useCacheIfAvailable

    /// Optional cache manager instance.
    public var cacheManager: (any AKMediaCacheProtocol)?

    private var _liveEdgeThreshold: TimeInterval?

    /// The live edge threshold in seconds. Returns a custom value if assigned, or defaults to `4.0`
    /// seconds for live streams, and `nil` for non-live media.
    public var liveEdgeThreshold: TimeInterval? {
        get { _liveEdgeThreshold ?? (isLive() ? 4.0 : nil) }
        set { _liveEdgeThreshold = newValue }
    }

    // MARK: - Initialization

    /// Initializes a new media item with playback properties and optional metadata.
    /// - Parameters:
    ///   - url: The media URL destination.
    ///   - type: The media type classification.
    ///   - customAsset: Optional custom pre-configured asset.
    ///   - customPlayerItem: Optional custom pre-configured player item.
    ///   - assetInitializationOptions: Options dictionary for initializing `AVURLAsset`.
    ///   - automaticallyLoadedAssetKeys: Asset property keys to pre-load.
    ///   - staticMetadata: Static Now Playing metadata.
    ///   - cachePolicy: Cache policy for this media item.
    ///   - cacheManager: Optional custom cache manager instance.
    ///   - liveEdgeThreshold: Optional custom live edge threshold in seconds.
    public init(
        url: URL,
        type: AKMediaType,
        customAsset: AVURLAsset? = nil,
        customPlayerItem: AVPlayerItem? = nil,
        assetInitializationOptions: [String: Any]? = nil,
        automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? = nil,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil,
        cachePolicy: AKMediaCachePolicy = .useCacheIfAvailable,
        cacheManager: (any AKMediaCacheProtocol)? = nil,
        liveEdgeThreshold: TimeInterval? = nil
    ) {
        self.url = url
        self.type = type
        self.customAsset = customAsset
        self.customPlayerItem = customPlayerItem
        self.assetInitializationOptions = assetInitializationOptions
        self.automaticallyLoadedAssetKeys = automaticallyLoadedAssetKeys
        self.staticMetadata = staticMetadata
        self.cachePolicy = cachePolicy
        self.cacheManager = cacheManager
        _liveEdgeThreshold = liveEdgeThreshold
    }

    /// Initializes a media item with a pre-configured `AVURLAsset` (e.g. for FairPlay DRM, custom
    /// headers, or `AVAssetResourceLoaderDelegate`).
    /// - Parameters:
    ///   - asset: The custom pre-configured `AVURLAsset`.
    ///   - type: The media type classification. Defaults to `.clip`.
    ///   - automaticallyLoadedAssetKeys: Optional asset property keys to pre-load. Defaults to
    /// `nil`.
    ///   - staticMetadata: Optional static Now Playing metadata. Defaults to `nil`.
    ///   - cachePolicy: Cache policy for this media item. Defaults to `.useCacheIfAvailable`.
    ///   - cacheManager: Optional custom cache manager instance. Defaults to `nil`.
    ///   - liveEdgeThreshold: Optional custom live edge threshold in seconds. Defaults to `nil`.
    public init(
        asset: AVURLAsset,
        type: AKMediaType = .clip,
        automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? = nil,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil,
        cachePolicy: AKMediaCachePolicy = .useCacheIfAvailable,
        cacheManager: (any AKMediaCacheProtocol)? = nil,
        liveEdgeThreshold: TimeInterval? = nil
    ) {
        url = asset.url
        self.type = type
        customAsset = asset
        customPlayerItem = nil
        assetInitializationOptions = nil
        self.automaticallyLoadedAssetKeys = automaticallyLoadedAssetKeys
        self.staticMetadata = staticMetadata
        self.cachePolicy = cachePolicy
        self.cacheManager = cacheManager
        _liveEdgeThreshold = liveEdgeThreshold
    }

    /// Initializes a media item with a pre-configured `AVPlayerItem` (e.g. for custom video
    /// compositions or audio mixes).
    ///
    /// Marked `@MainActor` because Apple's `AVPlayerItem.asset` property is isolated to
    /// `@MainActor` in Swift 6.
    /// - Parameters:
    ///   - playerItem: The custom pre-configured `AVPlayerItem`.
    ///   - type: The media type classification. Defaults to `.clip`.
    ///   - staticMetadata: Optional static Now Playing metadata. Defaults to `nil`.
    ///   - cachePolicy: Cache policy for this media item. Defaults to `.useCacheIfAvailable`.
    ///   - cacheManager: Optional custom cache manager instance. Defaults to `nil`.
    ///   - liveEdgeThreshold: Optional custom live edge threshold in seconds. Defaults to `nil`.
    @MainActor
    public init(
        playerItem: AVPlayerItem,
        type: AKMediaType = .clip,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil,
        cachePolicy: AKMediaCachePolicy = .useCacheIfAvailable,
        cacheManager: (any AKMediaCacheProtocol)? = nil,
        liveEdgeThreshold: TimeInterval? = nil
    ) {
        let asset = playerItem.asset as? AVURLAsset
        url = asset?.url ?? URL(fileURLWithPath: "")
        self.type = type
        customAsset = asset
        customPlayerItem = playerItem
        assetInitializationOptions = nil
        automaticallyLoadedAssetKeys = nil
        self.staticMetadata = staticMetadata
        self.cachePolicy = cachePolicy
        self.cacheManager = cacheManager
        _liveEdgeThreshold = liveEdgeThreshold
    }

    deinit {
        AKLogger.logDeinit(String(describing: Self.self), pointer: Unmanaged.passUnretained(self))
    }

    // MARK: - Public Methods

    /// Updates the static Now Playing metadata for the media item.
    /// - Parameter staticMetadata: The new metadata payload conforming to
    /// `AKNowPlayableStaticMetadataProtocol`.
    public func updateMetadata(_ staticMetadata: any AKNowPlayableStaticMetadataProtocol) {
        self.staticMetadata = staticMetadata
    }
}
