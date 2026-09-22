//
//  AKMediaCachePolicy.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 07/09/26.
//

/// Defines caching policies applied when loading media assets.
public enum AKMediaCachePolicy: Sendable {
    /// Follows the player's cache manager settings.
    case useCacheIfAvailable
    /// Ignores disk cache and always streams directly from remote URL.
    case ignoreCache
}

