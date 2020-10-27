//
//  AKPlayerRouteChangeObservingService.swift
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

protocol AKPlayerRouteChangeObservingServiceable {
    var onChangeRoute: ((_ reason: AVAudioSession.RouteChangeReason) -> Void)? { get set }
}

final class AKPlayerRouteChangeObservingService: AKPlayerRouteChangeObservingServiceable {
    
    // MARK: - Properties
    
    private let configuration: AKPlayerConfiguration
    
    var onChangeRoute: ((_ reason: AVAudioSession.RouteChangeReason) -> Void)?
    
    /**
     The `NSKeyValueObservation` for the KVO on `\AVPlayer.timeControlStatus`.
     */
    private var playerTimeControlStatusObserver: NSKeyValueObservation?
    
    // MARK: - Init
    
    init(configuration: AKPlayerConfiguration) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleService)
        self.configuration = configuration
        /* Observe audio session notifications to ensure that your app responds appropriately to route changes. */
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange(_ :)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleService)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
        }
        
        onChangeRoute?(reason)
    }
    
    // MARK: - Additional Helper Functions
    
    func hasHeadphones(in routeDescription: AVAudioSessionRouteDescription) -> Bool {
        // Filter the outputs to only those with a port type of headphones.
        return !routeDescription.outputs.filter({$0.portType == .headphones}).isEmpty
    }
}

