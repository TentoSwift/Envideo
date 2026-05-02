import SwiftUI
import AVKit

struct UpNextView: View {
    let videoHistory: [HistoryItem]
    let thumbnails: [String: Image]
    let positions: [String: Double]
    let durations: [String: Double]
    let selectedKey: String?
    let onSelect: (HistoryItem) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                ForEach(videoHistory) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        UpNextCardView(
                            item: item,
                            thumb: thumbnails[item.key],
                            saved: positions[item.key] ?? 0,
                            total: durations[item.key] ?? 0,
                            isSelected: selectedKey == item.key
                        )
                    }
                    .buttonStyle(CustomButtonStyle())
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20)
        .scrollTargetBehavior(.viewAligned)
        .scrollInputBehavior(.enabled, for: .look)
    }
}

struct UpNextCardView: View {
    let item: HistoryItem
    let thumb: Image?
    let saved: Double
    let total: Double
    let isSelected: Bool

    var body: some View {
        Group {
            if let thumb {
                thumb.resizable().scaledToFill()
            } else {
                Rectangle().fill(.gray.opacity(0.3))
            }
        }
        .frame(width: 290.4, height: 163.35)
        .clipped()
        .cornerRadius(15)
        .overlay(alignment: .bottomLeading) {
            VStack {
                HStack {
                    Text(item.displayName)
                        .lineLimit(1)
                        .fontWeight(.bold)
                        .font(.caption)
                    Spacer()
                    Text("\(Int(total / 60))分")
                        .font(.system(.caption, design: .rounded))
                }
                .foregroundStyle(.white)
                ProgressView(value: saved, total: total)
                    .tint(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 13)
            .padding(.top)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 15,
                    bottomTrailingRadius: 15,
                    topTrailingRadius: 0
                )
                .fill(.ultraThickMaterial)
                .environment(\.colorScheme, .light)
                .mask {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black.opacity(0.8), location: 0.5),
                            .init(color: .black, location: 0.6),
                            .init(color: .white, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
    }
}

struct FullScreenPlayerView: UIViewControllerRepresentable {

    let player: AVPlayer
    let videoHistory: [HistoryItem]
    let thumbnails: [String: Image]
    let positions: [String: Double]
    let durations: [String: Double]
    let selectedKey: String?
    let onSelect: (HistoryItem) -> Void

    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true

        let view = UpNextView(
            videoHistory: videoHistory,
            thumbnails: thumbnails,
            positions: positions,
            durations: durations,
            selectedKey: selectedKey,
            onSelect: onSelect
        )

        let hc = UIHostingController(rootView: view)
        hc.title = String(localized: "KEY_")
        hc.preferredContentSize = CGSize(width: 900, height: 260)

        vc.customInfoViewControllers = [hc]
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player {
            vc.player?.pause()
            vc.player = player

            let savedPosition = positions[selectedKey ?? ""] ?? 0
            let targetSeconds = (savedPosition > 0) ? savedPosition : 0.1
            let startTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)

            player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                if finished {
                    DispatchQueue.main.async { player.play() }
                }
            }
        }

        if let hc = vc.customInfoViewControllers.first as? UIHostingController<UpNextView> {
            hc.rootView = UpNextView(
                videoHistory: videoHistory,
                thumbnails: thumbnails,
                positions: positions,
                durations: durations,
                selectedKey: selectedKey,
                onSelect: onSelect
            )
        }
    }
}
