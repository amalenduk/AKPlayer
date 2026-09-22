//
//   CustomURLPlaygroundView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import SwiftUI
import UIKit

public struct CustomURLPlaygroundView: View {
    public enum PlayerTarget: String, CaseIterable, Identifiable {
        case video = "Video Player"
        case live = "Live Stream"
        case audiobook = "Audiobook / Podcast"

        public var id: String {
            rawValue
        }

        public var icon: String {
            switch self {
            case .video: "play.rectangle.fill"
            case .live: "dot.radiowaves.left.and.right"
            case .audiobook: "book.fill"
            }
        }

        public var color: Color {
            switch self {
            case .video: .blue
            case .live: .red
            case .audiobook: .purple
            }
        }
    }

    // Form Inputs
    @State private var urlString = ""
    @State private var titleString = ""
    @State private var subtitleString = ""
    @State private var selectedTarget: PlayerTarget = .video
    @State private var userAgent = "AKPlayerDemo/1.0"
    @State private var authHeader = ""
    @State private var showAdvancedHeaders = false

    /// Player Launch Trigger
    @State private var activePlaybackMedia: (media: AKMedia, target: PlayerTarget)?

    // Global Settings
    @AppStorage("globalAutoPlay") private var globalAutoPlay = true
    @AppStorage("recentCustomURLs") private var recentCustomURLsData = ""

    @Environment(\.dismiss) private var dismiss

    public init(initialTarget: PlayerTarget = .video) {
        _selectedTarget = State(initialValue: initialTarget)
    }

    private var isValidURL: Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "file"
        else {
            return false
        }
        return true
    }

    private var recentURLs: [String] {
        recentCustomURLsData.split(separator: "|||").map(String.init)
    }

    private func saveToRecent(url: String) {
        var recents = recentURLs.filter { $0 != url }
        recents.insert(url, at: 0)
        let trimmed = Array(recents.prefix(8))
        recentCustomURLsData = trimmed.joined(separator: "|||")
    }

    private func removeFromRecent(url: String) {
        let filtered = recentURLs.filter { $0 != url }
        recentCustomURLsData = filtered.joined(separator: "|||")
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Player Target
                Section("Target Player Engine") {
                    Picker("Player Type", selection: $selectedTarget) {
                        ForEach(PlayerTarget.allCases) { target in
                            Label(target.rawValue, systemImage: target.icon)
                                .tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Section 2: Stream URL Input
                Section("Stream Destination URL") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("https://example.com/stream.m3u8", text: $urlString)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)

                            if !urlString.isEmpty {
                                Button {
                                    urlString = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                if let clip = UIPasteboard.general.string {
                                    urlString = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        if !urlString.isEmpty, !isValidURL {
                            Text("Please enter a valid http:// or https:// URL")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Section 3: Metadata (Optional)
                Section("Metadata (Optional)") {
                    TextField("Title (e.g. My HLS Stream)", text: $titleString)
                    TextField("Artist / Subtitle (e.g. 1080p 60fps)", text: $subtitleString)
                }

                // Section 4: Advanced Headers & Auth
                Section {
                    DisclosureGroup("HTTP Headers & Auth", isExpanded: $showAdvancedHeaders) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("User-Agent", text: $userAgent)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            TextField("Authorization Header (Bearer token)", text: $authHeader)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.top, 4)
                    }
                }

                // Section 5: Launch Playback Button
                Section {
                    Button {
                        launchPlayer()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Launch \(selectedTarget.rawValue)", systemImage: "play.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(!isValidURL)
                    .listRowBackground(isValidURL ? selectedTarget.color : Color.gray.opacity(0.3))
                }

                // Section 6: Quick Preset Samples
                Section("Quick Preset Samples") {
                    presetRow(
                        title: "Apple TV Advanced (HLS Atmos)",
                        url: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8",
                        target: .video
                    )
                    presetRow(
                        title: "Apple Interstitials & Ads (HLS)",
                        url: "https://devstreaming-cdn.apple.com/videos/streaming/examples/interstitial-sample/mvp_interstitial_sample.m3u8",
                        target: .video
                    )
                    presetRow(
                        title: "Bip Bop Advanced Stream",
                        url: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8",
                        target: .video
                    )
                    presetRow(
                        title: "iReplay 24/7 Live Stream",
                        url: "https://ireplay.tv/test/blender.m3u8",
                        target: .live
                    )
                    presetRow(
                        title: "Bloomberg Originals Live News",
                        url: "https://86fdc85a.wurl.com/master/f36d25e7e52f1ba8d7e56eb859c636563214f541/TEctZ2JfQmxvb21iZXJnT3JpZ2luYWxzX0hMUw/playlist.m3u8",
                        target: .live
                    )
                    presetRow(
                        title: "The Art of War (M4B Audiobook)",
                        url: "https://archive.org/download/art_of_war_librivox/art_of_war_librivox.m4b",
                        target: .audiobook
                    )
                    presetRow(
                        title: "SoundHelix Instrumental (MP3)",
                        url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
                        target: .audiobook
                    )
                }

                // Section 7: Recent History
                if !recentURLs.isEmpty {
                    Section("Recent Custom Streams") {
                        ForEach(recentURLs, id: \.self) { recent in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recent)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Button {
                                    urlString = recent
                                } label: {
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    removeFromRecent(url: recent)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("URL Playground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(item: Binding(
                get: { activePlaybackMedia.map { PlaybackPresentation(
                    media: $0.media,
                    target: $0.target
                ) } },
                set: {
                    if $0 == nil {
                        activePlaybackMedia = nil
                    }
                }
            )) { item in
                destinationPlayerView(for: item)
            }
        }
    }

    // MARK: - Helpers

    private struct PlaybackPresentation: Identifiable {
        var id = UUID()
        let media: AKMedia
        let target: PlayerTarget
    }

    @ViewBuilder
    private func destinationPlayerView(for item: PlaybackPresentation) -> some View {
        switch item.target {
        case .video:
            SimpleVideoPlayerView(media: item.media, autoPlay: globalAutoPlay)
        case .live:
            LivePlayerView(media: item.media, autoPlay: globalAutoPlay)
        case .audiobook:
            AudiobookPlayerView(media: item.media, autoPlay: globalAutoPlay)
        }
    }

    private func presetRow(title: String, url: String, target: PlayerTarget) -> some View {
        Button {
            urlString = url
            titleString = title
            selectedTarget = target
        } label: {
            HStack(spacing: 12) {
                Image(systemName: target.icon)
                    .foregroundColor(target.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(url)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
    }

    private func launchPlayer() {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleaned) else { return }

        saveToRecent(url: cleaned)

        var headers: [String: String] = [:]
        if !userAgent.isEmpty {
            headers["User-Agent"] = userAgent
        }
        if !authHeader.isEmpty {
            headers["Authorization"] = authHeader
        }

        let effectiveTitle = titleString
            .isEmpty ? (url.lastPathComponent.isEmpty ? "Custom Stream" : url.lastPathComponent) :
            titleString
        let effectiveSubtitle = subtitleString.isEmpty ? url.host : subtitleString

        let testMedia = TestMedia(
            name: effectiveTitle,
            subtitle: effectiveSubtitle,
            url: url,
            kind: selectedTarget == .live ? .live : .clip
        )

        guard let akMedia = makeAKMedia(from: testMedia, customHeaders: headers) else { return }
        activePlaybackMedia = (media: akMedia, target: selectedTarget)
    }
}
