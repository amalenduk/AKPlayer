//
//  AKMediaItem.swift
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

import AVFoundation.AVPlayerItem

public class AKMediaItem: AKMediaItemPlayable {
    
    // MARK: - Properties
    
    public var item: AVPlayerItem
    
    public var url: URL
    
    public var type: AKMediaType
    
    public var options: [String : Any]?
    
    public var staticMetadata: AKPlayableStaticMetadata?
    
    // MARK: - Init
    
    public init?(item: AVPlayerItem,
                 type: AKMediaType,
                 options: [String : Any]? = nil,
                 staticMetadata: AKPlayableStaticMetadata? = nil) {
        self.item = item
        self.type = type
        self.options = options
        self.staticMetadata = staticMetadata
        
        guard let url = (item.asset as? AVURLAsset)?.url else { return nil }
        self.url = url
    }
}