import SwiftUI

@main
struct MyPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1160, minHeight: 670)
                .frame(maxWidth: 1200, maxHeight: 800)
        }
        .windowResizability(.contentSize)
    }
}

enum ImmersiveIDs {
    static let customCinema = "custom-cinema"
}
