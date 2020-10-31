//
//  SimpleVideoViewController.swift
//  AKPlayer
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

import AVFoundation
import AKPlayer
import UIKit

class SimpleVideoViewController: UIViewController {
    
    // MARK: - Outlates
    
    @IBOutlet weak private var stateLabel: UILabel!
    @IBOutlet weak private var timingLabel: UILabel!
    @IBOutlet weak private var durationLabel: UILabel!
    @IBOutlet weak private var errorLabel: UILabel!
    @IBOutlet weak private var playerVideo: AKPlayerView!
    @IBOutlet weak private var prevSeek: UIButton!
    @IBOutlet weak private var nextSeek: UIButton!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    private let player: AKPlayer = {
        AKPlayerLogger.setup.domains = [.state, .error]
        let configuration = AKPlayerDefaultConfiguration()
        return AKPlayer(plugins: [], configuration: configuration)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Simple Video"
        guard let videoLayer = playerVideo.layer as? AVPlayerLayer
            else { return }
        videoLayer.player = player.player
        player.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterInBackground(_ :)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterInForeground(_ :)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // MARK: - User Interactions
    
    @IBAction func play(_ sender: UIButton) {
        player.play()
    }
    
    @IBAction func pause(_ sender: UIButton) {
        player.pause()
    }
    
    @IBAction func stop(_ sender: Any) {
        player.stop()
    }
    
    @IBAction func loop(_ sender: UIButton) {
        
    }
    
    @IBAction func load(_ sender: Any) {
        let url = URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4")!
        let metadata = AKMediaStaticMetadata(assetURL: url, mediaType: .video, isLiveStream: false, title: "Some title", artist: "Bal", artwork: nil, albumArtist: "dfgg", albumTitle: "ggee")
        let media = AKMedia(url: url, type: .clip, staticMetadata: metadata)
        player.load(media: media)
    }
    
    @IBAction func loadAndPlay(_ sender: Any) {
        let url = URL(string: "https://www.learningcontainer.com/wp-content/uploads/2020/05/sample-mov-file.mov")!
        let metadata = AKMediaStaticMetadata(assetURL: url, mediaType: .video, isLiveStream: false, title: "Some title", artist: "By Google", artwork: nil, albumArtist: "dfgg", albumTitle: "ggee")
        let media = AKMedia(url: url, type: .clip, staticMetadata: metadata)
        player.load(media: media, autoPlay: true, at: CMTime(seconds: 10, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
    
    @IBAction func prevSeek(_ sender: UIButton) {
        player.seek(offset: -15)
    }
    
    @IBAction func nextSeek(_ sender: UIButton) {
        player.seek(offset: +15)
    }
    
    // MARK: - Observers
    
    @objc func didEnterInBackground(_ notification: Notification) {
        playerVideo.player = nil
    }
    
    @objc func didEnterInForeground(_ notification: Notification) {
        playerVideo.player = player.player
    }
}

extension SimpleVideoViewController: AKPlayerDelegate {
    
    func akPlayer(_ player: AKPlayer, didStateChange state: AKPlayer.State) {
        DispatchQueue.main.async {
            self.stateLabel.text = "State: " + state.description
            if state != .failed { self.errorLabel.text = nil }
            if state == .waitingForNetwork || state == .buffering || state == .loading {
                self.indicator.startAnimating()
            }else {
                self.indicator.stopAnimating()
            }
        }
    }
    
    func akPlayer(_ player: AKPlayer, didCurrentMediaChange media: AKPlayable) {
        
    }
    
    func akPlayer(_ player: AKPlayer, didCurrentTimeChange currentTime: CMTime) {
        DispatchQueue.main.async { self.timingLabel.text = "Current Timing: " + String(format: "%.2f", currentTime.seconds) }
    }
    
    func akPlayer(_ player: AKPlayer, didItemDurationChange itemDuration: CMTime) {
        DispatchQueue.main.async {
            self.durationLabel.text = "Duration: " + String(format: "%.2f", itemDuration.seconds)
        }
    }
    
    func akPlayer(_ player: AKPlayer, unavailableAction reason: AKPlayerUnavailableActionReason) {
        
    }
    
    func akPlayer(_ player: AKPlayer, didItemPlayToEndTime endTime: CMTime) {
        
    }
    
    func akPlayer(_ player: AKPlayer, didFailedWith error: AKPlayerError) {
        DispatchQueue.main.async {
            self.errorLabel.text = "Error: " + error.localizedDescription
        }
    }
}
