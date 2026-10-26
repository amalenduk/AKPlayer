//
//   AKSubtitleOutputService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation
import Synchronization

// MARK: - Delegate Push Handler

private final class AKLegibleOutputPushDelegateHandler: NSObject,
    AVPlayerItemLegibleOutputPushDelegate, @unchecked Sendable
{
    private let onStrings: @Sendable ([NSAttributedString], CMTime) -> Void

    init(onStrings: @escaping @Sendable ([NSAttributedString], CMTime) -> Void) {
        self.onStrings = onStrings
        super.init()
    }

    func legibleOutput(
        _: AVPlayerItemLegibleOutput,
        didOutputAttributedStrings strings: [NSAttributedString],
        nativeSampleBuffers _: [Any],
        forItemTime itemTime: CMTime
    ) {
        onStrings(strings, itemTime)
    }
}

// MARK: - AKSubtitleOutputService

/// Thread-safe service for intercepting active subtitles and closed captions in real-time
/// using AVFoundation's `AVPlayerItemLegibleOutput`.
public final class AKSubtitleOutputService: NSObject, AKSubtitleOutputServiceProtocol,
    AKSubtitleOutputLifecycleManaging, @unchecked Sendable
{
    // MARK: - Internal State

    private struct State {
        var isRunning = false
        var currentCue: AKSubtitleCue?
        var suppressesPlayerRendering = true
        weak var attachedPlayerItem: AVPlayerItem?
    }

    private let state = Mutex<State>(State())

    // MARK: - Dependencies

    private weak var mediaManager: (any AKMediaManagerProtocol)?
    private let legibleOutput = AVPlayerItemLegibleOutput()
    private var pushHandler: AKLegibleOutputPushDelegateHandler?
    private let callbackQueue = DispatchQueue(label: "com.akplayer.subtitleOutputQueue")

    // MARK: - Events

    private let eventsBroadcaster = AKEventBroadcaster<AKSubtitleEvent>()

    public var events: AsyncStream<AKSubtitleEvent> {
        eventsBroadcaster.makeStream()
    }

    // MARK: - Properties

    public var isRunning: Bool {
        state.withLock { $0.isRunning }
    }

    public var currentCue: AKSubtitleCue? {
        state.withLock { $0.currentCue }
    }

    public var suppressesPlayerRendering: Bool {
        get { state.withLock { $0.suppressesPlayerRendering } }
        set {
            state.withLock { $0.suppressesPlayerRendering = newValue }
            legibleOutput.suppressesPlayerRendering = newValue
        }
    }

    // MARK: - Initialization & Deinitialization

    public init(mediaManager: any AKMediaManagerProtocol) {
        defer {
            AKLogger.logInit(self)
        }
        self.mediaManager = mediaManager
        super.init()

        legibleOutput.suppressesPlayerRendering = true

        let handler = AKLegibleOutputPushDelegateHandler { [weak self] strings, itemTime in
            self?.handleLegibleStrings(strings, at: itemTime)
        }
        self.pushHandler = handler
        legibleOutput.setDelegate(handler, queue: callbackQueue)
    }

    deinit {
        let attachedItem = state.withLock { state -> AVPlayerItem? in
            state.isRunning = false
            let item = state.attachedPlayerItem
            state.attachedPlayerItem = nil
            return item
        }
        if let attachedItem {
            Task { @MainActor [legibleOutput] in
                if attachedItem.outputs.contains(where: { $0 === legibleOutput }) {
                    attachedItem.remove(legibleOutput)
                }
            }
        }
        eventsBroadcaster.finish()
        AKLogger.logDeinit(
            String(describing: Self.self),
            pointer: Unmanaged.passUnretained(self)
        )
    }

    // MARK: - Control Methods

    public func start() {
        let shouldStart: Bool = state.withLock { state in
            if state.isRunning {
                return false
            }
            state.isRunning = true
            return true
        }
        guard shouldStart else { return }

        eventsBroadcaster.send(.isRunningDidChange(true))

        if let playerItem = mediaManager?.playerItem {
            attach(to: playerItem)
        }
    }

    public func stop() {
        let itemToDetach: AVPlayerItem? = state.withLock { state in
            if !state.isRunning {
                return nil
            }
            state.isRunning = false
            state.currentCue = nil
            let item = state.attachedPlayerItem
            state.attachedPlayerItem = nil
            return item
        }

        if let itemToDetach {
            Task { @MainActor [legibleOutput] in
                if itemToDetach.outputs.contains(where: { $0 === legibleOutput }) {
                    itemToDetach.remove(legibleOutput)
                }
            }
        }

        eventsBroadcaster.send(.cueDidChange(nil))
        eventsBroadcaster.send(.isRunningDidChange(false))
    }

    public func clearCue() {
        state.withLock { $0.currentCue = nil }
        eventsBroadcaster.send(.cueDidChange(nil))
    }

    // MARK: - Lifecycle Management

    func attach(to playerItem: AVPlayerItem) {
        let isCurrentlyRunning = state.withLock { state -> Bool in
            guard state.isRunning else { return false }
            state.attachedPlayerItem = playerItem
            return true
        }

        guard isCurrentlyRunning else { return }

        Task { @MainActor [legibleOutput] in
            if !playerItem.outputs.contains(where: { $0 === legibleOutput }) {
                playerItem.add(legibleOutput)
            }
        }
    }

    func detach(from playerItem: AVPlayerItem?) {
        guard let playerItem else { return }
        state.withLock { state in
            if state.attachedPlayerItem === playerItem {
                state.attachedPlayerItem = nil
            }
        }
        Task { @MainActor [legibleOutput] in
            if playerItem.outputs.contains(where: { $0 === legibleOutput }) {
                playerItem.remove(legibleOutput)
            }
        }
    }

    func resetSession() {
        state.withLock {
            $0.currentCue = nil
            $0.attachedPlayerItem = nil
        }
        eventsBroadcaster.send(.cueDidChange(nil))
    }

    // MARK: - Private Processing

    private func handleLegibleStrings(_ strings: [NSAttributedString], at itemTime: CMTime) {
        guard isRunning else { return }

        let nonEmptyStrings = strings.filter {
            !$0.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if nonEmptyStrings.isEmpty {
            state.withLock { $0.currentCue = nil }
            eventsBroadcaster.send(.cueDidChange(nil))
        } else {
            let combinedText = nonEmptyStrings.map(\.string).joined(separator: "\n")
            let mutable = NSMutableAttributedString()
            for (idx, str) in nonEmptyStrings.enumerated() {
                if idx > 0 {
                    mutable.append(NSAttributedString(string: "\n"))
                }
                mutable.append(str)
            }
            let attributed = AttributedString(mutable)
            let cue = AKSubtitleCue(
                text: combinedText,
                attributedText: attributed,
                itemTime: itemTime
            )
            state.withLock { $0.currentCue = cue }
            eventsBroadcaster.send(.cueDidChange(cue))
        }
    }
}
