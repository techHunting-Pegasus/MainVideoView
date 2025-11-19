import SwiftUI
import Combine
import AVKit

struct VideoSettingsOverlay: View {
    @ObservedObject var vm: VideoPlayerViewModel
    @Binding var isVisible: Bool
    
    @State private var selectedQuality: String = "Auto"
    @State private var selectedSpeed: String = "1x"
    @State private var selectedlanguae: String = "English"
    @State private var selectedsubtitile: String = "None"
    
     func applyfulters() {
         
         
         vm.setBitRate(selectedQuality)
         vm.setSubtitle(selectedsubtitile)
         vm.setLanguage(selectedlanguae)
         vm.setPlaybackSpeed(selectedSpeed)
         
         isVisible = false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                HStack {
                    Button(action: {
                        applyfulters()
                    }) {
                        Text("Apply").foregroundStyle(.white)
                            .font(.system(size: 17, weight: .bold, design: .default))
                    }
                    Button(action: { withAnimation { isVisible = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.5))
            
            Group {
                settingsRow(title: "Quality", options: vm.availableQualities, selected: $selectedQuality)
                settingsRow(title: "Speed", options: ["0.5x", "1x", "1.5x", "2x"], selected: $selectedSpeed)
                settingsRow(title: "Language", options:vm.availableLanguages, selected: $selectedlanguae)
                settingsRow(title: "Subtitle", options: vm.availableSubtitles, selected: $selectedsubtitile)
            }
            .onAppear {
                // Set default selections when the overlay appears
                selectedQuality = vm.currentQuality ?? "Auto"
                selectedSpeed = vm.currentSpeed ?? "1x"
                selectedlanguae = vm.currentLanguage ?? vm.availableLanguages.first ?? "Unknown"
                selectedsubtitile = vm.currentSubtitle ?? vm.availableSubtitles.first ?? "None"
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 350)
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
        .shadow(radius: 10)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding()
        
    }
    
    @ViewBuilder
    private func settingsRow<T: Hashable>(
        title: String,
        options: [T],
        selected: Binding<T>
    ) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(options, id: \.self) { option in
                        let mainOption: String = {
                            if title == "Quality", let optionString = option as? String {
                                return vm.displayName(for: optionString)
                            } else {
                                return "\(option)"
                            }
                        }()
                        Button(action: {
                            selected.wrappedValue = option
                            
                        }) {
                            
                            Text("\(mainOption)")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selected.wrappedValue == option ? Color.blue : Color.gray.opacity(0.3))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }
    
    
    // Parse qualities from M3U8 master playlist
    
}
#Preview {
    
    let sampleURL = URL(string: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8")!
    let vm = VideoPlayerViewModel(url: sampleURL, autoplay: false)
    VideoSettingsOverlay(vm: vm, isVisible: .constant(true))
        .transition(.move(edge: .trailing))
    
}
