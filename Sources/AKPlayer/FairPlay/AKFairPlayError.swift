//
//   AKFairPlayError.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - AKFairPlayError

/// Strongly-typed error states encountered during FairPlay Streaming (FPS) DRM certificate
/// fetching, SPC generation, KSM license requests, and CKC processing.
public enum AKFairPlayError: Error, Equatable, Sendable {
    // MARK: - Cases

    /// The FairPlay application certificate URL or data was not provided.
    case missingCertificate

    /// Fetching the FairPlay application certificate failed with the underlying error.
    case certificateFetchFailed(String)

    /// Extracting the content identifier from the `skd://` URI or initialization data failed.
    case invalidContentIdentifier(String)

    /// Generating the Server Playback Context (SPC) request data failed with the underlying error.
    case spcGenerationFailed(String)

    /// The Key Security Module (KSM) license server returned an HTTP error or network failure.
    case licenseServerRequestFailed(statusCode: Int, message: String)

    /// The Content Key Context (CKC) response data returned by the license server was empty or
    /// invalid.
    case invalidCKCData

    /// Processing the CKC content key response failed on the `AVContentKeyRequest`.
    case keyResponseProcessingFailed(String)

    /// Storing or retrieving persistable offline content keys failed.
    case offlineKeyStorageFailed(String)
}

// MARK: - LocalizedError Conformance

extension AKFairPlayError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingCertificate:
            NSLocalizedString(
                "FairPlay DRM application certificate is missing. Please provide a certificate URL or Data.",
                comment: "AKFairPlayError.missingCertificate"
            )
        case let .certificateFetchFailed(reason):
            NSLocalizedString(
                "Failed to fetch FairPlay application certificate: \(reason)",
                comment: "AKFairPlayError.certificateFetchFailed"
            )
        case let .invalidContentIdentifier(uri):
            NSLocalizedString(
                "Failed to extract a valid FairPlay content identifier from URI: '\(uri)'.",
                comment: "AKFairPlayError.invalidContentIdentifier"
            )
        case let .spcGenerationFailed(reason):
            NSLocalizedString(
                "Failed to generate FairPlay Server Playback Context (SPC): \(reason)",
                comment: "AKFairPlayError.spcGenerationFailed"
            )
        case let .licenseServerRequestFailed(statusCode, message):
            NSLocalizedString(
                "FairPlay license server request failed with HTTP \(statusCode): \(message)",
                comment: "AKFairPlayError.licenseServerRequestFailed"
            )
        case .invalidCKCData:
            NSLocalizedString(
                "FairPlay Content Key Context (CKC) response from license server was empty or malformed.",
                comment: "AKFairPlayError.invalidCKCData"
            )
        case let .keyResponseProcessingFailed(reason):
            NSLocalizedString(
                "Failed to process FairPlay CKC key response on AVContentKeyRequest: \(reason)",
                comment: "AKFairPlayError.keyResponseProcessingFailed"
            )
        case let .offlineKeyStorageFailed(reason):
            NSLocalizedString(
                "FairPlay persistable offline key storage operation failed: \(reason)",
                comment: "AKFairPlayError.offlineKeyStorageFailed"
            )
        }
    }
}
