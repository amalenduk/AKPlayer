//
//   AKMediaCacheProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKMediaCacheProtocol

/// Protocol defining disk caching and prefetching capabilities for media items.
public protocol AKMediaCacheProtocol: Sendable {
    /// Checks if a playable media item is already cached on disk.
    /// - Parameter media: The playable media item to check.
    /// - Returns: `true` if the media is cached; otherwise, `false`.
    func isCached(for media: any AKPlayable) -> Bool

    /// Retrieves a cached `AVURLAsset` for the given media item, or returns `nil` if not cached.
    /// - Parameter media: The playable media item to retrieve.
    /// - Returns: A cached `AVURLAsset` instance, or `nil` if unavailable.
    func asset(for media: any AKPlayable) async -> AVURLAsset?

    /// Prefetches and caches media asset data ahead of playback.
    /// - Parameter media: The playable media item to prefetch.
    /// - Throws: An error if prefetching fails.
    func prefetch(media: any AKPlayable) async throws

    /// Clears all cached media files from local disk storage.
    /// - Throws: An error if cache clearing fails.
    func clearCache() async throws
}
