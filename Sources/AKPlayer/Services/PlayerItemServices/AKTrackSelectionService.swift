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
import Synchronization

// MARK: - AKTrackSelectionServiceProtocol

public protocol AKTrackSelectionServiceProtocol: AnyObject, Sendable {
    
    // MARK: - 1. Group Methods
    
    /// Retrieves domain-level media group details for a single track type.
    func trackGroup(for type: AKTrackType) async throws -> AKMediaTrackGroup?
    
    /// Retrieves domain-level media groups for multiple track types.
    func trackGroups(for types: [AKTrackType]) async throws -> [AKMediaTrackGroup]
    
    // MARK: - 2. Options / Tracks Methods
    
    /// Retrieves all available track options for a specific track type.
    func availableTracks(for type: AKTrackType) async throws -> [AKMediaTrackOption]
    
    /// Retrieves all available track options for multiple track types.
    func availableTracks(for types: [AKTrackType]) async throws -> [AKMediaTrackOption]
    
    /// Fetches the currently selected track option for a given track type.
    func selectedTrack(for type: AKTrackType) async throws -> AKMediaTrackOption?
    
    /// Fetches currently selected track options across multiple track types.
    func selectedTracks(for types: [AKTrackType]) async throws -> [AKMediaTrackOption]
    
    // MARK: - Now Playing Language Options
    
    /// Retrieves currently selected language options formatted for `MPNowPlayingInfoCenter`.
    func currentLanguageOptions(for types: [AKTrackType]) async throws -> [MPNowPlayingInfoLanguageOption]
    
    /// Retrieves available language option groups formatted for `MPNowPlayingInfoCenter`.
    func availableLanguageOptionGroups(for types: [AKTrackType]) async throws -> [MPNowPlayingInfoLanguageOptionGroup]
    
    // MARK: - 3. Select Methods
    
    /// Selects a specific track option for a given track type.
    func select(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws
    
    // MARK: - 4. Select Preferred Methods
    
    /// Selects the best track option based on user locale preferences or system default settings.
    func selectPreferredTrack(for type: AKTrackType) async throws
    
    // MARK: - 5. Session & Stream Observations
    
    /// Clears internal track caches and resets observer sessions.
    func resetSession() async
    
    /// Creates an `AsyncStream` emitting track selection updates whenever the active track changes.
    func selectionChanges(for type: AKTrackType) -> AsyncStream<AKMediaTrackOption?>
}

// MARK: - Implementation

public final class AKTrackSelectionService: AKTrackSelectionServiceProtocol, Sendable {
    
    // MARK: - Internal State
    
    private struct State {
        var groupCache: [String: AVMediaSelectionGroup] = [:]
        var continuations: [AKTrackType: [UUID: AsyncStream<AKMediaTrackOption?>.Continuation]] = [:]
        var lastKnownSelection: [AKTrackType: AKMediaTrackOption?] = [:]
        var observationTask: Task<Void, Never>?
    }
    
    // MARK: - Properties
    
    /// An unowned reference to the owner media manager.
    private unowned let mediaManager: any AKMediaManagerProtocol
    
    /// Thread-safe state container using Swift 6 native Mutex.
    private let state = Mutex(State())
    
    /// Convenience accessor for the active `AVPlayerItem`.
    private var playerItem: AVPlayerItem? {
        mediaManager.playerItem
    }
    
    // MARK: - Initialization & Cleanup
    
    public init(mediaManager: any AKMediaManagerProtocol) {
        self.mediaManager = mediaManager
        startObservingExternalChanges()
    }
    
    deinit {
        state.withLock {
            $0.observationTask?.cancel()
            $0.continuations.values.forEach { $0.values.forEach { $0.finish() } }
            $0.continuations.removeAll()
        }
    }
    
    // MARK: - 1. Group Methods
    
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
        return groups.flatMap { $0.options }
    }
    
    public func selectedTrack(for type: AKTrackType) async throws -> AKMediaTrackOption? {
        guard let playerItem,
              let group = try await mediaGroup(for: type, in: playerItem.asset) else {
            return nil
        }
        
        guard let selectedOption = await playerItem.currentMediaSelection.selectedMediaOption(in: group) else {
            return resolvedOffOption(for: type, allowsEmptySelection: group.allowsEmptySelection)
        }
        
        return AKMediaTrackOption(
            option: selectedOption,
            isDefault: selectedOption == group.defaultOption
        )
    }
    
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
    
    public func currentLanguageOptions(for types: [AKTrackType]) async throws -> [MPNowPlayingInfoLanguageOption] {
        guard let playerItem else { return [] }
        
        var languageOptions: [MPNowPlayingInfoLanguageOption] = []
        
        for type in types {
            guard let group = try await mediaGroup(for: type, in: playerItem.asset) else {
                continue
            }
            
            if let selectedOption = await playerItem.currentMediaSelection.selectedMediaOption(in: group),
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
    
    public func select(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws {
        guard let playerItem else {
            throw AKPlayerError.noItemToPlay
        }
        
        guard let group = try await mediaGroup(for: type, in: playerItem.asset) else { return }
        
        let isDeselecting = (option == nil || option == .off || option?.option == nil)
        let canAllowEmpty = allowsEmptySelection(type) && group.allowsEmptySelection
        
        if isDeselecting && !canAllowEmpty {
            throw AKPlayerError.trackSelectionFailure(reason: .emptySelectionForbidden(type))
        }
        
        if let mediaOption = option?.option {
            playerItem.select(mediaOption, in: group)
        } else {
            playerItem.select(nil, in: group)
        }
        
        let resolved = try await selectedTrack(for: type)
        recordAndBroadcastIfChanged(resolved, for: type)
    }
    
    // MARK: - 4. Select Preferred Methods
    
    public func selectPreferredTrack(for type: AKTrackType) async throws {
        guard let group = try await trackGroup(for: type), !group.options.isEmpty else {
            return
        }
        
        if allowsEmptySelection(type), !systemCaptioningEnabled() {
            if group.allowsEmptySelection {
                try await select(.off, for: type)
            }
            return
        }
        
        let preferredLocale = Locale.preferredLanguages.first.map(Locale.init(identifier:)) ?? Locale.current
        let matches = AVMediaSelectionGroup.mediaSelectionOptions(
            from: group.options.compactMap { $0.option },
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
    
    public func resetSession() async {
        state.withLock {
            $0.groupCache.removeAll()
            $0.lastKnownSelection.removeAll()
        }
        startObservingExternalChanges()
    }
    
    public func selectionChanges(for type: AKTrackType) -> AsyncStream<AKMediaTrackOption?> {
        let id = UUID()
        return AsyncStream { continuation in
            state.withLock {
                $0.continuations[type, default: [:]][id] = continuation
                if let current = $0.lastKnownSelection[type] {
                    continuation.yield(current)
                }
            }
            
            // Seed initial track asynchronously if not yet cached
            Task { [weak self] in
                guard let self else { return }
                if let current = try? await self.selectedTrack(for: type) {
                    self.recordAndBroadcastIfChanged(current, for: type)
                }
            }
            
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock {
                    $0.continuations[type]?.removeValue(forKey: id)
                    if $0.continuations[type]?.isEmpty == true {
                        $0.continuations.removeValue(forKey: type)
                    }
                }
            }
        }
    }
    
    // MARK: - External Change Observation
    
    private func startObservingExternalChanges() {
        guard let playerItem else { return }
        
        state.withLock { $0.observationTask?.cancel() }
        
        let task = Task { [weak self, weak playerItem] in
            guard let playerItem else { return }
            
            for await _ in NotificationCenter.default.notifications(
                named: AVPlayerItem.mediaSelectionDidChangeNotification,
                object: playerItem
            ) {
                guard !Task.isCancelled, let self else { break }
                await self.handleExternalChangeNotification()
            }
        }
        
        state.withLock { $0.observationTask = task }
    }
    
    private func handleExternalChangeNotification() async {
        let types = state.withLock { Array($0.continuations.keys) }
        for type in types {
            guard let resolved = try? await selectedTrack(for: type) else { continue }
            recordAndBroadcastIfChanged(resolved, for: type)
        }
    }
    
    // MARK: - Private Utilities
    
    private func systemCaptioningEnabled() -> Bool {
        guard let characteristics = MACaptionAppearanceCopyPreferredCaptioningMediaCharacteristics(.user)
            .takeRetainedValue() as? [AVMediaCharacteristic]
        else {
            return false
        }
        return !characteristics.isEmpty
    }
    
    private func allowsEmptySelection(_ type: AKTrackType) -> Bool {
        (type == .subtitle || type == .closedCaption)
    }
    
    private func resolvedOffOption(for type: AKTrackType, allowsEmptySelection groupAllowsEmpty: Bool) -> AKMediaTrackOption? {
        if allowsEmptySelection(type) && groupAllowsEmpty {
            return .off
        }
        return nil
    }
    
    private func mediaCharacteristic(for type: AKTrackType) -> AVMediaCharacteristic {
        switch type {
        case .audio, .audioDescription: .audible
        case .subtitle, .closedCaption: .legible
        case .videoAlternative: .visual
        }
    }
    
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
    
    private func mediaGroup(for type: AKTrackType, in asset: AVAsset) async throws -> AVMediaSelectionGroup? {
        guard let playerItem else { return nil }
        let key = "\(ObjectIdentifier(playerItem).hashValue)-\(type)"
        
        if let cached = state.withLock({ $0.groupCache[key] }) {
            return cached
        }
        
        let characteristic = mediaCharacteristic(for: type)
        do {
            let group = try await asset.loadMediaSelectionGroup(for: characteristic)
            guard let group else { return nil }
            state.withLock { $0.groupCache[key] = group }
            return group
        } catch {
            throw AKPlayerError.trackSelectionFailure(
                reason: .groupLoadFailed(type, error: error)
            )
        }
    }
    
    private func recordAndBroadcastIfChanged(_ option: AKMediaTrackOption?, for type: AKTrackType) {
        let continuationsToNotify: [AsyncStream<AKMediaTrackOption?>.Continuation]? = state.withLock {
            if $0.lastKnownSelection[type] == option, $0.lastKnownSelection.keys.contains(type) {
                return nil
            }
            $0.lastKnownSelection[type] = option
            return $0.continuations[type].map { Array($0.values) }
        }
        
        continuationsToNotify?.forEach { $0.yield(option) }
    }
}

// MARK: - Protocol Extension Defaults

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
