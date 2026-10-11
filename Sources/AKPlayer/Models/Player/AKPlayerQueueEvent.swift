//
//   AKPlayerQueueEvent.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

/// Queue-specific changes published by ``AKQueuePlayer``.
public enum AKPlayerQueueEvent: Sendable {
    /// The queue was replaced with a new list of items.
    case itemsLoaded(items: [any AKPlayable], startIndex: Int, autoPlay: Bool)

    /// An item was added at the specified queue index.
    case itemAdded(any AKPlayable, at: Int)

    /// An item was removed from the specified queue index.
    case itemRemoved(any AKPlayable, at: Int)

    /// An item was moved between queue indices.
    case itemMoved(any AKPlayable, from: Int, to: Int)

    /// The active queue item changed.
    case currentItemDidChange(item: (any AKPlayable)?, index: Int?)

    /// The queue repeat mode changed.
    case repeatModeDidChange(AKRepeatMode)

    /// Queue shuffle mode changed.
    case shuffleModeDidChange(isEnabled: Bool)
}

// MARK: - Equatable Conformance

extension AKPlayerQueueEvent: Equatable {
    /// Compares two `AKPlayerQueueEvent` instances for equality.
    public static func == (lhs: AKPlayerQueueEvent, rhs: AKPlayerQueueEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.itemsLoaded(lItems, lStart, lAuto), .itemsLoaded(rItems, rStart, rAuto)):
            guard lStart == rStart, lAuto == rAuto,
                  lItems.count == rItems.count else { return false }
            return zip(lItems, rItems).allSatisfy { $0.0.isEqual(to: $0.1) }
        case let (.itemAdded(lItem, lAt), .itemAdded(rItem, rAt)):
            return lAt == rAt && lItem.isEqual(to: rItem)
        case let (.itemRemoved(lItem, lAt), .itemRemoved(rItem, rAt)):
            return lAt == rAt && lItem.isEqual(to: rItem)
        case let (.itemMoved(lItem, lFrom, lTo), .itemMoved(rItem, rFrom, rTo)):
            return lFrom == rFrom && lTo == rTo && lItem.isEqual(to: rItem)
        case let (.currentItemDidChange(lItem, lIdx), .currentItemDidChange(rItem, rIdx)):
            guard lIdx == rIdx else { return false }
            switch (lItem, rItem) {
            case (.none, .none):
                return true
            case let (.some(l), .some(r)):
                return l.isEqual(to: r)
            default:
                return false
            }
        case let (.repeatModeDidChange(l), .repeatModeDidChange(r)):
            return l == r
        case let (.shuffleModeDidChange(l), .shuffleModeDidChange(r)):
            return l == r
        default:
            return false
        }
    }
}
