//
//  AKMediaCacheProtocol.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 07/09/26.
//

import AVFoundation

// MARK: - AKMediaCacheProtocol

public protocol AKMediaCacheProtocol: Sendable {
    /// Checks if a playable item is already cached on disk.
    func isCached(for media: any AKPlayable) -> Bool
    
    /// Retrieves an cached AVURLAsset or returns nil if not cached.
    func asset(for media: any AKPlayable) async -> AVURLAsset?
    
    /// Prefetches and caches media ahead of playback.
    func prefetch(media: any AKPlayable) async throws
    
    /// Clears cached media files.
    func clearCache() async throws
}
