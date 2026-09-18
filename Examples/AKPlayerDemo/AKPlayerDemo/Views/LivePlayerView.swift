//
//  LivePlayerView.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 18/09/26.
//

import SwiftUI
import AKPlayer
import AVFoundation

// MARK: - LivePlayerUIView

struct LivePlayerUIView: UIViewRepresentable {
    @ObservedObject var viewModel: LivePlayerViewModel
    
    func makeUIView(context: Context) -> AKPlayerView {
        let v = AKPlayerView()
        v.player = viewModel.player.player
        viewModel.setupPip(with: v.playerLayer)
        return v
    }
    
    func updateUIView(_ uiView: AKPlayerView, context: Context) {
        if uiView.player != viewModel.player.player {
            uiView.player = viewModel.player.player
        }
    }
    
    static func dismantleUIView(_ uiView: AKPlayerView, coordinator: ()) {
        uiView.player = nil
    }
}

// MARK: - LivePlayerView

public struct LivePlayerView: View {
    @StateObject public var viewModel = LivePlayerViewModel()
    
    public let initialMedia: AKMedia?
    public let autoPlay: Bool
    
    @State private var isScrubbing: Bool = false
    @State private var scrubOffset: Double = 0.0
    @State private var isPulseActive: Bool = false
    @State private var showCustomURLAlert: Bool = false
    @State private var customURLString: String = ""
    @State private var activeStreamTitle: String = "iReplay Live"
    
    @Environment(\.dismiss) private var dismiss
    
    public init(
        media: AKMedia? = nil,
        autoPlay: Bool = true
    ) {
        self.initialMedia = media
        self.autoPlay = autoPlay
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    videoPlayerContainer()
                    liveSyncHeroBanner()
                    dvrScrubberSection()
                    playbackControlsSection()
                    catchUpSpeedSection()
                    diagnosticsSection()
                    
                    if let msg = viewModel.unavailableMessage {
                        unavailableBanner(msg)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(activeStreamTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        viewModel.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(sampleTestMedia.filter { $0.kind == .live }) { liveMedia in
                                Button {
                                    activeStreamTitle = liveMedia.name
                                    if let akMedia = makeAKMedia(from: liveMedia) {
                                        viewModel.load(media: akMedia, autoPlay: true)
                                    }
                                } label: {
                                    Label(liveMedia.name, systemImage: "tv")
                                }
                            }
                            
                            Divider()
                            
                            Button {
                                showCustomURLAlert = true
                            } label: {
                                Label("Custom Stream URL...", systemImage: "link")
                            }
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                        }
                        
                        if viewModel.isPipPossible {
                            Button {
                                viewModel.togglePip()
                            } label: {
                                Image(systemName: viewModel.isPipActive ? "pip.exit" : "pip.enter")
                            }
                        }
                    }
                }
            }
            .alert("Load Custom Live Stream", isPresented: $showCustomURLAlert) {
                TextField("https://example.com/live/master.m3u8", text: $customURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Load") {
                    if let url = URL(string: customURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
                       !customURLString.isEmpty {
                        let customLive = TestMedia(
                            name: "Custom Live Stream",
                            subtitle: url.host,
                            url: url,
                            kind: .live
                        )
                        activeStreamTitle = "Custom Live Stream"
                        if let akMedia = makeAKMedia(from: customLive) {
                            viewModel.load(media: akMedia, autoPlay: true)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a valid HLS Live stream (.m3u8) URL:")
            }
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }
    
    // MARK: - Video Container
    
    @ViewBuilder
    private func videoPlayerContainer() -> some View {
        ZStack(alignment: .top) {
            LivePlayerUIView(viewModel: viewModel)
                .aspectRatio(16/9, contentMode: .fit)
                .background(Color.black)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Top overlay bar
            HStack {
                liveEdgeBadge()
                
                Spacer()
                
                if viewModel.presentationSize != .zero {
                    Text("\(Int(viewModel.presentationSize.width))x\(Int(viewModel.presentationSize.height))")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            
            // Loading Overlay
            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Syncing Live Stream...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
                .cornerRadius(14)
            }
        }
    }
    
    // MARK: - Live Edge Badge (Top Overlay)
    
    @ViewBuilder
    private func liveEdgeBadge() -> some View {
        if viewModel.isAtLiveEdge {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulseActive ? 1.3 : 0.9)
                    .opacity(isPulseActive ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulseActive)
                
                Text("LIVE")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.85))
            .clipShape(Capsule())
            .shadow(color: Color.red.opacity(0.5), radius: 6)
            .onAppear { isPulseActive = true }
        } else {
            Button {
                viewModel.jumpToLive()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text("JUMP TO LIVE (-\(formatTimeOffset(viewModel.liveOffset)))")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .foregroundColor(.orange)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Hero Live Sync Banner
    
    @ViewBuilder
    private func liveSyncHeroBanner() -> some View {
        if viewModel.isAtLiveEdge {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundColor(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watching Live Broadcast")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("Stream is synchronized at live head (<4s drift)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("0.0s Drift")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.orange)
                        Text("Behind Live Edge")
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                    }
                    Text("You are \(formatTimeOffset(viewModel.liveOffset)) behind live broadcast")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    viewModel.jumpToLive()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Jump to Live")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .shadow(color: Color.red.opacity(0.4), radius: 4)
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }
    
    // MARK: - DVR Scrubber Section
    
    @ViewBuilder
    private func dvrScrubberSection() -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("DVR Buffer Window")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let currentDrift = isScrubbing ? scrubOffset : -viewModel.liveOffset
                if abs(currentDrift) <= viewModel.liveEdgeThreshold {
                    Text("🔴 LIVE")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                } else {
                    Text(formatTimeOffset(abs(currentDrift)))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.orange)
                }
            }
            
            let minOffset = -max(1.0, viewModel.dvrWindowDuration)
            let maxOffset = 0.0
            
            Slider(
                value: Binding(
                    get: {
                        if isScrubbing {
                            return scrubOffset
                        } else {
                            return -min(viewModel.liveOffset, viewModel.dvrWindowDuration)
                        }
                    },
                    set: { newVal in
                        scrubOffset = newVal
                    }
                ),
                in: minOffset...maxOffset,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing {
                        viewModel.scrubDVR(offsetFromLive: scrubOffset)
                    }
                }
            )
            .tint(viewModel.isAtLiveEdge ? .red : .orange)
            
            HStack {
                Text("-\(formatSeconds(viewModel.dvrWindowDuration))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("LIVE")
                    .font(.caption2.bold())
                    .foregroundColor(viewModel.isAtLiveEdge ? .red : .secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Playback Controls Section
    
    @ViewBuilder
    private func playbackControlsSection() -> some View {
        HStack(spacing: 24) {
            // Rewind 15s in DVR
            Button {
                viewModel.seekBackward(seconds: 15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            // Play / Pause Toggle
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.stateDescription == "Playing" ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            
            // Skip 15s / Jump to Live
            Button {
                viewModel.seekForward(seconds: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            // Direct Jump to Live Button
            Button {
                viewModel.jumpToLive()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title3)
                    Text("Live Head")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(viewModel.isAtLiveEdge ? .red : .primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // MARK: - Catch-up Speed Controls
    
    @ViewBuilder
    private func catchUpSpeedSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Catch-Up Playback Rate")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2fx", viewModel.playbackRate.rate))
                    .font(.caption.monospacedDigit().bold())
            }
            
            HStack(spacing: 8) {
                ForEach([AKPlaybackRate.normal, .fast, .faster, .superfast], id: \.rate) { rate in
                    let isSelected = (viewModel.playbackRate.rate == rate.rate)
                    Button {
                        viewModel.setPlaybackRate(rate)
                    } label: {
                        Text(rate.title)
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
            
            Text("Tip: Speeding up to 1.25x or 1.5x allows catching up smoothly to the live head without jumping.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Diagnostics & Telemetry
    
    @ViewBuilder
    private func diagnosticsSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Stream Telemetry")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("State:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.stateDescription)
                        .font(.caption2.bold())
                    
                    Text("Drift / Lag:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fs", viewModel.liveOffset))
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundColor(viewModel.isAtLiveEdge ? .green : .orange)
                }
                
                GridRow {
                    Text("DVR Buffer:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fs", viewModel.dvrWindowDuration))
                        .font(.caption2.monospacedDigit())
                    
                    Text("Position:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fs", viewModel.currentTime))
                        .font(.caption2.monospacedDigit())
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Unavailable Banner
    
    @ViewBuilder
    private func unavailableBanner(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(msg)
                .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - Helpers & Setup
    
    private func setupPlayer() {
        if let media = initialMedia {
            activeStreamTitle = media.staticMetadata?.title ?? "Live Stream"
            viewModel.load(media: media, autoPlay: autoPlay)
        } else {
            // Default to 24/7 Live HLS Stream
            if let defaultLive = sampleTestMedia.first(where: { $0.kind == .live }),
               let media = makeAKMedia(from: defaultLive) {
                activeStreamTitle = defaultLive.name
                viewModel.load(media: media, autoPlay: autoPlay)
            }
        }
    }
    
    private func formatTimeOffset(_ seconds: Double) -> String {
        let s = Int(seconds)
        let mins = s / 60
        let secs = s % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func formatSeconds(_ seconds: Double) -> String {
        let s = Int(seconds)
        let mins = s / 60
        let secs = s % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Previews

struct LivePlayerView_Previews: PreviewProvider {
    static var previews: some View {
        LivePlayerView()
    }
}
