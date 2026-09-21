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

public protocol AKPlayerItemInitServiceProtocol: Sendable {
    /// Creates and returns an AVURLAsset based on media configuration / cache / custom asset
    func createAsset(for media: any AKPlayable) async -> AVURLAsset
    
    /// Validates asynchronous playability and DRM protection keys
    func validatePlayability(of asset: AVURLAsset) async throws
    
    /// Constructs and returns an AVPlayerItem configured with automatically loaded keys
    func createPlayerItem(from asset: AVURLAsset, for media: any AKPlayable) -> AVPlayerItem
}

public final class AKPlayerItemInitService: AKPlayerItemInitServiceProtocol {
    
    // Explicit public initializer for framework accessibility
    public init() {}
    
    public func createAsset(for media: any AKPlayable) async -> AVURLAsset {
        var asset: AVURLAsset
        if let custom = media.customAsset {
            asset = custom
        } else if let customItem = media.customPlayerItem,
                  let itemAsset = await MainActor.run(body: { customItem.asset as? AVURLAsset }) {
            asset = itemAsset
        } else if media.cachePolicy == .useCacheIfAvailable,
                  let cache = media.cacheManager,
                  let cachedAsset = await cache.asset(for: media) {
            asset = cachedAsset
        } else {
            asset = AVURLAsset(
                url: media.url,
                options: media.assetInitializationOptions
            )
        }
        return asset
    }
    
    public func validatePlayability(of asset: AVURLAsset) async throws {
        do {
            let (isPlayable, hasProtectedContent) = try await asset.load(.isPlayable, .hasProtectedContent)
            
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
                throw AKPlayerError.assetLoadingFailed(reason: .notConnectedToInternet(error: error))
            default:
                throw AKPlayerError.assetLoadingFailed(reason: .propertyKeyLoadingFailed(error: error))
            }
        } catch let error as AKPlayerError {
            throw error
        } catch {
            throw AKPlayerError.assetLoadingFailed(reason: .propertyKeyLoadingFailed(error: error))
        }
    }
    
    public func createPlayerItem(from asset: AVURLAsset, for media: any AKPlayable) -> AVPlayerItem {
        let item: AVPlayerItem = if let customItem = media.customPlayerItem {
            customItem
        } else if let keys = media.automaticallyLoadedAssetKeys {
            AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: keys)
        } else {
            AVPlayerItem(asset: asset)
        }
        
        return item
    }
}
