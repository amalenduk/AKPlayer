//
//   IPTVService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - IPTVService

/// Service responsible for fetching, parsing, and caching IPTV M3U / M3U8 playlists.
public final class IPTVService: @unchecked Sendable {
    public static let shared = IPTVService()

    private let cache = NSCache<NSURL, NSArray>()

    private init() {}

    /// Fetches and parses an M3U playlist from the specified remote URL.
    /// - Parameter playlistURL: The destination M3U / M3U8 playlist URL.
    /// - Returns: An array of parsed `IPTVChannel` objects.
    public func fetchChannels(from playlistURL: URL) async throws -> [IPTVChannel] {
        if playlistURL == IPTVPlaylistPreset.verifiedURL || playlistURL.scheme == "internal" {
            return IPTVChannel.verifiedChannels
        }

        if let cached = cache.object(forKey: playlistURL as NSURL) as? [IPTVChannel],
           !cached.isEmpty
        {
            return cached
        }

        var request = URLRequest(url: playlistURL)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        guard let content = String(data: data, encoding: .utf8) ?? String(
            data: data,
            encoding: .ascii
        ) else {
            throw URLError(.cannotDecodeContentData)
        }

        let channels = parseM3U(content: content)
        cache.setObject(channels as NSArray, forKey: playlistURL as NSURL)
        return channels
    }

    /// Parses the raw string contents of an M3U playlist file into structured `IPTVChannel` models.
    /// - Parameter content: The complete textual content of the M3U playlist.
    /// - Returns: A collection of parsed channels.
    public func parseM3U(content: String) -> [IPTVChannel] {
        var channels: [IPTVChannel] = []
        let lines = content.components(separatedBy: .newlines)

        var currentTitle = ""
        var currentGroup = "General"
        var currentLogo: URL?
        var currentCountry: String?
        var currentLanguage: String?
        var currentTvgId: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            if trimmed.hasPrefix("#EXTINF:") {
                // 1. Extract Channel Title (after last comma)
                if let commaIndex = trimmed.lastIndex(of: ",") {
                    let titleSubstring = trimmed[trimmed.index(after: commaIndex)...]
                    currentTitle = String(titleSubstring).trimmingCharacters(in: .whitespaces)
                }

                // 2. Extract group-title
                if let group = extractAttribute("group-title", from: trimmed) {
                    currentGroup = group
                }

                // 3. Extract tvg-logo
                if let logoStr = extractAttribute("tvg-logo", from: trimmed),
                   let logo = URL(string: logoStr), !logoStr.isEmpty
                {
                    currentLogo = logo
                }

                // 4. Extract tvg-country
                if let country = extractAttribute("tvg-country", from: trimmed) {
                    currentCountry = country
                }

                // 5. Extract tvg-language
                if let language = extractAttribute("tvg-language", from: trimmed) {
                    currentLanguage = language
                }

                // 6. Extract tvg-id / tvg-name
                if let tvgId = extractAttribute("tvg-id", from: trimmed) ?? extractAttribute(
                    "tvg-name",
                    from: trimmed
                ) {
                    currentTvgId = tvgId
                }
            } else if !trimmed.hasPrefix("#") {
                // Stream URL line
                if let url = URL(string: trimmed), !currentTitle.isEmpty {
                    let channel = IPTVChannel(
                        name: currentTitle,
                        groupTitle: currentGroup,
                        logoURL: currentLogo,
                        streamURL: url,
                        country: currentCountry,
                        language: currentLanguage,
                        tvgId: currentTvgId
                    )
                    channels.append(channel)
                }

                // Reset temporary attributes for next entry
                currentTitle = ""
                currentGroup = "General"
                currentLogo = nil
                currentCountry = nil
                currentLanguage = nil
                currentTvgId = nil
            }
        }

        return channels
    }

    /// Extracts a quoted attribute value from an `#EXTINF` header line.
    /// - Parameters:
    ///   - attribute: The key name (e.g. `group-title` or `tvg-logo`).
    ///   - line: The full `#EXTINF` header string.
    /// - Returns: The extracted attribute string, or `nil` if not present.
    private func extractAttribute(_ attribute: String, from line: String) -> String? {
        let pattern = "\(attribute)=\""
        guard let startRange = line.range(of: pattern) else { return nil }
        let remainder = line[startRange.upperBound...]
        guard let endQuote = remainder.firstIndex(of: "\"") else { return nil }
        let value = String(remainder[..<endQuote]).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
