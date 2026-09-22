//
//   AKFairPlayConfiguration.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKFairPlayConfiguration

/// Configuration settings, endpoint URLs, HTTP headers, and custom lifecycle closures
/// for FairPlay Streaming (FPS) DRM certificate loading and license key exchanges.
public struct AKFairPlayConfiguration: @unchecked Sendable {
    // MARK: - Properties

    /// Remote URL hosting the FairPlay Application Certificate (e.g. `cert.cer` or `cert.der`).
    public var certificateURL: URL?

    /// Preloaded FairPlay Application Certificate data, if already available locally or cached.
    public var certificateData: Data?

    /// Remote Key Security Module (KSM) license server URL that processes SPC data and returns CKC
    /// licenses.
    public var licenseURL: URL?

    /// Custom HTTP header fields (such as Bearer tokens or tenant IDs) attached to license
    /// requests.
    public var licenseHeaders: [String: String]

    /// Optional explicit content identifier string overriding automatic extraction from `skd://`
    /// URIs.
    public var contentIdentifier: String?

    /// A Boolean value indicating whether persistable content keys for offline playback are
    /// enabled.
    public var offlineKeysEnabled: Bool

    /// Local file directory URL used to store and load persistable offline content keys.
    public var offlineKeyStorageURL: URL?

    // MARK: - Custom Async Closures

    /// Custom closure to fetch the Application Certificate data from a custom source or proxy.
    public var fetchCertificate: (@Sendable (URL) async throws -> Data)?

    /// Custom closure to parse the content identifier data from the `skd://` URI.
    public var extractContentIdentifier: (@Sendable (URL) throws -> Data)?

    /// Custom closure to request the CKC license data from the KSM license server.
    /// Parameters: `(spcData, assetIdData, assetIdString)` -> `ckcData`
    public var fetchLicenseKey: (@Sendable (
        _ spcData: Data,
        _ assetIdData: Data,
        _ assetIdString: String
    ) async throws -> Data)?

    /// Custom closure to persist an offline content key for an asset identifier.
    public var persistOfflineKey: (@Sendable (_ assetId: String, _ keyData: Data) async throws
        -> Void)?

    /// Custom closure to load a previously persisted offline content key for an asset identifier.
    public var loadOfflineKey: (@Sendable (_ assetId: String) async throws -> Data?)?

    // MARK: - Initialization

    /// Initializes a FairPlay configuration with certificate and license server settings.
    /// - Parameters:
    ///   - certificateURL: Remote URL hosting the FairPlay application certificate.
    ///   - certificateData: Preloaded application certificate data.
    ///   - licenseURL: Key Security Module (KSM) license server URL.
    ///   - licenseHeaders: Custom HTTP headers for license requests (e.g. authorization tokens).
    ///   - contentIdentifier: Optional explicit content identifier override.
    ///   - offlineKeysEnabled: Whether persistable keys for offline playback are enabled.
    ///   - offlineKeyStorageURL: Local directory URL for persistable key storage.
    ///   - fetchCertificate: Optional custom certificate fetch closure.
    ///   - extractContentIdentifier: Optional custom content ID extractor closure.
    ///   - fetchLicenseKey: Optional custom license fetch closure.
    ///   - persistOfflineKey: Optional custom offline key persister closure.
    ///   - loadOfflineKey: Optional custom offline key loader closure.
    public init(
        certificateURL: URL? = nil,
        certificateData: Data? = nil,
        licenseURL: URL? = nil,
        licenseHeaders: [String: String] = [:],
        contentIdentifier: String? = nil,
        offlineKeysEnabled: Bool = false,
        offlineKeyStorageURL: URL? = nil,
        fetchCertificate: (@Sendable (URL) async throws -> Data)? = nil,
        extractContentIdentifier: (@Sendable (URL) throws -> Data)? = nil,
        fetchLicenseKey: (@Sendable (
            _ spcData: Data,
            _ assetIdData: Data,
            _ assetIdString: String
        ) async throws -> Data)? = nil,
        persistOfflineKey: (@Sendable (_ assetId: String, _ keyData: Data) async throws -> Void)? =
            nil,
        loadOfflineKey: (@Sendable (_ assetId: String) async throws -> Data?)? = nil
    ) {
        self.certificateURL = certificateURL
        self.certificateData = certificateData
        self.licenseURL = licenseURL
        self.licenseHeaders = licenseHeaders
        self.contentIdentifier = contentIdentifier
        self.offlineKeysEnabled = offlineKeysEnabled
        self.offlineKeyStorageURL = offlineKeyStorageURL
        self.fetchCertificate = fetchCertificate
        self.extractContentIdentifier = extractContentIdentifier
        self.fetchLicenseKey = fetchLicenseKey
        self.persistOfflineKey = persistOfflineKey
        self.loadOfflineKey = loadOfflineKey
    }
}
