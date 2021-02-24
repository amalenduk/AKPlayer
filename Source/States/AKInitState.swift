//
//  AKInitState.swift
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

final class AKInitState: AKPlayerStateControllable {
    
    // MARK: - Properties
    
    unowned var manager: AKPlayerManageable
    
    var state: AKPlayer.State = .initialization
    
    // MARK: - Init
    
    init(manager: AKPlayerManageable) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleState)
        self.manager = manager
        manager.plugins.forEach({$0.playerPlugin(didInit: manager.player)})
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
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
    }
    
    func pause() {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
    }
    
    func stop() {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
    }
    
    func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
        completionHandler(false)
    }
    
    func seek(to time: CMTime) {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .waitTillMediaLoaded)
    }
    
    func seek(to time: Double, completionHandler: @escaping (Bool) -> Void) {
        seek(to: CMTime(seconds: time, preferredTimescale: manager.configuration.preferredTimescale), completionHandler: completionHandler)
    }
    
    func seek(to time: Double) {
        seek(to: CMTime(seconds: time, preferredTimescale: manager.configuration.preferredTimescale))
    }
    
    func seek(offset: Double) {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .waitTillMediaLoaded)
    }
    
    func seek(offset: Double, completionHandler: @escaping (Bool) -> Void) {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
        completionHandler(false)
    }
    
    func seek(toPercentage value: Double, completionHandler: @escaping (Bool) -> Void) {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
        completionHandler(false)
    }

    func seek(toPercentage value: Double) {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
    }

    func step(byCount stepCount: Int) {
        AKPlayerLogger.shared.log(message: AKPlayerUnavailableActionReason.loadMediaFirst.description, domain: .unavailableCommand)
        manager.delegate?.playerManager(unavailableAction: .loadMediaFirst)
    }
}
