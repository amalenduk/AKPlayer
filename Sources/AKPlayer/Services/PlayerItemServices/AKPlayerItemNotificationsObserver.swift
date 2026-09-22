//
//   AKPlayerItemNotificationsObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import Synchronization

// MARK: - Event Model

/// Events emitted by AVPlayerItem during playback.
public enum AKPlayerItemNotificationEvent: Sendable {
    /// Playback reached the end timestamp of the media item.
    case didPlayToEndTime(CMTime)
    /// Playback failed to reach end time due to an error.
    case failedToPlayToEndTime(AKPlayerError)
    /// Playback stalled due to insufficient buffered media data.
    case playbackStalled
    /// The media timeline jumped discontinuously.
    case timeJumped
    /// Active media selection (audio track, subtitles) changed.
    case mediaSelectionDidChange
    /// Recommended time offset from live edge changed for live streams.
    case recommendedTimeOffsetFromLiveDidChange(CMTime)
}

// MARK: - Protocol

/// Protocol defining the interface for observing AVPlayerItem system notifications.
public protocol AKPlayerItemNotificationsObserverProtocol: AnyObject, Sendable {
    /// Multi-subscriber stream emitting AVPlayerItem lifecycle events.
    var events: AsyncStream<AKPlayerItemNotificationEvent> { get }
}

// MARK: - Implementation

/// Thread-safe observer managing system notifications for AVPlayerItem instances.
public final class AKPlayerItemNotificationsObserver: AKPlayerItemNotificationsObserverProtocol,
    Sendable
{
    // MARK: - Properties

    /// Internal broadcaster dispatching player item notification events to subscribers.
    private let broadcaster = AKEventBroadcaster<AKPlayerItemNotificationEvent>()

    /// Mutex protecting the active notification observation task group for the current player item.
    private let activeTask = Mutex<Task<Void, Never>?>(nil)
    /// Mutex protecting the media manager state observation task.
    private let stateTask = Mutex<Task<Void, Never>?>(nil)

    /// Multi-subscriber stream emitting AVPlayerItem lifecycle events.
    public var events: AsyncStream<AKPlayerItemNotificationEvent> {
        broadcaster.makeStream()
    }

    // MARK: - Init & Deinit

    /// Initializes an observer monitoring notifications for player items loaded in the media
    /// manager.
    /// - Parameter mediaManager: The media manager instance providing the active player item.
    public init(mediaManager: any AKMediaManagerProtocol) {
        startMonitoringMediaEvents(for: mediaManager)
    }

    deinit {
        stopMonitoringMediaEvents()
        stopObserving()
        broadcaster.finish()
    }

    // MARK: - Media State Monitoring

    /// Begins monitoring media manager state transitions to dynamically attach or detach item
    /// observation.
    /// - Parameter mediaManager: The media manager providing player item updates.
    private func startMonitoringMediaEvents(for mediaManager: any AKMediaManagerProtocol) {
        let task = Task { [weak self, weak mediaManager] in
            guard let mediaManager else { return }

            // Check initial state
            if await mediaManager.state == .playerItemLoaded,
               let item = await mediaManager.playerItem
            {
                self?.startObserving(playerItem: item)
            }

            for await event in await mediaManager.events {
                guard !Task.isCancelled, let self else { break }

                if case let .stateDidChange(state) = event {
                    if state == .playerItemLoaded, let item = await mediaManager.playerItem {
                        startObserving(playerItem: item)
                    } else if state == .idle || state == .failed {
                        stopObserving()
                    }
                }
            }
        }

        stateTask.withLock { $0 = task }
    }

    /// Cancels and releases the active media manager state observation task.
    private func stopMonitoringMediaEvents() {
        stateTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }

    // MARK: - AVPlayerItem Observation

    /// Attaches NotificationCenter observers for the given player item and forwards events through
    /// the broadcaster.
    /// - Parameter playerItem: The `AVPlayerItem` to observe.
    private func startObserving(playerItem: AVPlayerItem) {
        stopObserving()

        let newTask = Task { [weak self, weak playerItem] in
            guard let playerItem else { return }

            await withTaskGroup(of: Void.self) { group in
                // 1. Did Play To End
                group.addTask { [weak self, weak playerItem] in
                    for await _ in NotificationCenter.default.notifications(
                        named: .AVPlayerItemDidPlayToEndTime,
                        object: playerItem
                    ) {
                        guard !Task.isCancelled, let self, let playerItem else { break }
                        self.broadcaster.send(.didPlayToEndTime(playerItem.currentTime()))
                    }
                }

                // 2. Failed To Play To End
                group.addTask { [weak self] in
                    for await notif in NotificationCenter.default.notifications(
                        named: .AVPlayerItemFailedToPlayToEndTime,
                        object: playerItem
                    ) {
                        guard !Task.isCancelled, let self else { break }
                        let nsError = notif
                            .userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
                        self.broadcaster
                            .send(
                                .failedToPlayToEndTime(
                                    .playerItemFailedToPlay(
                                        reason: .failedToPlayToEndTime(
                                            error: nsError
                                        )
                                    )
                                )
                            )
                    }
                }

                // 3. Playback Stalled
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(
                        named: .AVPlayerItemPlaybackStalled,
                        object: playerItem
                    ) {
                        guard !Task.isCancelled, let self else { break }
                        self.broadcaster.send(.playbackStalled)
                    }
                }

                // 4. Time Jumped
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(
                        named: AVPlayerItem.timeJumpedNotification,
                        object: playerItem
                    ) {
                        guard !Task.isCancelled, let self else { break }
                        self.broadcaster.send(.timeJumped)
                    }
                }

                // 5. Media Selection Changed
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(
                        named: AVPlayerItem.mediaSelectionDidChangeNotification,
                        object: playerItem
                    ) {
                        guard !Task.isCancelled, let self else { break }
                        self.broadcaster.send(.mediaSelectionDidChange)
                    }
                }

                // 6. Live Offset Changed
                group.addTask { [weak self, weak playerItem] in
                    for await _ in NotificationCenter.default.notifications(
                        named: AVPlayerItem.recommendedTimeOffsetFromLiveDidChangeNotification,
                        object: playerItem
                    ) {
                        guard !Task.isCancelled, let self, let playerItem else { break }
                        self.broadcaster
                            .send(.recommendedTimeOffsetFromLiveDidChange(playerItem
                                    .recommendedTimeOffsetFromLive))
                    }
                }
            }
        }

        activeTask.withLock { $0 = newTask }
    }

    /// Stops observing the current player item and cancels active notification tasks.
    private func stopObserving() {
        activeTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }
}
