//
//  AKPlayerPlaybackRateService.swift
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

protocol AKPlayerPlaybackRateServiceable {
    var itemRateCallback: ((Bool) -> Void) { get set }
}

final class AKPlayerPlaybackRateService: AKPlayerPlaybackRateServiceable {

    // MARK: - Properties

    private let item: AVPlayerItem
    private let rate: AKPlaybackRate
    internal var itemRateCallback: ((Bool) -> Void)

    // MARK: - Init

    @discardableResult init(with item: AVPlayerItem, rate: AKPlaybackRate, callback: @escaping (Bool) -> Void) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleService)
        self.item = item
        self.rate = rate
        self.itemRateCallback = callback
        itemCanBePlayed(at: rate)
    }

    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleService)
    }

    // MARK: - Additional Helper Functions

    private func itemCanBePlayed(at rate: AKPlaybackRate) {
        switch rate.rate {
        case 0.0...:
            switch rate.rate {
            case 2.0...:
                itemRateCallback(item.canPlayFastForward)
            case 1.0..<2.0:
                itemRateCallback(true)
            case 0.0..<1.0:
                itemRateCallback(item.canPlaySlowForward)
            default:
                assertionFailure("Implement condition")
            }
        case ..<0.0:
            switch rate.rate {
            case -1.0:
                itemRateCallback(item.canPlayReverse)
            case -1.0..<0.0:
                itemRateCallback(item.canPlaySlowReverse)
            case ..<(-1.0):
                itemRateCallback(item.canPlayFastReverse)
            default:
                assertionFailure("Implement condition")
            }
        default:
            assertionFailure("Implement condition")
        }
    }
}

