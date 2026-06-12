import SwiftUI
import MediaPlayer

extension ContentView {

    func setupRemoteCommands() {
        let rcc = MPRemoteCommandCenter.shared()
        let ctrl = playerController

        rcc.playCommand.isEnabled = true
        rcc.playCommand.addTarget { _ in ctrl.play(); return .success }

        rcc.pauseCommand.isEnabled = true
        rcc.pauseCommand.addTarget { _ in ctrl.pause(); return .success }

        rcc.togglePlayPauseCommand.isEnabled = true
        rcc.togglePlayPauseCommand.addTarget { _ in ctrl.toggle(); return .success }

        rcc.skipForwardCommand.isEnabled = true
        rcc.skipForwardCommand.preferredIntervals = [15]
        rcc.skipForwardCommand.addTarget { _ in ctrl.skip(by: 15); return .success }

        rcc.skipBackwardCommand.isEnabled = true
        rcc.skipBackwardCommand.preferredIntervals = [15]
        rcc.skipBackwardCommand.addTarget { _ in ctrl.skip(by: -15); return .success }
    }
}
