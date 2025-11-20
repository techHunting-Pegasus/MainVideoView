


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
            vc.videoGravity = config.videoGravity ?? .resizeAspect
            vc.allowsPictureInPicturePlayback = config.allowsPiP ?? true
            vc.delegate = context.coordinator
            return vc
        }

        func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

}


public struct VideoViewPlayer: View {
    @ObservedObject var vm: VideoPlayerViewModel
        let config: VideoPlayerConfig
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    @State private var brightness: CGFloat = UIScreen.main.brightness
    @State private var localBrightness: CGFloat = UIScreen.main.brightness
    @State private var localVolume: Float = AVAudioSession.sharedInstance().outputVolume
    @State private var activeSide: String? = nil   // "left" or "right"
    @State private var showOverlay = false
    @State var showSettings : Bool = false
    let delegate: VideoViewDelegate?
        
        public init(viewModel: VideoPlayerViewModel, config: VideoPlayerConfig = .init(), delegate: VideoViewDelegate? = nil) {
            self.delegate = delegate
            self.vm = viewModel
            self.config = config
            let thumbImage = UIImage(systemName: "circle.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20))
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            UISlider.appearance().setThumbImage(thumbImage, for: .normal)
        }
    
        
    public var body: some View {
        GeometryReader { geo in
            ZStack {
                VideoPlayerContainer(player: vm.player, config: config)
                    .onTapGesture {
                        withAnimation { /*vm.showControls.toggle() */}
                    }
                    .frame(
                        width: vm.isfilled ? screenHeight : geo.size.width,
                        height: vm.isfullScreen ? screenWidth : geo.size.width * 9 / 16
                    )
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let dragAmount = value.translation.height
                                let screenHalf = geo.size.width / 2
                                let isLeftSide = value.startLocation.x < screenHalf
                                
                                if isLeftSide {
                                    activeSide = "left"
                                    // Brightness control
                                    localBrightness = max(0.0, min(1.0, brightness - dragAmount / 300))
                                    
                                    // Update screen brightness smoothly
                                    DispatchQueue.main.async {
                                        UIScreen.main.brightness = localBrightness
                                    }
                                } else {
                                    activeSide = "right"
                                    // Volume control
                                    let newVolume = max(0.0, min(1.0, localVolume - Float(dragAmount / 300)))
                                    vm.volume = newVolume  // update your player volume
                                }
                                
                                withAnimation { showOverlay = true }
                            }
                            .onEnded { _ in
                                brightness = UIScreen.main.brightness
                                localVolume = vm.volume
                                withAnimation(.easeOut(duration: 0.5)) {
                                    showOverlay = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    activeSide = nil
                                }
                            }
                    )
                if showOverlay, activeSide == "left" {
                    VStack(alignment:.leading) {
                        Slider(
                            value: Binding(
                                get: { Double(localBrightness) },
                                set: { newValue in
                                    localBrightness = CGFloat(newValue)
                                    UIScreen.main.brightness = localBrightness
                                }
                            ),
                            in: 0...1
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100)
                        .accentColor(.yellow)
                        .tint(.yellow)
                        .padding(.leading, 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                    
                }
                
                // MARK: - Show Right (Volume) Slider
                if showOverlay, activeSide == "right" {
                    VStack {
                        Slider(
                            value: Binding(
                                get: { Double(vm.volume) },
                                set: { vm.volume = Float($0) }
                            ),
                            in: 0...1
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100)
                        .accentColor(.red)
                        .tint(.white)
                        .padding(.trailing, 10)
                        
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
                }
                if vm.isBuffering {
                        ZStack {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: vm.isBuffering)
                    }
                
                
                if  vm.showControls && !showSettings {
                    
                    if (!vm.isfullScreen){
                        PotraghtControle(vm: vm, delegate: delegate)
                    }else{
//                        LandscapdeControls(vm: vm, delegate: delegate, screenwidth: screenWidth, screenheight: screenHeight, setting: $showSettings)
//                            .frame(width: geo.size.width)
                    }
                }

                
//                    Button {
//                        vm.playPause()
//                    } label: {
//                        if vm.isPlaying {
//                            config.pauseButtonView ?? AnyView(defaultPauseButton)
//                        } else {
//                            config.playButtonView ?? AnyView(defaultPlayButton)
//                        }
//                    }
                
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

public protocol VideoViewDelegate {
    func videoDidPlay()
    func videoDidPause()
    func videoDidFinish()
    func isfullscren(isfull: Bool)
}


extension VideoViewDelegate {
    func videoDidPlay() {}
    func videoDidPause() {}
    func videoDidFinish() {}
    func isfullscren(isfull: Bool) {}
}

struct PotraghtControle : View {
    
    
    @ObservedObject var vm: VideoPlayerViewModel
    var delegate: VideoViewDelegate?
    var body: some View {
        VStack {
            Spacer()
            
            // Control Buttons
            HStack(spacing: 40) {
                Button { vm.rewind10s() } label: { Image(systemName: "gobackward.10").font(.title).tint(.white) }
                if vm.isBuffering {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.8)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: vm.isBuffering)
                }else{
                    Button { vm.togglePlayPause() } label: { Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill").font(.title).tint(.white) }
                }
              
                
                Button { vm.forward10s() } label: { Image(systemName: "goforward.10").font(.title).tint(.white) }
            }
            .padding(.top,30)
            
            
            Spacer()
            
            HStack {
                
                
                Spacer()
                
                HStack(spacing:20) {
                    Image(systemName: vm.ismute ? "speaker.slash.fill" : "speaker.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                    
                        .foregroundColor(.white)
                        .onTapGesture { vm.toggleMute() }
                    
                    
                    Image(systemName: "viewfinder")
                        .resizable()
                        .frame(width: 30,height: 30)
                        .foregroundStyle(.white)
                        .onTapGesture {
                            
                            vm.toggleFullscreen()
                            if vm.isfullScreen{
                                delegate?.isfullscren(isfull: true)
                                
                            }else{
                                delegate?.isfullscren(isfull: false)
                            }
                        }
                    
                }
            }
            .padding()
            
        }
    }
}
