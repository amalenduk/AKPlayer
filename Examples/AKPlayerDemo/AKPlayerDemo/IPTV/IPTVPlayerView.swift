//
//   IPTVPlayerView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import AVFoundation
import SwiftUI

// MARK: - IPTVPlayerUIView

private struct IPTVPlayerUIView: UIViewRepresentable {
    @ObservedObject var viewModel: IPTVPlayerViewModel

    func makeUIView(context _: Context) -> AKPlayerView {
        let v = AKPlayerView()
        v.player = viewModel.player.player
        v.playerLayer.videoGravity = viewModel.videoGravity
        viewModel.setupPip(with: v.playerLayer)
        return v
    }

    func updateUIView(_ uiView: AKPlayerView, context _: Context) {
        if uiView.player != viewModel.player.player {
            uiView.player = viewModel.player.player
        }
        if uiView.playerLayer.videoGravity != viewModel.videoGravity {
            uiView.playerLayer.videoGravity = viewModel.videoGravity
        }
    }

    static func dismantleUIView(_ uiView: AKPlayerView, coordinator _: ()) {
        uiView.player = nil
    }
}

// MARK: - IPTVPlayerView

public struct IPTVPlayerView: View {
    @StateObject private var viewModel = IPTVPlayerViewModel()
    @State private var showingCustomURLSheet = false
    @State private var customURLInput = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Video Player Section (When a channel is selected)
                if viewModel.currentChannel != nil {
                    playerContainer()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 2. Preset and Category Picker Filters
                filtersHeaderSection()

                // 3. Channel Count & Search Summary
                channelCountHeader()

                // 4. Channel List / State Views
                if viewModel.isLoadingChannels {
                    loadingView()
                } else if let error = viewModel.channelLoadError {
                    errorView(message: error)
                } else if viewModel.filteredChannels.isEmpty {
                    emptySearchResultsView()
                } else {
                    channelListView()
                }
            }
            .navigationTitle("Live IPTV")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search \(viewModel.channels.count) live channels..."
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustomURLSheet = true
                    } label: {
                        Image(systemName: "link.badge.plus")
                    }
                    .accessibilityLabel("Custom M3U URL")
                }
            }
            .sheet(isPresented: $showingCustomURLSheet) {
                customURLSheet()
            }
        }
    }

    // MARK: - Player Container

    private func playerContainer() -> some View {
        VStack(spacing: 0) {
            ZStack {
                IPTVPlayerUIView(viewModel: viewModel)
                    .frame(height: 220)
                    .background(Color.black)
                    .clipped()

                // Buffering Spinner Overlay
                if viewModel.isBuffering, viewModel.playbackError == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.3)
                }

                // Stream Error / Offline Overlay
                if let errorMsg = viewModel.playbackError {
                    VStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Stream Unavailable")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(errorMsg)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 16)

                        HStack(spacing: 8) {
                            Button {
                                viewModel.playNextChannel()
                            } label: {
                                Label("Next", systemImage: "forward.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)

                            Button {
                                if let preset = viewModel.presets
                                    .first(where: { $0.id == "verified" })
                                {
                                    viewModel.loadChannels(for: preset)
                                }
                            } label: {
                                Label("Verified ⭐", systemImage: "checkmark.seal.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.85))
                }

                // Top Controls (Live Badge & PiP & Aspect)
                VStack {
                    HStack {
                        liveBadge()
                        Spacer()
                        topOverlayControls()
                    }
                    .padding(8)
                    Spacer()
                }
            }

            // Channel Info & Control Strip
            if let channel = viewModel.currentChannel {
                playerControlBar(channel: channel)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    private func liveBadge() -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isPlaying ? Color.red : Color.orange)
                .frame(width: 8, height: 8)
            Text(viewModel.stateDescription.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.65))
        .cornerRadius(6)
    }

    private func topOverlayControls() -> some View {
        HStack(spacing: 8) {
            Button {
                viewModel.toggleVideoGravity()
            } label: {
                Image(systemName: viewModel
                    .videoGravity == .resizeAspect ? "aspectratio" :
                    "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
            }

            if viewModel.isPipPossible {
                Button {
                    viewModel.togglePip()
                } label: {
                    Image(systemName: viewModel.isPipActive ? "pip.exit" : "pip.enter")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                }
            }

            Button {
                viewModel.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Circle())
            }
        }
    }

    private func playerControlBar(channel: IPTVChannel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Text(channel.groupTitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Previous Channel
            Button {
                viewModel.playPreviousChannel()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())

            // Play / Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())

            // Next Channel
            Button {
                viewModel.playNextChannel()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())

            // Jump to Live
            Button {
                viewModel.jumpToLive()
            } label: {
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Section

    private func filtersHeaderSection() -> some View {
        VStack(spacing: 6) {
            // Preset Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.presets) { preset in
                        Button {
                            viewModel.loadChannels(for: preset)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: preset.icon)
                                    .font(.caption2)
                                Text(preset.title)
                                    .font(.caption)
                                    .fontWeight(viewModel.selectedPreset == preset && !viewModel
                                        .isCustomURLEnabled ? .bold : .regular)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedPreset == preset && !viewModel
                                .isCustomURLEnabled ? Color.blue : Color(.systemGray5))
                            .foregroundColor(viewModel.selectedPreset == preset && !viewModel
                                .isCustomURLEnabled ? .white : .primary)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(IPTVCategory.allCases) { cat in
                        Button {
                            viewModel.selectedCategory = cat
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10))
                                Text(cat.rawValue)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.selectedCategory == cat ? Color.secondary
                                .opacity(0.3) : Color.clear)
                            .cornerRadius(12)
                        }
                        .foregroundColor(viewModel.selectedCategory == cat ? .primary : .secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 6)

            Divider()
        }
    }

    private func channelCountHeader() -> some View {
        HStack {
            Text("\(viewModel.filteredChannels.count) Channels")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if viewModel.isCustomURLEnabled {
                Text("Custom M3U")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Channel List View

    private func channelListView() -> some View {
        List {
            ForEach(viewModel.filteredChannels) { channel in
                channelRow(channel: channel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.playChannel(channel)
                    }
            }
        }
        .listStyle(.plain)
    }

    private func channelRow(channel: IPTVChannel) -> some View {
        let isCurrent = viewModel.currentChannel == channel
        return HStack(spacing: 12) {
            // Channel Logo Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(width: 50, height: 50)

                if let logo = channel.logoURL {
                    AsyncImage(url: logo) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 42, height: 42)
                    } placeholder: {
                        Image(systemName: "tv")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "tv")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.name)
                        .font(.body)
                        .fontWeight(isCurrent ? .bold : .medium)
                        .foregroundColor(isCurrent ? .blue : .primary)
                        .lineLimit(1)

                    if let country = channel.country, !country.isEmpty {
                        Text(country.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(channel.groupTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let lang = channel.language, !lang.isEmpty {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(lang.uppercased())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isCurrent {
                Image(systemName: "waveform")
                    .font(.body)
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "play.circle")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - State Views

    private func loadingView() -> some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Fetching live channels from iptv-org...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Failed to Load Playlist")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                viewModel.loadChannels(for: viewModel.selectedPreset)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private func emptySearchResultsView() -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No Channels Found")
                .font(.headline)
            Text("Try refining your search keyword or switching category filter.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Custom URL Sheet

    private func customURLSheet() -> some View {
        NavigationStack {
            Form {
                Section("Custom M3U / M3U8 Playlist URL") {
                    TextField("https://example.com/playlist.m3u", text: $customURLInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section("Popular iptv-org Playlists") {
                    Button("Index (All Channels)") {
                        customURLInput = "https://iptv-org.github.io/iptv/index.m3u"
                    }
                    Button("Categories: News") {
                        customURLInput = "https://iptv-org.github.io/iptv/categories/news.m3u"
                    }
                    Button("Categories: Sports") {
                        customURLInput = "https://iptv-org.github.io/iptv/categories/sports.m3u"
                    }
                    Button("Categories: Music") {
                        customURLInput = "https://iptv-org.github.io/iptv/categories/music.m3u"
                    }
                    Button("Country: United States") {
                        customURLInput = "https://iptv-org.github.io/iptv/countries/us.m3u"
                    }
                    Button("Country: India") {
                        customURLInput = "https://iptv-org.github.io/iptv/countries/in.m3u"
                    }
                }
            }
            .navigationTitle("Load Custom M3U")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCustomURLSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Load") {
                        viewModel.customM3UURLString = customURLInput
                        viewModel.loadCustomPlaylist()
                        showingCustomURLSheet = false
                    }
                    .disabled(customURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
