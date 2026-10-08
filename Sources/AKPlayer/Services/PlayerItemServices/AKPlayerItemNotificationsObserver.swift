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

// MARK: - Internal Lifecycle Protocol

/// Internal lifecycle management contract for player item notifications observer.
protocol AKPlayerItemNotificationsLifecycleManaging: AnyObject, Sendable {
    /// Starts observing system notifications for the specified player item.
    func startObserving(playerItem: AVPlayerItem)

    /// Stops observing system notifications and cancels active notification tasks.
    func stopObserving()
}

// MARK: - Implementation

/// Thread-safe observer managing system notifications for AVPlayerItem instances.
public final class AKPlayerItemNotificationsObserver: AKPlayerItemNotificationsObserverProtocol,
    AKPlayerItemNotificationsLifecycleManaging,
    Sendable
{
    // MARK: - Properties

    /// Internal broadcaster dispatching player item notification events to subscribers.
    private let broadcaster = AKEventBroadcaster<AKPlayerItemNotificationEvent>()

    /// Mutex protecting the active notification observation task group for the current player item.
    private let activeTask = Mutex<Task<Void, Never>?>(nil)

    /// Multi-subscriber stream emitting AVPlayerItem lifecycle events.
    public var events: AsyncStream<AKPlayerItemNotificationEvent> {
        broadcaster.makeStream()
    }

    // MARK: - Init & Deinit

    /// Initializes an observer monitoring notifications for player items.
    /// - Parameter mediaManager: Optional media manager reference for dependency injection.
    public init(mediaManager _: (any AKMediaManagerProtocol)? = nil) {}

    deinit {
        stopObserving()
        broadcaster.finish()
    }

    // MARK: - AVPlayerItem Observation

    /// Attaches NotificationCenter observers for the given player item and forwards events through
    /// the broadcaster.
    /// - Parameter playerItem: The `AVPlayerItem` to observe.
    public func startObserving(playerItem: AVPlayerItem) {
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
    public func stopObserving() {
        activeTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }
}

// MARK: - Equatable Conformance

extension AKPlayerItemNotificationEvent: Equatable {
    public static func == (
        lhs: AKPlayerItemNotificationEvent,
        rhs: AKPlayerItemNotificationEvent
    ) -> Bool {
        switch (lhs, rhs) {
        case let (.didPlayToEndTime(l), .didPlayToEndTime(r)):
            l == r
        case (.failedToPlayToEndTime, .failedToPlayToEndTime):
            true
        case (.playbackStalled, .playbackStalled):
            true
        case (.timeJumped, .timeJumped):
            true
        case (.mediaSelectionDidChange, .mediaSelectionDidChange):
            true
        case let (
            .recommendedTimeOffsetFromLiveDidChange(l),
            .recommendedTimeOffsetFromLiveDidChange(r)
        ):
            l == r
        default:
            false
        }
    }
}
