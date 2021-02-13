//
//  AKPlayerTimeObservingService.swift
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

protocol AKPlayerTimeObservingServiceable {
    var onChangePeriodicTime: ((_ time: CMTime) -> Void)? { get set }
    func stop(clearCallBacks flag: Bool)
}

final class AKPlayerTimeObservingService: AKPlayerTimeObservingServiceable {
    
    // MARK: - Properties
    
    private let player: AVPlayer
    private let configuration: AKPlayerConfiguration
    
    private var periodicTimeObserverToken : Any?
    
    var onChangePeriodicTime: ((_ time: CMTime) -> Void)?
    
    // MARK: - Init
    
    init(with player: AVPlayer, configuration: AKPlayerConfiguration) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleService)
        self.player = player
        self.configuration = configuration
        addPeriodicTimeObserver(player: player)
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleService)
        removePeriodicTimeObserver(player: player)
    }

    func stop(clearCallBacks flag: Bool) {
        if flag {
            onChangePeriodicTime = nil
        }
        removePeriodicTimeObserver(player: player)
    }
    
    // MARK: - Additional Helper Functions
    
    private func addPeriodicTimeObserver(player: AVPlayer) {
        // Invoke callback every half second
        let interval = CMTime(seconds: configuration.periodicPlayingTimeInSecond,
                              preferredTimescale: configuration.preferredTimescale)
        // Add time observer. Invoke closure on the main queue.
        periodicTimeObserverToken =
            player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
                [weak self] time in
                guard let strongSelf = self else { return }
                strongSelf.onChangePeriodicTime?(time)
        }
    }
    
    private func removePeriodicTimeObserver(player: AVPlayer) {
        // If a time observer exists, remove it
        if let timeObserverToken = periodicTimeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            periodicTimeObserverToken = nil
        }
    }
}
