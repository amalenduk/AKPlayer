//
//   CMTime+Extension.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - CMTime Extensions

public extension CMTime {
    // MARK: - Formatting Properties & Functions

    /// Converts the CMTime duration into a standard formatted time string
    /// (e.g., "01:23:45" or "03:45").
    var stringValue: String {
        guard isValid, isNumeric else {
            return "--:--"
        }

        let duration = lrint(seconds)
        let positiveDuration = abs(duration)

        if positiveDuration > 3600 {
            return String(
                format: "%@%01ld:%02ld:%02ld",
                duration < 0 ? "-" : "",
                positiveDuration / 3600,
                (positiveDuration / 60) % 60,
                positiveDuration % 60
            )
        } else {
            return String(
                format: "%@%02ld:%02ld",
                duration < 0 ? "-" : "",
                (positiveDuration / 60) % 60,
                positiveDuration % 60
            )
        }
    }

    /// Converts the CMTime duration into a precise formatted string including
    /// milliseconds (e.g., "03:45.123").
    /// - Returns: A formatted sub-second duration string.
    func subSecondStringValue() -> String {
        guard isValid, isNumeric else {
            return "--:--.---"
        }

        let duration = lrint(seconds)
        let positiveDuration = abs(duration)
        let hours = positiveDuration / 3600
        let minutes = (positiveDuration / 60) % 60
        let seconds = positiveDuration % 60
        let milliseconds = positiveDuration - ((hours * 3600 + minutes * 60 + seconds) * 1000)

        if hours > 1 {
            return String(
                format: "%@%01ld:%02ld:%02ld.%03ld",
                duration < 0 ? "-" : "",
                hours,
                minutes,
                seconds,
                milliseconds
            )
        } else {
            return String(
                format: "%@%02ld:%02ld.%03ld",
                duration < 0 ? "-" : "",
                minutes,
                seconds,
                milliseconds
            )
        }
    }

    /// Converts the CMTime duration into a localized, human-readable verbal
    /// string (e.g., "3 minutes 45 seconds").
    /// - Returns: A descriptive time representation.
    func verboseStringValue() -> String {
        guard isValid && isNumeric else {
            return ""
        }

        let duration = lrint(seconds)
        let positiveDuration = abs(duration)
        let hours = positiveDuration / 3600
        let mins = (positiveDuration / 60) % 60
        let seconds = positiveDuration % 60
        let remaining = duration < 0

        var components = DateComponents()
        components.hour = Int(hours)
        components.minute = Int(mins)
        components.second = Int(seconds)

        var verboseString = DateComponentsFormatter.localizedString(
            from: components,
            unitsStyle: .full
        )
        verboseString =
            remaining
                ? String(
                    format: "%@ remaining",
                    verboseString!
                ) : verboseString
        return verboseString!.replacingOccurrences(of: ",", with: "")
    }
}

// MARK: - CMTimeRange Extensions

public extension CMTimeRange {
    // MARK: - Convenience Properties

    /// Indicates whether the time range is valid and non-empty.
    var isValidAndNotEmpty: Bool {
        isValid && !isEmpty
    }
}
