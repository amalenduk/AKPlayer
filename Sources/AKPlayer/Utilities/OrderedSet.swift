//
//   OrderedSet.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - OrderedSet

/// An ordered collection of unique elements maintaining insertion sequence.
public struct OrderedSet<Element: Hashable>: Sequence {
    // MARK: - Properties

    /// The backing array preserving ordered sequence.
    private var elements: [Element]

    /// The backing set enforcing element uniqueness and $O(1)$ existence
    /// lookups.
    private var set: Set<Element>

    /// The last element in the ordered set, if any.
    public var last: Element? {
        elements.last
    }

    /// The first element in the ordered set, if any.
    public var first: Element? {
        elements.first
    }

    /// The total number of unique elements stored in the set.
    public var count: Int {
        elements.count
    }

    /// A Boolean value indicating whether the set contains no elements.
    public var isEmpty: Bool {
        elements.isEmpty
    }

    // MARK: - Initialization

    /// Initializes an empty ordered set collection.
    public init() {
        elements = []
        set = Set()
    }

    // MARK: - Insertion & Lookup

    /// Inserts the specified element into the ordered set if it is not already
    /// present.
    /// - Parameter element: The element to append to the end of the collection.
    public mutating func insert(_ element: Element) {
        if set.insert(element).inserted {
            elements.append(element)
        }
    }

    /// Returns a Boolean value indicating whether the set contains the given
    /// element.
    /// - Parameter element: The element to search for in the collection.
    /// - Returns: `true` if the element exists; otherwise, `false`.
    public func contains(_ element: Element) -> Bool {
        set.contains(element)
    }

    // MARK: - Sequence Protocol

    /// Returns an iterator over the ordered elements of the collection.
    public func makeIterator() -> IndexingIterator<[Element]> {
        elements.makeIterator()
    }

    // MARK: - Removal Operations

    /// Removes and discards the first element from the ordered set.
    public mutating func removeFirst() {
        guard !elements.isEmpty else { return }
        let removedElement = elements.removeFirst()
        set.remove(removedElement)
    }

    /// Removes and discards the last element from the ordered set.
    public mutating func removeLast() {
        guard !elements.isEmpty else { return }
        let removedElement = elements.removeLast()
        set.remove(removedElement)
    }

    /// Removes all elements from the ordered set.
    public mutating func removeAll() {
        elements.removeAll()
        set.removeAll()
    }

    /// Removes the specified element from the set if present.
    /// - Parameter element: The element to remove.
    public mutating func remove(_ element: Element) {
        guard set.contains(element) else { return }
        elements.removeAll(where: { $0 == element })
        set.remove(element)
    }
}
