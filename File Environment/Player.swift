//
//  Player.swift
//  File Environment
//
//  Created by 石野天斗 on 2026/02/24.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers
internal import Combine

final class PlayerController: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    func skip(by seconds: Double) {
        guard let player else { return }

        let newTime = currentTime + seconds
        let clamped = max(0, min(newTime, duration))

        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)

        currentTime = clamped
    }
}

struct PlayerContainerView: View {

    let url: URL
    let initialPosition: Double
    let onProgress: (Double) -> Void
    let onDuration: (Double) -> Void
    let onAspectRatio: ((CGFloat) -> Void)?
    @ObservedObject var playerController: PlayerController

    var body: some View {
        PlayerViewControllerRepresentable(
            url: url,
            initialPosition: initialPosition,
            onProgress: onProgress,
            onDuration: onDuration,
            onAspectRatio: onAspectRatio,
            playerController: playerController
        )
    }
}

// MARK: - AVPlayer bridge
struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {

    let url: URL
    let initialPosition: Double
    let onProgress: (Double) -> Void
    let onDuration: (Double) -> Void
    let onAspectRatio: ((CGFloat) -> Void)?
    let playerController: PlayerController

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onProgress: onProgress,
            onDuration: onDuration,
            onAspectRatio: onAspectRatio,
            playerController: playerController
        )
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        
        // AVPlayerViewController の標準コントロール（再生/シーク等）を表示しない
        vc.showsPlaybackControls = false

        let didStart = url.startAccessingSecurityScopedResource()

        let player = AVPlayer(url: url)
        vc.player = player

        playerController.player = player
        playerController.isPlaying = true

        context.coordinator.scopedURL = url
        context.coordinator.didStartAccess = didStart

        context.coordinator.attach(to: player)

        if initialPosition > 0 {
            player.seek(to: CMTime(seconds: initialPosition, preferredTimescale: 600))
        }

        player.play()
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator {

        private let onProgress: (Double) -> Void
        private let onDuration: (Double) -> Void
        private let onAspectRatio: ((CGFloat) -> Void)?
        private let playerController: PlayerController

        private var observer: Any?
        private var statusObserver: NSKeyValueObservation?
        private weak var attachedPlayer: AVPlayer?
        private var notificationToken: NSObjectProtocol?

        var scopedURL: URL?
        var didStartAccess: Bool = false

        init(onProgress: @escaping (Double) -> Void,
             onDuration: @escaping (Double) -> Void,
             onAspectRatio: ((CGFloat) -> Void)?,
             playerController: PlayerController) {

            self.onProgress = onProgress
            self.onDuration = onDuration
            self.onAspectRatio = onAspectRatio
            self.playerController = playerController
        }

        func attach(to player: AVPlayer) {
            attachedPlayer = player

            statusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                   guard let self else { return }
                   DispatchQueue.main.async {
                       switch player.timeControlStatus {
                       case .playing:
                           self.playerController.isPlaying = true
                       case .paused:
                           self.playerController.isPlaying = false
                       default:
                           break
                       }
                   }
               }

               observer = player.addPeriodicTimeObserver(
                   forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                   queue: .main
               ) { [weak self] time in
                   guard let self else { return }
                   let seconds = CMTimeGetSeconds(time)
                   if seconds.isFinite {
                       self.onProgress(seconds)
                       self.playerController.currentTime = seconds
                   }
               }

            if let item = player.currentItem {

                let duration = CMTimeGetSeconds(item.asset.duration)
                if duration.isFinite, duration > 0 {
                    onDuration(duration)
                    playerController.duration = duration
                }

                notificationToken = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { [weak self] _ in
                    guard let self,
                          let player = self.playerController.player else { return }

                    player.seek(to: .zero)
                    self.playerController.currentTime = 0
                    self.playerController.isPlaying = false

                    NotificationCenter.default.post(name: .updateThumbnail, object: nil)
                }

                let size = item.presentationSize
                if size.width > 0 {
                    onAspectRatio?(size.height / size.width)
                }
            }
        }

        deinit {
            if let attachedPlayer, let obs = observer {
                attachedPlayer.removeTimeObserver(obs)
            }
            if let notificationToken {
                NotificationCenter.default.removeObserver(notificationToken)
            }
            statusObserver?.invalidate()
            if didStartAccess, let scopedURL {
                scopedURL.stopAccessingSecurityScopedResource()
            }
        }
    }
}
