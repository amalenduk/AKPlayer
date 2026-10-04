//
//   TimeInterval+Extension.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

public extension TimeInterval {
    /// Formats a duration in the style:
    /// - "00:05" for short durations
    /// - "01:02:03" for hours
    /// - "1:02:03:04" for days
    var humanReadableClock: String {
        let totalSeconds = Int(abs(self))
        let days = totalSeconds / 86400
        let hours = (totalSeconds / 3600) % 24
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        let sign = self < 0 ? "-" : ""

        if days > 0 {
            return String(format: "%@%d:%02d:%02d:%02d", sign, days, hours, minutes, seconds)
        } else if hours > 0 {
            return String(format: "%@%02d:%02d:%02d", sign, hours, minutes, seconds)
        } else {
            return String(format: "%@%02d:%02d", sign, minutes, seconds)
        }
    }
}
