import SwiftUI
import AVFoundation

@main
struct MyPlayerApp: App {

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1160, minHeight: 670)
                .frame(maxWidth: 1200, maxHeight: 800)
                .tint(.indigo)
        }
        .windowResizability(.contentSize)

        ImmersiveSpace(id: ImmersiveIDs.cinema) {
            CinemaImmersiveView()
        }
        .immersionStyle(selection: .constant(.full), in: .full)

        ImmersiveSpace(id: ImmersiveIDs.studio) {
            StudioImmersiveView()
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}

