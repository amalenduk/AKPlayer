//
//  AKVideoPlayerControlView.swift
//  AKPlayer_Example
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit
import AVFoundation
import AKPlayer

protocol AKVideoPlayerControlViewDelegate: AnyObject {
    func controlView(_ view: AKVideoPlayerControlView, didTapPlaybackButton button: AKPlaybackButton)
    func controlView(_ view: AKVideoPlayerControlView, progressSlider slider: UISlider, didChanged value: Float)
    func controlView(_ view: AKVideoPlayerControlView, progressSlider slider: UISlider, didStartTrackingWith value: Float)
    func controlView(_ view: AKVideoPlayerControlView, progressSlider slider: UISlider, didEndTrackingWith value: Float)
}

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
    
    // MARK: - Properties
    
    weak var delegate: AKVideoPlayerControlViewDelegate?
    
    // MARK: Lifecycle
    
    // Custom initializers go here
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    // MARK: View Lifecycle
    
    // MARK: Layout
    
    /// Override this function to apply the design on views
    open func applyDesigns() {
        topToolBar.setBackgroundImage(UIImage(),
                                      forToolbarPosition: .any,
                                      barMetrics: .default)
        topToolBar.setShadowImage(UIImage(),
                                  forToolbarPosition: .any)
        
        progressSlider.setThumbImage(UIImage(named: "ic.track.thumb"),
                                     for: .normal)
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
    
    @objc private func playPauseButtonAction(_ sender: UIButton) {
        delegate?.controlView(self, didTapPlaybackButton: playbackButton)
    }
    
    @objc private func minimizeBarButtonAction(_ sender: UIButton) {
        
    }
    
    @objc func progressSliderDidStartTracking(_ slider: UISlider) {
        delegate?.controlView(self, progressSlider: slider, didStartTrackingWith: slider.value)
    }
    
    @objc func progressSliderDidEndTracking(_ slider: UISlider) {
        delegate?.controlView(self, progressSlider: slider, didEndTrackingWith: slider.value)
    }
    
    @objc func progressSliderDidChangedValue(_ slider: UISlider) {
        delegate?.controlView(self, progressSlider: slider, didChanged: slider.value)
    }
    
    // MARK: Additional Helpers
    
    /// Called by both `init(frame: CGRect)` and `init?(coder: NSCoder)`,
    open func commonInit() {
        Bundle.main.loadNibNamed("AKVideoPlayerControlView", owner: self, options: nil)
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(contentView)
        
        applyDesigns()
        resetControlls()
        addTargets()
    }
    
    open func addTargets() {
        playbackButton.addTarget(self, action: #selector(playPauseButtonAction(_ :)), for: .touchUpInside)
        minimizeButton.action = #selector(minimizeBarButtonAction(_ :))
        progressSlider.addTarget(self, action: #selector(progressSliderDidStartTracking(_ :)), for: [.touchDown])
        progressSlider.addTarget(self, action: #selector(progressSliderDidEndTracking(_ :)), for: [.touchUpInside, .touchCancel, .touchUpOutside])
        progressSlider.addTarget(self, action: #selector(progressSliderDidChangedValue(_ :)), for: [.valueChanged])
    }
    
    open func progressSlider(_ isAvailable: Bool) {
        progressSlider.isEnabled = isAvailable
    }
    
    open func setCurrentTime(_ time: CMTime) {
        if time.isValid && time.isNumeric {
            currentTimeLabel.text = time.positionalTime
        }
    }
    
    open func setSliderProgress(_ currentTime: CMTime, itemDuration: CMTime?) {
        if let itemDuration = itemDuration, itemDuration.isValid && itemDuration.isNumeric, !progressSlider.isTracking {
            progressSlider.value = Float(currentTime.seconds / itemDuration.seconds)
        }
    }
    
    open func setDuration(_ duration: CMTime) {
        if duration.isValid && duration.isNumeric {
            totalDurationLabel.text = duration.positionalTime
        }
    }
    
    open func setPlaybackState(_ state: AKPlaybackButton.AKPlaybackState) {
        playbackButton.changePlayback(state)
    }
    
    open func changedPlayerState(_ state: AKPlayer.State) {
        switch state {
        case .buffering:
            playbackButton.changePlayback(.playing)
            playbackButton.isHidden = true
            indicator.startAnimating()
        case .failed:
            playbackButton.changePlayback(.failed)
            playbackButton.isHidden = false
            indicator.stopAnimating()
        case .initialization:
            break
        case .loaded:
            playbackButton.changePlayback(.paused)
            playbackButton.isHidden = false
            indicator.stopAnimating()
        case .loading:
            playbackButton.changePlayback(.paused)
            playbackButton.isHidden = true
            indicator.startAnimating()
        case .paused:
            playbackButton.changePlayback(.paused)
            playbackButton.isHidden = false
            indicator.stopAnimating()
        case .playing:
            playbackButton.changePlayback(.playing)
            playbackButton.isHidden = false
            indicator.stopAnimating()
        case .stopped:
            playbackButton.changePlayback(.stopped)
            playbackButton.isHidden = false
            indicator.stopAnimating()
        case .waitingForNetwork:
            playbackButton.changePlayback(.playing)
            playbackButton.isHidden = true
            indicator.startAnimating()
        }
    }
}

// MARK: - AKPlayerPlugin

extension AKVideoPlayerControlView: AKPlayerPlugin {
    
}
