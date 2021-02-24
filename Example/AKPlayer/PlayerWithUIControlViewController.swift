//
//  PlayerWithUIControlViewController.swift
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
import AKPlayer

class PlayerWithUIControlViewController: UIViewController {
    
    // MARK: - UIElements
    
    @IBOutlet weak var videoPlayer: AKVideoPlayer!
    @IBOutlet weak var bottomContainerView: UIView!
    @IBOutlet weak var loadButton: UIButton!

    // MARK: - Variables

    var url: URL!
    var metadata: AKNowPlayableStaticMetadata!
    var media: AKMedia!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Controlled Player"
        
        url = URL(string: "https://www.radiantmediaplayer.com/media/big-buck-bunny-360p.mp4")!
        metadata = AKNowPlayableStaticMetadata(assetURL: url, mediaType: .video, isLiveStream: false, title: "Some title", artist: "Amalendu Kar", artwork: nil, albumArtist: "Amalendu Kar", albumTitle: "Amalendu Kar")
        media = AKMedia(url: url, type: .clip, staticMetadata: metadata)
        view.bringSubviewToFront(videoPlayer)
    }

    // MARK: - User Interactions

    @IBAction func loadButtonAction(_ sender: Any) {
        videoPlayer.load(media: media, autoPlay: true)
    }
}
