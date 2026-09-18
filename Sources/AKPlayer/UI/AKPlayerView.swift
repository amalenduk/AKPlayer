//
//   AKPlayerView.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import UIKit

/// A simple `UIView` subclass backed by an `AVPlayerLayer` layer.
open class AKPlayerView: UIView {
    /// The player from which to source the media content for the view
    /// controller.
    open var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    open var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    /// Override UIView property
    override public static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    /** Specifies how the video is displayed within a player layer’s bounds.
     (AVLayerVideoGravityResizeAspect is default) */
    open func setVideoFillMode(_ fillMode: String) {
        playerLayer.videoGravity = AVLayerVideoGravity(rawValue: fillMode)
    }
}
