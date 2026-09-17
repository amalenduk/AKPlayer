//
//  SimpleVideoPlayerView.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 02/09/26.
//

import SwiftUI
import AKPlayer
import AVFoundation
import Combine
import Foundation

struct AKPlayerUIView: UIViewRepresentable {
    
    @ObservedObject var viewModel: SimpleVideoPlayerViewModel
    
    func makeUIView(context: Context) -> AKPlayerView {
        let v = AKPlayerView()
        v.player = viewModel.player.player
        
        // Setup Picture-in-Picture controller using the AKPlayerView layer[cite: 3, 4]
        viewModel.setupPip(with: v.playerLayer)
        
        return v
    }
    
    func updateUIView(_ uiView: AKPlayerView, context: Context) {
        uiView.player = viewModel.player.player
    }
}

public struct SimpleVideoPlayerView: View {
    
    @StateObject public var viewModel: SimpleVideoPlayerViewModel
    
    private let initialMedia: AKMedia?
    private let autoPlay: Bool
    
    @State private var showingRateDialog = false
    @State private var showingSelectionSheet = false
    
    @State private var isScrubbing: Bool = false
    @State private var scrubbingProgress: Double = 0.0
    
    @Environment(\.dismiss) private var dismiss
    
    public init(
        media: AKMedia? = nil,
        autoPlay: Bool = false
    ) {
        _viewModel = StateObject(
            wrappedValue: SimpleVideoPlayerViewModel()
        )
        
        self.initialMedia = media
        self.autoPlay = autoPlay
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                playerSection()
                statusSection()
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
        }
    }
    
    @ViewBuilder
    private func playerSection() -> some View {
        AKPlayerUIView(viewModel: viewModel)
            .frame(height: 260)
            .background(Color.black)
            .clipped()
    }
    
    @ViewBuilder
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
                    get: {
                        viewModel.autoPlayEnabled
                    },
                    set: {
                        viewModel.autoPlayEnabled = $0
                    }
                )
            )
            .toggleStyle(.switch)
            .fixedSize()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func progressSection() -> some View {
        HStack {
            currentTimeLabel()
            
            progressSlider()
            
            durationLabel()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
    private func progressSlider() -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                progressBackground()
                
                currentProgressView(width: geo.size.width)
                
                seekSlider()
            }
        }
        .frame(height: 30)
    }
    
    @ViewBuilder
    private func progressBackground() -> some View {
        Capsule()
            .fill(Color(.systemGray5))
            .frame(height: 4)
    }
    
    @ViewBuilder
    private func currentProgressView(width: CGFloat) -> some View {
        let progress = viewModel.duration > 0
        ? viewModel.currentTime / viewModel.duration
        : 0
        
        Rectangle()
            .fill(Color.accentColor)
            .frame(
                width: width * CGFloat(min(1, progress)),
                height: 4
            )
            .animation(
                .linear,
                value: viewModel.currentTime
            )
    }
    
    @ViewBuilder
    private func seekSlider() -> some View {
        let currentFraction = viewModel.duration > 0
        ? viewModel.currentTime / viewModel.duration
        : 0.0
        
        Slider(
            value: Binding<Double>(
                get: {
                    // Display local scrubbing position while dragging; otherwise display real playback position
                    isScrubbing ? scrubbingProgress : currentFraction
                },
                set: { newFraction in
                    scrubbingProgress = newFraction
                }
            ),
            in: 0...1,
            onEditingChanged: { editing in
                isScrubbing = editing
                if !editing {
                    // User stopped scrubbing (touch released) -> trigger actual seek
                    let targetSeconds = scrubbingProgress * max(1.0, viewModel.duration)
                    viewModel.seek(to: targetSeconds)
                }
            }
        )
        .accentColor(.clear)
        .opacity(0.99)
        .frame(height: 30)
    }
    
    @ViewBuilder
    private func playbackControlsSection() -> some View {
        VStack(spacing: 8) {
            primaryPlaybackControls()
            seekControls()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func primaryPlaybackControls() -> some View {
        HStack(spacing: 12) {
            playButton()
            pauseButton()
            stopButton()
        }
    }
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
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
    
    @ViewBuilder
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
                in: 0...1
            )
            
            muteButton()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
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
    
    @ViewBuilder
    private func additionalControlsSection() -> some View {
        HStack(
            alignment: .center,
            spacing: 12
        ) {
            playbackRateButton()
            loadButton()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func playbackRateButton() -> some View {
        Button {
            showingRateDialog = true
        } label: {
            HStack {
                Image(systemName: "speedometer")
                Text(viewModel.playbackRate.rateTitle)
            }
        }
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
    
    @ViewBuilder
    private func loadButton() -> some View {
        Button("Load") {
            guard let initialMedia else { return }
            viewModel.load(media: initialMedia, autoPlay: viewModel.autoPlayEnabled)
        }
        .buttonStyle(.bordered)
    }
    
    @ViewBuilder
    private func mediaOptionsSection() -> some View {
        HStack(
            alignment: .center,
            spacing: 12
        ) {
            tracksButton()
            infoButton()
            testButton()
            test2Button()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func tracksButton() -> some View {
        Button("Tracks") {
            viewModel.refreshSelectionGroups()
            showingSelectionSheet = true
        }
    }
    
    @ViewBuilder
    private func infoButton() -> some View {
        Button("Info") {
            let desc =
            viewModel.player.currentMedia?.description
            ?? "n/a"
            
            viewModel.debugInfo = "Asset: " + desc
        }
    }
    
    @ViewBuilder
    private func testButton() -> some View {
        Button("Test") {
            viewModel.interstitialService.interstitialPlayer?.pause()
        }
    }
    
    @ViewBuilder
    private func test2Button() -> some View {
        Button("Test") {
            viewModel.interstitialService.cancelCurrent(resumptionOffset: .zero)
        }
    }
    
    @ViewBuilder
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
        viewModel.loadAndObserveCurrentTime()
        
        if autoPlay {
            if let media = initialMedia {
                viewModel.load(
                    media: media,
                    autoPlay: autoPlay
                )
            }
        }
    }
}

extension SimpleVideoPlayerView {
    
    @ViewBuilder
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
    }
    
    @ViewBuilder
    func tracksSheet() -> some View {
        NavigationStack {
            List {
                if viewModel.selectionGroups.isEmpty {
                    ContentUnavailableView(
                        "No Tracks Available",
                        systemImage: "waveform.slash",
                        description: Text("No alternative audio or subtitle tracks were found for this media.")
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
    }
    
    @ViewBuilder
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
}

struct SimpleVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleVideoPlayerView()
    }
}
