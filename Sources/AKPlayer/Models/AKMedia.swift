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
    
    @MainActor
    public var asset: AVURLAsset? {
        manager.asset ?? customAsset
    }
    
    @MainActor
    public var playerItem: AVPlayerItem? {
        manager.playerItem ?? customPlayerItem
    }
    
    /// Optional dictionary options used when initializing the underlying
    /// `AVURLAsset`.
    public let assetInitializationOptions: [String: Any]?
    
    /// Optional asset properties to automatically load asynchronously prior to
    /// playback.
    public let automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]?
    
    /// Optional static Now Playing metadata associated with the media.
    public private(set) var staticMetadata:
    (
        any AKNowPlayableStaticMetadataProtocol
    )?
    
    public var cachePolicy: AKMediaCachePolicy = .useCacheIfAvailable
    
    // Internal seed inputs passed by the developer
    let customAsset: AVURLAsset?
    let customPlayerItem: AVPlayerItem?
    
    // MARK: - Initialization
    
    /// Initializes a new media item with playback properties and optional
    /// metadata.
    /// - Parameters:
    ///   - url: The media URL destination.
    ///   - type: The media type classification.
    ///   - assetInitializationOptions: Options dictionary for initializing
    /// `AVURLAsset`.
    ///   - automaticallyLoadedAssetKeys: Asset property keys to pre-load.
    ///   - staticMetadata: Static Now Playing metadata.
    public init(
        url: URL,
        type: AKMediaType,
        assetInitializationOptions: [String: Any]? = nil,
        automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? = nil,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil
    ) {
        self.url = url
        self.type = type
        self.assetInitializationOptions = assetInitializationOptions
        self.automaticallyLoadedAssetKeys = automaticallyLoadedAssetKeys
        self.staticMetadata = staticMetadata
        customAsset = nil
        customPlayerItem = nil
    }
    
    /// Custom Asset Initializer (For FairPlay DRM / Custom Headers /
    /// ResourceLoader)
    public init(
        asset: AVURLAsset,
        type: AKMediaType = .clip,
        automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? = nil,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil
    ) {
        url = asset.url
        self.type = type
        assetInitializationOptions = nil
        self.automaticallyLoadedAssetKeys = automaticallyLoadedAssetKeys
        self.staticMetadata = staticMetadata
        customAsset = asset
        customPlayerItem = nil
    }
    
    /// Pre-configured Player Item Initializer (For Video Compositions / Custom
    /// Audio Mix)
    @MainActor
    public init(
        playerItem: AVPlayerItem,
        type: AKMediaType = .clip,
        staticMetadata _: (any AKNowPlayableStaticMetadataProtocol)? = nil
    ) {
        if let asset = playerItem.asset as? AVURLAsset {
            url = asset.url
            customAsset = asset
        } else {
            url = URL(fileURLWithPath: "")
            customAsset = nil
        }
        self.type = type
        assetInitializationOptions = nil
        automaticallyLoadedAssetKeys = nil
        customPlayerItem = playerItem
    }
    
    deinit {
        AKLogger.logDeinit(String(describing: Self.self),
                           pointer: Unmanaged.passUnretained(self))
    }
    
    // MARK: - Public Methods
    
    /// Updates the static Now Playing metadata for the media item.
    /// - Parameter staticMetadata: The new metadata payload conforming to
    /// `AKNowPlayableStaticMetadataProtocol`.
    public func updateMetadata(
        _ staticMetadata: any AKNowPlayableStaticMetadataProtocol
    ) {
        self.staticMetadata = staticMetadata
    }
}
