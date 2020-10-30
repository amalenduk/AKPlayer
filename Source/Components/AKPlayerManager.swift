//
//  AKPlayerManager.swift
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

open class AKPlayerManager: AKPlayerManageable {
    
    // MARK: - Properties

    open private (set) var currentMedia: AKPlayable? {
        didSet {
            guard let media = currentMedia else { assertionFailure("Media should available"); return }
            plugins.forEach({$0.playerPlugin(didChanged: media)})
        }
    }

    open var currentItem: AVPlayerItem? {
        return player.currentItem
    }
    
    open var currentTime: CMTime {
        return player.currentTime()
    }
    
    open var itemDuration: CMTime? {
        return currentItem?.duration
    }
    
    open private (set) var player: AVPlayer

    /// Current state of the player
    open var state: AKPlayer.State {
        return controller.state
    }
    
    open private (set) var plugins: [AKPlayerPlugin]
    
    open private (set) var configuration: AKPlayerConfiguration
    
    open private (set) var controller: AKPlayerStateControllable! {
        didSet {
            delegate?.playerManager(didStateChange: controller.state)
        }
    }

    open weak var delegate: AKPlayerManageableDelegate?
    
    public let audioSessionService: AKAudioSessionServiceable

    public var playerNowPlayingMetadataService: AKPlayerNowPlayingMetadataServiceable?

    public private(set) var remoteCommandsService: AKNowPlayableCommandService?
    
    // MARK: - Init
    
    public init(player: AVPlayer,
                plugins: [AKPlayerPlugin],
                configuration: AKPlayerConfiguration,
                audioSessionService: AKAudioSessionServiceable = AKAudioSessionService(),
                playerNowPlayingMetadataService: AKPlayerNowPlayingMetadataServiceable = AKPlayerNowPlayingMetadataService()) {
        self.player = player
        self.plugins = plugins
        self.configuration = configuration
        self.audioSessionService = audioSessionService
        self.playerNowPlayingMetadataService = playerNowPlayingMetadataService

        if configuration.isRemoteCommandsEnabled {
            remoteCommandsService = AKNowPlayableCommandService(with: player, configuration: configuration, manager: self)
            remoteCommandsService?.enable()
        }
        
        setAudioSessionCategory()
        
        defer {
            controller = AKInitState(manager: self)
        }
    }
    
    deinit {
        AKNowPlayableCommand.allCases.forEach({$0.removeHandler()})
    }
    
    open func change(_ controller: AKPlayerStateControllable) {
        self.controller = controller
    }

    // MARK: - Commands

    open func load(media: AKPlayable) {
        currentMedia = media
        controller.load(media: media)
    }
    
    open func load(media: AKPlayable, autoPlay: Bool) {
        currentMedia = media
        controller.load(media: media, autoPlay: autoPlay)
    }
    
    open func load(media: AKPlayable, autoPlay: Bool, at position: CMTime) {
        currentMedia = media
        controller.load(media: media, autoPlay: autoPlay, at: position)
    }
    
    open func load(media: AKPlayable, autoPlay: Bool, at position: Double) {
        currentMedia = media
        controller.load(media: media, autoPlay: autoPlay, at: position)
    }
    
    open func play() {
        controller.play()
    }
    
    open func pause() {
        controller.pause()
    }
    
    open func stop() {
        controller.stop()
    }
    
    open func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        guard let item = currentItem else { unaivalableCommand(reason: .loadMediaFirst); completionHandler(false); return }
        
        let seekService = AKPlayerSeekService(with: item, configuration: configuration)
        let result = seekService.boundedTime(time)
        
        if let seekTime = result.time {
            controller.seek(to: seekTime, completionHandler: completionHandler)
        } else if let reason = result.reason {
            unaivalableCommand(reason: reason)
            completionHandler(false)
        } else {
            assertionFailure("BoundedPosition should return at least value or reason")
        }
    }
    
    open func seek(to time: CMTime) {
        seek(to: time) { (finished) in
            if !finished {
                AKPlayerLogger.shared.log(message: "Seek to time: \(time.seconds) is not completed", domain: .state)
            }
        }
    }
    
    open func seek(to time: Double, completionHandler: @escaping (Bool) -> Void) {
        seek(to: CMTime(seconds: time, preferredTimescale: configuration.preferredTimescale), completionHandler: completionHandler)
    }
    
    open func seek(to time: Double) {
        seek(to: CMTime(seconds: time, preferredTimescale: configuration.preferredTimescale))
    }
    
    open func seek(offset: Double) {
        let position = currentTime.seconds + offset
        seek(to: position)
    }
    
    open func seek(offset: Double, completionHandler: @escaping (Bool) -> Void) {
        let position = currentTime.seconds + offset
        seek(to: position, completionHandler: completionHandler)
    }
    
    // MARK: - Additional Helper Functions
    
    private func unaivalableCommand(reason: AKPlayerUnavailableActionReason) {
        delegate?.playerManager(unavailableAction: reason)
        AKPlayerLogger.shared.log(message: reason.description, domain: .unavailableCommand)
    }
    
    open func setAudioSessionCategory() {
        audioSessionService.setCategory(configuration.audioSessionCategory, mode: configuration.audioSessionMode, options: configuration.audioSessionCategoryOptions)
    }

    public func setNowPlayingMetadata() {
        guard configuration.isRemoteCommandsEnabled else { return }
        guard let media = currentMedia else { assertionFailure("Media should exist here"); return }
        guard let staticMetadata = media.staticMetadata, let playerNowPlayingMetadataService = playerNowPlayingMetadataService else { return }
        playerNowPlayingMetadataService.setNowPlayingMetadata(staticMetadata)
    }
    
    public func setNowPlayingPlaybackInfo() {
        guard configuration.isRemoteCommandsEnabled else { return }
        guard let playerNowPlayingMetadataService = playerNowPlayingMetadataService else { return }
        playerNowPlayingMetadataService.setNowPlayingPlaybackInfo(AKMediaDynamicMetadata(rate: player.rate, position: Float(currentTime.seconds), duration: Float(player.currentItem?.duration.seconds ?? 0), currentLanguageOptions: [], availableLanguageOptionGroups: []))
    }
}
