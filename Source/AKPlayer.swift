//
//  AKPlayer.swift
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

open class AKPlayer: AKPlayerExposable {

    // MARK: - Properties
    
    open var currentMedia: AKPlayable? {
        return manager.currentMedia
    }

    open var currentItem: AVPlayerItem? {
        return manager.currentItem
    }

    open var currentTime: CMTime {
        return manager.currentTime
    }

    open var itemDuration: CMTime? {
        return manager.itemDuration
    }

    open var state: AKPlayer.State {
        return manager.state
    }

    public let player: AVPlayer
    
    public let manager: AKPlayerManager
    
    open weak var delegate: AKPlayerDelegate?
    
    // MARK: - Init
    
    public init(player: AVPlayer = AVPlayer(),
                plugins: [AKPlayerPlugin] = [],
                configuration: AKPlayerConfiguration = AKPlayerDefaultConfiguration(),
                loggerDomains: [AKPlayerLoggerDomain] = []) {
        self.player = player
        AKPlayerLogger.setup.domains = loggerDomains
        manager = AKPlayerManager(player: player, plugins: plugins, configuration: configuration)
        manager.delegate = self
    }

    // MARK: - Commands
    
    open func load(media: AKPlayable) {
        manager.load(media: media)
    }
    
    open func load(media: AKPlayable, autoPlay: Bool) {
        manager.load(media: media, autoPlay: autoPlay)
    }
    
    open func load(media: AKPlayable, autoPlay: Bool, at position: CMTime) {
        manager.load(media: media, autoPlay: autoPlay, at: position)
    }
    
    open func load(media: AKPlayable, autoPlay: Bool, at position: Double) {
        manager.load(media: media, autoPlay: autoPlay, at: position)
    }
    
    open func play() {
        manager.play()
    }
    
    open func pause() {
        manager.pause()
    }
    
    open func stop() {
        manager.stop()
    }
    
    open func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        manager.seek(to: time, completionHandler: completionHandler)
    }
    
    open func seek(to time: CMTime) {
        manager.seek(to: time)
    }
    
    open func seek(to time: Double, completionHandler: @escaping (Bool) -> Void) {
        manager.seek(to: time, completionHandler: completionHandler)
    }
    
    open func seek(to time: Double) {
        manager.seek(to: time)
    }
    
    open func seek(offset: Double) {
        manager.seek(offset: offset)
    }
    
    open func seek(offset: Double, completionHandler: @escaping (Bool) -> Void) {
        manager.seek(offset: offset, completionHandler: completionHandler)
    }

    open func setNowPlayingMetadata() {
        manager.setNowPlayingMetadata()
    }

    open func setNowPlayingPlaybackInfo() {
        manager.setNowPlayingPlaybackInfo()
    }
}

// MARK: - AKPlayerManageableDelegate

extension AKPlayer: AKPlayerManageableDelegate {

    public func playerManager(didStateChange state: AKPlayer.State) {
        delegate?.akPlayer(self, didStateChange: state)
    }
    
    public func playerManager(didCurrentMediaChange media: AKPlayable) {
        delegate?.akPlayer(self, didCurrentMediaChange: media)
    }
    
    public func playerManager(didCurrentTimeChange currentTime: CMTime) {
        delegate?.akPlayer(self, didCurrentTimeChange: currentTime)
    }
    
    public func playerManager(didItemDurationChange itemDuration: CMTime) {
        delegate?.akPlayer(self, didItemDurationChange: itemDuration)
    }
    
    public func playerManager(unavailableAction reason: AKPlayerUnavailableActionReason) {
        delegate?.akPlayer(self, unavailableAction: reason)
    }
    
    public func playerManager(didItemPlayToEndTime endTime: CMTime) {
        delegate?.akPlayer(self, didItemPlayToEndTime: endTime)
    }

    public func playerManager(didFailedWith error: AKPlayerError) {
        delegate?.akPlayer(self, didFailedWith: error)
    }
}

public extension AKPlayer {
    enum State: String, CustomStringConvertible {
        case buffering
        case failed
        case initialization
        case loaded
        case loading
        case paused
        case playing
        case stopped
        case waitingForNetwork
        
        public var description: String {
            switch self {
            case .waitingForNetwork:
                return "Waiting For Network"
            default:
                return rawValue.capitalized
            }
        }
    }
}
