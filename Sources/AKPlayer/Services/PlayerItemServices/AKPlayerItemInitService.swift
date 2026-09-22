//
//   AKPlayerItemInitService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

/*
 https://developer.apple.com/documentation/avfoundation/avasynchronouskeyvalueloading
 https://developer.apple.com/documentation/avfoundation/avasset
 https://developer.apple.com/documentation/avfoundation/avplayeritem
 https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/MediaPlaybackGuide/Contents/Resources/en.lproj/ExploringAVFoundation/ExploringAVFoundation.html
 */

import AVFoundation

/// Protocol defining requirements for creating and validating AVPlayerItem and AVURLAsset
/// instances.
public protocol AKPlayerItemInitServiceProtocol: Sendable {
    /// Creates and returns an AVURLAsset based on media configuration / cache / custom asset
    func createAsset(for media: any AKPlayable) async -> AVURLAsset

    /// Validates asynchronous playability and DRM protection keys
    func validatePlayability(of asset: AVURLAsset) async throws

    /// Constructs and returns an AVPlayerItem configured with automatically loaded keys
    func createPlayerItem(from asset: AVURLAsset, for media: any AKPlayable) -> AVPlayerItem
}

/// Service managing the creation, validation, and initialization of `AVURLAsset` and `AVPlayerItem`
/// instances.
public final class AKPlayerItemInitService: AKPlayerItemInitServiceProtocol {
    /// Initializes a new instance of the player item initialization service.
    public init() {}

    /// Creates and returns an `AVURLAsset` based on media configuration, cache, or custom asset.
    /// - Parameter media: The media item for which to create the asset.
    /// - Returns: A configured `AVURLAsset`.
    public func createAsset(for media: any AKPlayable) async -> AVURLAsset {
        if let custom = media.customAsset {
            custom
        } else if let customItem = media.customPlayerItem,
                  let itemAsset = await MainActor.run(body: { customItem.asset as? AVURLAsset })
        {
            itemAsset
        } else if media.cachePolicy == .useCacheIfAvailable,
                  let cache = media.cacheManager,
                  let cachedAsset = await cache.asset(for: media)
        {
            cachedAsset
        } else {
            AVURLAsset(
                url: media.url,
                options: media.assetInitializationOptions
            )
        }
    }

    /// Validates asynchronous playability and DRM protection keys on the given asset.
    /// - Parameter asset: The `AVURLAsset` to validate.
    public func validatePlayability(of asset: AVURLAsset) async throws {
        do {
            let (isPlayable, hasProtectedContent) = try await asset.load(
                .isPlayable,
                .hasProtectedContent
            )

            try Task.checkCancellation()

            guard isPlayable else {
                throw AKPlayerError.assetLoadingFailed(reason: .notPlayable)
            }
            guard !hasProtectedContent else {
                throw AKPlayerError.assetLoadingFailed(reason: .protectedContent)
            }

        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw CancellationError()
            case .notConnectedToInternet:
                throw AKPlayerError
                    .assetLoadingFailed(reason: .notConnectedToInternet(error: error))
            default:
                throw AKPlayerError
                    .assetLoadingFailed(reason: .propertyKeyLoadingFailed(error: error))
            }
        } catch let error as AKPlayerError {
            throw error
        } catch {
            throw AKPlayerError.assetLoadingFailed(reason: .propertyKeyLoadingFailed(error: error))
        }
    }

    /// Constructs and returns an `AVPlayerItem` configured with automatically loaded keys for the
    /// playable item.
    /// - Parameters:
    ///   - asset: The underlying `AVURLAsset`.
    ///   - media: The playable media item.
    /// - Returns: An instantiated `AVPlayerItem`.
    public func createPlayerItem(
        from asset: AVURLAsset,
        for media: any AKPlayable
    ) -> AVPlayerItem {
        if let customItem = media.customPlayerItem {
            customItem
        } else if let keys = media.automaticallyLoadedAssetKeys {
            AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: keys)
        } else {
            AVPlayerItem(asset: asset)
        }
    }
}
