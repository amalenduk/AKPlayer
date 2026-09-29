//
//   AKPlatformTypes.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

#if canImport(UIKit)
    import UIKit

    /// Cross-platform view type (`UIView` on iOS, iPadOS, tvOS, and visionOS).
    public typealias AKPlatformView = UIView

    /// Cross-platform image type (`UIImage` on iOS, iPadOS, tvOS, and visionOS).
    public typealias AKPlatformImage = UIImage

    /// Cross-platform color type (`UIColor` on iOS, iPadOS, tvOS, and visionOS).
    public typealias AKPlatformColor = UIColor

    /// Cross-platform view controller type (`UIViewController` on iOS, iPadOS, tvOS, and visionOS).
    public typealias AKPlatformViewController = UIViewController

#elseif canImport(AppKit)
    import AppKit

    /// Cross-platform view type (`NSView` on macOS).
    public typealias AKPlatformView = NSView

    /// Cross-platform image type (`NSImage` on macOS).
    public typealias AKPlatformImage = NSImage

    /// Cross-platform color type (`NSColor` on macOS).
    public typealias AKPlatformColor = NSColor

    /// Cross-platform view controller type (`NSViewController` on macOS).
    public typealias AKPlatformViewController = NSViewController
#endif
