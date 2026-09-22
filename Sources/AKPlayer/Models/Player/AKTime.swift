//
//   AKTime.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia

// MARK: - AKTime

/// A lightweight value type encapsulating a CoreMedia timestamp (`CMTime`) along with formatted
/// string representations.
public struct AKTime: Equatable, Comparable, CustomStringConvertible, Sendable {
    // MARK: - Properties

    /// The underlying CoreMedia time representation, or `nil` if unspecified.
    public let value: CMTime?

    // MARK: - Initializers

    /// Initializes an `AKTime` instance from an optional `CMTime` value.
    /// - Parameter time: The underlying `CMTime` representation.
    public init(time: CMTime?) {
        value = time
    }

    /// Initializes an `AKTime` instance from a numeric seconds duration and timescale.
    /// - Parameters:
    ///   - seconds: The duration in seconds.
    ///   - preferredTimescale: The preferred timescale for the `CMTime`.
    public init(seconds: Double, preferredTimescale: Int32) {
        self.init(
            time: CMTimeMakeWithSeconds(
                seconds,
                preferredTimescale: preferredTimescale
            )
        )
    }

    /// Initializes an `AKTime` instance from a numeric seconds duration using nanosecond timescale.
    /// - Parameter seconds: The duration in seconds.
    public init(seconds: Double) {
        self.init(
            time: CMTimeMakeWithSeconds(
                seconds,
                preferredTimescale: CMTimeScale(NSEC_PER_SEC)
            )
        )
    }

    // MARK: - Computed Properties

    /// The time value expressed in fractional seconds, or `nil` if invalid or non-numeric.
    public var seconds: Double? {
        guard let value, value.isValid, value.isNumeric else { return nil }
        return CMTimeGetSeconds(value)
    }

    /// Textual description matching `stringValue`.
    public var description: String {
        stringValue
    }

    /// Formatted time string in `mm:ss` or `h:mm:ss` format (e.g., "03:45" or "1:15:30").
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

    /// Formatted time string including milliseconds in `mm:ss.SSS` or `h:mm:ss.SSS` format.
    /// - Returns: The formatted sub-second string.
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

    /// Formatted verbose natural language time string (e.g. "3 minutes 45 seconds" or "3 minutes 45
    /// seconds remaining").
    /// - Returns: The localized verbose time string.
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

    /// Compares two `AKTime` instances based on their numeric seconds.
    public static func < (lhs: AKTime, rhs: AKTime) -> Bool {
        guard let a = lhs.value?.seconds,
              let b = rhs.value?.seconds
        else { return false }
        return a < b
    }

    /// Checks equality between two `AKTime` instances based on their numeric seconds.
    public static func == (lhs: AKTime, rhs: AKTime) -> Bool {
        lhs.value?.seconds == rhs.value?.seconds
    }
}
