//
//  AKLoadedState.swift
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

final class AKLoadedState: AKPlayerStateControllable {
    
    // MARK: - Properties
    
    unowned var manager: AKPlayerManageable
    
    var state: AKPlayer.State = .loaded
    
    private let autoPlay: Bool
    private let position: CMTime?
    
    private var playerTimeObservingService: AKPlayerTimeObservingServiceable!
    
    // MARK: - Init
    
    init(manager: AKPlayerManageable,
         autoPlay: Bool = false,
         at position: CMTime? = nil) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleState)
        self.manager = manager
        self.autoPlay = autoPlay
        self.position = position
        guard let media = manager.currentMedia, let currentItem = manager.currentItem else { assertionFailure("Media and Current item should available"); return }
        manager.currentMedia?.setAssetMetadata(AKMediaMetadata(with: currentItem.asset.commonMetadata))
        manager.delegate?.playerManager(didItemDurationChange: currentItem.duration)
        manager.plugins.forEach({$0.playerPlugin(didLoad: media, with: currentItem.duration)})
        startPlayerTimeObserving()
        if let position = position {
            seek(to: position)
        }else {
            manager.delegate?.playerManager(didCurrentTimeChange: currentItem.currentTime())
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            if self.autoPlay { self.play() }
        }
        setMetadata()
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleState)
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
        let controller = AKBufferingState(manager: manager)
        manager.change(controller)
        controller.playCommand()
    }
    
    func pause() {
        let controller = AKPausedState(manager: manager)
        manager.change(controller)
    }
    
    func stop() {
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
    
    func step(byCount stepCount: Int) {
        guard let playerItem = manager.currentItem else { assertionFailure("Player item should available"); return }
        if stepCount.signum() == 1, playerItem.canStepForward {
            playerItem.step(byCount: stepCount)
        }else {
            if playerItem.canStepBackward { playerItem.step(byCount: stepCount) }
        }
    }
    
    // MARK: - Additional Helper Functions
    
    private func startPlayerTimeObserving() {
        playerTimeObservingService = AKPlayerTimeObservingService(with: manager.player, configuration: manager.configuration)
        
        playerTimeObservingService.onChangePeriodicTime = { [unowned self] time in
            manager.setNowPlayingPlaybackInfo()
            manager.delegate?.playerManager(didCurrentTimeChange: time)
        }
    }
    
    private func setMetadata() {
        manager.setNowPlayingMetadata()
    }
}
