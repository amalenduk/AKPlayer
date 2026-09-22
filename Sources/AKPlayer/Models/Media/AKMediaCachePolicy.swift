//
//   AKMediaCachePolicy.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

/// Defines caching policies applied when loading media assets.
public enum AKMediaCachePolicy: Sendable {
    /// Follows the player's cache manager settings.
    case useCacheIfAvailable
    /// Ignores disk cache and always streams directly from remote URL.
    case ignoreCache
}
