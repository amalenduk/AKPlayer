//
//  AKPlayerTimeControlStatusObservingService.swift
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

protocol AKPlayerTimeControlStatusObservingServiceable {
    var onChangeTimeControlStatus: ((_ status: AVPlayer.TimeControlStatus) -> Void)? { get set }
    
    func stop(clearCallBacks flag: Bool)
}

final class AKPlayerTimeControlStatusObservingService: AKPlayerTimeControlStatusObservingServiceable {
    
    // MARK: - Properties
    
    private let player: AVPlayer
    private let configuration: AKPlayerConfiguration
    
    var onChangeTimeControlStatus: ((_ status: AVPlayer.TimeControlStatus) -> Void)?
    
    /**
     The `NSKeyValueObservation` for the KVO on `\AVPlayer.timeControlStatus`.
     */
    private var playerTimeControlStatusObserver: NSKeyValueObservation?
    
    // MARK: - Init
    
    init(with player: AVPlayer, configuration: AKPlayerConfiguration) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleService)
        self.player = player
        self.configuration = configuration
        addPlayerTimeControlStatus(player: player)
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleService)
        removePlayerTimeControlStatus(player: player)
    }
    
    func stop(clearCallBacks flag: Bool) {
        if flag {
            onChangeTimeControlStatus = nil
        }
        removePlayerTimeControlStatus(player: player)
    }
    
    // MARK: - Additional Helper Functions
    
    private func addPlayerTimeControlStatus(player: AVPlayer) {
        /*
         Create an observer to toggle the play/pause button control icon to
         reflect the playback state of the player's `timeControStatus` property.
         */
        playerTimeControlStatusObserver = player.observe(\AVPlayer.timeControlStatus,
                                                         options: [.new]) {
                                                            [unowned self] _, _ in
                                                            self.onChangeTimeControlStatus?(player.timeControlStatus)
        }
    }
    
    private func removePlayerTimeControlStatus(player: AVPlayer) {
        // If a time observer exists, remove it
        if let playerTimeControlStatusObserver = playerTimeControlStatusObserver {
            playerTimeControlStatusObserver.invalidate()
        }
    }
}
