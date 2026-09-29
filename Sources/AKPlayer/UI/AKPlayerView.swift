//
//   AKPlayerView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

#if canImport(UIKit)
    import UIKit

    /// A `UIView` subclass backed by an `AVPlayerLayer` for rendering video content on iOS and
    /// tvOS.
    open class AKPlayerView: UIView {
        /// The player from which to source the media content for the view controller.
        open var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue }
        }

        /// The underlying `AVPlayerLayer` used for rendering video content.
        open var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }

        /// Specifies the layer class for this view as `AVPlayerLayer`.
        override public static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        /// Specifies how the video is displayed within the player layer's bounds.
        /// - Parameter fillMode: The video gravity raw string value (e.g.
        /// `AVLayerVideoGravity.resizeAspect.rawValue`).
        open func setVideoFillMode(_ fillMode: String) {
            playerLayer.videoGravity = AVLayerVideoGravity(rawValue: fillMode)
        }
    }

#elseif canImport(AppKit)
    import AppKit

    /// An `NSView` subclass backed by an `AVPlayerLayer` for rendering video content on macOS.
    open class AKPlayerView: NSView {
        /// The player from which to source the media content for the view controller.
        open var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue }
        }

        /// The underlying `AVPlayerLayer` used for rendering video content.
        open var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }

        /// Overrides backing layer construction to produce an `AVPlayerLayer`.
        override open func makeBackingLayer() -> CALayer {
            AVPlayerLayer()
        }

        /// Initializes a new player view with the specified frame rectangle.
        override public init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }

        /// Initializes a new player view from decoded archive data.
        public required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
        }

        /// Specifies how the video is displayed within the player layer's bounds.
        /// - Parameter fillMode: The video gravity raw string value (e.g.
        /// `AVLayerVideoGravity.resizeAspect.rawValue`).
        open func setVideoFillMode(_ fillMode: String) {
            playerLayer.videoGravity = AVLayerVideoGravity(rawValue: fillMode)
        }
    }
#endif
