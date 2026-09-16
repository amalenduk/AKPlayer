//
//  AKInterstitialPlaybackState.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 17/09/26.
//

import Foundation

public enum AKInterstitialPlaybackState: String, Sendable, Equatable {
    case idle
    case loading
    case buffering
    case playing
    case paused
    case finished
}

