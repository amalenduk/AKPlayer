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

// MARK: - AKPlayerItemInitServiceProtocol

/// Protocol defining media asset initialization, playability validation, and
/// AVPlayerItem construction routines.
@MainActor
public protocol AKPlayerItemInitServiceProtocol: AnyObject {
    
    /// The loaded URL asset backing the current initialization process.
    var asset: AVURLAsset? { get }
    
    /// The instantiated player item created from the validated asset.
    var playerItem: AVPlayerItem? { get }
    
    // MARK: - Fine-Grained Setup Steps
    
    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    /// - Returns: The newly initialized `AVURLAsset`.
    @discardableResult
    func createAsset() async -> AVURLAsset
    
    /// Asynchronously validates key asset properties (`isPlayable`,
    /// `hasProtectedContent`).
    /// - Throws: `AKPlayerError` if validation fails, or `CancellationError` if
    /// cancelled.
    func validateAssetPlayability() async throws
    
    /// Constructs an `AVPlayerItem` from the initialized `AVURLAsset`.
    /// - Returns: The configured `AVPlayerItem`.
    @discardableResult
    func createPlayerItemFromAsset() -> AVPlayerItem
    
    // MARK: - Unified Conveniences
    
    /// Executes the full initialization pipeline: creates asset, validates
    /// playability, and constructs player item.
    /// - Returns: A fully prepared `AVPlayerItem`.
    /// - Throws: An `AKPlayerError` or `CancellationError` if any pipeline
    /// stage fails.
    @discardableResult
    func preparePlayerItem() async throws -> AVPlayerItem
    
    /// Aborts active asset property loading and cancels pending asynchronous
    /// tasks.
    func abortAssetInitialization()
}

// MARK: - AKPlayerItemInitService

/// Service responsible for asynchronous AVAsset loading, playability checks,
/// and AVPlayerItem instantiation.
@MainActor
public final class AKPlayerItemInitService: AKPlayerItemInitServiceProtocol {
    // MARK: - Properties
    
    /// The target playable media item backing this initialization pipeline.
    private unowned let media: any AKPlayable
    
    /// The loaded URL asset backing the current initialization process.
    public private(set) var asset: AVURLAsset?
    
    /// The instantiated player item created from the validated asset.
    public private(set) var playerItem: AVPlayerItem?
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes an asset initialization service instance for a specific
    /// media item.
    /// - Parameter media: The target playable media context.
    public init(with media: any AKPlayable) {
        self.media = media
    }
    
    deinit {
        // Since asset might be a reference type, cancel loading safely.
        // In Swift 6+, accessing stored properties from deinit requires care,
        // but calling methods on non-isolated or safely captured classes is
        // supported.
        asset?.cancelLoading()
    }
    
    // MARK: - Public Pipeline Methods
    
    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    /// - Returns: The newly initialized `AVURLAsset`.
    @discardableResult
    public func createAsset() async -> AVURLAsset {
        if let custom = media.asset {
            asset = custom
        } else {
            if media.cachePolicy == .useCacheIfAvailable,
               let cache = media.cacheManager,
               let asset = await cache.asset(for: media) {
                self.asset = asset
            } else {
                asset = AVURLAsset(
                    url: media.url,
                    options: media.assetInitializationOptions
                )
            }
        }
        return asset!
    }
    
    /// Asynchronously validates key asset properties (`isPlayable`,
    /// `hasProtectedContent`).
    /// - Throws: `AKPlayerError` if validation fails, or `CancellationError` if
    /// cancelled.
    public func validateAssetPlayability() async throws {
        guard let asset else {
            let error = NSError(
                domain: "AKPlayer",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Asset must be created before validation.",
                ]
            )
            throw
            AKPlayerError
                .assetLoadingFailed(
                    reason: .propertyKeyLoadingFailed(error: error)
                )
        }
        
        do {
            let (isPlayable, hasProtectedContent) = try await asset.load(
                .isPlayable, .hasProtectedContent
            )
            
            try Task.checkCancellation()
            
            guard isPlayable else {
                throw AKPlayerError.assetLoadingFailed(reason: .notPlayable)
            }
            guard !hasProtectedContent else {
                throw
                AKPlayerError
                    .assetLoadingFailed(reason: .protectedContent)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError
                    where error.code == .notConnectedToInternet
        {
            throw
            AKPlayerError
                .assetLoadingFailed(
                    reason: .notConnectedToInternet(error: error)
                )
        } catch let error as AKPlayerError {
            throw error
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw
            AKPlayerError
                .assetLoadingFailed(
                    reason: .propertyKeyLoadingFailed(error: error)
                )
        }
    }
    
    /// Constructs an `AVPlayerItem` from the initialized `AVURLAsset`.
    /// - Returns: The configured `AVPlayerItem`.
    @discardableResult
    public func createPlayerItemFromAsset() -> AVPlayerItem {
        guard let asset = asset ?? media.asset else {
            fatalError(
                "Asset must be created before calling createPlayerItemFromAsset()."
            )
        }
        
        let item: AVPlayerItem =
        if let customItem = media.playerItem {
            customItem
        } else {
            if let keys = media.automaticallyLoadedAssetKeys {
                AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: keys)
            } else {
                AVPlayerItem(asset: asset)
            }
        }
        
        playerItem = item
        return item
    }
    
    // MARK: - Unified Convenience API
    
    /// Executes the full initialization pipeline: creates asset, validates
    /// playability, and constructs player item.
    /// - Returns: A fully prepared `AVPlayerItem`.
    /// - Throws: An `AKPlayerError` or `CancellationError` if any pipeline
    /// stage fails.
    @discardableResult
    public func preparePlayerItem() async throws -> AVPlayerItem {
        await createAsset()
        try await validateAssetPlayability()
        return createPlayerItemFromAsset()
    }
    
    /// Aborts active asset property loading and cancels pending asynchronous
    /// tasks.
    public func abortAssetInitialization() {
        asset?.cancelLoading()
    }
}
