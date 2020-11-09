//
//  AKBufferingState.swift
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

final class AKBufferingState: AKPlayerStateControllable {
    
    // MARK: - Properties
    
    unowned var manager: AKPlayerManageable
    
    var state: AKPlayer.State = .buffering
    
    private var playerItemBufferObservingService: AKPlayerItemBufferObservingServiceable?
    private var playerTimeObservingService: AKPlayerTimeObservingServiceable!
    private var audioSessionInterruptionObservingService: AKAudioSessionInterruptionObservingServiceable!
    private var routeChangeObservingService: AKPlayerRouteChangeObservingServiceable!
    private var playerTimeControlStatusObservingService: AKPlayerTimeControlStatusObservingServiceable!
    
    // MARK: - Init
    
    init(manager: AKPlayerManageable) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleState)
        self.manager = manager
        guard let media = manager.currentMedia else { assertionFailure("Media should available"); return }
        manager.plugins.forEach({$0.playerPlugin(didStartBuffering: media)})
        startplayerItemBufferObserving()
        startPlayerTimeObserving()
        startAudioSessionInterruptionObserving()
        startRouteChangeObserving()
        startPlayerTimeControlStatusObserving()
        manager.setNowPlayingPlaybackInfo()
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleState)
    }
    
    // MARK: - Commands
    
    func load(media: AKPlayable) {
        let controller = AKLoadingState(manager: manager, media: media)
        change(controller)
    }
    
    func load(media: AKPlayable, autoPlay: Bool) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay)
        change(controller)
    }
    
    func load(media: AKPlayable, autoPlay: Bool, at position: CMTime) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay, at: position)
        change(controller)
    }
    
    func load(media: AKPlayable, autoPlay: Bool, at position: Double) {
        let controller = AKLoadingState(manager: manager, media: media, autoPlay: autoPlay, at: CMTime(seconds: position, preferredTimescale: manager.configuration.preferredTimescale))
        change(controller)
    }
    
    func play() {
        AKPlayerLogger.shared.log(message: "Already trying to play", domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .alreadyTryingToPlay)
    }
    
    func pause() {
        /* It is necessary to remove the callbacks for time control status before change state to paused state,
         Eighter it will cause an infinite loop between paused state and the time control staus to call on waiting
         for the network state. */
        playerTimeControlStatusObservingService?.stop(clearCallBacks: true)
        let controller = AKPausedState(manager: manager)
        change(controller)
    }
    
    func stop() {
        let controller = AKStoppedState(manager: manager)
        change(controller)
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
    
    private func startplayerItemBufferObserving() {
        guard let playerItem = manager.currentItem else { assertionFailure("Player item should available"); return }
        playerItemBufferObservingService = AKPlayerItemBufferObservingService(with: playerItem, configuration: manager.configuration)
        
        playerItemBufferObservingService?.onChangePlaybackBufferEmptyStatus = { [unowned self] flag in
            if flag {
                let controller = AKWaitingForNetworkState(manager: self.manager)
                self.change(controller)
            }
        }
        
        playerItemBufferObservingService?.onChangePlaybackBufferFullStatus = { [unowned self] flag in
            if flag {
                let controller = AKPlayingState(manager: self.manager)
                self.change(controller)
            }
        }
        
        playerItemBufferObservingService?.onChangePlaybackLikelyToKeepUpStatus = { [unowned self] flag in
            if flag {
                let controller = AKPlayingState(manager: self.manager)
                self.change(controller)
            }
        }
        
        playerItemBufferObservingService?.onChangePlaybackBufferStatus = { [unowned self] flag in
            if flag {
                let controller = AKPlayingState(manager: self.manager)
                self.change(controller)
            }else {
                let controller = AKWaitingForNetworkState(manager: self.manager)
                self.change(controller)
            }
        }
    }
    
    private func change(_ controller: AKPlayerStateControllable) {
        playerItemBufferObservingService?.stop(clearCallBacks: true)
        guard let media = manager.currentMedia else { assertionFailure("Media and Current item should available"); return }
        if controller is AKPlayingState { manager.plugins.forEach({$0.playerPlugin(didStartPlaying: media, at: manager.currentTime)})}
        manager.change(controller)
    }
    
    func playCommand() {
        manager.player.play()
    }
    
    private func startPlayerTimeObserving() {
        playerTimeObservingService = AKPlayerTimeObservingService(with: manager.player, configuration: manager.configuration)
        
        playerTimeObservingService.onChangePeriodicTime = { [unowned self] time in
            self.manager.delegate?.playerManager(didCurrentTimeChange: time)
        }
    }
    
    private func startAudioSessionInterruptionObserving() {
        audioSessionInterruptionObservingService = AKAudioSessionInterruptionObservingService()
        
        audioSessionInterruptionObservingService.onInterruptionBegan = { [unowned self] in
            self.pause()
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
            default:
                break
            }
        }
    }
}
