//
//  AKPlayerPlaybackObservingService.swift
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

protocol AKPlayerPlaybackObservingServiceable {
    var onPlayerItemDidPlayToEndTime: (() -> Void)? { get set }
    var onPlayerItemFailedToPlayToEndTime: (() -> Void)? { get set }
    var onPlayerItemPlaybackStalled: (() -> Void)? { get set }
}

final class AKPlayerPlaybackObservingService: AKPlayerPlaybackObservingServiceable {
    
    // MARK: - Properties
    
    private let playerItem: AVPlayerItem
    
    var onPlayerItemDidPlayToEndTime: (() -> Void)?
    var onPlayerItemFailedToPlayToEndTime: (() -> Void)?
    var onPlayerItemPlaybackStalled: (() -> Void)?
    
    // MARK: - Init
    
    init(playerItem: AVPlayerItem) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleService)
        self.playerItem = playerItem
        /* When the player item has played to its end time */
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_ :)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        /* When the player item has failed to play to its end time */
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_ :)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        /* A notification that’s posted when some media doesn’t arrive in time to continue playback.
         
         The notification’s object is the player item whose playback is unable to continue due to network delays. Streaming-media playback continues once the player receives a sufficient amount of data. File-based playback doesn’t continue.
         */
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemPlaybackStalled(_ :)), name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: playerItem)
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleService)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: playerItem)
    }
    
    /* Called when the player item has played to its end time. */
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, item == playerItem else { return }
        onPlayerItemDidPlayToEndTime?()
    }
    
    /* When the player item has failed to play to its end time */
    @objc private func playerItemFailedToPlayToEndTime(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, item == playerItem else { return }
        onPlayerItemFailedToPlayToEndTime?()
    }
    
    /* A notification that’s posted when some media doesn’t arrive in time to continue playback. */
    @objc func playerItemPlaybackStalled(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, item == playerItem else { return }
        onPlayerItemPlaybackStalled?()
    }
}
