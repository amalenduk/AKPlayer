//
//   Runtime.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

/// Retrieves an associated object from an Objective-C runtime object reference.
/// - Parameters:
///   - object: The source object holding the association.
///   - key: The unique association pointer key.
/// - Returns: The associated object typed as `T`, or `nil` if not found.
func getAssociatedObject<T>(_ object: AnyObject, _ key: UnsafeRawPointer) -> T? {
    objc_getAssociatedObject(object, key) as? T
}

/// Sets a non-atomic retained associated object on an Objective-C runtime object.
/// - Parameters:
///   - object: The target object receiving the association.
///   - key: The unique association pointer key.
///   - value: The object value to associate, or `nil` to clear.
func setRetainedAssociatedObject(
    _ object: AnyObject,
    _ key: UnsafeRawPointer,
    _ value: (some AnyObject)?
) {
    objc_setAssociatedObject(
        object,
        key,
        value,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
}

