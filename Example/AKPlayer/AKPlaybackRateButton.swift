//
//  AKPlaybackRateButton.swift
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
import AKPlayer

typealias AKPlaybackRateHandler = (AKPlaybackRate) -> Void

open class AKPlaybackRateButton : UIButton, UIContextMenuInteractionDelegate {

    // MARK: - Poperties

    private var onRateChangeHandler: AKPlaybackRateHandler?
    private var rate: AKPlaybackRate = .normal {
        didSet {
            setTitle(rate.rateTitle, for: .normal)
            self.onRateChangeHandler?(self.rate)
            layoutSubviews()
        }
    }

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)

        commonInit()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)

        commonInit()
    }

    override open var isHighlighted: Bool {
        didSet {
            super.isHighlighted = false
        }
    }

    // MARK: - Additional Helper Functions

    private func commonInit() {
        adjustsImageWhenHighlighted = false
        setTitle(rate.rateTitle, for: .normal)
        addTarget(self, action: #selector(didTapButton(_:)), for: .primaryActionTriggered)
        addInteraction(UIContextMenuInteraction(delegate: self))
    }

    @objc private func didTapButton(_ button: UIButton) {
        self.rate = rate.next
    }

    func onRateChange(_ handler: @escaping AKPlaybackRateHandler) {
        self.onRateChangeHandler = handler
    }

    func change(_ rate: AKPlaybackRate) {
        if self.rate != rate {
            self.rate = rate
        }
    }

    var playbackRate: AKPlaybackRate {
        return rate
    }

    public func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            return UIMenu(title: "", children: AKPlaybackRate.allCases.map { newRate in
                UIAction(title: newRate.title, state: self.rate == newRate ? .on : .off) { _ in
                    self.rate = newRate
                }
            })
        }
    }
}
