//
//   AudiobookPlayerView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import AVFoundation
import SwiftUI

public struct AudiobookPlayerView: View {
    @StateObject public var viewModel: AudiobookPlayerViewModel
    private let media: AKMedia?
    private let autoPlay: Bool

    @State private var showingChaptersSheet = false
    @State private var showingRateDialog = false
    @State private var showingSleepTimerSheet = false
    @State private var showingCustomAdsSheet = false
    @State private var isScrubbing = false
    @State private var scrubbingValue = 0.0

    @Environment(\.dismiss) private var dismiss

    public init(media: AKMedia? = nil, autoPlay: Bool = true) {
        _viewModel = StateObject(wrappedValue: AudiobookPlayerViewModel())
        self.media = media
        self.autoPlay = autoPlay
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [Color.indigo.opacity(0.3), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header Bar
                    headerBar()

                    Spacer()

                    // Artwork / Book Cover
                    artworkSection()

                    // Titles & Chapter Indicator
                    titleSection()

                    Spacer()

                    // Scrubber / Progress Bar
                    progressSection()

                    // Main Playback Controls (15s back, Play/Pause, 30s forward, Chapter Skip)
                    controlsSection()

                    // Bottom Utility Bar (Speed, Chapters, Sleep Timer)
                    bottomUtilityBar()

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .onAppear {
                if let media {
                    viewModel.load(media: media, autoPlay: autoPlay)
                }
            }
            .onDisappear {
                viewModel.stop()
            }
            .sheet(isPresented: $showingChaptersSheet) {
                chaptersSheet()
            }
            .sheet(isPresented: $showingSleepTimerSheet) {
                sleepTimerSheet()
            }
            .sheet(isPresented: $showingCustomAdsSheet) {
                CustomAdsManagerView(player: viewModel.player)
            }
            .confirmationDialog(
                "Playback Speed",
                isPresented: $showingRateDialog,
                titleVisibility: .visible
            ) {
                ForEach(AKPlaybackRate.allCases, id: \.self) { rate in
                    Button(rate.title) {
                        viewModel.setRate(rate)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Header Bar

    private func headerBar() -> some View {
        HStack {
            Button {
                viewModel.stop()
                dismiss()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Text("AUDIOBOOK / PODCAST")
                .font(.caption2.bold())
                .tracking(2)
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            // AirPlay / Route Picker
            AKAirPlayRoutePickerView(
                tintColor: .white.withAlphaComponent(0.8),
                activeTintColor: .systemYellow
            )
            .frame(width: 32, height: 32)
        }
        .padding(.top, 8)
    }

    // MARK: - Artwork Section

    private func artworkSection() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.5), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 260, height: 260)
                .shadow(color: Color.purple.opacity(0.4), radius: 25, x: 0, y: 12)

            VStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))

                if let current = viewModel.currentChapter {
                    Text(current.title)
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                }
            }
        }
        .scaleEffect(viewModel.isPlaying ? 1.0 : 0.94)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.isPlaying)
    }

    // MARK: - Title Section

    private func titleSection() -> some View {
        VStack(spacing: 6) {
            Text(viewModel.media?.staticMetadata?.title ?? "Audiobook Title")
                .font(.title3.bold())
                .foregroundColor(.white)
                .lineLimit(1)

            if let subtitle = viewModel.media?.staticMetadata?.artist {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            if let currentChapter = viewModel.currentChapter {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text(
                        "Chapter \(viewModel.currentChapterIndex + 1) of \(viewModel.chapters.count): \(currentChapter.title)"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundColor(.yellow.opacity(0.9))
                    .lineLimit(1)
                }
                .padding(.top, 4)
            }

            if viewModel.isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                        .scaleEffect(0.7)
                    Text(viewModel.stateDescription.uppercased())
                        .font(.caption2.bold())
                        .foregroundColor(.yellow)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Progress Section

    private func progressSection() -> some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubbingValue : viewModel.currentTime },
                    set: { scrubbingValue = $0 }
                ),
                in: 0 ... max(1, viewModel.duration),
                onEditingChanged: { editing in
                    if editing {
                        scrubbingValue = viewModel.currentTime
                        isScrubbing = true
                    } else {
                        viewModel.seek(to: scrubbingValue)
                        isScrubbing = false
                    }
                }
            )
            .tint(.yellow)

            HStack {
                Text(formatTime(isScrubbing ? scrubbingValue : viewModel.currentTime))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if viewModel.duration > 0 {
                    let remaining = viewModel
                        .duration - (isScrubbing ? scrubbingValue : viewModel.currentTime)
                    Text("-\(formatTime(max(0, remaining)))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Controls Section

    private func controlsSection() -> some View {
        HStack(spacing: 28) {
            // Previous Chapter
            Button {
                viewModel.previousChapter()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(viewModel.currentChapterIndex > 0 ? 0.9 : 0.3))
            }
            .disabled(viewModel.chapters.isEmpty)

            // Skip 15s Back
            Button {
                viewModel.skipBackward15()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            // Play / Pause Button with Loading Indicator
            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 68, height: 68)
                        .shadow(color: Color.yellow.opacity(0.4), radius: 10, x: 0, y: 4)

                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.black)
                            .offset(x: viewModel.isPlaying ? 0 : 2)
                    }
                }
            }

            // Skip 30s Forward
            Button {
                viewModel.skipForward30()
            } label: {
                Image(systemName: "goforward.30")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            // Next Chapter
            Button {
                viewModel.nextChapter()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title3)
                    .foregroundColor(.white
                        .opacity(viewModel.currentChapterIndex + 1 < viewModel.chapters
                            .count ? 0.9 : 0.3))
            }
            .disabled(viewModel.chapters.isEmpty)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Utility Bar

    private func bottomUtilityBar() -> some View {
        HStack {
            // Playback Speed
            Button {
                showingRateDialog = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                    Text(viewModel.playbackRate.rateTitle)
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .foregroundColor(.white)
                .clipShape(Capsule())
            }

            Spacer()

            // Chapters List Button
            Button {
                showingChaptersSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    Text("Chapters (\(viewModel.chapters.count))")
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .disabled(viewModel.chapters.isEmpty)

            Spacer()

            // Custom Ads Button
            Button {
                showingCustomAdsSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "badge.plus.radiowaves.right")
                    Text("Ads")
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.25))
                .foregroundColor(.orange)
                .clipShape(Capsule())
            }

            Spacer()

            // Sleep Timer
            Button {
                showingSleepTimerSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel
                        .sleepTimerOption == .off ? "moon.zzz" : "moon.zzz.fill")
                    if viewModel.sleepTimerRemainingSeconds > 0 {
                        Text("\(viewModel.sleepTimerRemainingSeconds / 60)m")
                            .fontWeight(.semibold)
                    } else {
                        Text("Sleep")
                            .fontWeight(.semibold)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(viewModel.sleepTimerOption == .off ? Color.white.opacity(0.15) : Color
                    .yellow.opacity(0.3))
                .foregroundColor(viewModel.sleepTimerOption == .off ? .white : .yellow)
                .clipShape(Capsule())
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Chapters Sheet

    private func chaptersSheet() -> some View {
        NavigationStack {
            List {
                ForEach(
                    Array(viewModel.chapters.enumerated()),
                    id: \.element.title
                ) { index, chapter in
                    Button {
                        viewModel.jumpTo(chapter: chapter)
                        showingChaptersSheet = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(index + 1). \(chapter.title)")
                                    .font(.body)
                                    .foregroundColor(chapter.title == viewModel.currentChapter?
                                        .title ? .yellow : .primary)
                                    .fontWeight(chapter.title == viewModel.currentChapter?
                                        .title ? .bold : .regular)

                                Text("Starts at \(formatTime(chapter.timeRange.start.seconds))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if chapter.title == viewModel.currentChapter?.title {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingChaptersSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sleep Timer Sheet

    private func sleepTimerSheet() -> some View {
        NavigationStack {
            List {
                ForEach(AudiobookPlayerViewModel.SleepTimerOption.allCases) { option in
                    Button {
                        viewModel.setSleepTimer(option)
                        showingSleepTimerSheet = false
                    } label: {
                        HStack {
                            Text(option.rawValue)
                                .foregroundColor(.primary)

                            Spacer()

                            if viewModel.sleepTimerOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingSleepTimerSheet = false }
                }
            }
        }
        .presentationDetents([.height(340)])
    }

    // MARK: - Helper

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}
