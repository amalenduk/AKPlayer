//
//  AKPlayingState.swift
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

final class AKPlayingState: AKPlayerStateControllable {
    
    // MARK: - Properties
    
    unowned var manager: AKPlayerManagerProtocol
    
    var state: AKPlayer.State = .playing
    
    private var playerPlaybackObservingService: AKPlayerPlaybackObservingServiceable!
    private var audioSessionInterruptionObservingService: AKAudioSessionInterruptionObservingServiceable!
    private var playerTimeObservingService: AKPlayerTimeObservingServiceable!
    private var routeChangeObservingService: AKPlayerRouteChangeObservingServiceable!
    private var playerTimeControlStatusObservingService: AKPlayerTimeControlStatusObservingServiceable!
    
    // MARK: - Init
    
    init(manager: AKPlayerManagerProtocol) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleState)
        self.manager = manager
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleState)
    }

    func stateUpdated() {
        guard let media = manager.currentMedia else { assertionFailure("Media should available"); return }
        manager.plugins.forEach({$0.playerPlugin(didStartPlaying: media, at: manager.currentTime)})
        startPlayerPlaybackObserving()
        startAudioSessionInterruptionObserving()
        startPlayerTimeObserving()
        startRouteChangeObserving()
        startPlayerTimeControlStatusObserving()
        manager.setNowPlayingPlaybackInfo()
    }
    
    // MARK: - Commands
    
    func load(media: AKPlayable) {
        let controller = AKLoadingState(manager: manager, media: media)
        manager.change(controller)
    }
    
    func load(media: AKPlayable, autoPlay: Bool) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay)
        manager.change(controller)
    }
    
    func load(media: AKPlayable, autoPlay: Bool, at position: CMTime) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay, at: position)
        manager.change(controller)
    }
    
    func load(media: AKPlayable, autoPlay: Bool, at position: Double) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay, at: CMTime(seconds: position, preferredTimescale: manager.configuration.preferredTimescale))
        manager.change(controller)
    }
    
    func play() {
        AKPlayerLogger.shared.log(message: "Already playing", domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .alreadyPlaying)
    }
    
    func pause() {
        /* It is necessary to remove the callbacks for time control status before change state to paused state,
         Eighter it will cause an infinite loop between paused state and the time control staus to call on waiting
         for the network state. */
        playerTimeControlStatusObservingService?.stop(clearCallBacks: true)
        let controller = AKPausedState(manager: manager)
        manager.change(controller)
    }
    
    func stop() {
        /* It is necessary to remove the callbacks for time control status before change state to paused state,
         Eighter it will cause an infinite loop between paused state and the time control staus to call on waiting
         for the network state. */
        playerTimeControlStatusObservingService?.stop(clearCallBacks: true)
        let controller = AKStoppedState(manager: manager)
        manager.change(controller)
    }
    
    func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        manager.currentItem?.cancelPendingSeeks()
        manager.player.seek(to: time, completionHandler: completionHandler)
    }
    
    func seek(to time: CMTime) {
        manager.currentItem?.cancelPendingSeeks()
        manager.player.seek(to: time)
    }
    
    func seek(to time: Double, completionHandler: @escaping (Bool) -> Void) {
        seek(to: CMTime(seconds: time, preferredTimescale: manager.configuration.preferredTimescale), completionHandler: completionHandler)
    }
    
    func seek(to time: Double) {
        seek(to: CMTime(seconds: time, preferredTimescale: manager.configuration.preferredTimescale))
    }
    
    func seek(offset: Double) {
        seek(to: manager.currentTime.seconds + offset)
    }
    
    func seek(offset: Double, completionHandler: @escaping (Bool) -> Void) {
        seek(to: manager.currentTime.seconds + offset, completionHandler: completionHandler)
    }
    
    func seek(toPercentage value: Double, completionHandler: @escaping (Bool) -> Void) {
        seek(to: (manager.itemDuration?.seconds ?? 0) / value, completionHandler: completionHandler)
    }
    
    func seek(toPercentage value: Double) {
        seek(to: (manager.itemDuration?.seconds ?? 0) / value)
    }
    
    // MARK: - Additional Helper Functions
    
    private func startPlayerPlaybackObserving() {
        guard let playerItem = manager.player.currentItem
            else { assertionFailure("Should not possible to start observing with out playerItem"); return }
        playerPlaybackObservingService = AKPlayerPlaybackObservingService(playerItem: playerItem)
        
        playerPlaybackObservingService.onPlayerItemDidPlayToEndTime = { [unowned self] in
            self.manager.delegate?.playerManager(didItemPlayToEndTime: self.manager.currentTime)
            guard let media = self.manager.currentMedia else { assertionFailure("Media should available"); return }
            self.manager.plugins.forEach({$0.playerPlugin(didPlayToEnd: media, at: self.manager.currentTime)})
            /* It is necessary to remove the callbacks for time control status before change state to stopped state,
             Eighter it will cause an infinite loop between paused state and the time control staus to call on waiting
             for the network state. */
            self.playerTimeControlStatusObservingService?.stop(clearCallBacks: true)
            let controller = AKStoppedState(manager: self.manager, playerItemDidPlayToEndTime: true)
            self.manager.change(controller)
        }
        
        playerPlaybackObservingService.onPlayerItemFailedToPlayToEndTime = { [unowned self] in
            let controller = AKWaitingForNetworkState(manager: self.manager)
            self.manager.change(controller)
        }
        
        playerPlaybackObservingService.onPlayerItemPlaybackStalled = { [unowned self] in
            let controller = AKWaitingForNetworkState(manager: self.manager)
            self.manager.change(controller)
        }
    }
    
    private func startAudioSessionInterruptionObserving() {
        audioSessionInterruptionObservingService = AKAudioSessionInterruptionObservingService()
        
        audioSessionInterruptionObservingService.onInterruptionBegan = { [unowned self] in
            self.pause()
        }
    }
    
    private func startPlayerTimeObserving() {
        playerTimeObservingService = AKPlayerTimeObservingService(with: manager.player, configuration: manager.configuration)
        
        playerTimeObservingService.onChangePeriodicTime = { [unowned self] time in
            self.manager.setNowPlayingPlaybackInfo()
            self.manager.delegate?.playerManager(didCurrentTimeChange: time)
        }
    }
    
    private func startRouteChangeObserving() {
        routeChangeObservingService = AKPlayerRouteChangeObservingService(configuration: manager.configuration)
        
        routeChangeObservingService.onChangeRoute = { [unowned self] reason  in
            switch reason {
            case .oldDeviceUnavailable, .unknown:
                self.pause()
            default:
                break
            }
        }
    }
    
    private func startPlayerTimeControlStatusObserving() {
        playerTimeControlStatusObservingService = AKPlayerTimeControlStatusObservingService(with: manager.player, configuration: manager.configuration)
        
        playerTimeControlStatusObservingService?.onChangeTimeControlStatus = { [unowned self] status in
            switch status {
            case .paused:
                self.pause()
            case .waitingToPlayAtSpecifiedRate:
                let controller = AKBufferingState(manager: self.manager)
                self.manager.change(controller)
            default:
                break
            }
        }
    }
}
