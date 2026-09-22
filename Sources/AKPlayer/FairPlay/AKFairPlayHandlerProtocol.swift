//
//   AKFairPlayHandlerProtocol.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - AKFairPlayHandlerProtocol

/// Protocol defining the interface for FairPlay DRM key session managers.
public protocol AKFairPlayHandlerProtocol: AnyObject, Sendable {
    /// The FairPlay DRM configuration parameters and endpoint settings.
    var configuration: AKFairPlayConfiguration { get }

    /// The underlying `AVContentKeySession` managing FairPlay key requests.
    var contentKeySession: AVContentKeySession { get }

    /// Attaches an `AVURLAsset` as a recipient for FairPlay content keys.
    /// - Parameter asset: The `AVURLAsset` to attach to the key session.
    func attach(to asset: AVURLAsset)

    /// Detaches an `AVURLAsset` from receiving FairPlay content keys.
    /// - Parameter asset: The `AVURLAsset` to detach from the key session.
    func detach(from asset: AVURLAsset)

    /// Explicitly pre-fetches and caches the FairPlay Application Certificate data.
    func preloadCertificate() async throws

    /// Invalidates and removes all active content key recipients, releasing delegate references.
    func invalidate()

    /// Invalidates a persistable content key and generates a server playback context (SPC) to
    /// verify invalidation.
    /// - Parameters:
    ///   - persistableKeyData: The persistable key data to invalidate.
    ///   - options: Optional server playback context options.
    /// - Returns: An optional verification SPC data.
    func invalidatePersistableContentKey(
        _ persistableKeyData: Data,
        options: [AVContentKeySessionServerPlaybackContextOption: Any]?
    ) async throws -> Data?

    /// Invalidates all of the application's persistable content keys and generates a server
    /// playback context (SPC).
    /// - Parameters:
    ///   - appCertData: The Application Certificate data.
    ///   - options: Optional server playback context options.
    /// - Returns: An optional verification SPC data.
    func invalidateAllPersistableContentKeys(
        forApp appCertData: Data,
        options: [AVContentKeySessionServerPlaybackContextOption: Any]?
    ) async throws -> Data?
}
