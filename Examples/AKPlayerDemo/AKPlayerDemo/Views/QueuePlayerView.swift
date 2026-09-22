//
//   QueuePlayerView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import AVFoundation
import SwiftUI

struct AKQueuePlayerUIView: UIViewRepresentable {
    @ObservedObject var viewModel: QueuePlayerViewModel

    func makeUIView(context _: Context) -> AKPlayerView {
        let v = AKPlayerView()
        v.player = viewModel.queuePlayer.player
        return v
    }

    func updateUIView(_ uiView: AKPlayerView, context _: Context) {
        if uiView.player != viewModel.queuePlayer.player {
            uiView.player = viewModel.queuePlayer.player
        }
    }

    static func dismantleUIView(_ uiView: AKPlayerView, coordinator _: ()) {
        uiView.player = nil
    }
}

public struct QueuePlayerView: View {
    @StateObject public var viewModel = QueuePlayerViewModel()

    public let initialMedias: [TestMedia]
    public let initialIndex: Int

    @State private var isScrubbing = false
    @State private var scrubbingProgress = 0.0
    @Environment(\.dismiss) private var dismiss

    public init(
        medias: [TestMedia] = sampleTestMedia,
        startIndex: Int = 0
    ) {
        initialMedias = medias
        initialIndex = startIndex
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Player Area
                playerHeroSection()
                    .padding(.bottom, 8)

                // Track Info & Progress
                nowPlayingInfoSection()

                // Playback & Queue Controls
                queueControlsSection()
                    .padding(.vertical, 8)

                Divider()

                // Up Next Queue List
                queueListSection()
            }
            .navigationTitle("Queue Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                viewModel.loadQueue(with: initialMedias, startIndex: initialIndex)
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }

    // MARK: - Player Hero

    private func playerHeroSection() -> some View {
        ZStack {
            AKQueuePlayerUIView(viewModel: viewModel)
                .frame(height: 200)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.3)
            }
        }
    }

    // MARK: - Now Playing Info

    private func nowPlayingInfoSection() -> some View {
        VStack(spacing: 6) {
            let currentItem = currentTestMedia()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentItem?.name ?? "No Media Playing")
                        .font(.headline)
                        .lineLimit(1)

                    Text(currentItem?.subtitle ?? viewModel.stateDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(viewModel.stateDescription)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateBadgeColor().opacity(0.15))
                    .foregroundColor(stateBadgeColor())
                    .cornerRadius(6)
            }
            .padding(.horizontal)

            // Timeline Scrubber
            HStack(spacing: 8) {
                Text(formatTime(viewModel.currentTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .leading)

                Slider(
                    value: Binding<Double>(
                        get: {
                            isScrubbing ? scrubbingProgress :
                                (viewModel.duration > 0 ? viewModel.currentTime / viewModel
                                    .duration : 0.0)
                        },
                        set: { scrubbingProgress = $0 }
                    ),
                    in: 0 ... 1,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            let target = scrubbingProgress * max(1.0, viewModel.duration)
                            viewModel.seek(to: target)
                        }
                    }
                )
                .accentColor(.blue)

                Text(formatTime(viewModel.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Queue Controls

    private func queueControlsSection() -> some View {
        HStack(spacing: 24) {
            // Shuffle Button
            Button {
                viewModel.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(viewModel.isShuffleEnabled ? .accentColor : .secondary)
            }

            // Previous Track Button
            Button {
                viewModel.previous()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.canPlayPrevious ? .primary : .secondary.opacity(0.4))
            }
            .disabled(!viewModel.canPlayPrevious)

            // Play / Pause Circular Button
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
            }

            // Next Track Button
            Button {
                viewModel.next()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.canPlayNext ? .primary : .secondary.opacity(0.4))
            }
            .disabled(!viewModel.canPlayNext)

            // Repeat Mode Button
            Button {
                viewModel.toggleRepeat()
            } label: {
                Image(systemName: repeatIconName())
                    .font(.title3)
                    .foregroundColor(viewModel.repeatMode != .off ? .accentColor : .secondary)
            }
        }
    }

    // MARK: - Up Next Queue List

    private func queueListSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Up Next")
                    .font(.headline)

                Text("(\(viewModel.playlist.count) items)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                EditButton()
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                ForEach(Array(viewModel.playlist.enumerated()), id: \.element.id) { index, item in
                    let isCurrent = (viewModel.currentIndex == index)

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isCurrent ? Color.accentColor
                                    .opacity(0.15) : Color(.systemGray5))
                                .frame(width: 36, height: 36)

                            if isCurrent, viewModel.isPlaying {
                                Image(systemName: "waveform")
                                    .font(.footnote)
                                    .foregroundColor(.accentColor)
                            } else {
                                Text("\(index + 1)")
                                    .font(.footnote)
                                    .fontWeight(isCurrent ? .bold : .regular)
                                    .foregroundColor(isCurrent ? .accentColor : .secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(isCurrent ? .bold : .regular)
                                .foregroundColor(isCurrent ? .accentColor : .primary)
                                .lineLimit(1)

                            if let sub = item.subtitle {
                                Text(sub)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if isCurrent {
                            Text("Playing")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.jumpTo(index: index)
                    }
                }
                .onDelete { indexSet in
                    if let first = indexSet.first {
                        viewModel.removeItem(at: first)
                    }
                }
                .onMove { source, dest in
                    viewModel.moveItem(from: source, to: dest)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func currentTestMedia() -> TestMedia? {
        guard let idx = viewModel.currentIndex, viewModel.playlist.indices.contains(idx) else {
            return nil
        }
        return viewModel.playlist[idx]
    }

    private func repeatIconName() -> String {
        switch viewModel.repeatMode {
        case .off: "repeat"
        case .all: "repeat"
        case .one: "repeat.1"
        }
    }

    private func stateBadgeColor() -> Color {
        switch viewModel.queuePlayer.state {
        case .playing: .green
        case .paused: .blue
        case .buffering, .loading: .orange
        case .failed: .red
        default: .secondary
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN else { return "00:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct QueuePlayerView_Previews: PreviewProvider {
    static var previews: some View {
        QueuePlayerView()
    }
}
