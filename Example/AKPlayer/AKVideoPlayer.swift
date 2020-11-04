//
//  AKVideoPlayer.swift
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

open class AKVideoPlayer: UIView {
    
    // MARK:- UIElements
    
    @IBOutlet private var contentView: UIView!
    @IBOutlet private weak var playerView: AKPlayerView!
    @IBOutlet private weak var controlView: AKVideoPlayerControlView!

    // MARK:- Variables
    
    open private(set) var player: AKPlayer!
    public let configuration = AKPlayerDefaultConfiguration()

    open var playbackRate: AKPlaybackRate {
        get { player.playbackRate }
        set { player.playbackRate = newValue }
    }
    
    weak var delegate: AKPlayerDelegate? {
        didSet {
            player.delegate = delegate
        }
    }
    
    // MARK: Lifecycle
    
    // Custom initializers go here
    
    // MARK: View Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonInit()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // MARK: Layout

    // MARK: User Interaction
    
    @objc private func playPauseButtonAction(_ sender: UIButton) {
        switch player.state {
        case .playing, .buffering, .loading, .waitingForNetwork:
            player.pause()
        case .initialization, .failed:
            player.play()
        case .loaded, .paused, .stopped:
            player.play()
        }
    }
    
    @objc private func minimizeBarButtonAction(_ sender: UIButton) {
        
    }

    @objc private func timeSliderTouchDownAction(_ sender: UISlider) {
        if let duration = player.itemDuration, duration.isValid && duration.isNumeric { }
    }
    
    @objc private func timeSliderValueChangedAction(_ sender: UISlider) {
        if let duration = player.itemDuration, duration.isValid && duration.isNumeric {
            controlView.currentTimeLabel.text = String(describing: CMTime(seconds: (duration.seconds * Double(sender.value)), preferredTimescale: configuration.preferredTimescale).positionalTime)
        }
    }
    
    @objc private func timeSliderSlideEndedAction(_ sender: UISlider) {
        if let duration = player.itemDuration, duration.isValid && duration.isNumeric {
            player.seek(to: duration.seconds * Double(sender.value))
        }
    }
    
    // MARK: Additional Helpers
    
    /// Override this function to add targets to buttons
    open func addTargets() {
        controlView.playbackButton.addTarget(self, action: #selector(playPauseButtonAction(_ :)), for: .touchUpInside)
        controlView.minimizeButton.action = #selector(minimizeBarButtonAction(_ :))
        
        controlView.progressSlider.addTarget(self, action: #selector(timeSliderTouchDownAction(_:)),
                                             for: .touchDown)
        
        controlView.progressSlider.addTarget(self, action: #selector(timeSliderValueChangedAction(_:)),
                                             for: .valueChanged)
        
        controlView.progressSlider.addTarget(self, action: #selector(timeSliderSlideEndedAction(_:)),
                                             for: [.touchUpInside, .touchCancel, .touchUpOutside])

        controlView.playbackrateButton.onRateChange { (rate) in
            self.player.playbackRate = rate
        }
    }
    
    /// Called by both `init(frame: CGRect)` and `init?(coder: NSCoder)`,
    open func commonInit() {
        Bundle.main.loadNibNamed("AKVideoPlayer", owner: self, options: nil)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(contentView)
        setupPlayer()
        addTargets()
        addObserbers()
    }
    
    private func setupPlayer() {
        AKPlayerLogger.setup.domains = AKPlayerLoggerDomain.allCases
        player = AKPlayer(plugins: [self], configuration: configuration)
        player.delegate = self
        playerView.playerLayer.player = player.player
    }

    open func progressSlider(_ isAvailable: Bool) {
        if isAvailable {
            controlView.progressSlider.isEnabled = false
        }else {
            controlView.progressSlider.isEnabled = true
        }
    }

    private func addObserbers() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterInBackground(_ :)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterInForeground(_ :)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    // MARK: - Obserbers

    @objc func didEnterInBackground(_ notification: Notification) {
        playerView.player = nil
    }

    @objc func didEnterInForeground(_ notification: Notification) {
        playerView.player = player.player
    }
}

// MARK: - AKPlayerPlugin

extension AKVideoPlayer: AKPlayerPlugin { }

// MARK: - AKPlayerCommand

extension AKVideoPlayer: AKPlayerCommand {
    
    public func load(media: AKPlayable) {
        player.load(media: media)
    }
    
    public func load(media: AKPlayable, autoPlay: Bool) {
        player.load(media: media, autoPlay: autoPlay)
    }
    
    public func load(media: AKPlayable, autoPlay: Bool, at position: CMTime) {
        player.load(media: media, autoPlay: autoPlay, at: position)
    }
    
    public func load(media: AKPlayable, autoPlay: Bool, at position: Double) {
        player.load(media: media, autoPlay: autoPlay, at: position)
    }
    
    public func play() {
        player.play()
    }
    
    public func pause() {
        player.pause()
    }
    
    public func stop() {
        player.stop()
    }
    
    public func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        player.seek(to: time, completionHandler: completionHandler)
    }
    
    public func seek(to time: CMTime) {
        player.seek(to: time)
    }
    
    public func seek(to time: Double, completionHandler: @escaping (Bool) -> Void) {
        player.seek(to: time, completionHandler: completionHandler)
    }
    
    public func seek(to time: Double) {
        player.seek(to: time)
    }
    
    public func seek(offset: Double) {
        player.seek(to: offset)
    }
    
    public func seek(offset: Double, completionHandler: @escaping (Bool) -> Void) {
        player.seek(to: offset, completionHandler: completionHandler)
    }
}

// MARK: - AKPlayerDelegate

extension AKVideoPlayer: AKPlayerDelegate {

    public func akPlayer(_ player: AKPlayer, didStateChange state: AKPlayer.State) {
        switch state {
        case .buffering:
            controlView.playbackButton.changePlayback(.playing)
            controlView.playbackButton.isHidden = true
            controlView.indicator.startAnimating()
        case .failed:
            controlView.playbackButton.changePlayback(.failed)
            controlView.playbackButton.isHidden = false
            controlView.indicator.stopAnimating()
        case .initialization:
            break
        case .loaded:
            controlView.playbackButton.changePlayback(.paused)
            controlView.playbackButton.isHidden = false
            controlView.indicator.stopAnimating()
        case .loading:
            controlView.playbackButton.changePlayback(.paused)
            controlView.playbackButton.isHidden = true
            controlView.indicator.startAnimating()
        case .paused:
            controlView.playbackButton.changePlayback(.paused)
            controlView.playbackButton.isHidden = false
            controlView.indicator.stopAnimating()
        case .playing:
            controlView.playbackButton.changePlayback(.playing)
            controlView.playbackButton.isHidden = false
            controlView.indicator.stopAnimating()
        case .stopped:
            controlView.playbackButton.changePlayback(.stopped)
            controlView.playbackButton.isHidden = false
            controlView.indicator.stopAnimating()
        case .waitingForNetwork:
            controlView.playbackButton.changePlayback(.playing)
            controlView.playbackButton.isHidden = true
            controlView.indicator.startAnimating()
        }
    }
    
    public func akPlayer(_ player: AKPlayer, didCurrentMediaChange media: AKPlayable) {
        DispatchQueue.main.async {
            self.controlView.resetControlls()
            self.progressSlider(!media.isLive())
        }
    }
    
    public func akPlayer(_ player: AKPlayer, didCurrentTimeChange currentTime: CMTime) {
        DispatchQueue.main.async {
            self.controlView.currentTimeLabel.text = currentTime.positionalTime
            if let duration = self.player.itemDuration, self.player.currentMedia!.type == .clip {
                if !self.controlView.progressSlider.isTracking {
                    self.controlView.progressSlider.value = Float(self.player.currentTime.seconds / (duration.seconds))
                }
            }
        }
    }
    
    public func akPlayer(_ player: AKPlayer, didItemDurationChange itemDuration: CMTime) {
        if itemDuration.isValid && itemDuration.isNumeric {
            DispatchQueue.main.async {
                self.controlView.totalDurationLabel.text = itemDuration.positionalTime
                self.controlView.progressSlider.isEnabled = true
            }
        }
    }
    
    public func akPlayer(_ player: AKPlayer, unavailableAction reason: AKPlayerUnavailableActionReason) {
        
    }
    
    public func akPlayer(_ player: AKPlayer, didItemPlayToEndTime endTime: CMTime) {
        
    }
    
    public func akPlayer(_ player: AKPlayer, didFailedWith error: AKPlayerError) {
        
    }

    public func akPlayer(_ player: AKPlayer, didPlaybackRateChange playbackRate: AKPlaybackRate) {
        controlView.playbackrateButton.change(playbackRate)
    }
}
