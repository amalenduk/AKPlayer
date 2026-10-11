//
//   AKPlayerObservable.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import CoreMedia
import Observation

/// Selects which playback timeline supplies an observable's current time and duration.
public enum AKPlayerTimelineSource: Sendable, Equatable {
    /// The underlying media item's timeline.
    case normal
    /// The timeline combining primary content and scheduled interstitials.
    case integrated
}

/// An Observation-compatible state model for building player interfaces around ``AKPlayer``.
///
/// The wrapper observes the player's unified event stream and publishes playback state, progress,
/// chapters, track selections, and interstitial states. The underlying player and its services
/// remain available for functionality not directly surfaced by this type.
@MainActor
@Observable
public class AKPlayerObservable: AKPlayerActionsProtocol {
    /// The underlying player that performs media loading and playback.
    public let player: AKPlayer

    /// The latest player event received by this wrapper.
    public private(set) var latestEvent: AKPlayerEvent?

    /// The current operational state of the player.
    public private(set) var state: AKPlayerState

    /// Whether the player is configured to automatically begin playback when media is ready.
    public private(set) var autoPlay: Bool

    /// Timeline used to update ``currentTime`` and ``duration``.
    ///
    /// Changing this value synchronizes the timeline properties from the selected source.
    public var timelineSource: AKPlayerTimelineSource {
        didSet {
            guard timelineSource != oldValue else { return }
            synchronizeTimelineValues()
        }
    }

    /// The currently loaded media item.
    public private(set) var currentMedia: (any AKPlayable)?

    /// The presentation dimensions of the current video item.
    public private(set) var presentationSize: CGSize

    /// Playback capabilities reported for the current media item.
    public private(set) var capabilities: [AKMediaCapability: Bool] = [:]

    /// Whether seeking is currently allowed for the media or active interstitial.
    public private(set) var canSeek = false

    /// The current playback position.
    public private(set) var currentTime: CMTime

    /// The duration of the current media item.
    public private(set) var duration: CMTime

    /// Buffered time ranges loaded in memory for the active media item.
    public private(set) var loadedTimeRanges: [CMTimeRange] = []

    /// Static metadata describing the current media (e.g., title, artist, artwork).
    public private(set) var metadata: AKMediaStaticMetadata?

    /// Dynamic timed metadata emitted at playback cue points.
    public private(set) var timedMetadata: [AVMetadataItem]?

    /// Whether an interstitial ad pod is currently active.
    public private(set) var isInterstitialActive = false

    /// Synthesized ad markers for the current media timeline.
    public private(set) var adMarkers: [AKInterstitialMarker] = []

    /// The marker for the currently active interstitial ad break, if any.
    public private(set) var currentAdMarker: AKInterstitialMarker?

    /// The 1-based index of the currently playing item in the active ad pod.
    public private(set) var currentAdItemIndex = 1

    /// The playback state of the active interstitial ad.
    public private(set) var interstitialPlaybackState: AKInterstitialPlaybackState = .idle

    /// The unique identifier of the currently active interstitial ad break, if any.
    public private(set) var currentInterstitialIdentifier: String?

    /// The progress of the currently playing interstitial ad item, if available.
    public private(set) var interstitialProgress: AKPlayerInterstitialProgress?

    /// The active playback rate.
    public private(set) var playbackRate: AKPlaybackRate

    /// The current output volume.
    public private(set) var volume: Float

    /// Whether player audio output is muted.
    public private(set) var isMuted: Bool

    /// The most recent unrecoverable player error.
    public private(set) var error: AKPlayerError?

    /// Whether the current media item is a live stream.
    public private(set) var isLive: Bool

    /// Whether playback is currently at the live edge.
    public private(set) var isAtLiveEdge: Bool

    /// The drift in seconds behind the live playback edge.
    public private(set) var liveDrift: TimeInterval = 0

    /// All chapters extracted from the current media item.
    public private(set) var chapters: [AKChapter] = []

    /// The chapter containing the current playback position, if any.
    public private(set) var currentChapter: AKChapter?

    /// Available track options keyed by track type.
    public private(set) var availableTracks: [AKTrackType: [AKMediaTrackOption]] = [:]

    /// Selected track options keyed by track type. Types with no selected option are absent.
    public private(set) var selectedTracks: [AKTrackType: AKMediaTrackOption] = [:]

    /// A description of the latest error while loading or selecting track options.
    public private(set) var trackSelectionError: String?

    // MARK: - Convenience Computed Properties

    /// The current media's track-selection service.
    public var trackSelectionService: (any AKTrackSelectionServiceProtocol)? {
        currentMedia?.trackSelection
    }

    /// The current media's chapter service.
    public var chapterService: (any AKChapterServiceProtocol)? {
        currentMedia?.chapterService
    }

    /// Checks whether the current media supports a playback capability.
    public func isSupported(_ capability: AKMediaCapability) -> Bool {
        capabilities[capability] ?? false
    }

    /// The current playback position in seconds, or zero if unavailable.
    public var currentTimeSeconds: Double {
        let seconds = currentTime.seconds
        return seconds.isFinite && !seconds.isNaN ? seconds : 0
    }

    /// The current media duration in seconds, or zero if unavailable.
    public var durationSeconds: Double {
        let seconds = duration.seconds
        return seconds.isFinite && !seconds.isNaN ? seconds : 0
    }

    /// The total buffered time in seconds calculated from the latest loaded time ranges, or zero if
    /// unavailable.
    public var bufferedDurationSeconds: Double {
        let current = currentTime
        for range in loadedTimeRanges where range.containsTime(current) {
            let end = CMTimeRangeGetEnd(range).seconds
            let cur = current.seconds
            if end >= cur {
                return end - cur
            }
        }
        return loadedTimeRanges.last.map { CMTimeRangeGetEnd($0).seconds } ?? 0
    }

    /// Whether the player is actively playing media.
    public var isPlaying: Bool {
        state.isPlaying
    }

    /// Whether the player is loading or buffering media.
    public var isLoading: Bool {
        state.isLoading || state.isBuffering || state.isWaitingForNetwork
    }

    /// Available audio tracks for the current media.
    public var audioTracks: [AKMediaTrackOption] {
        availableTracks[.audio] ?? []
    }

    /// Currently selected audio track.
    public var selectedAudioTrack: AKMediaTrackOption? {
        selectedTracks[.audio]
    }

    /// Available subtitle tracks for the current media.
    public var subtitleTracks: [AKMediaTrackOption] {
        availableTracks[.subtitle] ?? []
    }

    /// Currently selected subtitle track.
    public var selectedSubtitleTrack: AKMediaTrackOption? {
        selectedTracks[.subtitle]
    }

    /// Available closed caption tracks for the current media.
    public var closedCaptionTracks: [AKMediaTrackOption] {
        availableTracks[.closedCaption] ?? []
    }

    /// Currently selected closed caption track.
    public var selectedClosedCaptionTrack: AKMediaTrackOption? {
        selectedTracks[.closedCaption]
    }

    /// Available alternative video tracks for the current media.
    public var videoAlternativeTracks: [AKMediaTrackOption] {
        availableTracks[.videoAlternative] ?? []
    }

    /// Currently selected alternative video track.
    public var selectedVideoAlternativeTrack: AKMediaTrackOption? {
        selectedTracks[.videoAlternative]
    }

    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var trackRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var liveDriftTimerTask: Task<Void, Never>?

    // MARK: - Initialization & Lifecycle

    /// Creates an observable model for an existing player or a new default player.
    /// - Parameter player: The player to observe. Defaults to a new ``AKPlayer``.
    public init(
        player: AKPlayer = AKPlayer(),
        timelineSource: AKPlayerTimelineSource = .normal
    ) {
        self.player = player
        self.timelineSource = timelineSource
        state = player.state
        autoPlay = player.autoPlay
        currentMedia = player.currentMedia
        presentationSize = player.currentItem?.presentationSize ?? .zero
        switch timelineSource {
        case .normal:
            currentTime = player.currentTime
            duration = player.currentItemDuration
        case .integrated:
            let service = player.interstitialService
            currentTime = CMTime(
                seconds: service.integratedTimelineCurrentTime,
                preferredTimescale: 600
            )
            duration = CMTime(
                seconds: service.integratedTimelineDuration,
                preferredTimescale: 600
            )
        }
        playbackRate = player.rate
        volume = player.volume
        isMuted = player.isMuted
        error = player.error
        isLive = player.isLive
        isAtLiveEdge = player.isAtLiveEdge
        liveDrift = player.currentMedia?.liveDrift ?? .zero
        metadata = player.currentMedia?.metadataProvider.staticMetadata
        timedMetadata = player.currentMedia?.metadataProvider.timedMetadata
        canSeek = player.interstitialService.isPlayingInterstitial
            ? player.interstitialService.canSeek
            : player.currentMedia?.canSeek ?? false
        adMarkers = player.interstitialService.markers
        currentAdMarker = player.interstitialService.currentMarker
        currentAdItemIndex = player.interstitialService.currentItemIndex

        if let media = player.currentMedia {
            refreshCapabilities(for: media)
            chapters = media.chapterService.chapters
            currentChapter = media.chapterService.currentChapter(at: player.currentTime)
            observeTrackSelection(for: media)
        }

        let events = player.events
        eventTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled, let self else { break }
                self.handle(event)
            }
        }
    }

    deinit {
        eventTask?.cancel()
        trackRefreshTask?.cancel()
        liveDriftTimerTask?.cancel()
    }

    // MARK: - Loading Media (AKPlayerActionsProtocol)

    /// Prepares the underlying player and its audio session.
    public func prepare() async throws {
        try await player.prepare()
    }

    /// Loads media into the underlying player.
    public func load(
        media: any AKPlayable,
        autoPlay: Bool = true,
        at position: AKSeekTarget? = nil
    ) {
        player.load(media: media, autoPlay: autoPlay, at: position)
    }

    // MARK: - Controlling Playback (AKPlayerActionsProtocol)

    /// Starts or resumes playback.
    public func play() {
        player.play()
    }

    /// Commands the player to begin media playback at a specified speed multiplier.
    /// - Parameter rate: The target playback speed rate multiplier.
    public func play(at rate: AKPlaybackRate) {
        player.play(at: rate)
    }

    /// Pauses playback.
    public func pause() {
        player.pause()
    }

    /// Toggles between playing and paused.
    public func togglePlayPause() {
        player.togglePlayPause()
    }

    /// Stops playback and clears the wrapper's active media state.
    public func stop() {
        trackRefreshTask?.cancel()
        player.stop()
    }

    // MARK: - Seeking Through Media (AKPlayerActionsProtocol)

    /// Asynchronously seeks to a designated target position within the primary playback timeline.
    /// - Parameter target: The destination position target.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seek(to target: AKSeekTarget) async -> Bool {
        await player.seek(to: target)
    }

    /// Asynchronously seeks to a designated target position with custom tolerance boundary
    /// constraints.
    /// - Parameters:
    ///   - target: The destination position target.
    ///   - toleranceBefore: The allowable tolerance boundary before the target time.
    ///   - toleranceAfter: The allowable tolerance boundary after the target time.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool {
        await player.seek(
            to: target,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter
        )
    }

    /// Seeks to a designated target position within primary timeline using a completion callback.
    /// - Parameters:
    ///   - target: The destination position target.
    ///   - completionHandler: A callback invoked when the seek operation finishes.
    public func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        player.seek(to: target, completionHandler: completionHandler)
    }

    /// Seeks to a designated target position with custom tolerance boundary constraints using a
    /// completion callback.
    /// - Parameters:
    ///   - target: The destination position target.
    ///   - toleranceBefore: The allowable tolerance boundary before the target time.
    ///   - toleranceAfter: The allowable tolerance boundary after the target time.
    ///   - completionHandler: A callback invoked when the seek operation finishes.
    public func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        player.seek(
            to: target,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }

    /// Asynchronously seeks to a designated target position within the active media or integrated
    /// timeline.
    /// - Parameters:
    ///   - target: The destination position target.
    ///   - scope: The timeline coordinate space targeted.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seek(to target: AKSeekTarget, scope: AKSeekScope) async -> Bool {
        await player.seek(to: target, scope: scope)
    }

    /// Asynchronously seeks to a designated target position with custom tolerance boundary
    /// constraints.
    /// - Parameters:
    ///   - target: The destination position target.
    ///   - scope: The timeline coordinate space targeted.
    ///   - toleranceBefore: The allowable tolerance boundary before the target time.
    ///   - toleranceAfter: The allowable tolerance boundary after the target time.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool {
        await player.seek(
            to: target,
            scope: scope,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter
        )
    }

    /// Seeks to a designated target position using a completion callback.
    /// - Parameters:
    ///   - target: The destination position target.
    ///   - scope: The timeline coordinate space targeted.
    ///   - completionHandler: A callback invoked when the seek operation finishes.
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        player.seek(to: target, scope: scope, completionHandler: completionHandler)
    }

    /// Seeks to a designated target position with custom tolerance boundary constraints using a
    /// completion callback.
    /// - Parameters:
    ///   - target: The destination position target.
    ///   - scope: The timeline coordinate space targeted.
    ///   - toleranceBefore: The allowable tolerance boundary before the target time.
    ///   - toleranceAfter: The allowable tolerance boundary after the target time.
    ///   - completionHandler: A callback invoked when the seek operation finishes.
    public func seek(
        to target: AKSeekTarget,
        scope: AKSeekScope,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        player.seek(
            to: target,
            scope: scope,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }

    /// Asynchronously seeks on the integrated timeline to a designated position in seconds.
    /// - Parameter seconds: The target position in seconds along the integrated timeline.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seekOnIntegratedTimeline(to seconds: Double) async -> Bool {
        await player.seekOnIntegratedTimeline(to: seconds)
    }

    /// Seeks on the integrated timeline to a designated position in seconds using a completion
    /// callback.
    /// - Parameters:
    ///   - seconds: The target position in seconds along the integrated timeline.
    ///   - completionHandler: A callback invoked when the seek operation finishes.
    public func seekOnIntegratedTimeline(
        to seconds: Double,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        player.seekOnIntegratedTimeline(to: seconds, completionHandler: completionHandler)
    }

    /// Seeks to a position expressed in seconds.
    /// - Parameters:
    ///   - seconds: The destination playback time.
    ///   - scope: The timeline coordinate space. Defaults to the primary timeline.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seek(to seconds: Double, scope: AKSeekScope = .primary) async -> Bool {
        await seek(to: .seconds(seconds), scope: scope)
    }

    /// Skips forward by the specified duration in seconds.
    /// - Parameter seconds: Number of seconds to jump ahead. Defaults to 15.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func skipForward(by seconds: Double = 15) async -> Bool {
        await seek(to: .offset(seconds))
    }

    /// Skips backward by the specified duration in seconds.
    /// - Parameter seconds: Number of seconds to jump behind. Defaults to 10.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func skipBackward(by seconds: Double = 10) async -> Bool {
        await seek(to: .offset(-seconds))
    }

    /// Seeks to a chapter's start time.
    /// - Parameter chapter: The chapter to seek to.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seek(to chapter: AKChapter) async -> Bool {
        await seek(to: .seconds(chapter.startTime))
    }

    /// Seeks to the next chapter, if one exists.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seekToNextChapter() async -> Bool {
        guard let chapterService,
              let chapter = chapterService.nextChapter(from: currentTime)
        else {
            return false
        }
        return await seek(to: chapter)
    }

    /// Seeks to the previous chapter, if one exists.
    /// - Returns: Whether the seek completed successfully.
    @discardableResult
    public func seekToPreviousChapter() async -> Bool {
        guard let chapterService,
              let chapter = chapterService.previousChapter(from: currentTime)
        else {
            return false
        }
        return await seek(to: chapter)
    }

    // MARK: - Media Navigation (AKPlayerActionsProtocol)

    /// Steps frame-by-frame through video media by a specified frame count offset.
    /// - Parameter count: The frame offset count (positive for forward, negative for reverse).
    public func step(by count: Int) {
        player.step(by: count)
    }

    /// Fast-forwards playback using the default fast-forward speed defined in player configuration.
    public func fastForward() {
        player.fastForward()
    }

    /// Fast-forwards playback at a custom speed multiplier rate.
    /// - Parameter rate: The target fast-forward speed rate multiplier.
    public func fastForward(at rate: AKPlaybackRate) {
        player.fastForward(at: rate)
    }

    /// Rewinds playback using the default rewind speed defined in player configuration.
    public func rewind() {
        player.rewind()
    }

    /// Rewinds playback at a custom speed multiplier rate.
    /// - Parameter rate: The target rewind speed rate multiplier.
    public func rewind(at rate: AKPlaybackRate) {
        player.rewind(at: rate)
    }

    // MARK: - Live Stream Navigation (AKPlayerActionsProtocol)

    /// Jumps directly to the live head of the stream and resumes playback at normal speed.
    /// - Returns: Whether the jump completed successfully.
    @discardableResult
    public func jumpToLive() async -> Bool {
        await player.jumpToLive()
    }

    /// Jumps directly to the live head of the stream with a completion callback.
    /// - Parameter completionHandler: A callback invoked when the seek operation finishes.
    public func jumpToLive(completionHandler: @escaping @Sendable (Bool) -> Void) {
        player.jumpToLive(completionHandler: completionHandler)
    }

    // MARK: - Audio & Volume Controls

    /// Changes the output volume.
    public func setVolume(_ volume: Float) {
        player.volume = volume
    }

    /// Changes the audio mute state.
    public func setMuted(_ isMuted: Bool) {
        player.isMuted = isMuted
    }

    /// Toggles the audio mute state.
    public func toggleMute() {
        setMuted(!isMuted)
    }

    /// Changes the playback rate.
    public func setPlaybackRate(_ rate: AKPlaybackRate) {
        player.play(at: rate)
    }

    // MARK: - Track Selection

    /// Reloads available and selected track options for the current media.
    /// - Parameter types: The track types to load. Defaults to every supported type.
    /// - Throws: ``AKPlayerError/noItemToPlay`` if there is no current media, or an error from
    /// the track-selection service.
    public func refreshTracks(for types: [AKTrackType] = AKTrackType.allCases) async throws {
        guard let media = currentMedia else {
            throw AKPlayerError.noItemToPlay
        }

        do {
            var available: [AKTrackType: [AKMediaTrackOption]] = [:]
            var selected: [AKTrackType: AKMediaTrackOption] = [:]

            for type in types {
                try Task.checkCancellation()
                available[type] = try await media.trackSelection.availableTracks(for: type)
                if let option = try await media.trackSelection.selectedTrack(for: type) {
                    selected[type] = option
                }
            }

            guard !Task.isCancelled, currentMedia === media else { return }
            for (type, options) in available {
                availableTracks[type] = options
            }
            for (type, option) in selected {
                selectedTracks[type] = option
            }
            for type in types where selected[type] == nil {
                selectedTracks.removeValue(forKey: type)
            }
            trackSelectionError = nil
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard currentMedia === media else { throw error }
            trackSelectionError = error.localizedDescription
            throw error
        }
    }

    /// Selects or disables a track for the specified type.
    /// - Parameters:
    ///   - option: The track option to select, or `nil` to clear the selection.
    ///   - type: The type of track to update.
    /// - Throws: ``AKPlayerError/noItemToPlay`` if there is no current media, or an error from
    /// the track-selection service.
    public func selectTrack(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws {
        guard let service = trackSelectionService else {
            throw AKPlayerError.noItemToPlay
        }

        do {
            try await service.select(option, for: type)
            if let option {
                selectedTracks[type] = option
            } else {
                selectedTracks.removeValue(forKey: type)
            }
            trackSelectionError = nil
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            trackSelectionError = error.localizedDescription
            throw error
        }
    }

    /// Selects the preferred track for the specified type.
    /// - Parameter type: The type of track to select.
    /// - Throws: ``AKPlayerError/noItemToPlay`` if there is no current media, or an error from
    /// the track-selection service.
    public func selectPreferredTrack(for type: AKTrackType) async throws {
        guard let service = trackSelectionService else {
            throw AKPlayerError.noItemToPlay
        }

        do {
            try await service.selectPreferredTrack(for: type)
            if let option = try await service.selectedTrack(for: type) {
                selectedTracks[type] = option
            } else {
                selectedTracks.removeValue(forKey: type)
            }
            trackSelectionError = nil
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            trackSelectionError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Private Event Observers

    private func observeTrackSelection(for media: any AKPlayable) {
        trackRefreshTask?.cancel()
        trackRefreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await refreshTracks(for: AKTrackType.allCases)
            } catch is CancellationError {
                return
            } catch {
                guard currentMedia === media else { return }
                AKLogger.error(
                    "Failed to load track options: \(error.localizedDescription)",
                    category: .player
                )
            }
        }
    }

    private func handle(_ event: AKPlayerEvent) {
        latestEvent = event

        switch event {
        case let .stateDidChange(newState):
            handleStateDidChange(newState)

        case let .autoPlayDidChange(isAutoPlay):
            autoPlay = isAutoPlay

        case let .mediaDidChange(media):
            handleMediaDidChange(media)

        case let .timeDidChange(time):
            handleTimeDidChange(time)

        case let .media(mediaEvent):
            handleMedia(mediaEvent)

        case let .interstitial(event):
            handleInterstitial(event)

        case let .playbackRateDidChange(newRate, _):
            playbackRate = newRate

        case let .volumeDidChange(newVolume):
            volume = newVolume

        case let .muteStatusDidChange(isMuted):
            self.isMuted = isMuted

        case let .didFail(playerError):
            error = playerError

        case .boundaryReached, .commandUnavailable, .didReachEnd, .sharePlayStateDidChange:
            break
        }
    }

    private func handleStateDidChange(_ newState: AKPlayerState) {
        state = newState
        if newState.isStopped {
            currentMedia = nil
            capabilities = [:]
            canSeek = false
            currentTime = .zero
            duration = .zero
            loadedTimeRanges = []
            presentationSize = .zero
            metadata = nil
            timedMetadata = nil
            chapters = []
            currentChapter = nil
            availableTracks = [:]
            selectedTracks = [:]
            isInterstitialActive = false
            adMarkers = []
            currentAdMarker = nil
            currentAdItemIndex = 1
            error = nil
            trackSelectionError = nil
            stopLiveDriftTimer()
        } else if newState.isFailed {
            canSeek = false
            error = player.error
            stopLiveDriftTimer()
        } else if newState.isLoading {
            error = nil
            stopLiveDriftTimer()
        } else if newState.isPaused || (newState.isLoaded && !autoPlay) {
            if isLive {
                startLiveDriftTimer()
            }
        } else {
            stopLiveDriftTimer()
        }
    }

    private func handleMediaDidChange(_ media: (any AKPlayable)?) {
        currentMedia = media
        metadata = media?.metadataProvider.staticMetadata
        isLive = player.isLive
    }

    private func handleTimeDidChange(_ time: CMTime) {
        if timelineSource == .normal {
            currentTime = time
            updateCurrentChapter()
        }

        if isLive {
            updateLiveDrift()
        }
    }

    // MARK: - Live Drift Tracking

    /// Updates live drift and live edge status when playing a live stream.
    private func updateLiveDrift() {
        guard isLive else { return }
        isAtLiveEdge = player.isAtLiveEdge
        liveDrift = currentMedia?.liveDrift ?? .zero
    }

    /// Starts a periodic timer to update live drift while playback is paused on a live stream.
    private func startLiveDriftTimer() {
        stopLiveDriftTimer()
        guard isLive else { return }
        updateLiveDrift()
        liveDriftTimerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { break }
                self.updateLiveDrift()
            }
        }
    }

    /// Stops the periodic timer that tracks live drift during pause.
    private func stopLiveDriftTimer() {
        liveDriftTimerTask?.cancel()
        liveDriftTimerTask = nil
    }

    private func handleMedia(_ event: AKMediaEvent) {
        switch event {
        case let .durationDidChange(newDuration):
            if timelineSource == .normal, !isLive {
                duration = newDuration
            }

        case let .loadedTimeRangesDidChange(ranges):
            loadedTimeRanges = ranges

        case let .seekableTimeRangesDidChange(ranges):
            updateCanSeek()
            updateLiveDurationFromSeekableWindow(ranges: ranges)
            if isLive {
                updateLiveDrift()
            }

        case .stateDidChange(.playerItemLoaded):
            guard let media = currentMedia else { break }
            refreshCapabilities(for: media)

        case let .capabilityDidChange(capability, isSupported):
            capabilities[capability] = isSupported

        case let .trackSelection(trackEvent):
            handleTrackSelection(trackEvent)

        case let .chapter(chapterEvent):
            handleChapter(chapterEvent)

        case let .metadata(metadataEvent):
            handleMetadata(metadataEvent)

        case let .presentationSizeDidChange(size):
            presentationSize = size

        case .stateDidChange, .timebaseDidChange, .playerItemNotification:
            break
        }
    }

    private func handleTrackSelection(_ event: AKTrackSelectionEvent) {
        switch event {
        case let .availableTracksDidChange(options, type):
            availableTracks[type] = options

        case let .selectedTrackDidChange(option, type):
            if let option {
                selectedTracks[type] = option
            } else {
                selectedTracks.removeValue(forKey: type)
            }
        }
    }

    private func handleChapter(_ event: AKChapterEvent) {
        switch event {
        case let .chaptersDidChange(newChapters):
            chapters = newChapters
            updateCurrentChapter()
        }
    }

    private func handleMetadata(_ event: AKMediaMetadataEvent) {
        switch event {
        case let .staticMetadataDidChange(newMetadata):
            metadata = newMetadata
        case let .timedMetadataDidChange(newMetadata):
            timedMetadata = newMetadata
        }
    }

    private func handleInterstitial(_ event: AKInterstitialEvent) {
        switch event {
        case let .willStart(event):
            isInterstitialActive = true
            currentInterstitialIdentifier = event.identifier
            updateCanSeek()
            updateCurrentAdMarker()
        case .didStart:
            isInterstitialActive = true
            updateCanSeek()
            updateCurrentAdMarker()
        case let .progress(progress):
            interstitialProgress = progress
        case .didFinish:
            isInterstitialActive = false
            currentInterstitialIdentifier = nil
            interstitialProgress = nil
        case let .integratedTimeline(.timeUpdated(current, _, dur)):
            guard timelineSource == .integrated else { break }
            currentTime = CMTime(seconds: current, preferredTimescale: 600)
            duration = CMTime(seconds: dur, preferredTimescale: 600)

            updateCurrentChapter()
        case let .adMarkersDidChange(markers):
            adMarkers = markers
        case let .playbackStateDidChange(state):
            interstitialPlaybackState = state
        case .scheduleDidChange, .integratedTimeline:
            break
        }
    }

    private func updateCurrentAdMarker() {
        currentAdMarker = player.interstitialService.currentMarker
        currentAdItemIndex = player.interstitialService.currentItemIndex
    }

    private func synchronizeTimelineValues() {
        switch timelineSource {
        case .normal:
            currentTime = player.currentTime
            duration = player.currentItemDuration
            updateCurrentChapter()
            updateLiveDurationFromSeekableWindow()
        case .integrated:
            let service = player.interstitialService
            currentTime = CMTime(
                seconds: service.integratedTimelineCurrentTime,
                preferredTimescale: 600
            )
            duration = CMTime(
                seconds: service.integratedTimelineDuration,
                preferredTimescale: 600
            )
        }
    }

    private func updateCanSeek() {
        let interstitialService = player.interstitialService
        if interstitialService.isPlayingInterstitial {
            canSeek = interstitialService.canSeek
        } else {
            canSeek = currentMedia?.canSeek ?? false
        }
    }

    private func updateLiveDurationFromSeekableWindow(ranges: [CMTimeRange]? = nil) {
        guard timelineSource == .normal, isLive else { return }

        let latestRange = ranges?.last ?? currentMedia?.seekingThroughMedia.seekableWindow
        guard let latestRange else { return }

        let rangeDuration = latestRange.duration.seconds
        guard rangeDuration.isFinite, rangeDuration > 0 else { return }

        duration = latestRange.duration
    }

    private func refreshCapabilities(for media: any AKPlayable) {
        capabilities = Dictionary(
            uniqueKeysWithValues: AKMediaCapability.allCases.map {
                ($0, media.manager.isSupported($0))
            }
        )
    }

    private func updateCurrentChapter() {
        guard !chapters.isEmpty else {
            currentChapter = nil
            return
        }

        // When on an integrated timeline, query using primary content time (player.currentTime)
        // because chapters are defined in primary asset coordinates, not integrated coordinates.
        let primaryTime = (timelineSource == .integrated) ? player.currentTime : currentTime
        currentChapter = currentMedia?.chapterService.currentChapter(at: primaryTime)
    }
}
