//
//  AKInterstitialEvent.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar. All rights reserved.
//  Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreMedia

// MARK: - AKInterstitialEvent

/// Events emitted exclusively while interstitial content is active or when the schedule changes.
/// Subscribe via `interstitialService.events`.
public enum AKInterstitialEvent: @unchecked Sendable {
    
    /// The full schedule of interstitial events changed (server-side or client-side).
    case scheduleDidChange([AVPlayerInterstitialEvent])
    
    /// An interstitial is about to begin (currentEvent became non-nil).
    case willStart(AVPlayerInterstitialEvent)
    
    /// An interstitial has started playing.
    case didStart(AVPlayerInterstitialEvent)
    
    /// Periodic progress while an interstitial is playing.
    case progress(AKPlayerInterstitialProgress)
    
    /// The interstitial finished, was skipped, or was cancelled.
    case didFinish(AVPlayerInterstitialEvent, reason: FinishReason)
    
    // MARK: - FinishReason
    
    public enum FinishReason: Sendable, Equatable {
        case completed
        case skipped
        case cancelled(resumptionOffset: CMTime)
        case error(Error)
        
        public static func == (lhs: FinishReason, rhs: FinishReason) -> Bool {
            switch (lhs, rhs) {
            case (.completed, .completed), (.skipped, .skipped):
                true
            case let (.cancelled(l), .cancelled(r)):
                l == r
            case (.error, .error):
                true // Error itself is not Equatable in a useful way here
            default:
                false
            }
        }
    }
}

// MARK: - Equatable

extension AKInterstitialEvent: Equatable {
    public static func == (lhs: AKInterstitialEvent, rhs: AKInterstitialEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.scheduleDidChange(l), .scheduleDidChange(r)):
            l.map(\.identifier) == r.map(\.identifier)
        case let (.willStart(l), .willStart(r)),
            let (.didStart(l), .didStart(r)):
            l.identifier == r.identifier
        case let (.progress(l), .progress(r)):
            l.currentTime == r.currentTime && l.duration == r.duration
        case let (.didFinish(lEvent, lReason), .didFinish(rEvent, rReason)):
            lEvent.identifier == rEvent.identifier && lReason == rReason
        default:
            false
        }
    }
}
