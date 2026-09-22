//
//   TestMediaListView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AKPlayer
import SwiftUI

public struct TestMediaListView: View {
    public var medias: [TestMedia]

    @State private var selectedMedia: TestMedia?
    @State private var playerMedia: TestMedia?
    @State private var livePlayerMedia: TestMedia?
    @State private var audiobookPlayerMedia: TestMedia?
    @State private var isQueuePlayerPresented = false
    @State private var queueStartIndex = 0

    public init(medias: [TestMedia] = sampleTestMedia) {
        self.medias = medias
    }

    public var body: some View {
        NavigationStack {
            List(Array(medias.enumerated()), id: \.element.id) { index, media in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(media.name)
                                    .font(.headline)

                                if media.kind == .live {
                                    Text("LIVE")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.85))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }

                            if let subtitle = media.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Menu {
                            if media.kind == .live {
                                Button {
                                    livePlayerMedia = media
                                } label: {
                                    Label(
                                        "Play in Live Player (Jump to Live)",
                                        systemImage: "dot.radiowaves.left.and.right"
                                    )
                                }
                            }

                            Button {
                                playerMedia = media
                            } label: {
                                Label("Play Video", systemImage: "play.circle")
                            }

                            Button {
                                audiobookPlayerMedia = media
                            } label: {
                                Label("Play as Audiobook / Podcast", systemImage: "book.fill")
                            }

                            Button {
                                queueStartIndex = index
                                isQueuePlayerPresented = true
                            } label: {
                                Label("Play in Queue", systemImage: "play.square.stack")
                            }
                        } label: {
                            Image(systemName: media
                                .kind == .live ? "dot.radiowaves.left.and.right" :
                                "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(media.kind == .live ? .red : .accentColor)
                        }
                    }

                    if let capabilities = media.testCapabilities, !capabilities.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test Focus:")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(capabilities.prefix(3), id: \.self) { cap in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text(cap)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    HStack {
                        if let langs = media.audioLanguages, !langs.isEmpty {
                            Text("Audio: " + langs.joined(separator: ", ").uppercased())
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }

                        if let subs = media.subtitleLanguages, !subs.isEmpty {
                            Text("Subs: " + subs.joined(separator: ", ").uppercased())
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                        }

                        Spacer()

                        Button("Full Details") {
                            selectedMedia = media
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 6)
                .contextMenu {
                    if media.kind == .live {
                        Button {
                            livePlayerMedia = media
                        } label: {
                            Label(
                                "Play in Live Player (Jump to Live)",
                                systemImage: "dot.radiowaves.left.and.right"
                            )
                        }
                    }

                    Button {
                        playerMedia = media
                    } label: {
                        Label("Play Video", systemImage: "play.circle")
                    }

                    Button {
                        audiobookPlayerMedia = media
                    } label: {
                        Label("Play as Audiobook / Podcast", systemImage: "book.fill")
                    }

                    Button {
                        queueStartIndex = index
                        isQueuePlayerPresented = true
                    } label: {
                        Label("Play in Queue from Here", systemImage: "play.square.stack")
                    }
                }
            }
            .navigationTitle("Apple Test Streams")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            if let live = medias.first(where: { $0.kind == .live }) {
                                livePlayerMedia = live
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                Text("Live")
                            }
                            .foregroundColor(.red)
                        }

                        Button {
                            queueStartIndex = 0
                            isQueuePlayerPresented = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.square.stack")
                                Text("Queue")
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedMedia) { media in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(media.name)
                                    .font(.title2)
                                    .bold()

                                if let subtitle = media.subtitle {
                                    Text(subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            if let capabilities = media.testCapabilities, !capabilities.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("🎯 What You Can Test")
                                        .font(.headline)

                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(capabilities, id: \.self) { item in
                                            HStack(alignment: .top, spacing: 6) {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.footnote)
                                                    .padding(.top, 2)
                                                Text(item)
                                                    .font(.subheadline)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                            }

                            if let note = media.note {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("📋 Stream Specifications")
                                        .font(.headline)

                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(10)
                                }
                            }

                            Spacer(minLength: 20)

                            if let url = media.url {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("🔗 Stream URL")
                                        .font(.headline)
                                    Text(url.absoluteString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Stream Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                selectedMedia = nil
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                if media.kind == .live {
                                    Button("Play in Live Player (Jump to Live)") {
                                        let live = media
                                        selectedMedia = nil
                                        Task { @MainActor in
                                            await Task.yield()
                                            livePlayerMedia = live
                                        }
                                    }
                                }

                                Button("Play Video") {
                                    let single = media
                                    selectedMedia = nil
                                    Task { @MainActor in
                                        await Task.yield()
                                        playerMedia = single
                                    }
                                }

                                Button("Play as Audiobook / Podcast") {
                                    let audio = media
                                    selectedMedia = nil
                                    Task { @MainActor in
                                        await Task.yield()
                                        audiobookPlayerMedia = audio
                                    }
                                }

                                Button("Play in Queue") {
                                    let idx = medias.firstIndex(where: { $0.id == media.id }) ?? 0
                                    selectedMedia = nil
                                    Task { @MainActor in
                                        await Task.yield()
                                        queueStartIndex = idx
                                        isQueuePlayerPresented = true
                                    }
                                }
                            } label: {
                                Text("Play")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .fullScreenCover(item: $playerMedia) { media in
                NavigationStack {
                    SimpleVideoPlayerView(
                        media: makeAKMedia(from: media),
                        autoPlay: true
                    )
                }
            }
            .fullScreenCover(item: $audiobookPlayerMedia) { media in
                AudiobookPlayerView(
                    media: makeAKMedia(from: media),
                    autoPlay: true
                )
            }
            .fullScreenCover(item: $livePlayerMedia) { media in
                NavigationStack {
                    LivePlayerView(
                        media: makeAKMedia(from: media),
                        autoPlay: true
                    )
                }
            }
            .fullScreenCover(isPresented: $isQueuePlayerPresented) {
                QueuePlayerView(
                    medias: medias,
                    startIndex: queueStartIndex
                )
            }
        }
    }
}

struct TestMediaListView_Previews: PreviewProvider {
    static var previews: some View {
        TestMediaListView()
    }
}
