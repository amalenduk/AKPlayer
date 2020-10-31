//
//  PlayerWithUIControlViewController.swift
//  AKPlayer_Example
//
//  Created by Bright Roots 2019 on 28/10/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import AKPlayer

class PlayerWithUIControlViewController: UIViewController {

    // MARK: - UIElements

    @IBOutlet weak var videoPlayer: AKVideoPlayer!
    @IBOutlet weak var bottomContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Controlled Player"

        let url = URL(string: "https://r3---sn-bvvbax-jj0e.googlevideo.com/videoplayback?expire=1604181786&ei=uoqdX9CaMtPw-gaxhZ2oBA&ip=36.83.180.231&id=o-AHaPWdlmEIBwfBUkwVMWPsCPyahB-CEdSxihG-aiJAp9&itag=18&source=youtube&requiressl=yes&vprv=1&mime=video%2Fmp4&gir=yes&clen=18567909&ratebypass=yes&dur=240.349&lmt=1584225636159251&fvip=3&c=WEB&txp=5531432&sparams=expire%2Cei%2Cip%2Cid%2Citag%2Csource%2Crequiressl%2Cvprv%2Cmime%2Cgir%2Cclen%2Cratebypass%2Cdur%2Clmt&sig=AOq0QJ8wRAIgMPkDfYALLTjW70K2Tzvf4IMP9LpWyr5-CelT8sa1TtoCIHYJTcR9BVTUOKbUBMwJkmhy6CT5Rop93KJNuO3bsvB_&rm=sn-2uuxa3vh-230e7s,sn-npoer7s&req_id=92a780c01b4ca3ee&redirect_counter=2&cms_redirect=yes&ipbypass=yes&mh=3Y&mip=223.29.196.83&mm=29&mn=sn-bvvbax-jj0e&ms=rdu&mt=1604167370&mv=m&mvi=3&nh=IgppcjAxLmNjdTAxKg00My4yNTEuMTc5Ljcz&pl=24&lsparams=ipbypass,mh,mip,mm,mn,ms,mv,mvi,nh,pl&lsig=AG3C_xAwRAIgTN3KzctyYkRN8DWPcongLwCnGJF1mtKF5Gyd4LTrIecCIE-y8Kimv2OPTmmlUdDrSvbqxkWAnzy2rKx1OQg5cUjK")!
        let metadata = AKMediaStaticMetadata(assetURL: url, mediaType: .video, isLiveStream: false, title: "Some title", artist: "Bal", artwork: nil, albumArtist: "dfgg", albumTitle: "ggee")
        let media = AKMedia(url: url, type: .clip, staticMetadata: metadata)
        videoPlayer.load(media: media)
    }
}
