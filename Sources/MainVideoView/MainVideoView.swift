


import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct VideoPlayerContainer: UIViewControllerRepresentable {
    
    let player: AVPlayer
        let config: VideoPlayerConfig
        
        class Coordinator: NSObject, AVPlayerViewControllerDelegate {}

        func makeCoordinator() -> Coordinator { Coordinator() }

        func makeUIViewController(context: Context) -> AVPlayerViewController {
            let vc = AVPlayerViewController()
            vc.player = player
            vc.showsPlaybackControls = false
            vc.videoGravity = config.videoGravity
            vc.allowsPictureInPicturePlayback = config.allowsPiP
            vc.delegate = context.coordinator
            return vc
        }

        func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

}


public struct VideoViewPlayer: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
        let config: VideoPlayerConfig
        
        public init(viewModel: VideoPlayerViewModel, config: VideoPlayerConfig = .init()) {
            self.viewModel = viewModel
            self.config = config
        }
        
    public var body: some View {
           ZStack {
               VideoPlayerContainer(player: viewModel.player, config: config)

               if config.showCenterButton {
                   Button {
                       viewModel.playPause()
                   } label: {
                       if viewModel.isPlaying {
                           config.pauseButtonView ?? AnyView(defaultPauseButton)
                       } else {
                           config.playButtonView ?? AnyView(defaultPlayButton)
                       }
                   }
               }
           }
       }
    private var defaultPlayButton: some View {
           Image(systemName: "play.circle.fill")
               .resizable()
               .frame(width: 60, height: 60)
               .foregroundColor(.white)
       }

       private var defaultPauseButton: some View {
           Image(systemName: "pause.circle.fill")
               .resizable()
               .frame(width: 60, height: 60)
               .foregroundColor(.white)
       }
}



