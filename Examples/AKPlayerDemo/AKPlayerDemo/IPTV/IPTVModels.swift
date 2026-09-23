//
//   IPTVModels.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import Foundation

// MARK: - IPTVChannel

/// Model representing a single IPTV television stream channel.
public struct IPTVChannel: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let groupTitle: String
    public let logoURL: URL?
    public let streamURL: URL
    public let country: String?
    public let language: String?
    public let tvgId: String?

    public init(
        id: UUID = UUID(),
        name: String,
        groupTitle: String = "General",
        logoURL: URL? = nil,
        streamURL: URL,
        country: String? = nil,
        language: String? = nil,
        tvgId: String? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.groupTitle = groupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.logoURL = logoURL
        self.streamURL = streamURL
        self.country = country
        self.language = language
        self.tvgId = tvgId
    }

    /// Converts this IPTV channel into a playable `AKMedia` item configured for live HLS playback.
    public func toAKMedia() -> AKMedia {
        let headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            "Accept": "*/*",
        ]

        let staticMeta = AKNowPlayableStaticMetadata(
            assetURL: streamURL,
            mediaType: .video,
            isLiveStream: true,
            title: name,
            artist: groupTitle.isEmpty ? "Live TV" : groupTitle,
            artwork: .none,
            albumArtist: country?.uppercased(),
            albumTitle: "IPTV Live TV"
        )

        return AKMedia(
            url: streamURL,
            type: .stream(isLive: true),
            assetInitializationOptions: [
                "AVURLAssetHTTPHeaderFieldsKey": headers,
            ],
            automaticallyLoadedAssetKeys: nil,
            staticMetadata: staticMeta,
            liveEdgeThreshold: 4.0
        )
    }

    /// Curated high-uptime, reliable 24/7 live channels for instant verification and testing.
    public static let verifiedChannels: [IPTVChannel] = [
        IPTVChannel(
            name: "NASA TV HD",
            groupTitle: "Science & Space",
            logoURL: URL(
                string: "https://upload.wikimedia.org/wikipedia/commons/e/e5/NASA_logo.svg"
            ),
            streamURL: URL(
                string: "https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8"
            )!,
            country: "US",
            language: "English",
            tvgId: "NASA.us"
        ),
        IPTVChannel(
            name: "DW English HD",
            groupTitle: "News",
            logoURL: URL(
                string: "https://upload.wikimedia.org/wikipedia/commons/7/75/Deutsche_Welle_logo.svg"
            ),
            streamURL: URL(
                string: "https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8"
            )!,
            country: "DE",
            language: "English",
            tvgId: "DWEnglish.de"
        ),
        IPTVChannel(
            name: "France 24 English",
            groupTitle: "News",
            logoURL: URL(
                string: "https://upload.wikimedia.org/wikipedia/commons/0/07/France_24_logo.svg"
            ),
            streamURL: URL(string: "https://static.france24.com/live/F24_EN_LO_HLS/live_tv.m3u8")!,
            country: "FR",
            language: "English",
            tvgId: "France24English.fr"
        ),
        IPTVChannel(
            name: "Red Bull TV",
            groupTitle: "Sports",
            logoURL: URL(
                string: "https://upload.wikimedia.org/wikipedia/en/thumb/f/f5/Red_Bull_TV_logo.svg/320px-Red_Bull_TV_logo.svg.png"
            ),
            streamURL: URL(
                string: "https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8"
            )!,
            country: "AT",
            language: "English",
            tvgId: "RedBullTV.at"
        ),
        IPTVChannel(
            name: "EuroNews English",
            groupTitle: "News",
            logoURL: URL(
                string: "https://upload.wikimedia.org/wikipedia/commons/9/91/Euronews_2016_logo.svg"
            ),
            streamURL: URL(
                string: "https://euronews-euronews-world-1-au.samsung.wurl.tv/playlist.m3u8"
            )!,
            country: "FR",
            language: "English",
            tvgId: "EuronewsEnglish.fr"
        ),
        IPTVChannel(
            name: "Apple HLS Live 1080p (Demo)",
            groupTitle: "Test Streams",
            logoURL: URL(
                string: "https://developer.apple.com/assets/elements/icons/hls/hls-96x96_2x.png"
            ),
            streamURL: URL(
                string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
            )!,
            country: "US",
            language: "English",
            tvgId: "AppleHLS.us"
        ),
        IPTVChannel(
            name: "Apple fMP4 Advanced Stream",
            groupTitle: "Test Streams",
            logoURL: URL(
                string: "https://developer.apple.com/assets/elements/icons/hls/hls-96x96_2x.png"
            ),
            streamURL: URL(
                string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
            )!,
            country: "US",
            language: "English",
            tvgId: "AppleAdv.us"
        ),
        IPTVChannel(
            name: "Arirang TV World",
            groupTitle: "Entertainment",
            logoURL: URL(
                string: "https://upload.wikimedia.org/wikipedia/commons/e/ea/Arirang_TV_logo.png"
            ),
            streamURL: URL(
                string: "https://amdlive.ctnd.com.edgesuite.net/arirang_1ch/smil:arirang_1ch.smil/playlist.m3u8"
            )!,
            country: "KR",
            language: "English",
            tvgId: "ArirangTV.kr"
        ),
    ]
}

// MARK: - IPTVCategory

/// Predefined categories matching iptv-org category playlists.
public enum IPTVCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case news = "News"
    case sports = "Sports"
    case music = "Music"
    case movies = "Movies"
    case animation = "Animation"
    case documentary = "Documentary"
    case entertainment = "Entertainment"
    case kids = "Kids"
    case general = "General"

    public var id: String {
        rawValue
    }

    public var icon: String {
        switch self {
        case .all: "tv.inset.filled"
        case .news: "newspaper.fill"
        case .sports: "sportscourt.fill"
        case .music: "music.note"
        case .movies: "film.fill"
        case .animation: "sparkles.tv.fill"
        case .documentary: "globe.americas.fill"
        case .entertainment: "popcorn.fill"
        case .kids: "figure.2.and.child.holdinghands"
        case .general: "tv"
        }
    }

    public var playlistURL: URL? {
        switch self {
        case .all:
            URL(string: "https://iptv-org.github.io/iptv/index.m3u")
        case .news:
            URL(string: "https://iptv-org.github.io/iptv/categories/news.m3u")
        case .sports:
            URL(string: "https://iptv-org.github.io/iptv/categories/sports.m3u")
        case .music:
            URL(string: "https://iptv-org.github.io/iptv/categories/music.m3u")
        case .movies:
            URL(string: "https://iptv-org.github.io/iptv/categories/movies.m3u")
        case .animation:
            URL(string: "https://iptv-org.github.io/iptv/categories/animation.m3u")
        case .documentary:
            URL(string: "https://iptv-org.github.io/iptv/categories/documentary.m3u")
        case .entertainment:
            URL(string: "https://iptv-org.github.io/iptv/categories/entertainment.m3u")
        case .kids:
            URL(string: "https://iptv-org.github.io/iptv/categories/kids.m3u")
        case .general:
            URL(string: "https://iptv-org.github.io/iptv/categories/general.m3u")
        }
    }
}

// MARK: - IPTVPlaylistPreset

/// Curated playlist presets from iptv-org repository.
public struct IPTVPlaylistPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: String
    public let url: URL

    public static let verifiedURL = URL(string: "internal://verified-streams")!

    public static let curatedPresets: [IPTVPlaylistPreset] = [
        IPTVPlaylistPreset(
            id: "verified",
            title: "⭐ Verified 24/7",
            subtitle: "High-uptime, guaranteed live channels",
            icon: "checkmark.seal.fill",
            url: verifiedURL
        ),
        IPTVPlaylistPreset(
            id: "news",
            title: "News 24/7",
            subtitle: "Global live news broadcasts",
            icon: "newspaper.fill",
            url: URL(string: "https://iptv-org.github.io/iptv/categories/news.m3u")!
        ),
        IPTVPlaylistPreset(
            id: "sports",
            title: "Sports Live",
            subtitle: "Live sport events and highlights",
            icon: "sportscourt.fill",
            url: URL(string: "https://iptv-org.github.io/iptv/categories/sports.m3u")!
        ),
        IPTVPlaylistPreset(
            id: "music",
            title: "Music Channels",
            subtitle: "24/7 Music videos & concerts",
            icon: "music.note.tv.fill",
            url: URL(string: "https://iptv-org.github.io/iptv/categories/music.m3u")!
        ),
        IPTVPlaylistPreset(
            id: "movies",
            title: "Movies & Cinema",
            subtitle: "Film and cinema streaming networks",
            icon: "film.stack.fill",
            url: URL(string: "https://iptv-org.github.io/iptv/categories/movies.m3u")!
        ),
        IPTVPlaylistPreset(
            id: "animation",
            title: "Animation & Anime",
            subtitle: "Animated shows and anime streams",
            icon: "sparkles.tv.fill",
            url: URL(string: "https://iptv-org.github.io/iptv/categories/animation.m3u")!
        ),
        IPTVPlaylistPreset(
            id: "documentary",
            title: "Documentaries",
            subtitle: "Nature, science, and history",
            icon: "globe.americas.fill",
            url: URL(string: "https://iptv-org.github.io/iptv/categories/documentary.m3u")!
        ),
        IPTVPlaylistPreset(
            id: "us",
            title: "United States",
            subtitle: "US National and regional channels",
            icon: "flag.fill",
            url: URL(string: "https://iptv-org.github.io/iptv/countries/us.m3u")!
        ),
        IPTVPlaylistPreset(
            id: "uk",
            title: "United Kingdom",
            subtitle: "UK broadcast and digital channels",
            icon: "flag.fill",
            url: URL(string: "https://iptv-org.github.io/iptv/countries/uk.m3u")!
        ),
    ]
}
