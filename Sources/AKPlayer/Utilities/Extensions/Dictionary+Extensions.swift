//
//   Dictionary+Extensions.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

// MARK: - Dictionary Extensions

extension Dictionary {
    // MARK: - Operations

    /// Merges the key-value pairs of the given dictionary into this dictionary,
    /// overwriting existing values for duplicate keys.
    /// - Parameter dict: The dictionary containing key-value pairs to merge.
    /// - Returns: A new dictionary containing the combined key-value pairs.
    func merging(dict: [Key: Value]) -> [Key: Value] {
        var mutableCopy = self
        for (key, value) in dict {
            mutableCopy[key] = value
        }
        return mutableCopy
    }
}
