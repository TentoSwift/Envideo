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

#if canImport(VLCKit)
import SwiftUI
import VLCKit
import UniformTypeIdentifiers

/// VLCMediaPlayer を UIView にレンダリングする最小ラッパー。
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

/// VLC で任意のファイルを開いて再生するだけのテスト画面。
/// MKV / AVI / WMV / FLV / WebM など AVFoundation 非対応形式の検証用。
struct VLCTestView: View {
    @State private var pickedURL: URL?
    @State private var picking = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = pickedURL {
                VLCVideoView(url: url)
                    .ignoresSafeArea()
                    .overlay(alignment: .topTrailing) {
                        Button("別のファイル") { pickedURL = nil; picking = true }
                            .padding()
                    }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                    Text("VLC で再生するファイルを選択")
                        .font(.title3)
                    Button("ファイルを選択") { picking = true }
                        .buttonStyle(.borderedProminent)
                    Text("MKV / AVI / WMV / FLV / WebM などを試せます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 480)
        .fileImporter(
            isPresented: $picking,
            allowedContentTypes: [.movie, .video, .audiovisualContent, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let u = urls.first {
                pickedURL = u
            }
        }
    }
}
#endif
