//
//   AKAudioSessionService.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)

    // MARK: - AKAudioSessionServiceProtocol (iOS / tvOS)

    /// A protocol defining requirements for managing audio session configuration,
    /// category settings, and activation state on iOS and tvOS.
    public protocol AKAudioSessionServiceProtocol: AnyObject, Sendable {
        /// The underlying `AVAudioSession` instance managed by the service.
        var audioSession: AVAudioSession { get }

        /// Configures the audio session category, mode, route sharing policy, and options.
        /// - Parameters:
        ///   - category: The audio session category to apply.
        ///   - mode: The audio session mode to apply.
        ///   - policy: The route sharing policy to apply (e.g. `.longFormAudio`, `.default`).
        ///   - options: The category options governing behavior such as mixing or ducking.
        /// - Throws: An error if the category configuration fails.
        func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode,
            policy: AVAudioSession.RouteSharingPolicy,
            options: AVAudioSession.CategoryOptions
        ) throws

        /// Configures the audio session category, mode, and options with default route sharing
        /// policy.
        /// - Parameters:
        ///   - category: The audio session category to apply.
        ///   - mode: The audio session mode to apply.
        ///   - options: The category options governing behavior such as mixing or ducking.
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

    // MARK: - AKAudioSessionServiceProtocol Default Implementations

    public extension AKAudioSessionServiceProtocol {
        /// Convenience overload configuring category with optional defaults.
        func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode = .default,
            policy: AVAudioSession.RouteSharingPolicy = .default,
            options: AVAudioSession.CategoryOptions = []
        ) throws {
            try setCategory(category, mode: mode, policy: policy, options: options)
        }

        /// Convenience overload using `routeSharingPolicy` label matching AVFoundation.
        func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode = .default,
            routeSharingPolicy: AVAudioSession.RouteSharingPolicy = .default,
            options: AVAudioSession.CategoryOptions = []
        ) throws {
            try setCategory(category, mode: mode, policy: routeSharingPolicy, options: options)
        }

        /// Convenience overload configuring category without explicit policy.
        func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode = .default,
            options: AVAudioSession.CategoryOptions = []
        ) throws {
            try setCategory(category, mode: mode, policy: .default, options: options)
        }
    }

    // MARK: - AKAudioSessionService (iOS / tvOS)

    /// A concrete implementation of `AKAudioSessionServiceProtocol` for managing
    /// system audio session configurations safely across iOS and tvOS.
    public final class AKAudioSessionService: AKAudioSessionServiceProtocol, Sendable {
        // MARK: - Properties

        /// The managed `AVAudioSession` instance.
        public let audioSession: AVAudioSession

        // MARK: - Init & Deinit

        /// Initializes a new audio session service with a target audio session instance.
        /// - Parameter audioSession: The `AVAudioSession` instance to manage. Defaults to the
        /// shared instance.
        public init(
            audioSession: AVAudioSession = AVAudioSession.sharedInstance()
        ) {
            self.audioSession = audioSession
        }

        deinit {}

        // MARK: - Configuration Methods

        /// Configures the underlying audio session category, mode, route sharing policy, and
        /// options.
        public func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode = .default,
            policy: AVAudioSession.RouteSharingPolicy = .default,
            options: AVAudioSession.CategoryOptions = []
        ) throws {
            do {
                try audioSession.setCategory(
                    category,
                    mode: mode,
                    policy: policy,
                    options: options
                )
            } catch {
                throw AKPlayerError.audioSessionFailure(reason: .failedToSetCategory(error: error))
            }
        }

        /// Configures the underlying audio session category using the `routeSharingPolicy`
        /// parameter label.
        public func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode = .default,
            routeSharingPolicy: AVAudioSession.RouteSharingPolicy = .default,
            options: AVAudioSession.CategoryOptions = []
        ) throws {
            try setCategory(category, mode: mode, policy: routeSharingPolicy, options: options)
        }

        /// Configures the underlying audio session category, mode, and options without explicit
        /// policy.
        public func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode = .default,
            options: AVAudioSession.CategoryOptions = []
        ) throws {
            try setCategory(category, mode: mode, policy: .default, options: options)
        }

        /// Activates or deactivates the underlying audio session.
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

#elseif os(macOS)

    // MARK: - AKAudioSessionServiceProtocol (macOS)

    /// A protocol defining requirements for audio configuration on macOS where CoreAudio manages
    /// audio system-wide.
    public protocol AKAudioSessionServiceProtocol: AnyObject, Sendable {
        /// Activates or prepares audio playback.
        func activate(_ active: Bool) throws
    }

    // MARK: - AKAudioSessionService (macOS)

    /// A safe macOS implementation of `AKAudioSessionServiceProtocol` where audio routing is
    /// handled automatically.
    public final class AKAudioSessionService: AKAudioSessionServiceProtocol, Sendable {
        public init() {}
        deinit {}

        public func activate(_: Bool) throws {
            // Audio routing is managed system-wide by CoreAudio on macOS.
        }
    }

#endif
