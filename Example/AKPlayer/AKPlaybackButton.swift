//
//  AKPlaybackButton.swift
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

@IBDesignable class AKPlaybackButton: UIButton {

    // MARK: - Poperties

    static let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30)

    enum AKPlaybackState: UInt  {
        case playing    = 0x00010000
        case paused     = 0x00020000
        case failed     = 0x00030000
        case stopped    = 0x00040000
    }

    private(set) var playbackState: AKPlaybackState = .paused

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        commonInit()
    }

    override var state: UIControl.State {
        return UIControl.State(rawValue: super.state.rawValue
            | UIButton.State(rawValue: playbackState.rawValue).rawValue)
    }

    open func changePlayback(_ state: AKPlaybackState) {
        self.playbackState = state
        layoutSubviews()
    }

    override var isHighlighted: Bool {
        didSet {
            super.isHighlighted = false
        }
    }

    // MARK: - Additional Helpers

    func commonInit() {
        adjustsImageWhenHighlighted = false
        setImage(UIImage(systemName: "pause.fill", withConfiguration: AKPlaybackButton.symbolConfiguration),
                 for: [UIButton.State.init(rawValue: AKPlaybackState.playing.rawValue)])
        setImage(UIImage(systemName: "play.fill", withConfiguration: AKPlaybackButton.symbolConfiguration),
                 for: [UIButton.State.init(rawValue: AKPlaybackState.paused.rawValue)])
        setImage(UIImage(systemName: "goforward", withConfiguration: AKPlaybackButton.symbolConfiguration),
                 for: [UIButton.State.init(rawValue: AKPlaybackState.failed.rawValue)])
        setImage(UIImage(systemName: "memories", withConfiguration: AKPlaybackButton.symbolConfiguration),
                 for: [UIButton.State.init(rawValue: AKPlaybackState.stopped.rawValue)])
        changePlayback(.paused)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.3, initialSpringVelocity: 0.3, options: .allowUserInteraction, animations: {
            self.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }, completion: nil)
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.3, initialSpringVelocity: 0.3, options: .allowUserInteraction, animations: {
            self.transform = .identity
        }, completion: nil)
        super.touchesEnded(touches, with: event)
    }
}
