//
//   AKLoadingState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKLoadingState

/// Concrete state representing a state where media is currently being
/// initialized, loaded, and prepared for active playback.
@MainActor
public class AKLoadingState: AKBaseState {
    // MARK: - Properties
    
    /// The media item being loaded into the player pipeline.
    private unowned let media: any AKPlayable
    
    /// Indicates whether playback should automatically start once loading
    /// completes.
    public private(set) var autoPlay: Bool
    
    /// An optional initial position to seek to upon entering loaded state.
    private let position: AKSeekTarget?
    
    /// An optional playback rate target to set upon loading complete.
    private var rate: AKPlaybackRate?
    
    /// Tracks if initialization operations were explicitly aborted or
    /// cancelled.
    private var isCancelled = false
    
    /// Asynchronous validation task reference used for loading asset
    /// playability.
    private var task: Task<Void, Never>?
    
    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a loading state instance with specified options.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving
    /// execution.
    ///   - media: The target media item to load.
    ///   - autoPlay: Whether auto-start is requested post-loading.
    ///   - position: Optional initial seek target.
    ///   - rate: Optional initial playback speed multiplier.
    public init(
        playerController: any AKPlayerControllerProtocol,
        media: any AKPlayable,
        autoPlay: Bool = false,
        position: AKSeekTarget? = nil,
        rate: AKPlaybackRate? = nil
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.media = media
        self.autoPlay = autoPlay
        self.position = position
        self.rate = rate
        super.init(playerController: playerController, state: .loading)
    }
    
    deinit {
        
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
        
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Entry point for state setup. Cleans up prior item observers, emits
    /// initial media change events, and monitors media load state transitions.
    override public func processStateChange() {
        super.processStateChange()
        playerController.emit(.mediaDidChange(media))
        
        media.statePublisher
            .sink { [weak self] state in
                guard let self else { return }
                hanldeChangeInMedia(state)
            }
            .store(in: &subscriptions)
    }
    
    // MARK: - Commands
    
    /// Registers playback request while media is still loading. Sets `autoPlay`
    /// flag to true.
    override public func play() {
        autoPlay = true
    }
    
    /// Intercepts specific speed adjustments requested during loading state and
    /// fires unavailable action delegate notifications.
    /// - Parameter rate: The target speed requested.
    override public func play(at _: AKPlaybackRate) {
        playerController.emit(.commandUnavailable(reason: .waitTillMediaLoaded))
    }
    
    /// Cancels queued autoplay request while media is loading.
    override public func pause() {
        autoPlay = false
    }
    
    /// Toggles autoplay behavior based on current state.
    override public func togglePlayPause() {
        autoPlay ? pause() : play()
    }
    
    // MARK: - Helper Functions
    
    /// Handles progressive steps across media preparation stages.
    /// - Parameter state: Current asset loading lifecycle phase.
    private func hanldeChangeInMedia(_ state: AKPlayableState) {
        switch state {
        case .idle:
            createAsset()
        case .assetLoaded:
            task = Task { [weak self] in
                guard let self else { return }
                await validateAssetPlayability()
                if isCancelled {
                    return
                }
                guard !Task.isCancelled else { return }
                createPlayerItemFromAsset()
            }
        case .playerItemLoaded:
            playerItemLoaded()
        case .readyToPlay where !(playerController.player.currentItem == media.playerItem):
            playerItemLoaded()
            becameReadyToPlay()
        case .readyToPlay:
            becameReadyToPlay()
        case .failed:
            if let error = media.error {
                failedToPrepareForPlayback(with: error)
            }
        }
    }
    
    /// Requests underlying media instance to construct its underlying AVAsset.
    private func createAsset() {
        media.createAsset()
    }
    
    /// Validates asset integrity and playability metrics asynchronously.
    private func validateAssetPlayability() async {
        do {
            try await media.validateAssetPlayability()
        } catch let playerError as AKPlayerError {
            failedToPrepareForPlayback(with: playerError)
        } catch {
            failedToPrepareForPlayback(
                with: .playerCanNoLongerPlay(error: error)
            )
        }
    }
    
    /// Requests media wrapper to generate AVPlayerItem out of validated asset.
    private func createPlayerItemFromAsset() {
        media.createPlayerItemFromAsset()
    }
    
    /// Prepares player item and links it with AVPlayer pipeline once loaded.
    private func playerItemLoaded() {
        /*
         You should call this method before associating the player item with the player to make
         sure you capture all state changes to the item’s status.
         */
        if let item = media.playerItem {
            playerController.player.replaceCurrentItem(with: item)
        }
    }
    
    /// Evaluates AVPlayer ready status and transitions state to `AKLoadedState`
    /// upon success.
    private func becameReadyToPlay() {
        // Handle "already ready" synchronously without going through Combine.
        if playerController.player.status == .readyToPlay {
            return transitionToLoaded()
        }
        
        if playerController.player.status == .failed {
            return transitionToFailed()
        }
        
        playerController.player.publisher(for: \.status, options: [.new])
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay: transitionToLoaded()
                case .failed: transitionToFailed()
                default: break
                }
            }
            .store(in: &subscriptions)
    }
    
    private func transitionToLoaded() {
        let controller = AKLoadedState(
            playerController: playerController,
            autoPlay: autoPlay,
            position: position
        )
        return change(controller)
    }
    
    private func transitionToFailed() {
        let controller = AKFailedState(
            playerController: playerController,
            error: .playerCanNoLongerPlay(error: playerController.player.error)
        )
        return change(controller)
    }
    
    /// Aborts tasks and asset loading operations.
    private func abortAssetInitialization() {
        task?.cancel()
        task = nil
        isCancelled = true
        subscriptions.forEach({ $0.cancel() })
        subscriptions.removeAll()
        media.abortAssetInitialization()
    }
    
    // MARK: - Error Handling
    
    /// Transitions state engine into `AKFailedState` when media initialization
    /// fails.
    /// - Parameter error: Specific player error description encounter.
    private func failedToPrepareForPlayback(with error: AKPlayerError) {
        guard !isCancelled else { return }
        let controller = AKFailedState(
            playerController: playerController,
            error: error
        )
        change(controller)
    }
    
    // MARK: - Transition Overrides
    
    /// Cancels asset loads and strips observers prior to stopping the player
    /// controller.
    override public func beforeStop() {
        abortAssetInitialization()
    }
    
    /// Checks availability for specified target actions during loading phase.
    override public func availability(for action: AKPlayerAction) -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?)
    {
        switch action {
        case .seek, .step, .fastForward, .rewind:
            (false, .waitTillMediaLoaded)
        default:
            super.availability(for: action)
        }
    }
    /// Cleans active Combine observers prior to completing state exit.
    override public func beforeStateChange() {
        task?.cancel()
        task = nil
        let subs = subscriptions
        subscriptions.removeAll()
        subs.forEach { $0.cancel() }
    }
}
