//
//   AKMediaTrackOption.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - AKTrackType

/// Defines the supported media track types within the player.
public enum AKTrackType: String, Sendable, Hashable, CaseIterable, Codable {
    /// Audible audio soundtrack or language channel.
    case audio
    /// Legible subtitle text track.
    case subtitle
    /// Legible closed-captioning track.
    case closedCaption
    /// Visual alternative video track (e.g., multi-angle video).
    case videoAlternative
    /// Audible descriptive audio track for visual assistance.
    case audioDescription

    /// The underlying AVMediaCharacteristic corresponding to this track type.
    var mediaCharacteristic: AVMediaCharacteristic {
        switch self {
        case .audio:
            .audible
        case .subtitle:
            .legible
        case .closedCaption:
            .legible
        case .videoAlternative:
            .visual
        case .audioDescription:
            .audible
        }
    }
}

// MARK: - AKMediaOptionBox

/// An internal, thread-safe wrapper box for AVFoundation's non-Sendable
/// `AVMediaSelectionOption`.
struct AKMediaOptionBox: @unchecked Sendable {
    /// The wrapped AVMediaSelectionOption.
    let option: AVMediaSelectionOption?
}

// MARK: - AKMediaTrackOption

/// Represents an available media track option (audio channel, subtitle,
/// caption).
public struct AKMediaTrackOption: Identifiable, Hashable, Sendable {
    // MARK: - Public Properties

    /// Unique identifier representing the media track option.
    public let id: String

    /// Display title for the media track.
    public let title: String

    /// Language code associated with the media track (e.g., ISO or BCP-47 identifier).
    public let languageCode: String

    /// Flag indicating whether this option is marked as default in the underlying asset.
    public let isDefault: Bool

    /// Indicates whether this option represents the disabled state (e.g., Subtitles Off).
    public var isOff: Bool {
        id == Self.off.id
    }

    // MARK: - Internal Properties

    private let optionBox: AKMediaOptionBox

    /// The underlying AVMediaSelectionOption representation.
    var option: AVMediaSelectionOption? {
        optionBox.option
    }

    // MARK: - Initializers

    /// Initializes a track option wrapper from an `AVMediaSelectionOption`.
    /// - Parameters:
    ///   - option: The underlying AVFoundation media selection option.
    ///   - isDefault: Whether this option is the default selection in the media asset.
    public init(option: AVMediaSelectionOption, isDefault: Bool) {
        optionBox = AKMediaOptionBox(option: option)
        title = option.displayName
        languageCode = option.extendedLanguageTag ?? option.locale?.identifier ?? ""
        self.isDefault = isDefault

        // Derive a stable, unique identifier using ObjectIdentifier + media characteristics
        let memoryAddress = String(UInt(bitPattern: ObjectIdentifier(option)), radix: 16)
        let tag = option.extendedLanguageTag ?? ""
        id = "\(memoryAddress)_\(tag)"
    }

    /// Initializer for custom/mock options or static `.off` state.
    /// - Parameters:
    ///   - title: Display title for the track.
    ///   - id: Unique identifier string for the track option.
    ///   - languageCode: Language code string (e.g. "en", "es").
    ///   - isDefault: Whether this option represents the default option.
    public init(
        title: String,
        id: String = UUID().uuidString,
        languageCode: String = "",
        isDefault: Bool = false
    ) {
        optionBox = AKMediaOptionBox(option: nil)
        self.title = title
        self.id = id
        self.languageCode = languageCode
        self.isDefault = isDefault
    }

    // MARK: - Static Constants

    /// Represents a disabled track selection state (e.g., Subtitles Off).
    public static let off = AKMediaTrackOption(title: "Off", id: "__off__")

    // MARK: - Hashable & Equatable

    /// Returns a boolean value indicating whether two track options are equal based on unique
    /// identifiers.
    public static func == (lhs: AKMediaTrackOption, rhs: AKMediaTrackOption) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes the essential components of this track option into the given hasher.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents an available group of selectable media options for a specific track type.
public struct AKMediaTrackGroup: Identifiable, Hashable, Sendable {
    // MARK: - Public Properties

    /// Unique identifier for the track group (e.g., "audio", "legible").
    public var id: String {
        type.rawValue
    }

    /// Target track type for this group (audio, subtitle, closed caption, etc.).
    public let type: AKTrackType

    /// Available options within this group.
    public let options: [AKMediaTrackOption]

    /// Currently selected option within this group, if any.
    public let selectedOption: AKMediaTrackOption?

    /// Default option specified by the underlying asset, if any.
    public let defaultOption: AKMediaTrackOption?

    /// Indicates whether the group permits empty/disabled selection (e.g. Subtitles Off).
    public let allowsEmptySelection: Bool

    // MARK: - Helpers

    /// Indicates whether an active track option is currently selected.
    public var hasSelection: Bool {
        selectedOption != nil && selectedOption != .off
    }

    // MARK: - Internal Properties

    /// Internal box housing the underlying system media selection group.
    private let groupBox: AKMediaGroupBox?

    /// The underlying system selection group.
    var group: AVMediaSelectionGroup? {
        groupBox?.group
    }

    // MARK: - Initializers

    /// Primary initializer for domain use and SwiftUI previews/testing.
    /// - Parameters:
    ///   - type: The media track type.
    ///   - options: The list of available track options in this group.
    ///   - selectedOption: The currently selected option, if any.
    ///   - defaultOption: The default option specified by the asset, if any.
    ///   - allowsEmptySelection: Whether empty selection (e.g. Subtitles Off) is permitted.
    public init(
        type: AKTrackType,
        options: [AKMediaTrackOption],
        selectedOption: AKMediaTrackOption? = nil,
        defaultOption: AKMediaTrackOption? = nil,
        allowsEmptySelection: Bool = true
    ) {
        self.type = type
        self.options = options
        self.selectedOption = selectedOption
        self.defaultOption = defaultOption
        self.allowsEmptySelection = allowsEmptySelection
        groupBox = nil
    }

    /// Internal initializer attaching the underlying system `AVMediaSelectionGroup`.
    /// - Parameters:
    ///   - type: The media track type.
    ///   - group: The underlying AVFoundation selection group.
    ///   - options: The list of track options available.
    ///   - selectedOption: The currently selected option.
    ///   - defaultOption: The default option specified by the media.
    ///   - allowsEmptySelection: Whether deselecting options is permitted.
    init(
        type: AKTrackType,
        group: AVMediaSelectionGroup,
        options: [AKMediaTrackOption],
        selectedOption: AKMediaTrackOption?,
        defaultOption: AKMediaTrackOption?,
        allowsEmptySelection: Bool
    ) {
        self.type = type
        self.options = options
        self.selectedOption = selectedOption
        self.defaultOption = defaultOption
        self.allowsEmptySelection = allowsEmptySelection
        groupBox = AKMediaGroupBox(group: group)
    }

    // MARK: - Hashable & Equatable

    /// Returns a boolean value indicating whether two track groups are identical in configuration
    /// and selection.
    public static func == (lhs: AKMediaTrackGroup, rhs: AKMediaTrackGroup) -> Bool {
        lhs.type == rhs.type &&
            lhs.options == rhs.options &&
            lhs.selectedOption == rhs.selectedOption &&
            lhs.defaultOption == rhs.defaultOption &&
            lhs.allowsEmptySelection == rhs.allowsEmptySelection
    }

    /// Hashes the essential components of this track group into the given hasher.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(options)
        hasher.combine(selectedOption)
        hasher.combine(defaultOption)
        hasher.combine(allowsEmptySelection)
    }
}

/// Thread-safe Sendable wrapper for `AVMediaSelectionGroup`.
final class AKMediaGroupBox: @unchecked Sendable {
    /// The wrapped media selection group.
    let group: AVMediaSelectionGroup?

    /// Initializes a new media group box.
    /// - Parameter group: The optional selection group to wrap.
    init(group: AVMediaSelectionGroup?) {
        self.group = group
    }
}
