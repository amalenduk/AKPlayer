//
//   AKTime.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia

// MARK: - AKTime

public struct AKTime: Equatable, Comparable, CustomStringConvertible, Sendable {
    // MARK: - Properties

    public let value: CMTime?

    // MARK: - Initializers

    public init(time: CMTime?) {
        value = time
    }

    public init(seconds: Double, preferredTimescale: Int32) {
        self.init(
            time: CMTimeMakeWithSeconds(
                seconds,
                preferredTimescale: preferredTimescale
            )
        )
    }

    public init(seconds: Double) {
        self.init(
            time: CMTimeMakeWithSeconds(
                seconds,
                preferredTimescale: CMTimeScale(NSEC_PER_SEC)
            )
        )
    }

    // MARK: - Computed Properties

    public var seconds: Double? {
        guard let value, value.isValid, value.isNumeric else { return nil }
        return CMTimeGetSeconds(value)
    }

    public var description: String {
        stringValue
    }

    public var stringValue: String {
        guard let value,
              value.isValid && value.isNumeric
        else { return "--:--" }
        let rawSeconds = value.seconds
        let totalSeconds = Int(abs(rawSeconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        let prefix = rawSeconds < 0 ? "-" : ""

        if hours > 0 {
            return String(
                format: "%@%01d:%02d:%02d",
                prefix,
                hours,
                minutes,
                seconds
            )
        } else {
            return String(format: "%@%02d:%02d", prefix, minutes, seconds)
        }
    }

    // MARK: - Methods

    public func subSecondStringValue() -> String {
        guard let value, value.isValid && value.isNumeric else {
            return "--:--.---"
        }

        let rawSeconds = value.seconds
        let positiveSeconds = abs(rawSeconds)

        let totalSeconds = Int(positiveSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60

        let fractionalSeconds =
            positiveSeconds
                .truncatingRemainder(dividingBy: 1)
        let milliseconds = Int((fractionalSeconds * 1000).rounded())
        let prefix = rawSeconds < 0 ? "-" : ""

        if hours > 0 {
            return String(
                format: "%@%01d:%02d:%02d.%03d",
                prefix,
                hours,
                minutes,
                seconds,
                milliseconds
            )
        } else {
            return String(
                format: "%@%02d:%02d.%03d",
                prefix,
                minutes,
                seconds,
                milliseconds
            )
        }
    }

    public func verboseStringValue() -> String {
        guard let value, value.isValid && value.isNumeric else {
            return ""
        }

        let rawSeconds = value.seconds
        let totalSeconds = Int(abs(rawSeconds))
        let hours = totalSeconds / 3600
        let mins = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        let remaining = rawSeconds < 0

        var components = DateComponents()
        components.hour = hours
        components.minute = mins
        components.second = seconds

        guard
            let formatted = DateComponentsFormatter.localizedString(
                from: components,
                unitsStyle: .full
            )
        else {
            return ""
        }

        let verboseString = remaining ? "\(formatted) remaining" : formatted
        return verboseString.replacingOccurrences(of: ",", with: "")
    }

    // MARK: - Protocol Conformances (Equatable & Comparable)

    public static func < (lhs: AKTime, rhs: AKTime) -> Bool {
        guard let a = lhs.value?.seconds,
              let b = rhs.value?.seconds
        else { return false }
        return a < b
    }

    public static func == (lhs: AKTime, rhs: AKTime) -> Bool {
        lhs.value?.seconds == rhs.value?.seconds
    }
}
