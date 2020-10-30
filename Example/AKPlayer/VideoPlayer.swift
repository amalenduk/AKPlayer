//
//  VideoPlayer.swift
//  AKPlayer_Example
//
//  Created by Bright Roots 2019 on 28/10/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import AVFoundation
import AKPlayer

class VideoPlayer: UIView {

    // MARK:- UIElements

    // MARK:- Variables

    private var player: AKPlayer!
    private var playerPlayer: AKPlayerView!

    // MARK: Lifecycle

    // Custom initializers go here

    // MARK: View Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        commonInit()
    }

    // MARK: Layout

    /// Override this function to apply the design on views
    open func applyDesigns() {

    }

    /// Override this function to add subviewes
    open func addUIElements() {
        addSubview(playerPlayer)
    }

    /// Override this function to add view Constraints
    open func makeViewConstraints() {
    }

    // MARK: User Interaction

    // MARK: Additional Helpers

    /// Override this function to add targets to buttons
    open func addTargets() {

    }

    /// Called by both `init(frame: CGRect)` and `init?(coder: NSCoder)`,
    open func commonInit() {
        setupPlayer()
        addUIElements()
        makeViewConstraints()
        applyDesigns()
        addTargets()
    }

    private func setupPlayer() {
        
    }
}
