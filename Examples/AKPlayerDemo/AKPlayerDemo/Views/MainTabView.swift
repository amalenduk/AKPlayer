//
//   MainTabView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import SwiftUI

public struct MainTabView: View {
    @AppStorage("globalAutoPlay") private var globalAutoPlay = true

    @State private var selectedVideoMedia: TestMedia?
    @State private var selectedLiveMedia: TestMedia?
    @State private var selectedAudiobookMedia: TestMedia?
    @State private var isQueuePlayerPresented = false
    @State private var queueStartIndex = 0
    @State private var isPlaygroundPresented = false
    @State private var playgroundInitialTarget: CustomURLPlaygroundView.PlayerTarget = .video

    public init() {}

    public var body: some View {
        TabView {
            // Tab 1: Video Player
            videoPlayerTab()
                .tabItem {
                    Label("Video", systemImage: "play.rectangle.fill")
                }

            // Tab 2: Live Streams
            livePlayerTab()
                .tabItem {
                    Label("Live Streams", systemImage: "dot.radiowaves.left.and.right")
                }

            // Tab 3: Audiobooks & Podcasts
            audiobookPlayerTab()
                .tabItem {
                    Label("Audiobooks", systemImage: "book.fill")
                }

            // Tab 4: Queue & Playlist
            queuePlayerTab()
                .tabItem {
                    Label("Queue", systemImage: "play.square.stack.fill")
                }

            // Tab 5: IPTV Live TV
            IPTVPlayerView()
                .tabItem {
                    Label("IPTV", systemImage: "tv.fill")
                }

            // Tab 6: About & GitHub
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
        }
        .sheet(item: $selectedVideoMedia) { media in
            if let akMedia = makeAKMedia(from: media) {
                SimpleVideoPlayerView(media: akMedia, autoPlay: globalAutoPlay)
            }
        }
        .sheet(item: $selectedLiveMedia) { media in
            if let akMedia = makeAKMedia(from: media) {
                LivePlayerView(media: akMedia, autoPlay: globalAutoPlay)
            }
        }
        .sheet(item: $selectedAudiobookMedia) { media in
            if let akMedia = makeAKMedia(from: media) {
                AudiobookPlayerView(media: akMedia, autoPlay: globalAutoPlay)
            }
        }
        .sheet(isPresented: $isPlaygroundPresented) {
            CustomURLPlaygroundView(initialTarget: playgroundInitialTarget)
        }
        .fullScreenCover(isPresented: $isQueuePlayerPresented) {
            QueuePlayerView(
                medias: sampleQueueMedia,
                startIndex: queueStartIndex
            )
        }
    }

    // MARK: - 1. Video Player Tab

    private func videoPlayerTab() -> some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Video Player Engine")
                                .font(.headline)
                            Text(
                                "Testing aspect ratio (Fit/Fill/Stretch), Subtitles, CC, PiP, and SSAI ad interstitials."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Sample Video Catalog") {
                    ForEach(sampleVideoMedia) { media in
                        Button {
                            selectedVideoMedia = media
                        } label: {
                            videoMediaRow(media: media)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Video Player")
            .toolbar {
                playerTabToolbar(target: .video)
            }
        }
    }

    private func videoMediaRow(media: TestMedia) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(media.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let subtitle = media.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            if let caps = media.testCapabilities, !caps.isEmpty {
                HStack(spacing: 6) {
                    ForEach(caps.prefix(2), id: \.self) { cap in
                        Text(cap)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 2. Live Player Tab

    private func livePlayerTab() -> some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Live Streaming & DVR")
                                .font(.headline)
                            Text(
                                "Real-time low-latency broadcast playback, sliding window buffer, and 'Jump to Live' synchronization."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Live Broadcast Channels") {
                    ForEach(sampleLiveMedia) { media in
                        Button {
                            selectedLiveMedia = media
                        } label: {
                            liveMediaRow(media: media)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Live Streams")
            .toolbar {
                playerTabToolbar(target: .live)
            }
        }
    }

    private func liveMediaRow(media: TestMedia) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(media.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("LIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    if let subtitle = media.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundColor(.red)
            }

            if let caps = media.testCapabilities, !caps.isEmpty {
                HStack(spacing: 6) {
                    ForEach(caps.prefix(2), id: \.self) { cap in
                        Text(cap)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 3. Audiobook Player Tab

    private func audiobookPlayerTab() -> some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audiobooks & Podcasts")
                                .font(.headline)
                            Text(
                                "M4B chapter extraction, chapter jumping, skip intervals (15s back / 30s forward), sleep timers, and AirPlay route policy."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Chaptered Audiobooks & Music") {
                    ForEach(sampleAudiobookMedia) { media in
                        Button {
                            selectedAudiobookMedia = media
                        } label: {
                            audiobookMediaRow(media: media)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Audiobooks")
            .toolbar {
                playerTabToolbar(target: .audiobook)
            }
        }
    }

    private func audiobookMediaRow(media: TestMedia) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: media.name.contains("Audiobook") ? "book.fill" : "music.note")
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(media.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let subtitle = media.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "headphones")
                    .font(.title3)
                    .foregroundColor(.purple)
            }

            if let caps = media.testCapabilities, !caps.isEmpty {
                HStack(spacing: 6) {
                    ForEach(caps.prefix(2), id: \.self) { cap in
                        Text(cap)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 4. Queue Player Tab

    private func queuePlayerTab() -> some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "play.square.stack.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                        Text("AKQueuePlayer Playlist Engine")
                            .font(.headline)

                        Text(
                            "Continuous queue playback with auto-advance, shuffle mode, repeat modes (.off, .one, .all), and Now Playing integration."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                        Button {
                            queueStartIndex = 0
                            isQueuePlayerPresented = true
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play Entire Queue (\(sampleQueueMedia.count) items)")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Playlist Items (Tap any item to start from there)") {
                    ForEach(
                        Array(sampleQueueMedia.enumerated()),
                        id: \.element.id
                    ) { index, media in
                        Button {
                            queueStartIndex = index
                            isQueuePlayerPresented = true
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(media.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    if let subtitle = media.subtitle {
                                        Text(subtitle)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "play.circle")
                                    .foregroundColor(.green)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Queue Player")
        }
    }

    // MARK: - Toolbar Helpers

    @ToolbarContentBuilder
    private func playerTabToolbar(target: CustomURLPlaygroundView
        .PlayerTarget) -> some ToolbarContent
    {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                playgroundInitialTarget = target
                isPlaygroundPresented = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Custom URL")
                        .font(.caption.bold())
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                globalAutoPlay.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: globalAutoPlay ? "bolt.fill" : "bolt.slash")
                    Text(globalAutoPlay ? "AutoPlay ON" : "AutoPlay OFF")
                        .font(.caption.bold())
                }
                .foregroundColor(globalAutoPlay ? .blue : .secondary)
            }
        }
    }
}
