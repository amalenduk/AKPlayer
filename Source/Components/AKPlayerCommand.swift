//
//  AKPlayerCommand.swift
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
import AVFoundation

public protocol AKPlayerCommand {
    func load(media: AKPlayable)
    func load(media: AKPlayable, autoPlay: Bool)
    func load(media: AKPlayable, autoPlay: Bool, at position: CMTime)
    func load(media: AKPlayable, autoPlay: Bool, at position: Double)
    func play()
    func pause()
    func stop()
    func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void)
    func seek(to time: CMTime)
    func seek(to time: Double, completionHandler: @escaping (Bool) -> Void)
    func seek(to time: Double)
    func seek(offset: Double)
    func seek(offset: Double, completionHandler: @escaping (Bool) -> Void)
    func seek(toPercentage value: Double, completionHandler: @escaping (Bool) -> Void)
    func seek(toPercentage value: Double)
    func step(byCount stepCount: Int)
}
