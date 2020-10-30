//
//  AKLoadingState.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import AVFoundation

final class AKLoadingState: AKPlayerStateControllable {
    
    // MARK: - Properties
    
    unowned var manager: AKPlayerManageable
    
    var state: AKPlayer.State = .loading
    
    private let media: AKPlayable
    private let autoPlay: Bool
    private let position: CMTime?
    
    private var playerIemInitializationService: AKPlayerItemInitializationServiceable!
    private var playerItemStatusObservingService: AKPlayerItemStatusObservingService!
    private var audioSessionInterruptionObservingService: AKAudioSessionInterruptionObservingServiceable!
    
    // MARK: - Init
    
    init(manager: AKPlayerManageable,
         media: AKPlayable,
         autoPlay: Bool = false,
         at position: CMTime? = nil) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleState)
        self.manager = manager
        self.media = media
        self.autoPlay = autoPlay
        self.position = position
        resetPlayerForNewMedia()
        manager.plugins.forEach({$0.playerPlugin(willStartLoading: media)})
        createPlayerItem(with: media)
        manager.plugins.forEach({$0.playerPlugin(didStartLoading: media)})
        startAudioSessionInterruptionObserving()
        manager.setNowPlayingMetadata()
        manager.setNowPlayingPlaybackInfo()
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleState)
    }
    
    // MARK: - Commands
    
    func load(media: AKPlayable) {
        let controller = AKLoadingState(manager: manager, media: media)
        manager.change(controller)
        manager.delegate?.playerManager(didCurrentMediaChange: media)
    }
    
    func load(media: AKPlayable, autoPlay: Bool) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay)
        manager.change(controller)
        manager.delegate?.playerManager(didCurrentMediaChange: media)
    }
    
    func load(media: AKPlayable, autoPlay: Bool, at position: CMTime) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay, at: position)
        manager.change(controller)
        manager.delegate?.playerManager(didCurrentMediaChange: media)
    }
    
    func load(media: AKPlayable, autoPlay: Bool, at position: Double) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay, at: CMTime(seconds: position, preferredTimescale: manager.configuration.preferredTimescale))
        manager.change(controller)
        manager.delegate?.playerManager(didCurrentMediaChange: media)
    }
    
    func play() {
        AKPlayerLogger.shared.log(message: "Wait media to be loaded before playing", domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .waitTillMediaLoaded)
    }
    
    func pause() {
        cancelLoading()
        let controller = AKPausedState(manager: manager)
        manager.change(controller)
    }
    
    func stop() {
        cancelLoading()
        let controller = AKStoppedState(manager: manager)
        manager.change(controller)
    }
    
    func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        AKPlayerLogger.shared.log(message: "Wait media to be loaded before playing", domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .waitTillMediaLoaded)
        completionHandler(false)
    }
    
    func seek(to time: CMTime) {
        AKPlayerLogger.shared.log(message: "Wait media to be loaded before playing", domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .waitTillMediaLoaded)
    }
    
    func seek(to time: Double, completionHandler: @escaping (Bool) -> Void) {
        seek(to: CMTime(seconds: time, preferredTimescale: manager.configuration.preferredTimescale), completionHandler: completionHandler)
    }
    
    func seek(to time: Double) {
        seek(to: CMTime(seconds: time, preferredTimescale: manager.configuration.preferredTimescale))
    }
    
    func seek(offset: Double) {
        AKPlayerLogger.shared.log(message: "Wait media to be loaded before playing", domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .waitTillMediaLoaded)
    }
    
    func seek(offset: Double, completionHandler: @escaping (Bool) -> Void) {
        AKPlayerLogger.shared.log(message: "Wait media to be loaded before playing", domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
        completionHandler(false)
    }
    
    // MARK: - Additional Helper Functions
    
    private func createPlayerItem(with media: AKPlayable) {
        playerIemInitializationService = AKPlayerItemInitializationService(with: media, configuration: manager.configuration)
        playerIemInitializationService.onCompletedCreatingPlayerItem = { [unowned self] result in
            switch result {
            case .success(let item):
                self.manager.player.replaceCurrentItem(with: item)
                self.startObservingStatus(for: item)
            case .failure(let error):
                self.assetFailedToPrepareForPlayback(with: error)
            }
        }
    }
    
    private func startObservingStatus(for item: AVPlayerItem) {
        playerItemStatusObservingService = AKPlayerItemStatusObservingService(playerItem: item) { [unowned self] (status) in
            switch status {
            case .unknown:
                assertionFailure()
            case .readyToPlay:
                self.readyToPlay(item: item)
            case .failed:
                self.assetFailedToPrepareForPlayback(with: .loadingFailed)
            @unknown default:
                assertionFailure()
            }
        }
    }
    
    private func readyToPlay(item: AVPlayerItem) {
        let controller = AKLoadedState(manager: manager)
        manager.change(controller)
        if let position = position {
            guard let item = manager.currentItem else { assertionFailure("Current item should be available"); return }
            
            let seekService = AKPlayerSeekService(with: item, configuration: manager.configuration)
            let result = seekService.boundedTime(position)
            
            if let seekTime = result.time {
                controller.seek(to: seekTime)
            } else if let reason = result.reason {
                AKPlayerLogger.shared.log(message: reason.description, domain: .unavailableCommand)
            } else {
                assertionFailure("BoundedPosition should return at least value or reason")
            }
        }
        if autoPlay { controller.play() }
    }
    
    private func cancelLoading() {
        playerIemInitializationService?.cancelLoading(clearCallBacks: true)
        manager.currentItem?.cancelPendingSeeks()
        manager.player.replaceCurrentItem(with: nil)
    }
    
    private func resetPlayerForNewMedia() {
        /*
         Loading a clip media from playing state, play automatically the new clip media
         Ensure player will play only when we ask
         */
        manager.player.pause()
        
        /*
         It seems to be a good idea to reset player current item
         Fix side effect when coming from failed state
         */
        manager.player.replaceCurrentItem(with: nil)
        
        cancelLoading()
    }
    
    private func startAudioSessionInterruptionObserving() {
        audioSessionInterruptionObservingService = AKAudioSessionInterruptionObservingService()
        
        audioSessionInterruptionObservingService.onInterruptionBegan = { [weak self] in
            guard let strongSelf = self else { return }
            let controller = AKPausedState(manager: strongSelf.manager)
            strongSelf.manager.change(controller)
        }
    }
    
    // MARK: - Error Handling - Preparing Assets for Playback Failed
    
    /* --------------------------------------------------------------
     **  Called when an asset fails to prepare for playback for any of
     **  the following reasons:
     **
     **  1) values of asset keys did not load successfully,
     **  2) the asset keys did load successfully, but the asset is not
     **     playable
     **  3) the item did not become ready to play.
     ** ----------------------------------------------------------- */
    private func assetFailedToPrepareForPlayback(with error: AKPlayerError) {
        AKPlayerLogger.shared.log(message: error.localizedDescription, domain: .error)
        let controller = AKFailedState(manager: manager, error: error)
        manager.change(controller)
    }
}
