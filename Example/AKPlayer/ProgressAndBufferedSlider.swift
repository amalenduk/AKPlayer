//
//  ProgressAndBufferedSlider.swift
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

import Foundation
import UIKit

@IBDesignable class AKProgressAndTimeRangesSlider: UISlider {

    var timerangesProgressView: UIProgressView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    open func commonInit() {
        setupUI()
        applyDesigns()
        resetControls()
        addUIElements()
        makeViewConstraints()
    }

    open func setupUI() {
        timerangesProgressView = UIProgressView()
    }

    open func applyDesigns() {
        setThumbImage(UIImage(named: "ic.track.thumb"), for: .normal)
        minimumTrackTintColor = .red
        maximumTrackTintColor = .darkGray

        timerangesProgressView.tintColor = .white
        timerangesProgressView.progressTintColor = .white
    }

    open func resetControls() {
        minimumValue = 0
        maximumValue = 1
        value = 0
        timerangesProgressView.progress = 0.8
    }

    open func addUIElements() {
        addSubview(timerangesProgressView)
    }

    open func makeViewConstraints() {

    }
}
