//
//  File.swift
//  MainVideoView
//
//  Created by Ishpreet Singh on 20/11/25.
//

import Foundation
import SwiftUI
import AVKit

public struct VideoPlayerConfig {
    public var videoGravity: AVLayerVideoGravity
    public var allowsPiP: Bool
    
    // Custom play/pause button
    public var showCenterButton: Bool
    public var playButtonView: AnyView?
    public var pauseButtonView: AnyView?

    public init(
        videoGravity: AVLayerVideoGravity = .resizeAspect,
        allowsPiP: Bool = true,
        showCenterButton: Bool = true,
        playButtonView: AnyView? = nil,
        pauseButtonView: AnyView? = nil
    ) {
        self.videoGravity = videoGravity
        self.allowsPiP = allowsPiP
        self.showCenterButton = showCenterButton
        self.playButtonView = playButtonView
        self.pauseButtonView = pauseButtonView
    }
}

