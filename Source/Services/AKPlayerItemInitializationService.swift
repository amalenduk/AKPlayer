//
//  AKPlayerItemInitializationService.swift
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

protocol AKPlayerItemInitializationServiceable {
    var onCompletedCreatingPlayerItem: ((Result<AVPlayerItem, AKPlayerError>) -> Void)? { get set }
    func cancelLoading(clearCallBacks: Bool)
}

final class AKPlayerItemInitializationService: AKPlayerItemInitializationServiceable {
    
    // MARK: - Properties
    
    private let media: AKPlayable
    private let configuration: AKPlayerConfiguration
    private var asset: AVAsset?
    
    var onCompletedCreatingPlayerItem: ((Result<AVPlayerItem, AKPlayerError>) -> Void)?
    
    // MARK: - Init
    
    init(with media: AKPlayable, configuration: AKPlayerConfiguration) {
        AKPlayerLogger.shared.log(message: "Init", domain: .lifecycleService)
        self.media = media
        self.configuration = configuration
        set(media: media)
    }
    
    deinit {
        AKPlayerLogger.shared.log(message: "DeInit", domain: .lifecycleService)
    }
    
    func cancelLoading(clearCallBacks: Bool) {
        if clearCallBacks { onCompletedCreatingPlayerItem = nil }
        asset?.cancelLoading()
    }
    
    // MARK: - Additional Helper Functions
    
    private func set(media: AKPlayable) {
        /*
         Create an asset for inspection of a resource referenced by a given URL.
         Load the values for the asset key "playable".
         */
        let asset: AVURLAsset = AVURLAsset(url: media.url, options: media.options)
        set(asset: asset)
    }
    
    private func set(asset: AVURLAsset) {
        /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
        asset.loadValuesAsynchronously(forKeys: configuration.itemLoadedAssetKeys) { [weak self] in
            guard let self = self else { return }
            /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
            DispatchQueue.main.async {
                self.loaded(asset: asset, with: self.configuration.itemLoadedAssetKeys)
            }
        }
    }
    
    /*
     Invoked at the completion of the loading of the values for all keys on the asset that we require.
     Checks whether loading was successfull and whether the asset is playable.
     If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
     */
    public func loaded(asset: AVURLAsset, with keys: [String]) {
        /* Make sure that the value of each key has loaded successfully. */
        for key in keys {
            var error: NSError? = nil
            let status: AVKeyValueStatus = asset.statusOfValue(forKey: key, error: &error)
            /* If you are also implementing -[AVAsset cancelLoading], add your code here to bail out properly in the case of cancellation. */
            switch status {
            case .loaded:
                // Sucessfully loaded. Continue processing.
                continue
            case .failed:
                return assetFailedToPrepareForPlayback(with: .failedLoadKey(key: key, error: error!))
            case .unknown:
                assertionFailure()
            case .loading:
                assertionFailure("Calling the getter for any key should be avoided befor the -loadValuesAsynchronouslyForKeys:completionHandler:")
            case .cancelled:
                return assetFailedToPrepareForPlayback(with: .loadingCancelled)
            @unknown default:
                assertionFailure()
            }
        }
        
        /* Use the AVAsset playable property to detect whether the asset can be played. */
        guard asset.isPlayable || !asset.hasProtectedContent else {
            return assetFailedToPrepareForPlayback(with: .contentsUnabailable)
        }
        
        /* At this point we're ready to set up for playback of the asset. */
        createPlayerItem(with: asset)
    }
    
    private func createPlayerItem(with asset: AVURLAsset) {
        
        /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
        let assetKeys = configuration.itemLoadedAssetKeys
        
        // Create a new AVPlayerItem with the asset and an
        // array of asset keys to be automatically loaded
        let playerItem = AVPlayerItem(asset: asset,
                                      automaticallyLoadedAssetKeys: assetKeys)
        onCompletedCreatingPlayerItem?(.success(playerItem))
    }
    
    // MARK: - Error Handling - Preparing Assets for Playback Failed
    
    /* --------------------------------------------------------------
     **  Called when an asset fails to prepare for playback for any of
     **  the following reasons:
     **
     **  1) values of asset keys did not load successfully,
     **  2) the asset keys did load successfully, but the asset is not
     **     playable
     **  3) the item did not become ready to play.
     ** ----------------------------------------------------------- */
    private func assetFailedToPrepareForPlayback(with error: AKPlayerError) {
        AKPlayerLogger.shared.log(message: error.localizedDescription, domain: .error)
        onCompletedCreatingPlayerItem?(.failure(error))
    }
}
