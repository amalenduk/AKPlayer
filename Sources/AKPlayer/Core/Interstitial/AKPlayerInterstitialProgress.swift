//
//  AKPlayerInterstitialProgress.swift
//  AKPlayer
//

import Foundation

public struct AKPlayerInterstitialProgress: Sendable, Equatable {
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let timeRemaining: TimeInterval
    
    public var percentage: Double {
        duration > 0 ? min(1.0, currentTime / duration) : 0
    }
    
    public init(currentTime: TimeInterval, duration: TimeInterval, timeRemaining: TimeInterval) {
        self.currentTime = currentTime
        self.duration = duration
        self.timeRemaining = timeRemaining
    }
}
