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
    case audio
    case subtitle
    case closedCaption
    case videoAlternative
    case audioDescription
    
    var mediaCharacteristic: AVMediaCharacteristic {
        switch self {
        case .audio:
            return .audible
        case .subtitle:
            return .legible
        case .closedCaption:
            return .legible
        case .videoAlternative:
            return .visual
        case .audioDescription:
            return .audible
        }
    }
}

// MARK: - AKMediaOptionBox

/// An internal, thread-safe wrapper box for AVFoundation's non-Sendable
/// `AVMediaSelectionOption`.
struct AKMediaOptionBox: @unchecked Sendable {
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
    
    var option: AVMediaSelectionOption? {
        optionBox.option
    }
    
    // MARK: - Initializers
    
    /// Initializes a track option wrapper from an `AVMediaSelectionOption`.
    public init(option: AVMediaSelectionOption, isDefault: Bool) {
        self.optionBox = AKMediaOptionBox(option: option)
        self.title = option.displayName
        self.languageCode = option.extendedLanguageTag ?? option.locale?.identifier ?? ""
        self.isDefault = isDefault
        
        // Derive a stable, unique identifier using ObjectIdentifier + media characteristics
        let memoryAddress = String(UInt(bitPattern: ObjectIdentifier(option)), radix: 16)
        let tag = option.extendedLanguageTag ?? ""
        self.id = "\(memoryAddress)_\(tag)"
    }
    
    /// Initializer for custom/mock options or static `.off` state.
    public init(title: String, id: String = UUID().uuidString, languageCode: String = "", isDefault: Bool = false) {
        self.optionBox = AKMediaOptionBox(option: nil)
        self.title = title
        self.id = id
        self.languageCode = languageCode
        self.isDefault = isDefault
    }
    
    // MARK: - Static Constants
    
    /// Represents a disabled track selection state (e.g., Subtitles Off).
    public static let off = AKMediaTrackOption(title: "Off", id: "__off__")
    
    // MARK: - Hashable & Equatable
    
    public static func == (lhs: AKMediaTrackOption, rhs: AKMediaTrackOption) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct AKMediaTrackGroup: Identifiable, Hashable, Sendable {
    
    // MARK: - Public Properties
    
    /// Unique identifier for the track group (e.g., "audio", "legible").
    public var id: String { type.rawValue }
    
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
        self.groupBox = nil
    }
    
    /// Internal initializer attaching the underlying system `AVMediaSelectionGroup`.
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
        self.groupBox = AKMediaGroupBox(group: group)
    }
    
    // MARK: - Hashable & Equatable
    
    public static func == (lhs: AKMediaTrackGroup, rhs: AKMediaTrackGroup) -> Bool {
        lhs.type == rhs.type &&
        lhs.options == rhs.options &&
        lhs.selectedOption == rhs.selectedOption &&
        lhs.defaultOption == rhs.defaultOption &&
        lhs.allowsEmptySelection == rhs.allowsEmptySelection
    }
    
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
    let group: AVMediaSelectionGroup?
    
    init(group: AVMediaSelectionGroup?) {
        self.group = group
    }
}
