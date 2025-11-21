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
    public var url : URL
    public var videoGravity: AVLayerVideoGravity?
    public var allowsPiP: Bool?
    public var autoplay: Bool?
    
    // Custom play/pause button
    public var showCenterButton: Bool?
    public var playButtonView: AnyView?
    public var pauseButtonView: AnyView?

    public init(
        url: URL,
        videoGravity: AVLayerVideoGravity = .resizeAspect,
        allowsPiP: Bool = true,
        autoplay: Bool = true,
        showCenterButton: Bool = true,
        playButtonView: AnyView? = nil,
        pauseButtonView: AnyView? = nil,
        
    ) {
        self.url = url
        self.videoGravity = videoGravity
        self.allowsPiP = allowsPiP
        self.autoplay = autoplay
        self.showCenterButton = showCenterButton
        self.playButtonView = playButtonView
        self.pauseButtonView = pauseButtonView
    }
}

