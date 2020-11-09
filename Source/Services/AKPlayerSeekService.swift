//
//  AKPlayerSeekService.swift
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

protocol AKPlayerSeekServiceable {
    func boundedTime(_ time: CMTime) -> (time: CMTime?, reason: AKPlayerUnavailableActionReason?)
}

final class AKPlayerSeekService: AKPlayerSeekServiceable {
    
    // MARK: - Properties
    
    private let playerItem: AVPlayerItem
    private let configuration: AKPlayerConfiguration
    
    // MARK: - Init
    
    init(with playerItem: AVPlayerItem, configuration: AKPlayerConfiguration) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleService)
        self.playerItem = playerItem
        self.configuration = configuration
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleService)
    }
    
    // MARK: - Additional Helper Functions
    
    private func isTimeInRanges(_ time: CMTime, _ ranges: [CMTimeRange]) -> Bool {
        return ranges.filter({$0.containsTime(time)}).count > 0
    }
    
    private func getRangesAvailable(for item: AVPlayerItem) -> [CMTimeRange] {
        let ranges = item.seekableTimeRanges + item.loadedTimeRanges
        return ranges.map { $0.timeRangeValue }
    }
    
    func boundedTime(_ time: CMTime) -> (time: CMTime?, reason: AKPlayerUnavailableActionReason?) {
        
        guard time.isValid && time.isNumeric && time.seconds > 0 else { return (time, nil)}
        
        let duration = playerItem.duration.seconds
        guard duration.isNormal else {
            let ranges = getRangesAvailable(for: playerItem)
            return isTimeInRanges(time, ranges) ? (time, nil) : (nil, .seekPositionNotAvailable)
        }
        
        guard time.seconds < duration else { return (nil, .seekPositionNotAvailable) }
        
        return (time, nil)
    }
}


