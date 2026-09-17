import CoreMedia
import Foundation
import Synchronization

// MARK: - AKSeek

/// Represents a media seek command containing the target position, tolerances,
/// and completion callback, guaranteeing single-execution safety.
public final class AKSeek: Equatable, Hashable, Identifiable, @unchecked Sendable {
    // MARK: - Properties

    /// Unique identifier for this specific seek request.
    public let id: UUID

    /// The target playback position.
    public let target: AKSeekTarget

    /// The maximum allowable time before the target time that the player may seek.
    public let toleranceBefore: CMTime

    /// The maximum allowable time after the target time that the player may seek.
    public let toleranceAfter: CMTime

    /// Internal thread-safe storage for the completion handler, cleared upon invocation.
    private let completionStorage: Mutex<(@Sendable (Bool) -> Void)?>

    // MARK: - Initialization

    /// Creates a new seek request.
    /// - Parameters:
    ///   - id: Unique identifier for this request. Defaults to a new `UUID()`.
    ///   - target: The target position to seek to.
    ///   - toleranceBefore: Tolerance before the target position. Defaults to `.positiveInfinity`.
    ///   - toleranceAfter: Tolerance after the target position. Defaults to `.positiveInfinity`.
    ///   - completionHandler: Callback executed when seeking completes or is canceled.
    public init(
        id: UUID = UUID(),
        target: AKSeekTarget,
        toleranceBefore: CMTime = .positiveInfinity,
        toleranceAfter: CMTime = .positiveInfinity,
        completionHandler: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.id = id
        self.target = target
        self.toleranceBefore = toleranceBefore
        self.toleranceAfter = toleranceAfter
        self.completionStorage = Mutex(completionHandler)
    }

    // MARK: - Completion Execution

    /// Invokes the completion handler with the given result.
    /// Guarantees that the completion handler is called at most once.
    public func complete(with result: Bool) {
        let handler = completionStorage.withLock { storage in
            let action = storage
            storage = nil
            return action
        }
        handler?(result)
    }

    // MARK: - Equatable & Hashable

    public static func == (lhs: AKSeek, rhs: AKSeek) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
