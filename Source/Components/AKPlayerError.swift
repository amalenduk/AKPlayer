//
//  AKPlayerError.swift
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

import Foundation

public enum AKPlayerError: Error {
    case failedLoadKey(key: String, error: Error)
    case loadingCancelled
    case contentsUnabailable
    case loadingFailed
}

extension AKPlayerError: LocalizedError {
    
    public var localizedDescription: String {
        switch self {
        case .failedLoadKey(let key, let error):
            return NSLocalizedString("The media failed to load the key \"\(key)\" because of error:\n \(error.localizedDescription)", comment: "Item cannot be played")
        case .loadingCancelled:
            return NSLocalizedString("The media loading is cancelled", comment: "Item cannot be played")
        case .contentsUnabailable:
            return NSLocalizedString("Item cannot be played, asset.isPlayable is false of asset.hasProtectedContent is true", comment: "Item cannot be played")
        case .loadingFailed:
            return NSLocalizedString("The media loading is failed", comment: "Item cannot be played")
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .failedLoadKey(let key, let error):
            return NSLocalizedString("You can't use this AVAsset because the media failed to load the key \"\(key)\" because of error:\n \(error.localizedDescription)", comment: "Item cannot be played")
        case .loadingCancelled:
            return NSLocalizedString("The media loading is cancelled", comment: "Item cannot be played")
        case .contentsUnabailable:
            return NSLocalizedString("Item cannot be played, asset.isPlayable is false of asset.hasProtectedContent is true", comment: "Item cannot be played")
        case .loadingFailed:
            return NSLocalizedString("The media loading is failed", comment: "Item cannot be played")
        }
    }
}
