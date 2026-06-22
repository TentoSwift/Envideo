//
//  VLCSpike.swift
//  Envideo
//
//  対応フォーマット拡張(MKV/AVI 等)の実現可能性を検証するスパイク。
//  すべて `#if canImport(VLCKit)` でガードしているため、VLCKit パッケージを
//  追加するまではこのファイルは丸ごとコンパイル対象外になり、本体ビルドに
//  影響しない。Xcode で VLCKit (https://github.com/virtualox/vlckit-spm,
//  4.0.0-alpha.19) を追加すると VLC 経路が有効化される。
//
//  方針: VLC は「変換」だけに使い、再生はネイティブ AVPlayer に任せる。
//  これにより Apple 環境のフルスクリーン・座席・履歴などが全部そのまま効く。
//

#if canImport(VLCKit)
import SwiftUI
import AVKit
import VLCKit
import UniformTypeIdentifiers

// MARK: - VLC 直接再生(参考: 環境ドッキングは効かない)

struct VLCVideoView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        let player = VLCMediaPlayer()
        player.drawable = view
        if url.startAccessingSecurityScopedResource() {
            context.coordinator.didStartAccess = true
            context.coordinator.scopedURL = url
        }
        player.media = VLCMedia(url: url)
        context.coordinator.player = player
        player.play()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var player: VLCMediaPlayer?
        var scopedURL: URL?
        var didStartAccess = false
        func stop() {
            player?.stop()
            player = nil
            if didStartAccess, let u = scopedURL { u.stopAccessingSecurityScopedResource() }
            didStartAccess = false
        }
        deinit { stop() }
    }
}

// MARK: - VLC で MP4 に変換(remux)

/// libVLC の sout を使い、入力(MKV/AVI 等)を MP4 に書き出す。
/// 中身が H.264/AAC なら再エンコードなしの remux になり高速・無劣化。
/// (非対応コーデックの場合は別途 #transcode が必要)
@Observable
final class VLCConverter: NSObject, VLCMediaPlayerDelegate {
    enum Status: Equatable {
        case idle, converting, done(URL), failed(String)
    }
    var status: Status = .idle

    private var player: VLCMediaPlayer?
    private var outputURL: URL?
    private var scopedURL: URL?
    private var didStartAccess = false
    private var hasStarted = false   // 再生が始まる前の初期 .stopped を完了と誤認しない

    func convertToMP4(_ input: URL) {
        status = .converting
        hasStarted = false

        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("converted-\(input.deletingPathExtension().lastPathComponent)")
            .appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: out)
        outputURL = out

        if input.startAccessingSecurityScopedResource() {
            didStartAccess = true
            scopedURL = input
        }

        guard let media = VLCMedia(url: input) else {
            status = .failed("メディアを開けませんでした")
            return
        }
        // remux: #transcode を挟まないので再エンコードなし(ストリームコピー)
        media.addOption(":sout=#standard{access=file,mux=mp4,dst=\(out.path)}")
        media.addOption(":sout-keep")
        media.addOption(":no-sout-rtp-sap")

        let p = VLCMediaPlayer()
        p.delegate = self
        p.media = media
        player = p
        p.play()
    }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let p = player else { return }
        switch p.state {
        case .opening, .buffering, .playing:
            hasStarted = true
        case .stopped:
            if hasStarted { finish(success: true) }
        case .error:
            finish(success: false)
        default:
            break
        }
    }

    private func finish(success: Bool) {
        player?.stop()
        player = nil
        if didStartAccess, let u = scopedURL { u.stopAccessingSecurityScopedResource() }
        didStartAccess = false

        let exists = outputURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        if success, exists, let out = outputURL {
            status = .done(out)
        } else {
            status = .failed("変換に失敗しました(コーデック非対応の可能性)")
        }
    }
}

// MARK: - テスト画面

struct VLCTestView: View {
    @State private var pickedURL: URL?      // VLC 直接再生用
    @State private var picking = false
    @State private var converter = VLCConverter()
    @State private var avPlayer: AVPlayer?

    private var sampleMKV: URL? {
        Bundle.main.url(forResource: "sample", withExtension: "mkv")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .frame(minWidth: 760, minHeight: 520)
        .fileImporter(
            isPresented: $picking,
            allowedContentTypes: [.movie, .video, .audiovisualContent, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let u = urls.first { pickedURL = u }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let player = avPlayer {
            // 変換後の MP4 をネイティブ AVPlayer で再生(=Apple 環境にも対応する形)
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .overlay(alignment: .topTrailing) {
                    Button("戻る") { avPlayer = nil; converter.status = .idle }.padding()
                }
        } else if let url = pickedURL {
            VLCVideoView(url: url)
                .ignoresSafeArea()
                .overlay(alignment: .topTrailing) {
                    Button("戻る") { pickedURL = nil }.padding()
                }
        } else {
            menu
        }
    }

    @ViewBuilder
    private var menu: some View {
        VStack(spacing: 18) {
            Image(systemName: "film.stack").font(.system(size: 52)).foregroundStyle(.secondary)
            Text("VLC フォーマット検証").font(.title3)

            // ① 変換して AVPlayer で再生(本命: ネイティブ扱いになる)
            Button {
                if let mkv = sampleMKV { avPlayer = nil; converter.convertToMP4(mkv) }
            } label: {
                Label("MKV を MP4 に変換 → AVPlayer で再生", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .disabled(converter.status == .converting)

            // ② VLC で直接再生(比較用)
            Button {
                pickedURL = sampleMKV
            } label: {
                Label("MKV を VLC で直接再生", systemImage: "play.rectangle")
            }

            Button("ファイルを選択(VLC 再生)") { picking = true }

            switch converter.status {
            case .converting:
                ProgressView("変換中…")
            case .failed(let msg):
                Text(msg).font(.caption).foregroundStyle(.red)
            case .done(let mp4):
                Color.clear.frame(height: 0)
                    .onAppear { avPlayer = AVPlayer(url: mp4) }
            case .idle:
                EmptyView()
            }
        }
        .padding(40)
    }
}
#endif
