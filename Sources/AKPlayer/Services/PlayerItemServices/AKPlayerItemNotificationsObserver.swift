import AVFoundation
import Foundation
import Synchronization

// MARK: - Event Model

/// Events emitted by AVPlayerItem during playback.
public enum AKPlayerItemNotificationEvent: Sendable {
    case didPlayToEndTime(CMTime)
    case failedToPlayToEndTime(AKPlayerError)
    case playbackStalled
    case timeJumped
    case mediaSelectionDidChange
    case recommendedTimeOffsetFromLiveDidChange(CMTime)
}

// MARK: - Protocol

public protocol AKPlayerItemNotificationsObserverProtocol: AnyObject, Sendable {
    /// Multi-subscriber stream emitting AVPlayerItem lifecycle events.
    var events: AsyncStream<AKPlayerItemNotificationEvent> { get }
}

// MARK: - Implementation

public final class AKPlayerItemNotificationsObserver: AKPlayerItemNotificationsObserverProtocol, Sendable {
    
    // MARK: - Properties
    
    private let broadcaster = AKEventBroadcaster<AKPlayerItemNotificationEvent>()
    
    // Swift 6 native Mutex (iOS 18+) to hold the Task references thread-safely
    private let activeTask = Mutex<Task<Void, Never>?>(nil)
    private let stateTask = Mutex<Task<Void, Never>?>(nil)
    
    public var events: AsyncStream<AKPlayerItemNotificationEvent> {
        broadcaster.makeStream()
    }
    
    // MARK: - Init & Deinit
    
    public init(mediaManager: any AKMediaManagerProtocol) {
        startMonitoringMediaEvents(for: mediaManager)
    }
    
    deinit {
        stopMonitoringMediaEvents()
        stopObserving()
        broadcaster.finish()
    }
    
    // MARK: - Media State Monitoring
    
    private func startMonitoringMediaEvents(for mediaManager: any AKMediaManagerProtocol) {
        let task = Task { [weak self, weak mediaManager] in
            guard let mediaManager else { return }
            
            // Check initial state
            if await mediaManager.state == .playerItemLoaded, let item = await mediaManager.playerItem {
                self?.startObserving(playerItem: item)
            }
            
            for await event in await mediaManager.events {
                guard !Task.isCancelled, let self else { break }
                
                if case .stateDidChange(let state) = event {
                    if state == .playerItemLoaded, let item = await mediaManager.playerItem {
                        self.startObserving(playerItem: item)
                    } else if state == .idle || state == .failed {
                        self.stopObserving()
                    }
                }
            }
        }
        
        stateTask.withLock { $0 = task }
    }
    
    private func stopMonitoringMediaEvents() {
        stateTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }
    
    // MARK: - AVPlayerItem Observation
    
    private func startObserving(playerItem: AVPlayerItem) {
        stopObserving()
        
        let newTask = Task { [weak self, weak playerItem] in
            guard let playerItem else { return }
            
            await withTaskGroup(of: Void.self) { group in
                
                // 1. Did Play To End
                group.addTask { [weak self, weak playerItem] in
                    for await _ in NotificationCenter.default.notifications(named: .AVPlayerItemDidPlayToEndTime, object: playerItem) {
                        guard !Task.isCancelled, let self, let playerItem else { break }
                        self.broadcaster.send(.didPlayToEndTime(playerItem.currentTime()))
                    }
                }
                
                // 2. Failed To Play To End
                group.addTask { [weak self] in
                    for await notif in NotificationCenter.default.notifications(named: .AVPlayerItemFailedToPlayToEndTime, object: playerItem) {
                        guard !Task.isCancelled, let self else { break }
                        let nsError = notif.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
                        self.broadcaster.send(.failedToPlayToEndTime(.playerItemFailedToPlay(reason: .failedToPlayToEndTime(error: nsError))))
                    }
                }
                
                // 3. Playback Stalled
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: .AVPlayerItemPlaybackStalled, object: playerItem) {
                        guard !Task.isCancelled, let self else { break }
                        self.broadcaster.send(.playbackStalled)
                    }
                }
                
                // 4. Time Jumped
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: AVPlayerItem.timeJumpedNotification, object: playerItem) {
                        guard !Task.isCancelled, let self else { break }
                        self.broadcaster.send(.timeJumped)
                    }
                }
                
                // 5. Media Selection Changed
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: AVPlayerItem.mediaSelectionDidChangeNotification, object: playerItem) {
                        guard !Task.isCancelled, let self else { break }
                        self.broadcaster.send(.mediaSelectionDidChange)
                    }
                }
                
                // 6. Live Offset Changed
                group.addTask { [weak self, weak playerItem] in
                    for await _ in NotificationCenter.default.notifications(named: AVPlayerItem.recommendedTimeOffsetFromLiveDidChangeNotification, object: playerItem) {
                        guard !Task.isCancelled, let self, let playerItem else { break }
                        self.broadcaster.send(.recommendedTimeOffsetFromLiveDidChange(playerItem.recommendedTimeOffsetFromLive))
                    }
                }
            }
        }
        
        activeTask.withLock { $0 = newTask }
    }
    
    private func stopObserving() {
        activeTask.withLock {
            $0?.cancel()
            $0 = nil
        }
    }
}
