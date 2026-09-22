//
//   AboutView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import SwiftUI

public struct AboutView: View {
    @AppStorage("globalAutoPlay") private var globalAutoPlay = true

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Header Banner Section
                Section {
                    VStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 8)

                        Text("AKPlayer")
                            .font(.title.bold())

                        Text("Enterprise AVPlayer Playback Engine for iOS 18+ in Swift 6")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        HStack(spacing: 8) {
                            badgeView(text: "Swift 6", color: .orange)
                            badgeView(text: "iOS 18+", color: .blue)
                            badgeView(text: "MIT License", color: .green)
                            badgeView(text: "SPM", color: .purple)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                // Playback Preferences Section
                Section("Playback Preferences") {
                    Toggle(isOn: $globalAutoPlay) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Global Auto-Play")
                                    .font(.body)
                                Text("Automatically start playback upon opening any player")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // GitHub & Open Source Section
                Section("Open Source & Repository") {
                    Link(destination: URL(string: "https://github.com/amalenduk/AKPlayerSPM")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .foregroundColor(.primary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GitHub Repository")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("github.com/amalenduk/AKPlayerSPM")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(
                        destination: URL(string: "https://github.com/amalenduk/AKPlayerSPM/issues")!
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.bubble")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Report an Issue / Bug")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(
                        destination: URL(
                            string: "https://github.com/amalenduk/AKPlayerSPM/blob/main/README.md"
                        )!
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.pages")
                                .foregroundColor(.indigo)
                                .frame(width: 24)
                            Text("Documentation & Guides")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Key Features Checklist
                Section("Core Capabilities") {
                    featureRow(
                        icon: "bolt.shield.fill",
                        color: .yellow,
                        title: "Swift 6 Strict Concurrency",
                        desc: "100% thread-safe under complete concurrency checking"
                    )
                    featureRow(
                        icon: "arrow.triangle.2.circlepath",
                        color: .blue,
                        title: "Deterministic State Machine",
                        desc: "Explicit transitions across idle, loading, playing, buffering, etc."
                    )
                    featureRow(
                        icon: "dot.radiowaves.left.and.right",
                        color: .red,
                        title: "Live Streams & DVR Catch-Up",
                        desc: "Automatic live edge detection with 1-tap 'Jump to Live'"
                    )
                    featureRow(
                        icon: "megaphone.fill",
                        color: .orange,
                        title: "HLS Interstitial Ads & Markers",
                        desc: "SSAI integration, ad progress countdown, and timeline markers"
                    )
                    featureRow(
                        icon: "book.fill",
                        color: .purple,
                        title: "Audiobook Chapters & Sleep Timer",
                        desc: "M4B chapter navigation, LibriVox parsing, and sleep timers"
                    )
                    featureRow(
                        icon: "play.square.stack.fill",
                        color: .green,
                        title: "Queue & Playlist Engine",
                        desc: "Pre-buffering, shuffle, repeat modes, and track switching"
                    )
                    featureRow(
                        icon: "captions.bubble.fill",
                        color: .teal,
                        title: "Audio & Subtitle Track Switching",
                        desc: "Characteristic filtering for Subtitles vs. Closed Captions (CC/SDH)"
                    )
                    featureRow(
                        icon: "airplayaudio",
                        color: .indigo,
                        title: "AirPlay & Long-Form Audio Policy",
                        desc: "AVRoutePickerView and .longFormAudio route sharing"
                    )
                    featureRow(
                        icon: "pip.fill",
                        color: .pink,
                        title: "Picture-in-Picture (PiP)",
                        desc: "Background video playback with restore UI callbacks"
                    )
                    featureRow(
                        icon: "lock.fill",
                        color: .blue,
                        title: "Lock Screen & Remote Commands",
                        desc: "Zero-boilerplate Now Playing info and MPRemoteCommandCenter"
                    )
                }

                // Version & Copyright Section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("1.0.0 (Swift 6 • iOS 18+)")
                            .foregroundColor(.primary)
                    }
                    HStack {
                        Text("License")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("MIT License")
                            .foregroundColor(.primary)
                    }
                    HStack {
                        Text("Author")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Amalendu Kar")
                            .foregroundColor(.primary)
                    }
                } footer: {
                    Text("Copyright © 2020 Amalendu Kar. All rights reserved.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func badgeView(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
