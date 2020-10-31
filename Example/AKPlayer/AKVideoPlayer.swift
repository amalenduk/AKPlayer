//
//  AKVideoPlayer.swift
//  AKPlayer_Example
//
//  Created by Bright Roots 2019 on 28/10/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import AVFoundation
import AKPlayer

class AKVideoPlayer: UIView {

    // MARK:- UIElements

    @IBOutlet var contentView: UIView!
    @IBOutlet weak var playerView: AKPlayerView!
    @IBOutlet weak var controlView: UIView!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var mainMaskView: UIView!
    @IBOutlet weak var maskStackView: UIStackView!
    @IBOutlet weak var middleMaskView: UIView!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var topToolBar: UIToolbar!
    @IBOutlet weak var minimizeButton: UIBarButtonItem!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var totalDurationLabel: UILabel!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var fullscreenButton: UIButton!
    @IBOutlet weak var videoGravityButton: UIBarButtonItem!
    @IBOutlet weak var playBackSpeedButton: UIBarButtonItem!

    // MARK:- Variables

    private var player: AKPlayer!
    private let configuration = AKPlayerDefaultConfiguration()

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

        timeSlider.setThumbImage(UIImage(named: "ic.track.thumb"), for: .normal)
    }

    open func resetControlls() {
        currentTimeLabel.text = "00:00"
        totalDurationLabel.text = "/ 00:00"
        timeSlider.value = 0
    }

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

    @objc private func videoGravityButtonAction(_ sender: UIButton) {
        switch playerView.playerLayer.videoGravity {
        case .resize:
            playerView.playerLayer.videoGravity = .resizeAspect
        case .resizeAspectFill:
            playerView.playerLayer.videoGravity = .resize
        case .resizeAspect:
            playerView.playerLayer.videoGravity = .resizeAspectFill
        default:
            playerView.playerLayer.videoGravity = .resize
        }
    }

    @objc private func playBackSpeedButtonAction(_ sender: UIButton) {
        player.rate = 0.5
    }

    // MARK: Additional Helpers

    /// Override this function to add targets to buttons
    func addTargets() {
        playPauseButton.addTarget(self, action: #selector(playPauseButtonAction(_ :)), for: .touchUpInside)
        minimizeButton.action = #selector(minimizeBarButtonAction(_ :))
        videoGravityButton.action = #selector(videoGravityButtonAction(_ :))
        playBackSpeedButton.action = #selector(playBackSpeedButtonAction(_ :))
    }

    /// Called by both `init(frame: CGRect)` and `init?(coder: NSCoder)`,
    open func commonInit() {
        Bundle.main.loadNibNamed("AKVideoPlayer", owner: self, options: nil)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(contentView)

        setupPlayer()
        applyDesigns()
        addTargets()
        resetControlls()
    }

    private func setupPlayer() {
        AKPlayerLogger.setup.domains = [.state, .error]
        player = AKPlayer(plugins: [self], configuration: configuration)
        player.delegate = self
        playerView.playerLayer.player = player.player
    }
}

// MARK: - AKPlayerPlugin

extension AKVideoPlayer: AKPlayerPlugin {
    func playerPlugin(didInit player: AVPlayer) {

    }

    func playerPlugin(didChanged state: AKPlayer.State) {

    }

    func playerPlugin(didChanged media: AKPlayable) {

    }

    func playerPlugin(willStartLoading media: AKPlayable) {

    }

    func playerPlugin(didStartLoading media: AKPlayable) {

    }

    func playerPlugin(didStartBuffering media: AKPlayable) {

    }

    func playerPlugin(didLoad media: AKPlayable, with duration: CMTime) {

    }

    func playerPlugin(willStartPlaying media: AKPlayable, at position: CMTime) {

    }

    func playerPlugin(didStartPlaying media: AKPlayable, at position: CMTime) {

    }

    func playerPlugin(didPaused media: AKPlayable, at position: CMTime) {

    }

    func playerPlugin(didStopped media: AKPlayable, at position: CMTime) {

    }

    func playerPlugin(didStartWaitingForNetwork media: AKPlayable) {

    }

    func playerPlugin(didFailed media: AKPlayable, with error: AKPlayerError) {

    }

    func playerPlugin(didPlayToEnd media: AKPlayable, at endTime: CMTime) {

    }
}

// MARK: - AKPlayerCommand

extension AKVideoPlayer: AKPlayerCommand {

    func load(media: AKPlayable) {
        player.load(media: media)
    }

    func load(media: AKPlayable, autoPlay: Bool) {
        player.load(media: media, autoPlay: autoPlay)
    }

    func load(media: AKPlayable, autoPlay: Bool, at position: CMTime) {
        player.load(media: media, autoPlay: autoPlay, at: position)
    }

    func load(media: AKPlayable, autoPlay: Bool, at position: Double) {
        player.load(media: media, autoPlay: autoPlay, at: position)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.stop()
    }

    func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        player.seek(to: time, completionHandler: completionHandler)
    }

    func seek(to time: CMTime) {
        player.seek(to: time)
    }

    func seek(to time: Double, completionHandler: @escaping (Bool) -> Void) {
        player.seek(to: time, completionHandler: completionHandler)
    }

    func seek(to time: Double) {
        player.seek(to: time)
    }

    func seek(offset: Double) {
        player.seek(to: offset)
    }

    func seek(offset: Double, completionHandler: @escaping (Bool) -> Void) {
        player.seek(to: offset, completionHandler: completionHandler)
    }
}

// MARK: - AKPlayerDelegate

extension AKVideoPlayer: AKPlayerDelegate {
    func akPlayer(_ player: AKPlayer, didStateChange state: AKPlayer.State) {
        switch state {
        case .buffering:
            playPauseButton.isSelected = true
            playPauseButton.isHidden = true
            indicator.startAnimating()
        case .failed:
            playPauseButton.isSelected = false
            playPauseButton.isHidden = false
            indicator.stopAnimating()
        case .initialization:
            break
        case .loaded:
            playPauseButton.isSelected = false
            playPauseButton.isHidden = false
            indicator.stopAnimating()
        case .loading:
            playPauseButton.isSelected = true
            playPauseButton.isHidden = true
            indicator.startAnimating()
        case .paused:
            playPauseButton.isSelected = false
            playPauseButton.isHidden = false
            indicator.stopAnimating()
        case .playing:
            playPauseButton.isSelected = true
            playPauseButton.isHidden = false
            indicator.stopAnimating()
        case .stopped:
            playPauseButton.isSelected = false
            playPauseButton.isHidden = false
            indicator.stopAnimating()
        case .waitingForNetwork:
            playPauseButton.isSelected = true
            playPauseButton.isHidden = true
            indicator.startAnimating()
        }
    }

    func akPlayer(_ player: AKPlayer, didCurrentMediaChange media: AKPlayable) {
        DispatchQueue.main.async {
            self.resetControlls()
        }
    }

    func akPlayer(_ player: AKPlayer, didCurrentTimeChange currentTime: CMTime) {
        DispatchQueue.main.async {
            self.currentTimeLabel.text = currentTime.positionalTime
            self.timeSlider.value = Float(self.player.currentTime.seconds / (self.player.itemDuration?.seconds ?? 0))
        }
    }

    func akPlayer(_ player: AKPlayer, didItemDurationChange itemDuration: CMTime) {
        DispatchQueue.main.async {
            self.totalDurationLabel.text = itemDuration.positionalTime
        }
    }
    
    func akPlayer(_ player: AKPlayer, unavailableAction reason: AKPlayerUnavailableActionReason) {

    }

    func akPlayer(_ player: AKPlayer, didItemPlayToEndTime endTime: CMTime) {

    }

    func akPlayer(_ player: AKPlayer, didFailedWith error: AKPlayerError) {

    }
}
