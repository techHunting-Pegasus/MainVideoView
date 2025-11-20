

import AVFoundation
import Combine

public class VideoPlayerViewModel: ObservableObject {
    let player: AVPlayer
    @Published var isPlaying: Bool = false
    
    public  init(url: URL) {
        self.player = AVPlayer(url: url)
    }
    
    public func playPause() {
            if isPlaying {
                player.pause()
            } else {
                player.play()
            }
            isPlaying.toggle()
        }
    
   
    
    public func seek(seconds: Double) {
           let current = player.currentTime().seconds
           let target = max(0, current + seconds)
           player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
       }
}
