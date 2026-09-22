//
//   AKFairPlayTests.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@testable import AKPlayer
import AVFoundation
import Foundation
import Testing

@MainActor
struct AKFairPlayTests {
    @Test func fairPlayConfigurationInitialization() throws {
        let certURL = try #require(URL(string: "https://fps.example.com/certificate.der"))
        let licenseURL = try #require(URL(string: "https://fps.example.com/license"))
        let dummyCertData = "DUMMY_CERT_DATA".data(using: .utf8)!

        let config = AKFairPlayConfiguration(
            certificateURL: certURL,
            certificateData: dummyCertData,
            licenseURL: licenseURL,
            licenseHeaders: [
                "Authorization": "Bearer test-drm-token-123",
                "X-Tenant-ID": "akplayer-demo",
            ],
            contentIdentifier: "custom_content_id_99",
            offlineKeysEnabled: true
        )

        #expect(config.certificateURL == certURL)
        #expect(config.certificateData == dummyCertData)
        #expect(config.licenseURL == licenseURL)
        #expect(config.licenseHeaders["Authorization"] == "Bearer test-drm-token-123")
        #expect(config.licenseHeaders["X-Tenant-ID"] == "akplayer-demo")
        #expect(config.contentIdentifier == "custom_content_id_99")
        #expect(config.offlineKeysEnabled == true)
    }

    #if !targetEnvironment(simulator)
        @Test func fairPlayHandlerAttachment() async throws {
            let dummyCertData = "MOCK_CERT_BYTES".data(using: .utf8)!
            let licenseURL = try #require(URL(string: "https://fps.example.com/license"))

            let config = AKFairPlayConfiguration(
                certificateData: dummyCertData,
                licenseURL: licenseURL
            )

            let handler = AKFairPlayHandler(configuration: config)
            let assetURL = try #require(URL(string: "https://fps.example.com/stream/main.m3u8"))
            let asset = AVURLAsset(url: assetURL)

            handler.attach(to: asset)
            #expect(handler.contentKeySession.contentKeyRecipients
                .contains { $0 as? AVURLAsset == asset })

            handler.detach(from: asset)
            #expect(!handler.contentKeySession.contentKeyRecipients
                .contains { $0 as? AVURLAsset == asset })

            handler.attach(to: asset)
            #expect(handler.contentKeySession.keySystem == .fairPlayStreaming)

            try await handler.preloadCertificate()

            handler.invalidate()
            #expect(handler.contentKeySession.contentKeyRecipients.isEmpty)
        }

        @Test func fairPlayCustomClosuresExecution() async throws {
            let dummyCertData = "FETCHED_CERT".data(using: .utf8)!
            let dummyCKCData = "MOCK_CKC_LICENSE".data(using: .utf8)!

            final class TestBox: @unchecked Sendable {
                var certFetchCalled = false
                var licenseFetchCalled = false
                var extractorCalled = false
            }
            let box = TestBox()

            let config = AKFairPlayConfiguration(
                certificateURL: URL(string: "https://fps.example.com/cert"),
                fetchCertificate: { _ in
                    box.certFetchCalled = true
                    return dummyCertData
                },
                extractContentIdentifier: { url in
                    box.extractorCalled = true
                    return url.lastPathComponent.data(using: .utf8) ?? Data()
                },
                fetchLicenseKey: { _, _, _ in
                    box.licenseFetchCalled = true
                    return dummyCKCData
                }
            )

            let handler = AKFairPlayHandler(configuration: config)
            try await handler.preloadCertificate()
            #expect(box.certFetchCalled == true)

            let testURL = try #require(URL(string: "skd://asset-video-1001"))
            let extracted = try config.extractContentIdentifier?(testURL)
            #expect(extracted != nil)
            #expect(box.extractorCalled == true)
            #expect(try String(data: #require(extracted), encoding: .utf8) == "asset-video-1001")

            let fetchedCKC = try await config.fetchLicenseKey?(Data(), Data(), "asset-video-1001")
            #expect(fetchedCKC == dummyCKCData)
            #expect(box.licenseFetchCalled == true)
        }
    #endif

    @Test func fairPlayErrorLocalization() {
        let missingCert = AKFairPlayError.missingCertificate
        #expect(missingCert.errorDescription?.contains("certificate") == true)

        let certFetchFailed = AKFairPlayError.certificateFetchFailed("Network timeout")
        #expect(certFetchFailed.errorDescription?.contains("Network timeout") == true)

        let invalidID = AKFairPlayError.invalidContentIdentifier("skd://bad-uri")
        #expect(invalidID.errorDescription?.contains("skd://bad-uri") == true)

        let spcFailed = AKFairPlayError.spcGenerationFailed("AVContentKeyRequest invalid")
        #expect(spcFailed.errorDescription?.contains("SPC") == true)

        let httpFailed = AKFairPlayError.licenseServerRequestFailed(
            statusCode: 403,
            message: "Unauthorized token"
        )
        #expect(httpFailed.errorDescription?.contains("403") == true)

        let invalidCKC = AKFairPlayError.invalidCKCData
        #expect(invalidCKC.errorDescription?.contains("CKC") == true)

        let playerError = AKPlayerError.fairPlay(reason: missingCert)
        #expect(playerError.errorDescription?.contains("certificate") == true)

        let playerError2 = AKPlayerError.fairPlay(reason: missingCert)
        #expect(playerError == playerError2)
    }

    #if !targetEnvironment(simulator)
        @Test func fairPlayMediaIntegration() async throws {
            let certData = "APP_CERT_DATA".data(using: .utf8)!
            let licenseURL = try #require(URL(string: "https://fps.example.com/license"))
            let mediaURL =
                try #require(URL(string: "https://fps.example.com/protected/master.m3u8"))

            let config = AKFairPlayConfiguration(
                certificateData: certData,
                licenseURL: licenseURL,
                contentIdentifier: "sample_fps_content_01"
            )

            let media = AKMedia(
                url: mediaURL,
                type: .clip,
                fairPlay: config
            )

            #expect(media.fairPlayConfiguration != nil)
            #expect(media.fairPlayHandler != nil)
            #expect(media.fairPlayConfiguration?.contentIdentifier == "sample_fps_content_01")

            let initService = AKPlayerItemInitService()
            let asset = await initService.createAsset(for: media)
            #expect(asset.url == mediaURL)

            let playerItem = initService.createPlayerItem(from: asset, for: media)
            #expect(playerItem.asset as? AVURLAsset == asset)
        }
    #endif
}
