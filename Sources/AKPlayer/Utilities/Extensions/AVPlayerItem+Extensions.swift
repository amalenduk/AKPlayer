//
//   AVPlayerItem+Extensions.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - AVPlayerItem Extensions

public extension AVPlayerItem {
    // MARK: - Capabilities

    /// Evaluates whether the player item can step by the specified frame count
    /// directionally.
    /// - Parameter count: The frame step count. Positive for forward, negative
    /// for backward.
    /// - Returns: A Boolean value indicating whether stepping in the requested
    /// direction is supported.
    func canStep(by count: Int) -> Bool {
        var isForward: Bool {
            count.signum() == 1
        }
        return isForward ? canStepForward : canStepBackward
    }

    /// Determines whether the player item can play at a given playback speed
    /// rate.
    /// - Parameter rate: The target playback speed rate to evaluate.
    /// - Returns: A Boolean value indicating capability to play at the
    /// specified rate.
    func canPlay(at rate: AKPlaybackRate) -> Bool {
        switch rate.rate {
        case 0.0...:
            switch rate.rate {
            case 2.0...:
                canPlayFastForward
            case 1.0 ..< 2.0:
                true
            case 0.0 ..< 1.0:
                canPlaySlowForward
            default:
                false
            }
        case ..<0.0:
            switch rate.rate {
            case -1.0:
                canPlayReverse
            case -1.0 ..< 0.0:
                canPlaySlowReverse
            case ..<(-1.0):
                canPlayFastReverse
            default:
                false
            }
        default:
            false
        }
    }
}
