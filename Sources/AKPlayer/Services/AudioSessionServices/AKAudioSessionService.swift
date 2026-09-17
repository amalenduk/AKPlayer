//
//   AKAudioSessionService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - AKAudioSessionServiceProtocol

/// A protocol defining requirements for managing audio session configuration,
/// category settings, and activation state.
public protocol AKAudioSessionServiceProtocol: AnyObject, Sendable {
    /// The underlying `AVAudioSession` instance managed by the service.
    var audioSession: AVAudioSession { get }

    /// Configures the audio session category, mode, and options.
    /// - Parameters:
    ///   - category: The audio session category to apply.
    ///   - mode: The audio session mode to apply.
    ///   - options: The category options governing behavior such as mixing or
    /// ducking.
    /// - Throws: An error if the category configuration fails.
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws

    /// Activates or deactivates the audio session.
    /// - Parameters:
    ///   - active: A Boolean value indicating whether to activate (`true`) or
    /// deactivate (`true` / `false`) the session.
    ///   - options: Options governing activation/deactivation behavior (such as
    /// notifying other audio sessions).
    /// - Throws: An error if activation or deactivation fails.
    func activate(
        _ active: Bool,
        options: AVAudioSession.SetActiveOptions
    ) throws
}

// MARK: - AKAudioSessionService

/// A concrete implementation of `AKAudioSessionServiceProtocol` for managing
/// system audio session configurations safely across any context.
public final class AKAudioSessionService: AKAudioSessionServiceProtocol, Sendable {
    // MARK: - Properties

    /// The managed `AVAudioSession` instance.
    public let audioSession: AVAudioSession

    // MARK: - Init & Deinit

    /// Initializes a new audio session service with a target audio session
    /// instance.
    /// - Parameter audioSession: The `AVAudioSession` instance to manage.
    /// Defaults to the shared instance.
    public init(
        audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    ) {
        self.audioSession = audioSession
    }

    deinit {}

    // MARK: - Configuration Methods

    /// Configures the underlying audio session category, mode, and options,
    /// wrapping any failures into player-specific errors.
    /// - Parameters:
    ///   - category: The audio session category.
    ///   - mode: The audio session mode. Defaults to `.default`.
    ///   - options: The category options. Defaults to an empty set.
    /// - Throws: `AKPlayerError.audioSessionFailure` if setting the category
    /// fails.
    public func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode = .default,
        options: AVAudioSession.CategoryOptions = []
    ) throws {
        do {
            try audioSession.setCategory(
                category,
                mode: mode,
                options: options
            )
        } catch {
            throw AKPlayerError.audioSessionFailure(reason: .failedToSetCategory(error: error))
        }
    }

    /// Activates or deactivates the underlying audio session, wrapping any
    /// failures into player-specific errors.
    /// - Parameters:
    ///   - active: A Boolean flag indicating activation state.
    ///   - options: Set options guiding the activation behavior. Defaults to an
    /// empty set.
    /// - Throws: `AKPlayerError.audioSessionFailure` if activation or
    /// deactivation fails.
    public func activate(
        _ active: Bool,
        options: AVAudioSession.SetActiveOptions = []
    ) throws {
        do {
            try audioSession.setActive(
                active,
                options: options
            )
        } catch {
            throw AKPlayerError.audioSessionFailure(
                reason: active
                    ? .failedToActivate(error: error)
                    : .failedToDeactivate(error: error)
            )
        }
    }
}
