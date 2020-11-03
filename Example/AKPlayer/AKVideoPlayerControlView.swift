//
//  AKVideoPlayerControlView.swift
//  AKPlayer_Example
//
//  Created by Bright Roots 2019 on 03/11/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class AKVideoPlayerControlView: UIView {

    // MARK:- UIElements

    @IBOutlet private var contentView: UIView!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var mainMaskView: UIView!
    @IBOutlet weak var maskStackView: UIStackView!
    @IBOutlet weak var middleMaskView: UIView!
    @IBOutlet weak var playbackButton: AKPlaybackButton!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var topToolBar: UIToolbar!
    @IBOutlet weak var minimizeButton: UIBarButtonItem!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var totalDurationLabel: UILabel!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var fullscreenButton: UIButton!

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
        topToolBar.setBackgroundImage(UIImage(),
                                      forToolbarPosition: .any,
                                      barMetrics: .default)
        topToolBar.setShadowImage(UIImage(), forToolbarPosition: .any)

        progressSlider.setThumbImage(UIImage(named: "ic.track.thumb"), for: .normal)
    }

    open func resetControlls() {
        currentTimeLabel.text = "00:00"
        totalDurationLabel.text = "/ 00:00"
        progressSlider.value = 0
        progressSlider.minimumValue = 0
        progressSlider.maximumValue = 1
        progressSlider.isEnabled = false
        progressSlider.layer.zPosition = CGFloat(1)
    }

    // MARK: User Interaction

    // MARK: Additional Helpers


    /// Called by both `init(frame: CGRect)` and `init?(coder: NSCoder)`,
    open func commonInit() {
        Bundle.main.loadNibNamed("AKVideoPlayerControlView", owner: self, options: nil)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(contentView)

        applyDesigns()
        resetControlls()
    }

    open func progressSlider(_ isAvailable: Bool) {
        if isAvailable {
            self.progressSlider.isEnabled = false
        }else {
            self.progressSlider.isEnabled = true
        }
    }
}
