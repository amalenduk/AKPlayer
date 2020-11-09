//
//  AKNowPlayableCommand.swift
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
import MediaPlayer

public enum AKNowPlayableCommand: CaseIterable {
    
    case pause, play, stop, togglePausePlay
    case nextTrack, previousTrack, changeRepeatMode, changeShuffleMode
    case changePlaybackRate, seekBackward, seekForward, skipBackward, skipForward, changePlaybackPosition
    case rating, like, dislike
    case bookmark
    case enableLanguageOption, disableLanguageOption
    
    // The underlying `MPRemoteCommandCenter` command for this `NowPlayable` command.
    
    var remoteCommand: MPRemoteCommand {
        
        let remoteCommandCenter = MPRemoteCommandCenter.shared()
        
        switch self {
        case .pause:
            return remoteCommandCenter.pauseCommand
        case .play:
            return remoteCommandCenter.playCommand
        case .stop:
            return remoteCommandCenter.stopCommand
        case .togglePausePlay:
            return remoteCommandCenter.togglePlayPauseCommand
        case .nextTrack:
            return remoteCommandCenter.nextTrackCommand
        case .previousTrack:
            return remoteCommandCenter.previousTrackCommand
        case .changeRepeatMode:
            return remoteCommandCenter.changeRepeatModeCommand
        case .changeShuffleMode:
            return remoteCommandCenter.changeShuffleModeCommand
        case .changePlaybackRate:
            return remoteCommandCenter.changePlaybackRateCommand
        case .seekBackward:
            return remoteCommandCenter.seekBackwardCommand
        case .seekForward:
            return remoteCommandCenter.seekForwardCommand
        case .skipBackward:
            return remoteCommandCenter.skipBackwardCommand
        case .skipForward:
            return remoteCommandCenter.skipForwardCommand
        case .changePlaybackPosition:
            return remoteCommandCenter.changePlaybackPositionCommand
        case .rating:
            return remoteCommandCenter.ratingCommand
        case .like:
            return remoteCommandCenter.likeCommand
        case .dislike:
            return remoteCommandCenter.dislikeCommand
        case .bookmark:
            return remoteCommandCenter.bookmarkCommand
        case .enableLanguageOption:
            return remoteCommandCenter.enableLanguageOptionCommand
        case .disableLanguageOption:
            return remoteCommandCenter.disableLanguageOptionCommand
        }
    }
    
    // Remove all handlers associated with this command.
    public func removeHandler() {
        remoteCommand.removeTarget(nil)
    }
    
    // Install a handler for this command.
    public func addHandler(_ handler: @escaping (AKNowPlayableCommand, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
        switch self {
        case .changePlaybackRate:
            MPRemoteCommandCenter.shared().changePlaybackRateCommand.supportedPlaybackRates = AKPlaybackRate.allCases.map({NSNumber(value: $0.rate)})
        case .skipBackward:
            MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [15.0]
        case .skipForward:
            MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [15.0]
        default:
            break
        }
        remoteCommand.addTarget { handler(self, $0) }
    }
    
    // Disable this command.
    public func setDisabled(_ isDisabled: Bool) {
        remoteCommand.isEnabled = !isDisabled
    }
    
    public static var playbackCommands: [AKNowPlayableCommand] {
        return [.pause, .play, .stop, .togglePausePlay]
    }
    
    public static var navigatingBetweenTracksCommands: [AKNowPlayableCommand] {
        return [.nextTrack, .previousTrack, .changeRepeatMode, .changeShuffleMode]
    }
    
    public static var navigatingTrackContentsCommands: [AKNowPlayableCommand] {
        return [.changePlaybackRate, .seekBackward, .seekForward, .skipBackward, .skipForward, .changePlaybackPosition]
    }
    
    public static var ratingMediaItemsCommands: [AKNowPlayableCommand] {
        return [.rating, .like, .dislike]
    }
    
    public static var bookmarkingMediaItemsCommands: [AKNowPlayableCommand] {
        return [.bookmark]
    }
    
    public static var enablingLanguageOptionsCommands: [AKNowPlayableCommand] {
        return [.enableLanguageOption, .disableLanguageOption]
    }
    
}

