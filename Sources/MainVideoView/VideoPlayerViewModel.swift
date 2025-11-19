//
//  VideoPlayerViewModel.swift
//  videoViewdemo
//
//  Created by Ishpreet Singh on 30/09/25.
//

import Foundation
import SwiftUI
import AVKit
import Combine

class VideoPlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var showControls: Bool = true
    @Published var ismute:Bool = false
    @Published var isfullScreen:Bool = false
    @Published var isBuffering: Bool = false
    @Published var isfilled:Bool = false
    @Published var availableQualities: [String] = []
    @Published  var ispause:Bool? = nil
    @Published var availableLanguages: [String] = []
    @Published var availableSubtitles: [String] = []
    @Published var currentLanguage: String?
    @Published var currentSpeed: String?
       @Published var currentSubtitle: String?
       @Published var currentQuality: String?
     var delegate : VideoViewDelegate?
    
    let player: AVPlayer
    private var timeObserver: Any?
    @Published var statusObserver: NSKeyValueObservation?
    @Published var timeControlObserver: NSKeyValueObservation?
    
    @Published var volume: Float = 1.0 { // default full volume
            didSet {
                player.volume = volume
                ismute = volume == 0
            }
        }
    @Published var isScrubbing = false
    init(url: URL, autoplay: Bool = true, delegate:VideoViewDelegate? = nil) {
        
        
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        
        
        item.preferredPeakBitRate = 50_000
        
        
        self.player = AVPlayer(playerItem: item)
        
        player.automaticallyWaitsToMinimizeStalling = false
        self.delegate = delegate
        Task {
                self.loadQualities(from: url)
            await loadMediaInfo(from: url)
            }
        
        
        if autoplay {
            player.play()
            isPlaying = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            item.preferredPeakBitRate = 0
        })
        
        observePlayer()
        addTimeObserver()
        observeEndOfVideo()
    }
    
    
    func loadMediaInfo(from url: URL) async {
            let (audioLanguages, subtitleExists) = await getMediaInfo(from: url)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // Audio: list of languages
                self.availableLanguages = audioLanguages
                self.currentLanguage = audioLanguages.first ?? "Unknown"

                // Subtitles: first item "None" then available subtitles
                self.availableSubtitles = ["None"]
                if subtitleExists {
                    // Replace with actual subtitle display names
                    if let asset = self.player.currentItem?.asset as? AVURLAsset,
                       let subtitleGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                        let subtitleOptions = subtitleGroup.options.map { $0.displayName }
                        self.availableSubtitles.append(contentsOf: subtitleOptions)
                        
                            player.currentItem?.select(nil, in: subtitleGroup)
                        
                    }
                }
                self.currentSubtitle = self.availableSubtitles.first
            }
        }
    func getMediaInfo(from url: URL) async -> ([String], Bool) {
            let asset = AVURLAsset(url: url)
            do {
                // Audio tracks
                let audioGroup = try await asset.loadMediaSelectionGroup(for: .audible)
                let audioLanguages = audioGroup?.options.compactMap { option in
                    option.locale?.language.languageCode?.identifier ?? option.displayName
                } ?? []

                // Subtitles
                let subtitleGroup = try await asset.loadMediaSelectionGroup(for: .legible)
                let hasSubtitles = (subtitleGroup?.options.isEmpty == false)

                return (audioLanguages, hasSubtitles)

            } catch {
                print("Failed to load media info:", error)
                return ([], false)
            }
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
    private func addTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self else { return }
            if !self.isScrubbing {
                       self.progress = time.seconds
                   }
            if let item = self.player.currentItem {
                self.duration = item.asset.duration.seconds
            }
        }
    }
    func updateScrub(to time: Double) {
           progress = time
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
    
    
    deinit {
        
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        timeControlObserver?.invalidate()
        statusObserver?.invalidate()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
    }
    
    // MARK: - Player Controls
    func togglePlayPause() {
        if isPlaying {
            player.pause()
            delegate?.videoDidPause()
        } else {
            player.play()
            delegate?.videoDidPlay()
        }
        isPlaying.toggle()
    }
    private var bitrateResetWorkItem: DispatchWorkItem?
    
    
    func rewind10s() {
        let current = player.currentTime().seconds
        let newTime = max(current - 10, 0)
        let shouldResume = player.timeControlStatus == .playing
        updateProgressImmediately(to: newTime)
        smoothSeek(to: newTime) {
            if shouldResume { self.player.play() }
        }
    }

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

    func seek(to time: Double) {
        isBuffering = true                 // << set immediately
        updateProgressImmediately(to: time)
        smoothSeek(to: time) { [weak self] in
            self?.isScrubbing = false
            self?.isBuffering = false      // << reset after seek completes
        }
    }

    // MARK: - Core Smooth Seek Logic
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
    private func updateProgressImmediately(to time: Double) {
        // Immediately reflect the new slider position
        
        DispatchQueue.main.async {
            self.progress = time
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
    
    func toggleMute() {
        if ismute {
            // Restore to previous volume
            volume = 1.0
        } else {
            // Mute (set to 0)
            volume = 0.0
        }
    }
    
    
    
    
    func  toggleFullscreen(){
        if isfullScreen{
            OrientationHelper.setOrientation(.portrait)
            isfullScreen = false
        }else{
            OrientationHelper.setOrientation(.landscapeRight)
            isfullScreen = true
        }
    }
    func didTapFillScreen() {
        isfilled.toggle()
    }
    
    func loadQualities(from url: URL) {
        availableQualities = ["Auto"] // Default
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let text = String(data: data, encoding: .utf8) {
                    let regex = try! NSRegularExpression(pattern: #"RESOLUTION=(\d+x\d+)"#)
                    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    
                    let resolutions = matches.compactMap {
                        Range($0.range(at: 1), in: text).map { String(text[$0]) }
                    }
                    
                    let uniqueResolutions = Array(Set(resolutions)).sorted { res1, res2 in
                        // sort by height
                        let height1 = Int(res1.split(separator: "x")[1]) ?? 0
                        let height2 = Int(res2.split(separator: "x")[1]) ?? 0
                        return height1 < height2
                    }

                    DispatchQueue.main.async {
                        self.availableQualities.append(contentsOf: uniqueResolutions)
                        print("Raw resolutions:", self.availableQualities)
                    }
                }
            } catch {
                print("Failed to fetch qualities:", error.localizedDescription)
            }
        }
    }

    // Helper to get UI-friendly name
    func displayName(for quality: String) -> String {
        if quality == "Auto" { return "Auto" }
        if let height = quality.split(separator: "x").last {
            return "\(height)p"
        }
        return quality
    }
    
    func setBitRate(_ definition: String) {
        currentQuality = definition

        var maxBitRate: Double = 0

        if definition == "Auto" {
            maxBitRate = 0
        } else if definition.contains("x") {
            // Dynamic resolution like "1921x818"
            let parts = definition.split(separator: "x")
            if let width = Double(parts[0]), let height = Double(parts[1]) {
                let pixels = width * height

                maxBitRate = pixels * 5000
            }
        } else {
            // Fallback for standard p-values
            switch definition {
            case "240p":   maxBitRate = 700_000
            case "360p":   maxBitRate = 1_500_000
            case "480p":   maxBitRate = 2_000_000
            case "720p":   maxBitRate = 4_000_000
            case "1080p":  maxBitRate = 6_000_000
            case "2k":     maxBitRate = 16_000_000
            case "4k":     maxBitRate = 45_000_000
            default:       maxBitRate = 0
            }
        }

        print("🎬 Setting bitrate for \(definition) -> \(maxBitRate)")
        player.currentItem?.preferredPeakBitRate = maxBitRate
        player.currentItem?.preferredForwardBufferDuration = 1
        player.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = false
    }

    
    func setPlaybackSpeed(_ speed: String) {
            currentSpeed = speed
            if let rate = Float(speed.replacingOccurrences(of: "x", with: "")) {
                player.rate = rate
            }
        }

        func setLanguage(_ language: String) {
            currentLanguage = language
            if let group = player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
                if let option = group.options.first(where: { $0.displayName == language }) {
                    player.currentItem?.select(option, in: group)
                }
            }
        }

        func setSubtitle(_ subtitle: String) {
            currentSubtitle = subtitle
            if subtitle == "None" {
                // Deselect all subtitles
                if let group = player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                    player.currentItem?.select(nil, in: group)
                }
            } else if let group = player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                if let option = group.options.first(where: { $0.displayName == subtitle }) {
                    player.currentItem?.select(option, in: group)
                }
            }
        }

}
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

struct VideoConfig {
    let url: URL
    var autoplay: Bool = true
    var showControlsOnStart: Bool = true
}


class VideoPiPDelegate: NSObject, AVPlayerViewControllerDelegate {
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP will start")
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP started")
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP will stop")
    }
    
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        print("PiP stopped")
    }
}
