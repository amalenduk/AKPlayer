//
//   SimpleVideoPlayerView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import AVFoundation
import Combine
import Foundation
import SwiftUI

struct AKPlayerUIView: UIViewRepresentable {
    @ObservedObject var viewModel: SimpleVideoPlayerViewModel

    func makeUIView(context _: Context) -> AKPlayerView {
        let v = AKPlayerView()
        v.player = viewModel.player.player
        v.playerLayer.videoGravity = viewModel.videoGravity

        // Setup Picture-in-Picture controller using the AKPlayerView layer
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

public struct SimpleVideoPlayerView: View {
    @StateObject public var viewModel: SimpleVideoPlayerViewModel

    private let initialMedia: AKMedia?
    private let autoPlay: Bool

    @State private var showingRateDialog = false
    @State private var showingSelectionSheet = false
    @State private var showingChaptersSheet = false
    @State private var showingCustomAdsSheet = false

    @State private var isScrubbing = false
    @State private var scrubbingProgress = 0.0

    @Environment(\.dismiss) private var dismiss

    public init(
        media: AKMedia? = nil,
        autoPlay: Bool = false
    ) {
        _viewModel = StateObject(
            wrappedValue: SimpleVideoPlayerViewModel()
        )

        initialMedia = media
        self.autoPlay = autoPlay
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                playerSection()
                statusSection()

                if viewModel.isInterstitialActive {
                    interstitialBanner()
                }

                progressSection()
                playbackControlsSection()
                volumeSection()
                additionalControlsSection()
                mediaOptionsSection()
                unavailableMessageView()

                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                closeButton()
            }
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                viewModel.stop()
            }
            .sheet(
                isPresented: Binding(
                    get: { viewModel.debugInfo != nil },
                    set: {
                        if !$0 {
                            viewModel.debugInfo = nil
                        }
                    }
                )
            ) {
                infoSheet()
            }
            .sheet(isPresented: $showingSelectionSheet) {
                tracksSheet()
            }
            .sheet(isPresented: $showingChaptersSheet) {
                chaptersSheet()
            }
            .sheet(isPresented: $showingCustomAdsSheet) {
                CustomAdsManagerView(player: viewModel.player)
            }
        }
    }

    private func playerSection() -> some View {
        AKPlayerUIView(viewModel: viewModel)
            .frame(height: 260)
            .background(Color.black)
            .clipped()
    }

    private func statusSection() -> some View {
        HStack(spacing: 8) {
            Text("State: " + viewModel.stateDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView()
                .progressViewStyle(.circular)
                .frame(width: 20, height: 20)
                .opacity(viewModel.isLoading ? 1 : 0)
                .animation(
                    .easeInOut(duration: 0.15),
                    value: viewModel.isLoading
                )

            Spacer()

            Toggle(
                "Auto Play",
                isOn: Binding(
                    get: { viewModel.autoPlayEnabled },
                    set: { viewModel.autoPlayEnabled = $0 }
                )
            )
            .toggleStyle(.switch)
            .fixedSize()
        }
        .padding(.horizontal)
    }

    private func interstitialBanner() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "megaphone.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    "Ad: \(viewModel.interstitialIdentifier ?? "Playing") (\(viewModel.interstitialPlaybackState.description))"
                )
                .font(.caption)
                .fontWeight(.bold)

                if let progress = viewModel.interstitialProgress {
                    Text(
                        "Remaining: \(String(format: "%.1fs", progress.timeRemaining)) / Total: \(String(format: "%.1fs", progress.duration))"
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Skip") {
                viewModel.cancelInterstitial()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private func progressSection() -> some View {
        HStack {
            currentTimeLabel()
            progressSlider()
            durationLabel()
        }
        .padding(.horizontal)
    }

    private func currentTimeLabel() -> some View {
        Text(
            viewModel.currentTime.isFinite
                ? String(
                    format: "%02d:%02d",
                    Int(viewModel.currentTime) / 60,
                    Int(viewModel.currentTime) % 60
                )
                : "--:--"
        )
        .font(.caption)
    }

    private func durationLabel() -> some View {
        Text(
            viewModel.duration.isFinite
                ? String(
                    format: "%02d:%02d",
                    Int(viewModel.duration) / 60,
                    Int(viewModel.duration) % 60
                )
                : "--:--"
        )
        .font(.caption)
    }

    private func progressSlider() -> some View {
        AKProgressBar(
            currentTime: viewModel.currentTime,
            duration: viewModel.duration,
            bufferProgress: viewModel.duration > 0 ? (viewModel.currentTime + 10) / viewModel
                .duration : 0.0,
            markers: viewModel.adMarkers,
            onSeek: { targetSeconds in
                viewModel.seek(to: targetSeconds)
            }
        )
    }

    private func playbackControlsSection() -> some View {
        VStack(spacing: 8) {
            primaryPlaybackControls()
            seekControls()
        }
        .padding(.horizontal)
    }

    private func primaryPlaybackControls() -> some View {
        HStack(spacing: 12) {
            playButton()
            pauseButton()
            stopButton()
        }
    }

    private func playButton() -> some View {
        Button {
            viewModel.play()
        } label: {
            Image(systemName: "play.fill")
                .font(.title3)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    private func pauseButton() -> some View {
        Button {
            viewModel.pause()
        } label: {
            Image(systemName: "pause.fill")
                .font(.title3)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    private func stopButton() -> some View {
        Button {
            viewModel.stop()
        } label: {
            Image(systemName: "stop.fill")
                .font(.title3)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
    }

    private func seekControls() -> some View {
        HStack(
            alignment: .center,
            spacing: 12
        ) {
            backwardTenButton()
            previousFrameButton()
            nextFrameButton()
            forwardTenButton()
        }
    }

    private func backwardTenButton() -> some View {
        Button {
            viewModel.seekOffset(-10)
        } label: {
            Image(systemName: "gobackward.10")
                .font(.body)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
    }

    private func previousFrameButton() -> some View {
        Button {
            viewModel.step(by: -1)
        } label: {
            Image(systemName: "backward.frame")
                .font(.body)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
    }

    private func nextFrameButton() -> some View {
        Button {
            viewModel.step(by: 1)
        } label: {
            Image(systemName: "forward.frame")
                .font(.body)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
    }

    private func forwardTenButton() -> some View {
        Button {
            viewModel.seekOffset(10)
        } label: {
            Image(systemName: "goforward.10")
                .font(.body)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
    }

    private func volumeSection() -> some View {
        HStack {
            Text("Volume")
                .font(.caption)

            Slider(
                value: Binding(
                    get: {
                        Double(viewModel.volume)
                    },
                    set: {
                        viewModel.setVolume(Float($0))
                    }
                ),
                in: 0 ... 1
            )

            muteButton()
        }
        .padding(.horizontal)
    }

    private func muteButton() -> some View {
        Button {
            viewModel.toggleMute()
        } label: {
            Image(
                systemName: viewModel.isMuted
                    ? "speaker.slash.fill"
                    : "speaker.wave.2.fill"
            )
            .font(.body)
            .frame(width: 30, height: 30)
        }
    }

    private func additionalControlsSection() -> some View {
        HStack(
            alignment: .center,
            spacing: 8
        ) {
            aspectRatioButton()
            subtitlesButton()
            if viewModel.isPipPossible {
                pipButton()
            }
            playbackRateButton()
            loadButton()
        }
        .padding(.horizontal)
    }

    private func aspectRatioButton() -> some View {
        Button {
            viewModel.toggleVideoGravity()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: viewModel
                    .videoGravity == .resizeAspect ? "aspectratio" :
                    (viewModel
                        .videoGravity == .resizeAspectFill ? "arrow.up.left.and.arrow.down.right" :
                        "arrow.left.and.right"))
                Text(viewModel
                    .videoGravity == .resizeAspect ? "Fit" :
                    (viewModel.videoGravity == .resizeAspectFill ? "Fill" : "Stretch"))
                    .font(.caption2)
            }
        }
        .buttonStyle(.bordered)
    }

    private func subtitlesButton() -> some View {
        Button {
            viewModel.toggleQuickSubtitles()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: viewModel
                    .isSubtitleEnabled ? "captions.bubble.fill" : "captions.bubble")
                Text(viewModel
                    .isSubtitleEnabled ? (viewModel.activeSubtitleLanguage ?? "CC") : "CC")
                    .font(.caption2)
            }
            .foregroundColor(viewModel.isSubtitleEnabled ? .yellow : .primary)
        }
        .buttonStyle(.bordered)
    }

    private func pipButton() -> some View {
        Button {
            viewModel.togglePip()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: viewModel.isPipActive ? "pip.exit" : "pip.enter")
                Text("PiP")
                    .font(.caption2)
            }
        }
        .buttonStyle(.bordered)
    }

    private func playbackRateButton() -> some View {
        Button {
            showingRateDialog = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "speedometer")
                Text(viewModel.playbackRate.rateTitle)
                    .font(.caption2)
            }
        }
        .buttonStyle(.bordered)
        .confirmationDialog(
            "Playback Rate",
            isPresented: $showingRateDialog,
            titleVisibility: .visible
        ) {
            ForEach(
                AKPlaybackRate.allCases,
                id: \.title
            ) { rate in
                Button(rate.title) {
                    viewModel.setRate(rate)
                }
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadButton() -> some View {
        Button {
            guard let initialMedia else { return }
            viewModel.load(media: initialMedia, autoPlay: viewModel.autoPlayEnabled)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.clockwise")
                Text("Reload")
                    .font(.caption2)
            }
        }
        .buttonStyle(.bordered)
    }

    private func mediaOptionsSection() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(
                alignment: .center,
                spacing: 8
            ) {
                customAdsButton()
                chaptersButton()
                tracksButton()
                infoButton()
            }
            .padding(.horizontal)
        }
    }

    private func customAdsButton() -> some View {
        Button {
            showingCustomAdsSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "badge.plus.radiowaves.right")
                Text("Add Ads")
            }
            .foregroundColor(.orange)
        }
        .buttonStyle(.bordered)
    }

    private func chaptersButton() -> some View {
        Button {
            viewModel.refreshChapters()
            showingChaptersSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "book.pages")
                Text(viewModel.chapters
                    .isEmpty ? "Chapters" : "Chapters (\(viewModel.chapters.count))")
            }
        }
        .buttonStyle(.bordered)
    }

    private func tracksButton() -> some View {
        Button {
            viewModel.refreshSelectionGroups()
            showingSelectionSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "waveform.badge.magnifyingglass")
                Text("Tracks")
            }
        }
        .buttonStyle(.bordered)
    }

    private func infoButton() -> some View {
        Button {
            let desc = viewModel.player.currentMedia?.description ?? "n/a"
            viewModel.debugInfo = "Asset: " + desc
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                Text("Info")
            }
        }
        .buttonStyle(.bordered)
    }

    private func unavailableMessageView() -> some View {
        HStack {
            Text(viewModel.unavailableMessage ?? "")
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .frame(height: 28)
        .padding(.horizontal)
    }

    @ToolbarContentBuilder
    private func closeButton() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
        }
    }

    private func setupPlayer() {
        if let media = initialMedia {
            viewModel.load(
                media: media,
                autoPlay: autoPlay
            )
        }
    }
}

extension SimpleVideoPlayerView {
    func infoSheet() -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.debugInfo ?? "")
                    .padding()

                Spacer()
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        viewModel.debugInfo = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func tracksSheet() -> some View {
        NavigationStack {
            List {
                if viewModel.selectionGroups.isEmpty {
                    ContentUnavailableView(
                        "No Tracks Available",
                        systemImage: "waveform.slash",
                        description: Text(
                            "No alternative audio or subtitle tracks were found for this media."
                        )
                    )
                } else {
                    ForEach(viewModel.selectionGroups) { group in
                        Section {
                            ForEach(group.options) { option in
                                trackOptionRow(option, in: group)
                            }
                        } header: {
                            Text(group.title)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        showingSelectionSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func trackOptionRow(
        _ option: SimpleVideoPlayerViewModel.SelectionOption,
        in group: SimpleVideoPlayerViewModel.SelectionGroup
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.option.title)
                    .font(.body)

                if !option.option.languageCode.isEmpty {
                    Text(option.option.languageCode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if option.isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.select(
                option: option,
                in: group
            )
        }
    }

    func chaptersSheet() -> some View {
        NavigationStack {
            List {
                if viewModel.chapters.isEmpty {
                    ContentUnavailableView(
                        "No Chapters Available",
                        systemImage: "book.closed",
                        description: Text("No embedded chapters were found in this media item.")
                    )
                } else {
                    ForEach(viewModel.chapters) { chapter in
                        chapterRow(chapter)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(viewModel.chapters
                .isEmpty ? "Chapters" : "Chapters (\(viewModel.chapters.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        showingChaptersSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    func chapterRow(_ chapter: AKChapter) -> some View {
        let isCurrent = viewModel.currentChapter == chapter
        HStack(spacing: 12) {
            if let artwork = chapter.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isCurrent ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
                        .frame(width: 40, height: 40)

                    Text("\(chapter.id)")
                        .font(.headline)
                        .foregroundColor(isCurrent ? .accentColor : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(chapter.title)
                        .font(.body)
                        .fontWeight(isCurrent ? .bold : .regular)
                        .foregroundColor(isCurrent ? .accentColor : .primary)
                        .lineLimit(2)

                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("\(formatTime(chapter.startTime)) - \(formatTime(chapter.endTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Duration: \(formatTime(chapter.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isCurrent {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
                    .font(.body)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectChapter(chapter)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN else { return "00:00" }
        let totalSec = Int(seconds)
        let hours = totalSec / 3600
        let minutes = (totalSec % 3600) / 60
        let secs = totalSec % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

struct SimpleVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleVideoPlayerView()
    }
}
