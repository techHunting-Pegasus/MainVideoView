

import AVFoundation
import Combine
import UIKit
import AVKit

public class VideoPlayerViewModel: ObservableObject {
    let player: AVPlayer
    @Published var isPlaying: Bool = false
    @Published var isfilled:Bool = false
    @Published var isfullScreen:Bool = false
    @Published var ismute:Bool = false
    @Published var volume: Float = 1.0 { // default full volume
            didSet {
                player.volume = volume
                ismute = volume == 0
            }
        }
    @Published var isBuffering: Bool = false
    @Published var showControls: Bool = true
    @Published var progress: Double = 0
    private var bitrateResetWorkItem: DispatchWorkItem?
    var delegate : VideoViewDelegate?
    @Published var duration: Double = 0
    @Published var isScrubbing = false
    
    
    public  init(url: URL,autoplay: Bool = true,delegate:VideoViewDelegate? = nil) {
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        
        
        item.preferredPeakBitRate = 50_000
        
        
        self.player = AVPlayer(playerItem: item)
        
        player.automaticallyWaitsToMinimizeStalling = false
        self.delegate = delegate
       
        
        
        if autoplay {
            player.play()
            isPlaying = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            item.preferredPeakBitRate = 0
        })
        
    }
    
    public  func togglePlayPause() {
        if isPlaying {
            player.pause()
            delegate?.videoDidPause()
        } else {
            player.play()
            delegate?.videoDidPlay()
        }
        isPlaying.toggle()
    }
    
   
    
    public func seek(seconds: Double) {
           let current = player.currentTime().seconds
           let target = max(0, current + seconds)
           player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
       }
    @MainActor
    func rewind10s() {
        let current = player.currentTime().seconds
        let newTime = max(current - 10, 0)
        let shouldResume = player.timeControlStatus == .playing
        updateProgressImmediately(to: newTime)
        smoothSeek(to: newTime) {
            if shouldResume { self.player.play() }
        }
    }
    @MainActor
    func forward10s() {
        guard let duration = player.currentItem?.duration.seconds else { return }
        let current = player.currentTime().seconds
        let newTime = min(current + 10, duration)
        let shouldResume = player.timeControlStatus == .playing
        updateProgressImmediately(to: newTime)
        smoothSeek(to: newTime) {
            if shouldResume { self.player.play() }
        }
    }
    @MainActor
    private func updateProgressImmediately(to time: Double) {
        // Immediately reflect the new slider position
        
        DispatchQueue.main.async {
            self.progress = time
        }
    }
    func toggleMute() {
        if ismute {
            // Restore to previous volume
            volume = 1.0
        } else {
            // Mute (set to 0)
            volume = 0.0
        }
    }
    
    private func smoothSeek(to seconds: Double, completion: (() -> Void)? = nil) {
        let wasPlaying = player.timeControlStatus == .playing
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        let tolerance = CMTime(seconds: 0.05, preferredTimescale: 600)

        // Temporarily lower bitrate
        player.currentItem?.preferredPeakBitRate = 50_000

        player.seek(to: target, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            guard let self = self else { return }


            self.scheduleBitrateReset()
            completion?()
        }
    }
    private func scheduleBitrateReset() {
        
        bitrateResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.player.currentItem?.preferredPeakBitRate = 0
        }
        bitrateResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: workItem)
    }
    
   @MainActor func  toggleFullscreen(){
        if isfullScreen{
            OrientationHelper.setOrientation(.portrait)
            isfullScreen = false
        }else{
            OrientationHelper.setOrientation(.landscapeRight)
            isfullScreen = true
        }
    }
    
    @MainActor
    func seek(to time: Double) {
        isBuffering = true                 // << set immediately
        updateProgressImmediately(to: time)
        smoothSeek(to: time) { [weak self] in
            self?.isScrubbing = false
            self?.isBuffering = false      // << reset after seek completes
        }
    }
    func formattedTime(from seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    func didTapFillScreen() {
        isfilled.toggle()
    }
    private var timeObserver: Any?
    @Published var statusObserver: NSKeyValueObservation?
    @Published var timeControlObserver: NSKeyValueObservation?
    func updatePlayer(url: URL) {
        // Remove old observers
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        timeControlObserver?.invalidate()
        statusObserver?.invalidate()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
        // Create new AVPlayerItem
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        item.preferredPeakBitRate = 50_000
        
        player.replaceCurrentItem(with: item)
        
        // Reattach observers
        observePlayer()
        observeEndOfVideo()
        addTimeObserver()
        
        player.play()
        isPlaying = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            item.preferredPeakBitRate = 0
        })
    }
    private func  observePlayer() {
        // Observe playback status
        timeControlObserver = player.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                
                
                self.isPlaying = player.timeControlStatus == .playing
                self.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
   
            }
        }
        
        // Observe player item status
        statusObserver = player.currentItem?.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if item.status == .failed {
                    print("Player item failed: \(String(describing: item.error))")
                } else if item.status == .readyToPlay {
                    self.duration = item.duration.seconds
                }
            }
        }
    }
    
//    private func addTimeObserver() {
//        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
//            guard let self = self else { return }
//            if !self.isScrubbing {
//                       self.progress = time.seconds
//                   }
//            if let item = self.player.currentItem {
//                self.duration = item.asset.duration.seconds
//            }
//        }
//    }
    private func addTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }

            // Progress update is safe
            if !self.isScrubbing {
                self.progress = time.seconds
            }

            // Duration update MUST be done on main actor
            Task { @MainActor in
                if let item = self.player.currentItem {
                    self.duration = item.asset.duration.seconds
                }
            }
        }
    }
    
    private func observeEndOfVideo() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    @objc private func playerDidFinishPlaying() {
        delegate?.videoDidFinish()
    }

}
@MainActor
struct OrientationHelper {
    static func setOrientation(_ orientation: UIInterfaceOrientationMask) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        // Tell the system to rotate
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { error in
            if error != nil {
                print("Orientation update error: \(error.localizedDescription)")
            }
        }
    }
}

public class VideoPiPDelegate: NSObject, AVPlayerViewControllerDelegate {
    public   func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP will start")
    }
    
    public  func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP started")
    }
    
    public func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP will stop")
    }
    
    public  func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP stopped")
    }
}
