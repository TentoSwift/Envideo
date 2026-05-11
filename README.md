# Envideo

## 概要

Apple Vision Pro 向けのイマーシブ動画プレイヤー。ローカルの動画ファイルや YouTube を、Blender で自作した映画館シーンの中で視聴できる visionOS アプリ。座席位置（高さ・列）を選んで、自分にとって心地よい距離感で映像を楽しめることを狙いとしている。

## 特徴

- **イマーシブシネマ** — Blender 製のオリジナル映画館シーンを RealityKit で読み込み、フルイマーシブ空間で再生
- **座席のカスタマイズ** — 高さ（上段／下段）と列（前列／中列／後列）を選択。位置に応じて床／天井の反射範囲も動的に調整
- **複数の動画ソース** — ローカル動画ファイル（セキュリティスコープ付きブックマークで永続化）と YouTube（URL 追加・アプリ内ブラウザの両対応）
- **履歴とレジューム** — サムネイル付きグリッドで履歴を一覧表示。再生位置を保存し、続きから再生可能
- **Now Playing 連携** — `MPRemoteCommandCenter` / `MPNowPlayingInfoCenter` で外部リモートコマンドに対応
- **アプリ内課金** — 無料版は履歴上限あり、StoreKit によるペイウォールでアンロック
- **多言語対応** — `Localizable.xcstrings` による文字列管理

## 技術スタック

- **言語** — Swift
- **UI** — SwiftUI（`WindowGroup` + `ImmersiveSpace`）
- **3D / イマーシブ** — RealityKit, Reality Composer Pro パッケージ（`RealityKitContent`）, ShaderGraphMaterial
- **シーン制作** — Blender（`blender/*.blend` をソースとして管理）
- **動画再生** — AVFoundation / AVKit（`AVPlayer`, `AVAudioSession`）
- **メディア統合** — MediaPlayer（Now Playing / Remote Command）
- **永続化** — `@AppStorage` + セキュリティスコープ付きブックマーク, `UserDefaults`
- **課金** — StoreKit 2
- **YouTube** — WKWebView ベースのアプリ内ブラウザおよび埋め込みプレイヤー

## 動作環境

- visionOS 26.0 以降（Apple Vision Pro）
- Xcode（visionOS 26.2 SDK 推奨）
- Bundle Identifier: `com.tento.File-Environment`

## ビルド

```sh
open "File Environment.xcodeproj"
```

ターゲット `File Environment` を visionOS シミュレータまたは実機で実行。

## スクリーンショット

| | |
| :---: | :---: |
| <img width="1920" alt="Envideo screenshot 1" src="https://github.com/user-attachments/assets/48222ea0-a021-4b59-9748-b5b34d5324a9" /> | <img width="1920" alt="Envideo screenshot 2" src="https://github.com/user-attachments/assets/bc752132-f117-4a47-9a5e-642f9e64f846" /> |

## プロジェクト構成

```
Envideo/
├── File Environment/
│   ├── File_EnvironmentApp.swift   # @main / Scene 定義
│   ├── Player.swift                # AVPlayer 制御
│   ├── StoreManager.swift          # StoreKit 課金管理
│   ├── HistoryItem.swift           # 履歴データモデル
│   └── VIews/                      # ContentView, CinemaImmersiveView, SeatPickerView ほか
├── Packages/RealityKitContent/      # Reality Composer Pro パッケージ（CinemaScene を含む）
└── blender/                         # シネマシーンの .blend ソース
```
