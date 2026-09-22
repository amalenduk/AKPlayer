//
//   TestMediaHelpers.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import Foundation
import UIKit

public func makeAKMedia(
    from test: TestMedia,
    customHeaders: [String: String]? = nil
) -> AKMedia? {
    guard let url = test.url else { return nil }
    var headers = ["User-Agent": "AKPlayerDemo/1.0"]
    if let customHeaders {
        headers.merge(customHeaders) { _, new in new }
    }
    let isAudioOnly = test.name.localizedCaseInsensitiveContains("Audio")
        || (test.subtitle?.localizedCaseInsensitiveContains("Audio") ?? false)
    let staticMetadata = AKNowPlayableStaticMetadata(
        assetURL: url,
        mediaType: isAudioOnly ? .audio : .video,
        isLiveStream: test.kind == .live,
        title: test.name,
        artist: test.subtitle,
        artwork: .none,
        albumArtist: nil,
        albumTitle: nil
    )
    return AKMedia(
        url: url,
        type: test.kind.akMediaType,
        assetInitializationOptions: ["AVURLAssetHTTPHeaderFieldsKey": headers],
        automaticallyLoadedAssetKeys: [.duration, .isPlayable, .commonMetadata],
        staticMetadata: staticMetadata
    )
}
