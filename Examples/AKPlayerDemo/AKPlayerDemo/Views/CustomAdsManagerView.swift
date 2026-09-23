//
//   CustomAdsManagerView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import AVFoundation
import CoreMedia
import SwiftUI

// MARK: - Ad Preset Model

public struct AdPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let urlString: String
    public let durationDescription: String

    public static let samplePresets: [AdPreset] = [
        AdPreset(
            id: "bipbop_4x3",
            title: "Apple BipBop 4:3 (10s HLS)",
            subtitle: "Standard HLS test ad stream",
            urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8",
            durationDescription: "~10 seconds"
        ),
        AdPreset(
            id: "bipbop_16x9",
            title: "Apple BipBop 16:9 (15s HLS)",
            subtitle: "Widescreen HLS test ad stream",
            urlString: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
            durationDescription: "~15 seconds"
        ),
        AdPreset(
            id: "bbb_teaser",
            title: "Big Buck Bunny Teaser (10s MP4)",
            subtitle: "Short video commercial",
            urlString: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
            durationDescription: "~15 seconds"
        ),
        AdPreset(
            id: "custom",
            title: "Custom Stream URL",
            subtitle: "Enter custom HLS/MP4 URL",
            urlString: "",
            durationDescription: "User defined"
        ),
    ]
}

// MARK: - Staged Ad Item

public struct StagedAdItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var identifier: String
    public var urlString: String
    public var scheduledTimeSeconds: Double
    public var timelineOccupancy: AVPlayerInterstitialEvent.TimelineOccupancy
    public var playoutLimitSeconds: Double? // nil = unlimited (.invalid)
    public var resumptionOffsetSeconds: Double
    public var constrainsSeekingForward: Bool
    public var requiresLinearPlayback: Bool
    public var supplementsPrimaryContent: Bool
    public var contentMayVary: Bool

    public var formattedTime: String {
        let totalSeconds = Int(scheduledTimeSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - CustomAdsManagerViewModel

@MainActor
public final class CustomAdsManagerViewModel: ObservableObject {
    // MARK: - Properties

    public let player: AKPlayer

    @Published public var currentTime = 0.0
    @Published public var mediaDuration = 0.0
    @Published public var mediaTitle = "Media"

    // Form inputs with complete default values
    @Published public var selectedPreset = AdPreset.samplePresets[0]
    @Published public var customURLString = ""
    @Published public var adIdentifier = "Ad-Midroll-1"
    @Published public var scheduledTimeSeconds = 30.0
    @Published public var timelineOccupancy: AVPlayerInterstitialEvent
        .TimelineOccupancy = .singlePoint
    @Published public var hasPlayoutLimit = false
    @Published public var playoutLimitSeconds = 15.0
    @Published public var resumptionOffsetSeconds = 0.0
    @Published public var constrainsSeekingForward = false
    @Published public var requiresLinearPlayback = false
    @Published public var supplementsPrimaryContent = false
    @Published public var contentMayVary = true

    /// Multi-ad staging queue
    @Published public var stagedAds: [StagedAdItem] = []

    /// Live scheduled events
    @Published public var liveScheduledEvents: [AVPlayerInterstitialEvent] = []

    // Feedback message
    @Published public var statusMessage: String?
    @Published public var isSuccessMessage = true

    // MARK: - Initialization

    public init(player: AKPlayer) {
        self.player = player
        refreshPlayerState()
        applyDefaultTiming()
    }

    // MARK: - Player State & Timing Rules

    public func refreshPlayerState() {
        let rawCurrent = player.currentTime.seconds
        currentTime = (rawCurrent.isFinite && !rawCurrent.isNaN) ? max(0, rawCurrent) : 0.0

        let rawDuration = player.currentItemDuration.seconds
        mediaDuration = (rawDuration.isFinite && !rawDuration.isNaN) ? max(0, rawDuration) : 0.0

        if let currentMedia = player.currentMedia {
            if let title = currentMedia.staticMetadata?.title, !title.isEmpty {
                mediaTitle = title
            } else if !currentMedia.url.lastPathComponent.isEmpty {
                mediaTitle = currentMedia.url.lastPathComponent
            } else {
                mediaTitle = "Active Stream"
            }
        }
        liveScheduledEvents = player.interstitialService.scheduledEvents
    }

    /// Calculates the minimum allowed scheduled time according to the 30-second rule.
    /// - If current time is near zero (<= 0.5s), pre-roll (0s) and any time >= 0 is allowed.
    /// - If playback has started (> 0.5s), time must be at least currentTime + 30s.
    public var minimumAllowedTime: Double {
        if currentTime <= 0.5 {
            return 0.0
        }
        return currentTime + 30.0
    }

    /// Enforces that the scheduled time satisfies the 30-second rule, pushing it to the minimum if
    /// below.
    public func enforceTimingRule() {
        if scheduledTimeSeconds < minimumAllowedTime {
            scheduledTimeSeconds = minimumAllowedTime
            statusMessage = "Time automatically adjusted to +30s rule (\(formatSeconds(minimumAllowedTime)))"
            isSuccessMessage = true
        }
    }

    /// Sets default values based on current playback position.
    public func applyDefaultTiming() {
        refreshPlayerState()
        scheduledTimeSeconds = minimumAllowedTime
        let nextIndex = (player.interstitialService.scheduledEvents.count + stagedAds.count + 1)
        adIdentifier = currentTime <= 0.5 ? "Preroll-Ad-\(nextIndex)" : "Midroll-Ad-\(nextIndex)"
        if selectedPreset.id != "custom" {
            customURLString = selectedPreset.urlString
        }
    }

    // MARK: - Quick Time Helpers

    public func setTimeToPreroll() {
        if currentTime <= 0.5 {
            scheduledTimeSeconds = 0.0
            statusMessage = "Scheduled as Pre-roll (00:00)"
            isSuccessMessage = true
        } else {
            scheduledTimeSeconds = minimumAllowedTime
            statusMessage = "Playback already started. Pushed to earliest allowed (+30s)"
            isSuccessMessage = true
        }
    }

    public func addOffsetFromNow(_ seconds: Double) {
        refreshPlayerState()
        scheduledTimeSeconds = max(minimumAllowedTime, currentTime + seconds)
        statusMessage = "Scheduled for \(formatSeconds(scheduledTimeSeconds)) (+\(Int(seconds))s from now)"
        isSuccessMessage = true
    }

    // MARK: - Staging & Scheduling

    public var effectiveURLString: String {
        if selectedPreset.id == "custom" {
            return customURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedPreset.urlString
    }

    public var isValidAdConfig: Bool {
        guard let url = URL(string: effectiveURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "file"
        else {
            return false
        }
        return true
    }

    public func createCurrentStagedItem() -> StagedAdItem? {
        guard isValidAdConfig else { return nil }
        enforceTimingRule()

        let effectivePlayoutLimit: Double? = {
            if hasPlayoutLimit {
                return playoutLimitSeconds
            }
            if timelineOccupancy == .fill {
                return playoutLimitSeconds > 0 ? playoutLimitSeconds : 15.0
            }
            return nil
        }()

        return StagedAdItem(
            identifier: adIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Ad-\(UUID().uuidString.prefix(6))" : adIdentifier,
            urlString: effectiveURLString,
            scheduledTimeSeconds: scheduledTimeSeconds,
            timelineOccupancy: timelineOccupancy,
            playoutLimitSeconds: effectivePlayoutLimit,
            resumptionOffsetSeconds: resumptionOffsetSeconds,
            constrainsSeekingForward: constrainsSeekingForward,
            requiresLinearPlayback: requiresLinearPlayback,
            supplementsPrimaryContent: supplementsPrimaryContent,
            contentMayVary: contentMayVary
        )
    }

    public func addCurrentToStaged() {
        guard let item = createCurrentStagedItem() else {
            statusMessage = "Please enter a valid HTTP/HTTPS media URL for the ad."
            isSuccessMessage = false
            return
        }

        stagedAds.append(item)
        statusMessage = "Added '\(item.identifier)' to staging queue (\(item.formattedTime))."
        isSuccessMessage = true

        // Prepare next default identifier and time (+30s further)
        scheduledTimeSeconds = max(minimumAllowedTime, item.scheduledTimeSeconds + 30.0)
        adIdentifier = "Midroll-Ad-\(player.interstitialService.scheduledEvents.count + stagedAds.count + 1)"
    }

    public func removeStagedItem(at offsets: IndexSet) {
        stagedAds.remove(atOffsets: offsets)
    }

    public func clearStaged() {
        stagedAds.removeAll()
    }

    // MARK: - Commit Schedule to AKPlayer

    public func scheduleStagedAds(replaceExisting: Bool) {
        // If staged is empty but user configured a valid current form, stage it first
        if stagedAds.isEmpty {
            if let singleItem = createCurrentStagedItem() {
                stagedAds.append(singleItem)
            } else {
                statusMessage = "Please configure a valid ad or add ads to the staging queue."
                isSuccessMessage = false
                return
            }
        }

        var configs: [AKInterstitialScheduleConfig] = []

        for item in stagedAds {
            guard let url = URL(string: item.urlString) else { continue }
            let templateItem = AVPlayerItem(url: url)

            var restrictions: AVPlayerInterstitialEvent.Restrictions = []
            if item.constrainsSeekingForward {
                restrictions.insert(.constrainsSeekingForwardInPrimaryContent)
            }
            if item.requiresLinearPlayback {
                restrictions.insert(.requiresPlaybackAtPreferredRateForAdvancement)
            }

            let playoutLimitCMTime = item.playoutLimitSeconds.map { CMTime(
                seconds: $0,
                preferredTimescale: 600
            ) } ?? .invalid
            let resumptionOffsetCMTime = CMTime(
                seconds: item.resumptionOffsetSeconds,
                preferredTimescale: 600
            )
            let presentationTime = CMTime(
                seconds: item.scheduledTimeSeconds,
                preferredTimescale: 600
            )

            let config = AKInterstitialScheduleConfig(
                time: presentationTime,
                templateItems: [templateItem],
                identifier: item.identifier,
                restrictions: restrictions,
                resumptionOffset: resumptionOffsetCMTime,
                playoutLimit: playoutLimitCMTime,
                timelineOccupancy: item.timelineOccupancy,
                supplementsPrimaryContent: item.supplementsPrimaryContent,
                contentMayVary: item.contentMayVary
            )
            configs.append(config)
        }

        player.interstitialService.schedule(configs, replaceExisting: replaceExisting)
        refreshPlayerState()
        stagedAds.removeAll()

        statusMessage = "Successfully scheduled \(configs.count) ad(s) on player timeline!"
        isSuccessMessage = true
    }

    public func scheduleCurrentImmediately() {
        guard let item = createCurrentStagedItem() else {
            statusMessage = "Please enter a valid HTTP/HTTPS media URL for the ad."
            isSuccessMessage = false
            return
        }

        stagedAds = [item]
        scheduleStagedAds(replaceExisting: false)
    }

    public func clearAllScheduledEvents() {
        player.interstitialService.setEvents([])
        refreshPlayerState()
        statusMessage = "Cleared all scheduled interstitial ad events."
        isSuccessMessage = true
    }

    public func formatSeconds(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - CustomAdsManagerView

public struct CustomAdsManagerView: View {
    @StateObject private var viewModel: CustomAdsManagerViewModel
    @Environment(\.dismiss) private var dismiss

    public init(player: AKPlayer) {
        _viewModel = StateObject(wrappedValue: CustomAdsManagerViewModel(player: player))
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Playback Timing & Minimum Rule Status
                playerTimingStatusSection()

                // Section 2: Preset Template Selection
                presetSelectionSection()

                // Section 3: Ad Configuration Form (All Fields Defaulted)
                adConfigurationSection()

                // Section 4: Timing & Quick Offset Buttons
                timingAdjustmentSection()

                // Section 5: Restrictions & Advanced Options
                advancedOptionsSection()

                // Section 6: Action Buttons
                actionButtonsSection()

                // Section 7: Staged Ads Queue (Multi-Ad Batch)
                if !viewModel.stagedAds.isEmpty {
                    stagedAdsSection()
                }

                // Section 8: Active Schedule on Player
                activeScheduleSection()
            }
            .navigationTitle("Custom Ads Scheduler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.scheduleCurrentImmediately()
                    } label: {
                        Text("Add & Schedule")
                            .bold()
                    }
                    .disabled(!viewModel.isValidAdConfig)
                }
            }
            .onAppear {
                viewModel.refreshPlayerState()
                viewModel.applyDefaultTiming()
            }
        }
    }

    // MARK: - Section 1: Player Timing & Status

    private func playerTimingStatusSection() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(viewModel.mediaTitle, systemImage: "play.circle.fill")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(viewModel.formatSeconds(viewModel.currentTime))
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(.accentColor)
                }

                Divider()

                HStack {
                    Text("Earliest Allowed Time:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if viewModel.currentTime <= 0.5 {
                        Text("00:00 (Pre-roll or anytime)")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    } else {
                        Text(
                            "≥ \(viewModel.formatSeconds(viewModel.minimumAllowedTime)) (+30s rule)"
                        )
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    }
                }

                if let message = viewModel.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(viewModel.isSuccessMessage ? .green : .red)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 2)
        } header: {
            Text("Active Player Context")
        }
    }

    // MARK: - Section 2: Preset Selection

    private func presetSelectionSection() -> some View {
        Section {
            Picker("Ad Preset", selection: $viewModel.selectedPreset) {
                ForEach(AdPreset.samplePresets) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedPreset) { _, newPreset in
                if newPreset.id != "custom" {
                    viewModel.customURLString = newPreset.urlString
                }
            }

            if viewModel.selectedPreset.id == "custom" {
                TextField("https://example.com/ad.m3u8", text: $viewModel.customURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.caption)
            } else {
                HStack {
                    Text("Preset Duration:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.selectedPreset.durationDescription)
                        .font(.caption.bold())
                }
            }
        } header: {
            Text("Ad Media Preset")
        } footer: {
            Text("Pre-loaded with reliable Apple HLS test ad streams and clips.")
        }
    }

    // MARK: - Section 3: Ad Configuration

    private func adConfigurationSection() -> some View {
        Section {
            HStack {
                Text("Identifier")
                Spacer()
                TextField("e.g. Midroll-1", text: $viewModel.adIdentifier)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.primary)
            }

            Picker("Timeline Occupancy", selection: $viewModel.timelineOccupancy) {
                Text("Single Point (Cue Point)")
                    .tag(AVPlayerInterstitialEvent.TimelineOccupancy.singlePoint)
                Text("Fill (Replace Duration)")
                    .tag(AVPlayerInterstitialEvent.TimelineOccupancy.fill)
            }
            .onChange(of: viewModel.timelineOccupancy) { _, newOccupancy in
                if newOccupancy == .fill, !viewModel.hasPlayoutLimit {
                    viewModel.hasPlayoutLimit = true
                }
            }
        } header: {
            Text("Ad Parameters")
        }
    }

    // MARK: - Section 4: Timing & Quick Offset Buttons

    private func timingAdjustmentSection() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Presentation Time")
                    Spacer()
                    Text(viewModel.formatSeconds(viewModel.scheduledTimeSeconds))
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(.accentColor)
                    Text("(\(Int(viewModel.scheduledTimeSeconds))s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $viewModel.scheduledTimeSeconds,
                    in: viewModel.minimumAllowedTime ... max(
                        viewModel.minimumAllowedTime + 300,
                        viewModel.mediaDuration > 0 ? viewModel.mediaDuration : 600
                    ),
                    step: 1.0
                )
                .onChange(of: viewModel.scheduledTimeSeconds) { _, _ in
                    viewModel.enforceTimingRule()
                }

                // Quick Offset Shortcuts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if viewModel.currentTime <= 0.5 {
                            Button("Pre-roll (0s)") {
                                viewModel.setTimeToPreroll()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                        }

                        Button("+30s from now") {
                            viewModel.addOffsetFromNow(30)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("+60s from now") {
                            viewModel.addOffsetFromNow(60)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("+2 min") {
                            viewModel.addOffsetFromNow(120)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("+5 min") {
                            viewModel.addOffsetFromNow(300)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Scheduled Presentation Time")
        } footer: {
            Text(viewModel.currentTime <= 0.5
                ? "Playback not started. You can schedule at 00:00 (Pre-roll) or any time."
                :
                "Playback underway. Ads must be scheduled at least 30s ahead of current time (\(viewModel.formatSeconds(viewModel.currentTime))).")
        }
    }

    // MARK: - Section 5: Restrictions & Advanced Options

    private func advancedOptionsSection() -> some View {
        Section {
            Toggle("Constrain Seeking Forward", isOn: $viewModel.constrainsSeekingForward)
            Toggle("Require Linear Playback", isOn: $viewModel.requiresLinearPlayback)

            Toggle("Playout Duration Limit", isOn: $viewModel.hasPlayoutLimit)
            if viewModel.hasPlayoutLimit {
                HStack {
                    Text("Limit Duration")
                    Spacer()
                    Stepper(
                        "\(Int(viewModel.playoutLimitSeconds))s",
                        value: $viewModel.playoutLimitSeconds,
                        in: 5 ... 120,
                        step: 5
                    )
                }
            }

            Toggle("Supplements Primary Content", isOn: $viewModel.supplementsPrimaryContent)
            Toggle("Content May Vary Dynamically", isOn: $viewModel.contentMayVary)
        } header: {
            Text("Restrictions & Advanced Options")
        }
    }

    // MARK: - Section 6: Action Buttons

    private func actionButtonsSection() -> some View {
        Section {
            Button {
                viewModel.addCurrentToStaged()
            } label: {
                Label("Add to Staging Queue (Batch)", systemImage: "plus.circle")
            }
            .disabled(!viewModel.isValidAdConfig)

            Button {
                viewModel.scheduleCurrentImmediately()
            } label: {
                Label("Schedule This Ad Immediately", systemImage: "bolt.fill")
                    .bold()
            }
            .disabled(!viewModel.isValidAdConfig)
        } header: {
            Text("Ad Actions")
        }
    }

    // MARK: - Section 7: Staged Ads Queue

    private func stagedAdsSection() -> some View {
        Section {
            ForEach(viewModel.stagedAds) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.identifier)
                            .font(.subheadline.bold())
                        Text(
                            "Scheduled at \(item.formattedTime) (\(Int(item.scheduledTimeSeconds))s)"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(item.timelineOccupancy == .singlePoint ? "Cue" : "Fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            .onDelete(perform: viewModel.removeStagedItem)

            HStack {
                Button("Schedule All (Append)") {
                    viewModel.scheduleStagedAds(replaceExisting: false)
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Schedule All (Replace)") {
                    viewModel.scheduleStagedAds(replaceExisting: true)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 2)
        } header: {
            HStack {
                Text("Staged Ads Queue (\(viewModel.stagedAds.count))")
                Spacer()
                Button("Clear", role: .destructive) {
                    viewModel.clearStaged()
                }
                .font(.caption)
            }
        } footer: {
            Text("Batch multiple ads and commit them all at once to the player timeline.")
        }
    }

    // MARK: - Section 8: Active Schedule on Player

    private func activeScheduleSection() -> some View {
        Section {
            if viewModel.liveScheduledEvents.isEmpty {
                Text("No custom interstitial ads scheduled on player.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(
                    Array(viewModel.liveScheduledEvents.enumerated()),
                    id: \.offset
                ) { _, event in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.identifier)
                                .font(.subheadline.bold())
                            Text(
                                "Cue: \(viewModel.formatSeconds(event.time.seconds)) (\(Int(event.time.seconds))s)"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(event.timelineOccupancy == .singlePoint ? "Point" : "Fill")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                }

                Button(role: .destructive) {
                    viewModel.clearAllScheduledEvents()
                } label: {
                    Label("Clear All Scheduled Ads", systemImage: "trash")
                }
            }
        } header: {
            HStack {
                Text("Active Player Schedule (\(viewModel.liveScheduledEvents.count))")
                Spacer()
                Button {
                    viewModel.refreshPlayerState()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
        }
    }
}
