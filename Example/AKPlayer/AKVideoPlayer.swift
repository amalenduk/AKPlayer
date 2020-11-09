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
    
    // MARK: Additional Helpers
    
    /// Called by both `init(frame: CGRect)` and `init?(coder: NSCoder)`,
    open func commonInit() {
        Bundle.main.loadNibNamed("AKVideoPlayer", owner: self, options: nil)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(contentView)
        controlView.delegate = self
        setupPlayer()
        addObserbers()
    }
    
    private func setupPlayer() {
        AKPlayerLogger.setup.domains = AKPlayerLoggerDomain.allCases
        player = AKPlayer(plugins: [self], configuration: configuration)
        player.delegate = self
        playerView.playerLayer.player = player.player
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
    
    public func seek(toPercentage value: Double, completionHandler: @escaping (Bool) -> Void) {
        player.seek(toPercentage: value, completionHandler: completionHandler)
    }
    
    public func seek(toPercentage value: Double) {
        player.seek(toPercentage: value)
    }
}

// MARK: - AKPlayerDelegate

extension AKVideoPlayer: AKPlayerDelegate {
    
    public func akPlayer(_ player: AKPlayer, didStateChange state: AKPlayer.State) {
        controlView.changedPlayerState(state)
    }
    
    public func akPlayer(_ player: AKPlayer, didCurrentMediaChange media: AKPlayable) {
        DispatchQueue.main.async {
            self.controlView.resetControlls()
            self.controlView.progressSlider(!media.isLive())
        }
    }
    
    public func akPlayer(_ player: AKPlayer, didCurrentTimeChange currentTime: CMTime) {
        DispatchQueue.main.async {
            self.controlView.setCurrentTime(currentTime)
            self.controlView.setSliderProgress(currentTime, itemDuration: player.itemDuration)
        }
    }
    
    public func akPlayer(_ player: AKPlayer, didItemDurationChange itemDuration: CMTime) {
        DispatchQueue.main.async {
            self.controlView.setDuration(itemDuration)
        }
    }
    
    public func akPlayer(_ player: AKPlayer, unavailableAction reason: AKPlayerUnavailableActionReason) {
        
    }
    
    public func akPlayer(_ player: AKPlayer, didItemPlayToEndTime endTime: CMTime) {
        
    }
    
    public func akPlayer(_ player: AKPlayer, didFailedWith error: AKPlayerError) {
        
    }
    
    public func akPlayer(_ player: AKPlayer, didPlaybackRateChange playbackRate: AKPlaybackRate) {
        
    }
}

// MARK: - AKVideoPlayerControlViewDelegate

extension AKVideoPlayer: AKVideoPlayerControlViewDelegate {
    
    func controlView(_ view: AKVideoPlayerControlView, didTapPlaybackButton button: AKPlaybackButton) {
        switch player.state {
        case .playing, .buffering, .loading, .waitingForNetwork:
            player.pause()
        case .initialization, .failed:
            player.play()
        case .loaded, .paused, .stopped:
            player.play()
        }
    }
    
    func controlView(_ view: AKVideoPlayerControlView, progressSlider slider: UISlider, didChanged value: Float) {
        if let duration = player.itemDuration, duration.isValid, duration.isNumeric {
            controlView.setCurrentTime(CMTime(seconds: (duration.seconds * Double(slider.value)), preferredTimescale: configuration.preferredTimescale))
        }
    }
    
    func controlView(_ view: AKVideoPlayerControlView, progressSlider slider: UISlider, didStartTrackingWith value: Float) { }
    
    func controlView(_ view: AKVideoPlayerControlView, progressSlider slider: UISlider, didEndTrackingWith value: Float) {
        seek(toPercentage: Double(slider.value))
    }
}
