//
//  SimpleVideoViewController.swift
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

import AVFoundation
import AKPlayer
import UIKit

class SimpleVideoViewController: UIViewController {
    
    // MARK: - Outlates
    
    @IBOutlet weak private var stateLabel: UILabel!
    @IBOutlet weak private var currentTime: UILabel!
    @IBOutlet weak private var durationLabel: UILabel!
    @IBOutlet weak private var rateLabel: UILabel!
    @IBOutlet weak private var playerVideo: AKPlayerView!
    @IBOutlet weak private var indicator: UIActivityIndicatorView!
    @IBOutlet weak private var debugMessageLabel: UILabel!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak private var rateButton: UIButton!
    @IBOutlet weak var assetInfoButton: UIButton!

    private let player: AKPlayer = {
        AKPlayerLogger.setup.domains = [.unavailableCommand]
        let configuration = AKPlayerDefaultConfiguration()
        return AKPlayer(plugins: [], configuration: configuration)
    }()

    var items: [Any] = []
    var reverseItems: [Any] = []
    var isTracking: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Simple Video"
        guard let videoLayer = playerVideo.layer as? AVPlayerLayer else { return }
        videoLayer.player = player.player
        player.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterInBackground(_ :)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterInForeground(_ :)), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        if #available(iOS 13.0, *) {
            reloadRateMenus()
        } else {
            rateButton.addTarget(self, action: #selector(rateChangeButtonAction(_ :)), for: .touchUpInside)
        }
        timeSlider.addTarget(self, action: #selector(progressSliderDidStartTracking(_ :)), for: [.touchDown])
        timeSlider.addTarget(self, action: #selector(progressSliderDidEndTracking(_ :)), for: [.touchUpInside, .touchCancel, .touchUpOutside])
        timeSlider.addTarget(self, action: #selector(progressSliderDidChangedValue(_ :)), for: [.valueChanged])
        timeSlider.minimumValue = 0
        timeSlider.maximumValue = 1
        timeSlider.value = 0
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // MARK: - Additional Helpers
    
    open func setSliderProgress(_ currentTime: CMTime, itemDuration: CMTime?) {
        guard !isTracking else { return }
        if let itemDuration = itemDuration, itemDuration.isValid && itemDuration.isNumeric, !timeSlider.isTracking {
            timeSlider.value = Float(currentTime.seconds / itemDuration.seconds)
        }
    }
    
    private func setDebugMessage(_ msg: String?) {
        debugMessageLabel.text = msg
        debugMessageLabel.alpha = 1.0
        UIView.animate(withDuration: 1.5) { self.debugMessageLabel.alpha = 0 }
    }

    @available(iOS 13.0, *)
    func reloadRateMenus() {
        let destruct = UIAction(title: "Cancel", attributes: .destructive) { _ in }
        items.removeAll()
        reverseItems.removeAll()
        
        for rate in AKPlaybackRate.allCases {
            let action = UIAction(title: rate.rateTitle, identifier: UIAction.Identifier.init("\(rate.rate)"), state: rate == player.playbackRate ? .on : .off) { [unowned self] _ in
                player.playbackRate = rate
            }
            items.append(action)
        }
        
        for rate in AKPlaybackRate.allCases {
            let action = UIAction(title: ("-" + rate.rateTitle), identifier: UIAction.Identifier.init("\(-rate.rate)"), state: .off) { [unowned self] _ in
                player.playbackRate = .custom(-rate.rate)
            }
            reverseItems.append(action)
        }
        
        let menu = UIMenu(title: "Rate", options: .displayInline, children: [destruct, UIMenu(title: "Rate", options: .displayInline, children: items as! [UIAction]), UIMenu(title: "Reverse", options: .destructive, children: reverseItems as! [UIAction])])
        
        if #available(iOS 14.0, *) {
            rateButton.menu = menu
            rateButton.showsMenuAsPrimaryAction = true
        }
    }
    
    // MARK: - User Interactions

    @IBAction func updateNowPlayingInfoButtonActon(_ sender: Any) {
        player.manager.setNowPlayingMetadata()
        player.manager.setNowPlayingPlaybackInfo()
    }

    @objc func rateChangeButtonAction(_ sender: UIButton) {
        player.playbackRate = player.playbackRate.next
    }

    @IBAction func infoButtonAction(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "AssetInfoViewController") as! AssetInfoViewController
        let navVc = UINavigationController(rootViewController: vc)
        vc.assetInfo = player.currentMedia?.assetMetadata
        present(navVc, animated: true, completion: nil)
    }

    @objc func progressSliderDidStartTracking(_ slider: UISlider) {
        isTracking = true
    }
    
    @objc func progressSliderDidEndTracking(_ slider: UISlider) {
        player.seek(toPercentage: Double(slider.value)) { finished in
            self.isTracking = false
        }
    }
    
    @objc func progressSliderDidChangedValue(_ slider: UISlider) {
    }
    
    @IBAction func play(_ sender: UIButton) {
        player.play()
    }
    
    @IBAction func pause(_ sender: UIButton) {
        player.pause()
    }
    
    @IBAction func stop(_ sender: Any) {
        player.stop()
    }
    
    @IBAction func load(_ sender: Any) {
        let url = URL(string: "https://5b44cf20b0388.streamlock.net:8443/vod/smil:bbb.smil/playlist.m3u8")!
        guard let path = Bundle.main.path(forResource: "Lut Gaye (Full Song) Emraan Hashmi, Yukti | Jubin N, Tanishk B, Manoj M | Bhushan K | Radhika-Vinay", ofType:"mp4") else {
            debugPrint("video.m4v not found")
            return
        }
        let metadata = AKNowPlayableStaticMetadata(assetURL: URL(fileURLWithPath: path), mediaType: .video, isLiveStream: false, title: "Some title", artist: "Bal", artwork: nil, albumArtist: "dfgg", albumTitle: "ggee")
        let media = AKMedia(url: url, type: .clip, staticMetadata: metadata)
        player.load(media: media)
    }
    
    @IBAction func loadAndPlay(_ sender: Any) {
        let url = URL(string: "https://5b44cf20b0388.streamlock.net:8443/vod/smil:bbb.smil/playlist.m3u8")!
        guard let path = Bundle.main.path(forResource: "Lut Gaye (Full Song) Emraan Hashmi, Yukti | Jubin N, Tanishk B, Manoj M | Bhushan K | Radhika-Vinay", ofType:"mp4") else {
            debugPrint("video.m4v not found")
            return
        }
        let metadata = AKNowPlayableStaticMetadata(assetURL: URL(fileURLWithPath: path), mediaType: .video, isLiveStream: false, title: "Some title", artist: "By Google", artwork: nil, albumArtist: "dfgg", albumTitle: "ggee")
        let media = AKMedia(url: URL(fileURLWithPath: path), type: .clip)
        player.load(media: media, autoPlay: true)
    }
    
    @IBAction func stepForward(_ sender: UIButton) {
        player.step(byCount: 1)
    }
    
    @IBAction func stepBackward(_ sender: UIButton) {
        player.step(byCount: -1)
    }
    
    @IBAction func prevSeek(_ sender: UIButton) {
        player.seek(offset: -15)
    }
    
    @IBAction func nextSeek(_ sender: UIButton) {
        player.seek(offset: 15)
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
        DispatchQueue.main.async {
            self.currentTime.text = "Current Timing: " + String(format: "%.2f", currentTime.seconds)
            self.setSliderProgress(currentTime, itemDuration: player.itemDuration)
        }
    }
    
    func akPlayer(_ player: AKPlayer, didItemDurationChange itemDuration: CMTime) {
        DispatchQueue.main.async {
            self.durationLabel.text = "Duration: " + String(format: "%.2f", itemDuration.seconds)
        }
    }
    
    func akPlayer(_ player: AKPlayer, unavailableAction reason: AKPlayerUnavailableActionReason) {
        DispatchQueue.main.async {
            self.setDebugMessage(reason.description)
        }
    }
    
    func akPlayer(_ player: AKPlayer, didItemPlayToEndTime endTime: CMTime) {
        
    }
    
    func akPlayer(_ player: AKPlayer, didFailedWith error: AKPlayerError) {
        DispatchQueue.main.async {
            self.setDebugMessage(error.localizedDescription)
        }
    }
    
    func akPlayer(_ player: AKPlayer, didPlaybackRateChange playbackRate: AKPlaybackRate) {
        rateLabel.text = "Rate: \(playbackRate.rateTitle)"
        if #available(iOS 13.0, *) {
            reloadRateMenus()
        }
    }
}
