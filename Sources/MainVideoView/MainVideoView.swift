


import SwiftUI
import AVKit
import AVFoundation
import UIKit



public struct VideoPlayerContainer: UIViewControllerRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    var allowsPiP: Bool = true
    var delegate: AVPlayerViewControllerDelegate?
    
    public  func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = videoGravity
        controller.allowsPictureInPicturePlayback = allowsPiP
        controller.delegate = delegate
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        return controller
    }
    
    public  func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.videoGravity = videoGravity
        uiViewController.allowsPictureInPicturePlayback = allowsPiP
    }
}



public struct VideoViewPlayer: View {
    @StateObject private var vm: VideoPlayerViewModel
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
        
    public init( config: VideoPlayerConfig , delegate: VideoViewDelegate? = nil) {
            self.delegate = delegate
        self._vm = StateObject(wrappedValue: VideoPlayerViewModel(url: config.url, autoplay: config.autoplay ?? true))
            self.config = config
            let thumbImage = UIImage(systemName: "circle.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20))
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            UISlider.appearance().setThumbImage(thumbImage, for: .normal)
        }
    public var body: some View {
        GeometryReader { geo in
            
            ZStack {
                
                VideoPlayerContainer(player: vm.player,videoGravity: vm.isfilled ? .resizeAspectFill : .resizeAspect, delegate: VideoPiPDelegate())
                    .onTapGesture {
                        print("sfedferf")
                        withAnimation { vm.showControls.toggle() }
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
                        LandscapdeControls(vm: vm, delegate: delegate, screenwidth: screenWidth, screenheight: screenHeight, setting: $showSettings)
                            .frame(width: geo.size.width)
                    }
                }
//                if showSettings {
//                    VideoSettingsOverlay(vm: vm, isVisible: $showSettings)
//                        .transition(.move(edge: .trailing))
//                }
                
            }
            .frame(
                width:  geo.size.width,
                height: vm.isfullScreen ? screenWidth : geo.size.width * 9 / 16
            )
            .background(Color.black)
            .onTapGesture {
                withAnimation {
                    vm.showControls.toggle()
                }
                
            }
            
        }
        .onChange(of: config.url) { oldValue, newURL in
            vm.updatePlayer(url: newURL)
        }
        .onChange(of: showSettings) { oldValue, newValue in
            if newValue {
                if (vm.isPlaying)
                {
                    vm.togglePlayPause()
                    vm.showControls = false
                }else{
                    vm.showControls = false
                }
            }else{
                
                vm.showControls = true
            }
        }
        .onChange(of: vm.showControls) { oldValue, newValue in
            if newValue == false && vm.isPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                    vm.showControls.toggle()
                })
            }
        }

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
struct LandscapdeControls: View {
    @ObservedObject var vm: VideoPlayerViewModel
    var delegate: VideoViewDelegate?
    var screenwidth: CGFloat
    var screenheight: CGFloat
    @Binding var setting: Bool
    @State var sliderValue: Double = 0.0
    
    
    
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                
                // MARK: Loader when buffering
                if !vm.isBuffering {
                    
                    // MARK: Playback Controls
                    HStack(spacing: 40) {
                        Button { vm.rewind10s() } label: {
                            Image(systemName: "gobackward.10")
                                .font(.title)
                                .tint(.white)
                        }
                        
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
                            Button { vm.togglePlayPause() } label: {
                                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .tint(.white)
                            }
                        }
                       
                        Button { vm.forward10s() } label: {
                            Image(systemName: "goforward.10")
                                .font(.title)
                                .tint(.white)
                        }
                    }
                    .padding(.top, screenwidth / 2.5)
                }
                
                Spacer()
                
                VStack {
                    // MARK: Seek Slider
                    
                    
                    
                    
                    HStack(alignment: .center) {
                        
                        TappableSlider(value: $vm.progress, range: 0...vm.duration,onEditingChanged: { editing in
                            vm.isScrubbing = editing
                            if !editing {
                                vm.seek(to: vm.progress) // Seek when drag ends
                            }
                        })
                        
                        Text("\(vm.formattedTime(from: vm.progress))/\(vm.formattedTime(from: vm.duration))")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 20)
                    
                    // MARK: Bottom Controls
                    HStack {
                        // Volume Controls
                        HStack {
                            Image(systemName: vm.ismute ? "speaker.slash.fill" : "speaker.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .onTapGesture { vm.toggleMute() }
                                .padding(.trailing, 20)
                            
                            Slider(value: Binding(
                                get: { Double(vm.volume) },
                                set: { vm.volume = Float($0) }
                            ), in: 0...1)
                            .accentColor(.red)
                            .tint(.white)
                            .frame(width: 150, height: 20)
                        }
                        
                        Spacer()
                        
                        // Action Buttons
                        HStack(spacing: 20) {
                            Image(systemName: vm.isfilled ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .onTapGesture {
                                    
                                    vm.didTapFillScreen()
                                }
                            
                            Image(systemName: "gear")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .onTapGesture {
                                    withAnimation { setting.toggle() }
                                }
                            
                            Image(systemName: "viewfinder")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .onTapGesture {
                                    if vm.isfilled{
                                        vm.didTapFillScreen()
                                    }
                                    vm.toggleFullscreen()
                                    delegate?.isfullscren(isfull: vm.isfullScreen)
                                }
                        }
                    }
                    
                }
                .padding()
            }
            
        }
        
    }
    
}

struct ContentView: View {
  
    private let url: URL
        private let config: VideoPlayerConfig

        init() {
            self.url = URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!
            self.config = VideoPlayerConfig(url: self.url)
        }
    
    var body: some View {
        ZStack{
            VStack {
                VideoViewPlayer(config: config)
            }
        }
       
    }
}

#Preview {
    ContentView()
}
struct TappableSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            Slider(value: $value, in: range, onEditingChanged: { editing in
                onEditingChanged?(editing)
            })
            .tint(.white)
            .padding(.trailing, 20)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let percent = min(max(0, Double(gesture.location.x / geometry.size.width)), 1)
                        let newValue = range.lowerBound + percent * (range.upperBound - range.lowerBound)
                        self.value = newValue
                        onEditingChanged?(true)
                    }
                    .onEnded { _ in
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: 40)
    }
}
