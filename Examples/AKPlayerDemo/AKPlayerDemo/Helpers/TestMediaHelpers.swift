//
//  TestMediaHelpers.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 02/09/26.
//

import Foundation
import UIKit
import AKPlayer

public func makeAKMedia(from test: TestMedia) -> AKMedia? {
    guard let url = test.url else { return nil }
    let headers = ["User-Agent": "AKPlayerDemo/1.0"]
    let staticMetadata = AKNowPlayableStaticMetadata(
        assetURL: url,
        mediaType: test.kind.akMediaType == .clip ? .video : .audio,
        isLiveStream: test.kind == .live,
        title: test.name,
        artist: test.subtitle,
        artwork: .none,
        albumArtist: nil,
        albumTitle: nil
    )
    let media = AKMedia(
        url: url,
        type: test.kind.akMediaType,
        assetInitializationOptions: ["AVURLAssetHTTPHeaderFieldsKey": headers],
        automaticallyLoadedAssetKeys: [.duration, .isPlayable, .commonMetadata],
        staticMetadata: staticMetadata
    )
    return media
}
