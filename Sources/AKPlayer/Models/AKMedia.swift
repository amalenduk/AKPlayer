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
    
    public var asset: AVURLAsset? {
        manager.asset ?? customAsset
    }
    
    public var playerItem: AVPlayerItem? {
        manager.playerItem ?? customPlayerItem
    }
    
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
    
    // Internal seed inputs passed by the developer
    let customAsset: AVURLAsset?
    let customPlayerItem: AVPlayerItem?
    
    // MARK: - Initialization
    
    /// Initializes a new media item with playback properties and optional metadata.
    /// - Parameters:
    ///   - url: The media URL destination.
    ///   - type: The media type classification.
    ///   - assetInitializationOptions: Options dictionary for initializing `AVURLAsset`.
    ///   - automaticallyLoadedAssetKeys: Asset property keys to pre-load.
    ///   - staticMetadata: Static Now Playing metadata.
    ///   - cachePolicy: Cache policy for this media item.
    ///   - cacheManager: Optional custom cache manager instance.
    public init(
        url: URL,
        type: AKMediaType,
        assetInitializationOptions: [String: Any]? = nil,
        automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? = nil,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil,
        cachePolicy: AKMediaCachePolicy = .useCacheIfAvailable,
        cacheManager: (any AKMediaCacheProtocol)? = nil
    ) {
        self.url = url
        self.type = type
        self.assetInitializationOptions = assetInitializationOptions
        self.automaticallyLoadedAssetKeys = automaticallyLoadedAssetKeys
        self.staticMetadata = staticMetadata
        self.cachePolicy = cachePolicy
        self.cacheManager = cacheManager
        self.customAsset = nil
        self.customPlayerItem = nil
    }
    
    /// Custom Asset Initializer (For FairPlay DRM / Custom Headers / ResourceLoader)
    public init(
        asset: AVURLAsset,
        type: AKMediaType = .clip,
        automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? = nil,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil,
        cachePolicy: AKMediaCachePolicy = .useCacheIfAvailable,
        cacheManager: (any AKMediaCacheProtocol)? = nil
    ) {
        self.url = asset.url
        self.type = type
        self.assetInitializationOptions = nil
        self.automaticallyLoadedAssetKeys = automaticallyLoadedAssetKeys
        self.staticMetadata = staticMetadata
        self.cachePolicy = cachePolicy
        self.cacheManager = cacheManager
        self.customAsset = asset
        self.customPlayerItem = nil
    }
    
    /// Pre-configured Player Item Initializer (For Video Compositions / Custom Audio Mix)
    ///
    /// Marked `@MainActor` because Apple's `AVPlayerItem.asset` property is isolated to `@MainActor` in Swift 6.
    @MainActor
    public init(
        playerItem: AVPlayerItem,
        type: AKMediaType = .clip,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil,
        cachePolicy: AKMediaCachePolicy = .useCacheIfAvailable,
        cacheManager: (any AKMediaCacheProtocol)? = nil
    ) {
        if let asset = playerItem.asset as? AVURLAsset {
            self.url = asset.url
            self.customAsset = asset
        } else {
            self.url = URL(fileURLWithPath: "")
            self.customAsset = nil
        }
        self.type = type
        self.assetInitializationOptions = nil
        self.automaticallyLoadedAssetKeys = nil
        self.staticMetadata = staticMetadata
        self.cachePolicy = cachePolicy
        self.cacheManager = cacheManager
        self.customPlayerItem = playerItem
    }
    
    deinit {
        AKLogger.logDeinit(String(describing: Self.self), pointer: Unmanaged.passUnretained(self))
    }
    
    // MARK: - Public Methods
    
    /// Updates the static Now Playing metadata for the media item.
    /// - Parameter staticMetadata: The new metadata payload conforming to `AKNowPlayableStaticMetadataProtocol`.
    public func updateMetadata(_ staticMetadata: any AKNowPlayableStaticMetadataProtocol) {
        self.staticMetadata = staticMetadata
    }
}
