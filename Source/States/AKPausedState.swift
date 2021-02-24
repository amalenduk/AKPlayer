//
//  AKPausedState.swift
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

final class AKPausedState: AKPlayerStateControllable {
    
    // MARK: - Properties
    
    unowned var manager: AKPlayerManageable
    
    var state: AKPlayer.State = .paused
    
    private var audioSessionInterruptionObservingService: AKAudioSessionInterruptionObservingServiceable!
    private var playerTimeObservingService: AKPlayerTimeObservingServiceable!
    private var playerTimeControlStatusObservingService: AKPlayerTimeControlStatusObservingServiceable?
    
    // MARK: - Init
    
    init(manager: AKPlayerManageable) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleState)
        self.manager = manager
        manager.player.pause()
        guard let media = manager.currentMedia else { assertionFailure("Media should available"); return }
        manager.plugins.forEach({$0.playerPlugin(didPaused: media, at: manager.currentTime)})
        startAudioSessionInterruptionObserving()
        startPlayerTimeObserving()
        startPlayerTimeControlStatusObserving()
        setMetadata()
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
        if manager.currentItem?.status == .readyToPlay {
            let controller = AKBufferingState(manager: manager)
            change(controller)
            controller.playCommand()
        } else if let media = manager.currentMedia {
            let controller = AKLoadingState(manager: manager, media: media)
            change(controller)
        } else {
            assertionFailure("Sould not be here")
        }
    }
    
    func pause() {
        AKPlayerLogger.shared.log(message: "Already paused", domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .alreadyPaused)
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

    func step(byCount stepCount: Int) {
        guard let playerItem = manager.currentItem else { assertionFailure("Player item should available"); return }
        if stepCount.signum() == 1, playerItem.canStepForward {
            playerItem.step(byCount: stepCount)
        }else {
            if playerItem.canStepBackward { playerItem.step(byCount: stepCount) }
        }
    }
    
    // MARK: - Additional Helper Functions
    
    private func change(_ controller: AKPlayerStateControllable) {
        playerTimeControlStatusObservingService?.stop(clearCallBacks: true)
        manager.change(controller)
    }
    
    private func startAudioSessionInterruptionObserving() {
        audioSessionInterruptionObservingService = AKAudioSessionInterruptionObservingService()
        
        audioSessionInterruptionObservingService.onInterruptionEnded = { shouldResume in
            if shouldResume {
                // To be implemented.
            }
        }
    }
    
    private func startPlayerTimeObserving() {
        /*
         Check before start observing boundaryTime becuase if current item is nil no need to start observing,
         Sometimes state can change direct from loading state to stop state
         */
        guard manager.player.currentItem != nil else { return }
        playerTimeObservingService = AKPlayerTimeObservingService(with: manager.player, configuration: manager.configuration)
        
        playerTimeObservingService.onChangePeriodicTime = { [unowned self] time in
            setMetadata()
            manager.delegate?.playerManager(didCurrentTimeChange: time)
        }
    }
    
    private func startPlayerTimeControlStatusObserving() {
        playerTimeControlStatusObservingService = AKPlayerTimeControlStatusObservingService(with: manager.player, configuration: manager.configuration)
        
        playerTimeControlStatusObservingService?.onChangeTimeControlStatus = { [unowned self] status in
            guard status == .playing else { return }
            let controller = AKPlayingState(manager: manager)
            change(controller)
        }
    }

    private func setMetadata() {
        manager.setNowPlayingPlaybackInfo()
    }
}
