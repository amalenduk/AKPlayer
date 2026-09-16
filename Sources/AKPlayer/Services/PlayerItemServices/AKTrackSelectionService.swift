//
//   AKTrackSelectionService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

@preconcurrency import AVFoundation
import Foundation
import MediaAccessibility
import MediaPlayer

@MainActor
public protocol AKTrackSelectionServiceProtocol: AnyObject {
    
    // MARK: - 1. Group Methods
    
    /// Retrieves domain-level media group details for a single track type.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: An `AKMediaTrackGroup` containing available options and active states, or `nil` if unavailable.
    func trackGroup(for type: AKTrackType) async throws -> AKMediaTrackGroup?
    
    /// Retrieves domain-level media groups for multiple track types.
    /// - Parameter types: An array of target `AKTrackType` values.
    /// - Returns: An array of available `AKMediaTrackGroup` items.
    func trackGroups(for types: [AKTrackType]) async throws -> [AKMediaTrackGroup]
    
    // MARK: - 2. Options / Tracks Methods
    
    /// Retrieves all available track options for a specific track type.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: An array of `AKMediaTrackOption` objects.
    func availableTracks(for type: AKTrackType) async throws -> [AKMediaTrackOption]
    
    /// Retrieves all available track options for a specific track type.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: An array of `AKMediaTrackOption` objects.
    func availableTracks(for types: [AKTrackType]) async throws -> [AKMediaTrackOption]
    
    /// Fetches the currently selected track option for a given track type.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: The active `AKMediaTrackOption`, or `nil` if no track is selected.
    func selectedTrack(for type: AKTrackType) async throws -> AKMediaTrackOption?
    
    /// Fetches currently selected track options across multiple track types.
    /// - Parameter types: An array of target `AKTrackType` values.
    /// - Returns: An array of active `AKMediaTrackOption` instances.
    func selectedTracks(for types: [AKTrackType]) async throws -> [AKMediaTrackOption]
    
    // MARK: - Now Playing Language Options
    
    /// Retrieves currently selected language options formatted for `MPNowPlayingInfoCenter`.
    /// - Parameter types: The target track types to query.
    func currentLanguageOptions(for types: [AKTrackType]) async throws -> [MPNowPlayingInfoLanguageOption]
    
    /// Retrieves available language option groups formatted for `MPNowPlayingInfoCenter`.
    /// - Parameter types: The target track types to query.
    func availableLanguageOptionGroups(for types: [AKTrackType]) async throws -> [MPNowPlayingInfoLanguageOptionGroup]
    
    
    // MARK: - 3. Select Methods
    
    /// Selects a specific track option for a given track type.
    /// - Parameters:
    ///   - option: The target `AKMediaTrackOption` to select, or `nil` / `.off` to disable.
    ///   - type: The target `AKTrackType`.
    func select(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws
    
    // MARK: - 4. Select Preferred Methods
    
    /// Selects the best track option based on user locale preferences or system default settings.
    /// - Parameter type: The target `AKTrackType`.
    func selectPreferredTrack(for type: AKTrackType) async throws
    
    // MARK: - 5. Session & Stream Observations
    
    /// Clears internal track caches and resets observer sessions.
    func resetSession() async
    
    /// Creates an `AsyncStream` emitting track selection updates whenever the active track changes.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: An `AsyncStream` yielding updated `AKMediaTrackOption` instances.
    nonisolated func selectionChanges(for type: AKTrackType) -> AsyncStream<AKMediaTrackOption?>
}

@MainActor
public final class AKTrackSelectionService: AKTrackSelectionServiceProtocol {
    // MARK: - Properties
    
    /// A weak reference to the parent media manager providing actor-safe access
    /// to the active `AVPlayerItem`.
    private weak var mediaManager: (any AKMediaManagerProtocol)?
    
    /// Cached `AVMediaSelectionGroup` objects mapped by asset item key and track type.
    private var groupCache: [String: AVMediaSelectionGroup] = [:]
    
    /// Active continuation listeners for streaming selection updates.
    private var continuations: [AKTrackType: [UUID: AsyncStream<AKMediaTrackOption?>.Continuation]] = [:]
    
    /// Last known track selections used to deduplicate broadcast updates.
    private var lastKnownSelection: [AKTrackType: AKMediaTrackOption?] = [:]
    
    /// Notification center token for external media selection observer.
    private var externalChangeObserver: NSObjectProtocol?
    
    /// Convenience non-throwing accessor for the active `AVPlayerItem`.
    private var playerItem: AVPlayerItem? {
        mediaManager?.playerItem
    }
    
    // MARK: - Initialization & Cleanup
    
    /// Initializes a new track selection service bound to a parent media manager.
    /// - Parameter mediaManager: The parent media manager instance.
    public init(mediaManager: any AKMediaManagerProtocol) {
        self.mediaManager = mediaManager
        
        // Start observing external track selection updates (e.g., system AVPlayerViewController changes)
        startObservingExternalChanges()
    }
    
    deinit {}
    
    // MARK: - 1. Group Methods
    
    /// Retrieves domain-level media group details for a single track type.
    public func trackGroup(for type: AKTrackType) async throws -> AKMediaTrackGroup? {
        guard let playerItem else {
            throw AKPlayerError.noItemToPlay
        }
        
        guard let group = try await mediaGroup(for: type, in: playerItem.asset) else {
            return nil
        }
        
        let filteredOptions = filterSpecialized(group.options, for: type)
        let defaultAVOption = group.defaultOption
        
        var trackOptions = filteredOptions.map {
            AKMediaTrackOption(option: $0, isDefault: $0 == defaultAVOption)
        }
        
        let selected = try await selectedTrack(for: type)
        let defaultTrackOption = trackOptions.first(where: { $0.isDefault })
        
        let allowsEmpty = allowsEmptySelection(type) && group.allowsEmptySelection
        if allowsEmpty {
            trackOptions.insert(.off, at: 0)
        }
        
        return AKMediaTrackGroup(
            type: type,
            options: trackOptions,
            selectedOption: selected,
            defaultOption: defaultTrackOption,
            allowsEmptySelection: allowsEmpty
        )
    }
    
    /// Retrieves domain-level media groups for multiple track types.
    public func trackGroups(for types: [AKTrackType]) async throws -> [AKMediaTrackGroup] {
        var groups: [AKMediaTrackGroup] = []
        for type in types {
            if let group = try await trackGroup(for: type) {
                groups.append(group)
            }
        }
        return groups
    }
    
    // MARK: - 2. Options / Tracks Methods
    
    /// Retrieves all available track options for a specific track type,
    /// prepending `.off` if empty selection is permitted.
    public func availableTracks(for type: AKTrackType) async throws -> [AKMediaTrackOption] {
        guard let group = try await trackGroup(for: type) else {
            return (type == .subtitle || type == .closedCaption) ? [.off] : []
        }
        
        return group.options
    }
    
    public func availableTracks(for types: [AKTrackType]) async throws -> [AKMediaTrackOption] {
        var groups: [AKMediaTrackGroup] = []
        for type in types {
            if let group = try await trackGroup(for: type) {
                groups.append(group)
            }
        }
        return groups.flatMap({ $0.options })
    }
    
    /// Fetches the currently selected track option for a given track type.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: The currently active `AKMediaTrackOption`, or `nil` if none is selected.
    /// - Throws: An `AKPlayerError.trackSelectionFailure` if media selection group fetching fails.
    public func selectedTrack(for type: AKTrackType) async throws -> AKMediaTrackOption? {
        guard let playerItem,
              let group = try await mediaGroup(for: type, in: playerItem.asset) else {
            return nil
        }
        
        guard let selectedOption = playerItem.currentMediaSelection.selectedMediaOption(in: group) else {
            // Fall back to .off ONLY if empty selection is actually allowed for this group/type
            return resolvedOffOption(for: type, allowsEmptySelection: group.allowsEmptySelection)
        }
        
        return AKMediaTrackOption(
            option: selectedOption,
            isDefault: selectedOption == group.defaultOption
        )
    }
    
    /// Fetches currently selected track options across multiple track types.
    public func selectedTracks(for types: [AKTrackType]) async throws -> [AKMediaTrackOption] {
        var selections: [AKMediaTrackOption] = []
        for type in types {
            if let selected = try await selectedTrack(for: type) {
                selections.append(selected)
            }
        }
        return selections
    }
    
    // MARK: - Now Playing Language Options
    
    // MARK: - Now Playing Language Options
    
    public func currentLanguageOptions(for types: [AKTrackType]) async throws -> [MPNowPlayingInfoLanguageOption] {
        guard let playerItem else { return [] }
        
        var languageOptions: [MPNowPlayingInfoLanguageOption] = []
        
        for type in types {
            guard let group = try await mediaGroup(for: type, in: playerItem.asset) else {
                continue
            }
            
            if let selectedOption = playerItem.currentMediaSelection.selectedMediaOption(in: group),
               let languageOption = selectedOption.makeNowPlayingInfoLanguageOption() {
                languageOptions.append(languageOption)
            }
        }
        
        return languageOptions
    }
    
    public func availableLanguageOptionGroups(for types: [AKTrackType]) async throws -> [MPNowPlayingInfoLanguageOptionGroup] {
        guard let playerItem else { return [] }
        
        var optionGroups: [MPNowPlayingInfoLanguageOptionGroup] = []
        
        for type in types {
            guard let group = try await mediaGroup(for: type, in: playerItem.asset) else {
                continue
            }
            
            let languageOptionGroup = group.makeNowPlayingInfoLanguageOptionGroup()
            optionGroups.append(languageOptionGroup)
        }
        
        return optionGroups
    }
    
    // MARK: - 3. Select Methods
    
    /// Selects a specific track option for a given track type.
    /// - Parameters:
    ///   - option: The option to select, or `nil` / `.off` to disable.
    ///   - type: The target `AKTrackType`.
    /// - Throws: `AKPlayerError.noItemToPlay` if no player item is set, or
    /// `AKPlayerError.trackSelectionFailure` if selection is forbidden.
    public func select(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws {
        guard let playerItem else {
            throw AKPlayerError.noItemToPlay
        }
        
        guard let group = try await mediaGroup(for: type, in: playerItem.asset) else { return }
        
        // Check if the caller is trying to turn off/deselect the track
        let isDeselecting = (option == nil || option == .off || option?.option == nil)
        let canAllowEmpty = allowsEmptySelection(type) && group.allowsEmptySelection
        
        if isDeselecting && !canAllowEmpty {
            throw AKPlayerError.trackSelectionFailure(reason: .emptySelectionForbidden(type))
        }
        
        // AVPlayerItem selection updates execute directly on MainActor
        if let mediaOption = option?.option {
            playerItem.select(mediaOption, in: group)
        } else {
            playerItem.select(nil, in: group)
        }
        
        let resolved = try await selectedTrack(for: type)
        recordAndBroadcastIfChanged(resolved, for: type)
    }
    // MARK: - 4. Select Preferred Methods
    
    /// Selects the best track option based on user locale preferences or default settings.
    /// - Parameter type: The target `AKTrackType`.
    /// - Throws: An `AKPlayerError` if querying tracks or performing selection encounters an error.
    public func selectPreferredTrack(for type: AKTrackType) async throws {
        guard let group = try await trackGroup(for: type) else {
            return
        }
        
        guard !group.options.isEmpty else { return }
        
        if allowsEmptySelection(type), !systemCaptioningEnabled() {
            if group.allowsEmptySelection {
                try await select(.off, for: type)
            }
            return
        }
        
        let preferredLocale = Locale.preferredLanguages.first.map(Locale.init(identifier:)) ?? Locale.current
        let matches = AVMediaSelectionGroup.mediaSelectionOptions(
            from: group.options.compactMap({ $0.option }),
            with: preferredLocale
        )
        
        if let best = matches.first,
           let match = group.options.first(where: { $0.option == best }) {
            try await select(match, for: type)
        } else if let fallback = group.options.first(where: { $0.isDefault }) {
            try await select(fallback, for: type)
        }
    }
    
    // MARK: - 5. Session & Stream Observations
    
    /// Clears track selection caches, observers, and resets session tracking.
    public func resetSession() async {
        // 1. Clear cached AVMediaSelectionGroup instances
        groupCache.removeAll()
        
        // 2. Clear stale track selection states
        lastKnownSelection.removeAll()
        
        // 3. Remove existing notification observer if active
        if let externalChangeObserver {
            NotificationCenter.default.removeObserver(externalChangeObserver)
            self.externalChangeObserver = nil
        }
        
        // 4. Re-bind external change observation with the current player item
        startObservingExternalChanges()
    }
    
    /// Creates an `AsyncStream` emitting track selection updates whenever the active track changes.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: An `AsyncStream` yielding optional `AKMediaTrackOption` updates.
    public nonisolated func selectionChanges(for type: AKTrackType) -> AsyncStream<AKMediaTrackOption?> {
        AsyncStream { continuation in
            let id = UUID()
            
            Task { @MainActor in
                self.addContinuation(continuation, with: id, for: type)
                
                // Seed stream with initial selection value
                if let current = try? await self.selectedTrack(for: type) {
                    continuation.yield(current)
                    self.recordSelection(current, for: type)
                }
            }
            
            // Clean up when subscriber cancels stream
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.removeContinuation(id, for: type)
                }
            }
        }
    }
    
    // MARK: - External Change Observation Helpers
    
    /// Starts observing external notifications for media selection changes.
    private func startObservingExternalChanges() {
        guard let playerItem else { return }
        
        externalChangeObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.mediaSelectionDidChangeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.handleExternalChangeNotification()
            }
        }
    }
    
    /// Handles media selection changes triggered externally by updating stream continuations.
    private func handleExternalChangeNotification() async {
        for type in continuations.keys {
            guard let resolved = try? await selectedTrack(for: type) else { continue }
            recordAndBroadcastIfChanged(resolved, for: type)
        }
    }
    
    // MARK: - Private Utilities
    
    /// Checks whether captioning preferences are enabled in system settings.
    /// - Returns: A Boolean indicating if system captioning is turned on.
    private func systemCaptioningEnabled() -> Bool {
        guard let characteristics = MACaptionAppearanceCopyPreferredCaptioningMediaCharacteristics(.user)
            .takeRetainedValue() as? [AVMediaCharacteristic]
        else {
            return false
        }
        return !characteristics.isEmpty
    }
    
    /// Helper method returning the default `.off` option for caption and subtitle track types.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: `.off` if the type is subtitle or closed caption, otherwise `nil`.
    private func offIfApplicable(_ type: AKTrackType) -> AKMediaTrackOption? {
        (type == .subtitle || type == .closedCaption) ? .off : nil
    }
    
    private func allowsEmptySelection(_ type: AKTrackType) -> Bool {
        return (type == .subtitle || type == .closedCaption)
    }
    
    /// Resolves the static `.off` option if the track type AND the underlying group permit empty selections.
    private func resolvedOffOption(for type: AKTrackType, allowsEmptySelection groupAllowsEmpty: Bool) -> AKMediaTrackOption? {
        if allowsEmptySelection(type) && groupAllowsEmpty {
            return .off
        }
        return nil
    }
    
    /// Maps an `AKTrackType` to its corresponding `AVMediaCharacteristic`.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: The matching `AVMediaCharacteristic`.
    private func mediaCharacteristic(for type: AKTrackType) -> AVMediaCharacteristic {
        switch type {
        case .audio, .audioDescription: .audible
        case .subtitle, .closedCaption: .legible
        case .videoAlternative: .visual
        }
    }
    
    /// Filters media options to isolate specialized tracks (e.g. accessibility/closed captions vs standard subtitles).
    private func filterSpecialized(_ options: [AVMediaSelectionOption], for type: AKTrackType) -> [AVMediaSelectionOption] {
        switch type {
        case .closedCaption:
            options.filter { $0.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility) }
        case .subtitle:
            options.filter { !$0.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility) }
        case .audioDescription:
            options.filter { $0.hasMediaCharacteristic(.describesVideoForAccessibility) }
        default:
            options
        }
    }
    
    /// Loads or returns the cached `AVMediaSelectionGroup` for a specific track type in an asset.
    private func mediaGroup(for type: AKTrackType, in asset: AVAsset) async throws -> AVMediaSelectionGroup? {
        guard let playerItem else { return nil }
        let key = "\(ObjectIdentifier(playerItem).hashValue)-\(type)"
        if let cached = groupCache[key] {
            return cached
        }
        
        let characteristic = mediaCharacteristic(for: type)
        do {
            let group = try await asset.loadMediaSelectionGroup(for: characteristic)
            guard let group else { return nil }
            groupCache[key] = group
            return group
        } catch {
            throw AKPlayerError.trackSelectionFailure(
                reason: .groupLoadFailed(type, error: error)
            )
        }
    }
    
    /// Updates the local dictionary of active track selections.
    private func recordSelection(_ option: AKMediaTrackOption?, for type: AKTrackType) {
        lastKnownSelection[type] = option
    }
    
    /// Records track changes and broadcasts updates to stream listeners if the selection changed.
    private func recordAndBroadcastIfChanged(_ option: AKMediaTrackOption?, for type: AKTrackType) {
        if lastKnownSelection[type] == option, lastKnownSelection.keys.contains(type) {
            return
        }
        
        lastKnownSelection[type] = option
        continuations[type]?.values.forEach { $0.yield(option) }
    }
    
    /// Registers an active continuation stream for track selection broadcasts.
    private func addContinuation(_ continuation: AsyncStream<AKMediaTrackOption?>.Continuation, with id: UUID, for type: AKTrackType) {
        continuations[type, default: [:]][id] = continuation
    }
    
    /// Removes a registered continuation stream subscriber.
    private func removeContinuation(_ id: UUID, for type: AKTrackType) {
        continuations[type]?.removeValue(forKey: id)
        if continuations[type]?.isEmpty == true {
            continuations.removeValue(forKey: type)
        }
    }
}

public extension AKTrackSelectionServiceProtocol {
    
    func currentLanguageOptions(
        for types: [AKTrackType] = [.audio, .subtitle, .closedCaption]
    ) async throws -> [MPNowPlayingInfoLanguageOption] {
        try await currentLanguageOptions(for: types)
    }
    
    func availableLanguageOptionGroups(
        for types: [AKTrackType] = [.audio, .subtitle, .closedCaption]
    ) async throws -> [MPNowPlayingInfoLanguageOptionGroup] {
        try await availableLanguageOptionGroups(for: types)
    }
}
