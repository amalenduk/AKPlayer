//
//  AKNowPlayableCommandService.swift
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
import Foundation
import MediaPlayer

public class AKNowPlayableCommandService {
    
    // MARK: - Properties
    
    public var defaultCommands: [AKNowPlayableCommand] {
        return [.play, .pause, .skipForward, .skipBackward, .changePlaybackPosition]
    }
    
    private let configuration: AKPlayerConfiguration
    private unowned let manager: AKPlayerManageable
    
    // MARK: - Init
    
    public init(with manager: AKPlayerManageable, configuration: AKPlayerConfiguration) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleService)
        self.configuration = configuration
        self.manager = manager
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleService)
    }
    
    // MARK: - Additional Helper Functions
    
    public func enable() {
        addHandlers()
    }
    
    private func addHandlers() {
        for command in defaultCommands {
            command.removeHandler()
            command.addHandler(handleCommand(command:event:))
        }
    }
    
    private func handleCommand(command: AKNowPlayableCommand, event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        
        switch command {
        case .pause:
            manager.controller.pause()
        case .play:
            manager.controller.play()
        case .stop:
            manager.controller.stop()
        case .togglePausePlay:
            switch manager.controller.state {
            case .playing, .buffering, .loading, .waitingForNetwork:
                manager.controller.pause()
            case .initialization:
                return .noActionableNowPlayingItem
            case .loaded, .paused, .stopped, .failed:
                manager.controller.play()
            }
        case .nextTrack:
            return .commandFailed
        case .previousTrack:
            return .commandFailed
        case .changePlaybackRate:
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            manager.playbackRate = AKPlaybackRate(rate: event.playbackRate)
        case .seekBackward:
            guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
            manager.player.rate = (event.type == .beginSeeking ? -3.0 : 1.0)
        case .seekForward:
            guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
            manager.player.rate = (event.type == .beginSeeking ? 3.0 : 1.0)
        case .skipBackward:
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            manager.controller.seek(offset: -event.interval)
        case .skipForward:
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            manager.controller.seek(offset: event.interval)
        case .changePlaybackPosition:
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            manager.controller.seek(to: event.positionTime)
        case .enableLanguageOption:
            guard let _ = event as? MPChangeLanguageOptionCommandEvent else { return .commandFailed }
            return .noActionableNowPlayingItem
        case .disableLanguageOption:
            guard let _ = event as? MPChangeLanguageOptionCommandEvent else { return .commandFailed }
            return .noActionableNowPlayingItem
        default:
            break
        }
        return .success
    }
}
