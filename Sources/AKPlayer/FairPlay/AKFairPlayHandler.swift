//
//   AKFairPlayHandler.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import Synchronization

// MARK: - AKFairPlayHandler

/// A built-in `AVContentKeySessionDelegate` helper that streamlines FairPlay Streaming (FPS)
/// DRM certificate loading, Server Playback Context (SPC) generation, and Content Key Context (CKC)
/// license key requests for protected HLS media streams.
public final class AKFairPlayHandler: NSObject, AKFairPlayHandlerProtocol,
    AVContentKeySessionDelegate, @unchecked Sendable
{
    // MARK: - Properties

    /// The FairPlay DRM configuration settings.
    public let configuration: AKFairPlayConfiguration

    /// The underlying `AVContentKeySession` configured with `.fairPlayStreaming`.
    public let contentKeySession: AVContentKeySession

    /// Serial dispatch queue for processing `AVContentKeySessionDelegate` callbacks.
    private let delegateQueue = DispatchQueue(
        label: "com.akplayer.fairplay.delegate",
        qos: .userInitiated
    )

    /// Thread-safe cached application certificate data.
    private let cachedCertificateMutex = Mutex<Data?>(nil)

    /// In-flight certificate loading task to avoid duplicate concurrent network fetches.
    private let certificateTaskMutex = Mutex<Task<Data, Error>?>(nil)

    // MARK: - Initialization

    /// Initializes a FairPlay DRM handler with configuration settings.
    /// - Parameter configuration: The FairPlay DRM configuration parameters.
    public init(configuration: AKFairPlayConfiguration) {
        self.configuration = configuration
        self.contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
        super.init()

        if let preloaded = configuration.certificateData {
            cachedCertificateMutex.withLock { $0 = preloaded }
        }

        self.contentKeySession.setDelegate(self, queue: delegateQueue)
        AKLogger.logInit(self)
    }

    deinit {
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
        for recipient in contentKeySession.contentKeyRecipients {
            contentKeySession.removeContentKeyRecipient(recipient)
        }
        contentKeySession.setDelegate(nil, queue: nil)
    }

    // MARK: - AKFairPlayHandlerProtocol Implementation

    /// Attaches an `AVURLAsset` as a recipient for FairPlay content keys.
    /// - Parameter asset: The `AVURLAsset` to attach.
    public func attach(to asset: AVURLAsset) {
        contentKeySession.addContentKeyRecipient(asset)
    }

    /// Detaches an `AVURLAsset` from receiving FairPlay content keys.
    /// - Parameter asset: The `AVURLAsset` to detach.
    public func detach(from asset: AVURLAsset) {
        contentKeySession.removeContentKeyRecipient(asset)
    }

    /// Explicitly pre-fetches and caches the FairPlay Application Certificate.
    public func preloadCertificate() async throws {
        _ = try await obtainApplicationCertificate()
    }

    /// Invalidates and removes all active content key recipients, releasing delegate references.
    public func invalidate() {
        for recipient in contentKeySession.contentKeyRecipients {
            contentKeySession.removeContentKeyRecipient(recipient)
        }
        contentKeySession.setDelegate(nil, queue: nil)
    }

    /// Invalidates a persistable content key and generates a server playback context (SPC) to
    /// verify invalidation.
    /// - Parameters:
    ///   - persistableKeyData: The persistable key data to invalidate.
    ///   - options: Optional server playback context options.
    /// - Returns: An optional verification SPC data.
    public func invalidatePersistableContentKey(
        _ persistableKeyData: Data,
        options: [AVContentKeySessionServerPlaybackContextOption: Any]? = nil
    ) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            contentKeySession.invalidatePersistableContentKey(
                persistableKeyData,
                options: options
            ) { spcData, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: spcData)
                }
            }
        }
    }

    /// Invalidates all of the application's persistable content keys and generates a server
    /// playback context (SPC).
    /// - Parameters:
    ///   - appCertData: The Application Certificate data.
    ///   - options: Optional server playback context options.
    /// - Returns: An optional verification SPC data.
    public func invalidateAllPersistableContentKeys(
        forApp appCertData: Data,
        options: [AVContentKeySessionServerPlaybackContextOption: Any]? = nil
    ) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            contentKeySession.invalidateAllPersistableContentKeys(
                forApp: appCertData,
                options: options
            ) { spcData, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: spcData)
                }
            }
        }
    }

    // MARK: - AVContentKeySessionDelegate

    /// Handles standard streaming content key requests from AVFoundation.
    public func contentKeySession(
        _: AVContentKeySession,
        didProvide keyRequest: AVContentKeyRequest
    ) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.processStreamingKeyRequest(keyRequest)
            } catch {
                AKLogger.error(
                    "FairPlay key request failed: \(error.localizedDescription)",
                    category: .player
                )
                keyRequest.processContentKeyResponseError(error)
            }
        }
    }

    /// Handles persistable content key requests for offline playback.
    public func contentKeySession(
        _: AVContentKeySession,
        didProvide keyRequest: AVPersistableContentKeyRequest
    ) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.processPersistableKeyRequest(keyRequest)
            } catch {
                AKLogger.error(
                    "FairPlay persistable key request failed: \(error.localizedDescription)",
                    category: .player
                )
                keyRequest.processContentKeyResponseError(error)
            }
        }
    }

    /// Handles content key request failures reported by the system.
    public func contentKeySession(
        _: AVContentKeySession,
        contentKeyRequest keyRequest: AVContentKeyRequest,
        didFailWithError err: Error
    ) {
        AKLogger.error(
            "AVContentKeySession reported error for key request: \(err.localizedDescription)",
            category: .player
        )
        keyRequest.processContentKeyResponseError(err)
    }

    /// Determines whether a failed content key request should be retried.
    public func contentKeySession(
        _: AVContentKeySession,
        shouldRetry _: AVContentKeyRequest,
        reason: AVContentKeyRequest.RetryReason
    ) -> Bool {
        switch reason {
        case .timedOut, .receivedResponseWithExpiredLease:
            true
        default:
            false
        }
    }

    // MARK: - Key Request Processing Pipeline

    /// Executes the full SPC -> KSM -> CKC pipeline for a standard streaming key request.
    /// - Parameter keyRequest: The active content key request.
    private func processStreamingKeyRequest(_ keyRequest: AVContentKeyRequest) async throws {
        // 1. Extract Asset / Content Identifier
        let (assetIdString, assetIdData) = try extractAssetIdentifier(from: keyRequest)

        // 2. Obtain Application Certificate Data
        let appCertData = try await obtainApplicationCertificate()

        // 3. Generate Server Playback Context (SPC) Data
        let spcData: Data
        do {
            spcData = try await keyRequest.makeStreamingContentKeyRequestData(
                forApp: appCertData,
                contentIdentifier: assetIdData
            )
        } catch {
            throw AKFairPlayError.spcGenerationFailed(error.localizedDescription)
        }

        // 4. Request Content Key Context (CKC) from License Server
        let ckcData = try await requestCKCLicense(
            spcData: spcData,
            assetIdData: assetIdData,
            assetIdString: assetIdString
        )

        guard !ckcData.isEmpty else {
            throw AKFairPlayError.invalidCKCData
        }

        // 5. Provide CKC to AVContentKeyRequest
        do {
            let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
            keyRequest.processContentKeyResponse(keyResponse)
        } catch {
            throw AKFairPlayError.keyResponseProcessingFailed(error.localizedDescription)
        }
    }

    /// Executes persistable key loading or generation for offline playback.
    /// - Parameter keyRequest: The active persistable content key request.
    private func processPersistableKeyRequest(
        _ keyRequest: AVPersistableContentKeyRequest
    ) async throws {
        let (assetIdString, assetIdData) = try extractAssetIdentifier(from: keyRequest)

        // 1. Check if offline key is already cached locally
        if let customLoader = configuration.loadOfflineKey {
            if let cachedKey = try await customLoader(assetIdString) {
                let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: cachedKey)
                keyRequest.processContentKeyResponse(keyResponse)
                return
            }
        } else if let storageURL = configuration.offlineKeyStorageURL {
            let fileURL = storageURL.appendingPathComponent("\(assetIdString).key")
            if FileManager.default.fileExists(atPath: fileURL.path),
               let localData = try? Data(contentsOf: fileURL)
            {
                let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: localData)
                keyRequest.processContentKeyResponse(keyResponse)
                return
            }
        }

        // 2. If not stored, generate new persistable key via SPC -> CKC exchange
        let appCertData = try await obtainApplicationCertificate()
        let spcData: Data
        do {
            spcData = try await keyRequest.makeStreamingContentKeyRequestData(
                forApp: appCertData,
                contentIdentifier: assetIdData
            )
        } catch {
            throw AKFairPlayError.spcGenerationFailed(error.localizedDescription)
        }

        let ckcData = try await requestCKCLicense(
            spcData: spcData,
            assetIdData: assetIdData,
            assetIdString: assetIdString
        )

        guard !ckcData.isEmpty else {
            throw AKFairPlayError.invalidCKCData
        }

        // 3. Obtain persistable content key from vendor response
        do {
            let persistableKeyData = try keyRequest.persistableContentKey(
                fromKeyVendorResponse: ckcData
            )

            // Persist for offline playback
            if let customPersister = configuration.persistOfflineKey {
                try await customPersister(assetIdString, persistableKeyData)
            } else if let storageURL = configuration.offlineKeyStorageURL {
                let fileURL = storageURL.appendingPathComponent("\(assetIdString).key")
                try persistableKeyData.write(to: fileURL, options: .atomic)
            }

            let keyResponse = AVContentKeyResponse(
                fairPlayStreamingKeyResponseData: persistableKeyData
            )
            keyRequest.processContentKeyResponse(keyResponse)
        } catch {
            throw AKFairPlayError.offlineKeyStorageFailed(error.localizedDescription)
        }
    }

    // MARK: - Certificate & License Helpers

    /// Obtains the Application Certificate data either from cache or remote network fetch.
    private func obtainApplicationCertificate() async throws -> Data {
        if let existing = cachedCertificateMutex.withLock({ $0 }) {
            return existing
        }

        // Check if a fetch task is already running
        let task: Task<Data, Error> = certificateTaskMutex.withLock { existingTask in
            if let existingTask {
                return existingTask
            }
            let newTask = Task<Data, Error> {
                let data: Data
                if let customFetcher = configuration.fetchCertificate,
                   let certURL = configuration.certificateURL
                {
                    data = try await customFetcher(certURL)
                } else if let certURL = configuration.certificateURL {
                    let (fetched, response) = try await URLSession.shared.data(from: certURL)
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode < 200 || httpResponse.statusCode >= 300
                    {
                        throw AKFairPlayError.licenseServerRequestFailed(
                            statusCode: httpResponse.statusCode,
                            message: "Failed to download certificate from \(certURL.absoluteString)"
                        )
                    }
                    data = fetched
                } else if let certData = configuration.certificateData {
                    data = certData
                } else {
                    throw AKFairPlayError.missingCertificate
                }
                return data
            }
            certificateTaskMutex.withLock { $0 = newTask }
            return newTask
        }

        do {
            let result = try await task.value
            cachedCertificateMutex.withLock { $0 = result }
            certificateTaskMutex.withLock { $0 = nil }
            return result
        } catch {
            certificateTaskMutex.withLock { $0 = nil }
            throw AKFairPlayError.certificateFetchFailed(error.localizedDescription)
        }
    }

    /// Extracts the asset identifier string and UTF-8 data representation from a content key
    /// request.
    /// - Parameter keyRequest: The content key request.
    /// - Returns: A tuple of `(identifierString, identifierData)`.
    private func extractAssetIdentifier(
        from keyRequest: AVContentKeyRequest
    ) throws -> (String, Data) {
        // 1. Explicit configuration override
        if let explicitID = configuration.contentIdentifier,
           let explicitData = explicitID.data(using: .utf8)
        {
            return (explicitID, explicitData)
        }

        // 2. Custom identifier extractor closure
        if let customExtractor = configuration.extractContentIdentifier {
            let uriString = (keyRequest.identifier as? String) ?? ""
            if let url = URL(string: uriString) {
                let extractedData = try customExtractor(url)
                let str = String(data: extractedData, encoding: .utf8) ?? uriString
                return (str, extractedData)
            }
        }

        // 3. Standard skd:// URI identifier parsing
        guard let uriString = keyRequest.identifier as? String,
              let url = URL(string: uriString)
        else {
            throw AKFairPlayError.invalidContentIdentifier(
                String(describing: keyRequest.identifier)
            )
        }

        // Extract host or path from skd://asset_id or skd://company.com/asset_id
        let extractedString: String = if let host = url.host(), !host.isEmpty {
            host
        } else {
            url.lastPathComponent.isEmpty ? uriString : url.lastPathComponent
        }

        guard let assetIdData = extractedString.data(using: .utf8) else {
            throw AKFairPlayError.invalidContentIdentifier(uriString)
        }

        return (extractedString, assetIdData)
    }

    /// Sends SPC data to the KSM license server and retrieves the CKC response.
    private func requestCKCLicense(
        spcData: Data,
        assetIdData: Data,
        assetIdString: String
    ) async throws -> Data {
        // 1. Custom license fetch closure
        if let customFetcher = configuration.fetchLicenseKey {
            return try await customFetcher(spcData, assetIdData, assetIdString)
        }

        // 2. Default standard HTTP POST request to licenseURL
        guard let licenseURL = configuration.licenseURL else {
            throw AKFairPlayError.licenseServerRequestFailed(
                statusCode: 0,
                message: "No licenseURL provided in AKFairPlayConfiguration."
            )
        }

        var request = URLRequest(url: licenseURL)
        request.httpMethod = "POST"
        request.httpBody = spcData
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        for (header, value) in configuration.licenseHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode < 200 || httpResponse.statusCode >= 300
        {
            let serverMessage = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AKFairPlayError.licenseServerRequestFailed(
                statusCode: httpResponse.statusCode,
                message: serverMessage
            )
        }

        return data
    }
}
