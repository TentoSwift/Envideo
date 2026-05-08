# Expenso

家族と共有できる家計簿iOSアプリ（開発中・ベータ版）

## 概要

Expensoは、家族やパートナーと家計を共有して管理できるiOSアプリです。
日々の支出をシンプルな操作で記録し、iCloud経由で家族と同期することで、
家計を「個人のもの」ではなく「家族で一緒に管理するもの」として扱えます。

## デモ

<img width="1206" height="2622" alt="simulator_screenshot_590A8A24-D093-4698-96C1-7F14BF9839AF" src="https://github.com/user-attachments/assets/ce434b95-68ac-4ce8-9c10-110c23edf972" />
<img width="1206" height="2622" alt="simulator_screenshot_B89E4C2F-ADAA-475E-86EB-08CD37692160" src="https://github.com/user-attachments/assets/2b6bbbef-b5c8-4d4e-ae65-acd1fbb7cb55" />

## 技術スタック

- Swift 5.x
- SwiftUI
- Core Data + CloudKit（iCloud同期）
- Combine / Swift Concurrency

## 主な機能

- 支出・収入の記録
- カテゴリ別の集計
- iCloudを通じた家族間でのデータ共有
- 月次・年次のグラフ表示

## 設計上の工夫

### データ永続化方式の選定

Core Data、SwiftData、Realmを比較検討し、最終的にCore Dataを選択しました。
理由は、CloudKitとの統合（NSPersistentCloudKitContainer）を利用して
iCloud共有機能を実装するためです。SwiftDataもCloudKit統合をサポートしますが、
共有機能（CKShare）の扱いに関しては成熟度の点でCore Dataを採用しました。

### ユーザー視点での改善

実際に自分で日々使う中で感じた「入力に手間がかかる」という課題を踏まえ、
入力UIを繰り返し改善してきました。

## 現在の状況

ベータ版として動作しており、App Store公開に向けて開発を継続中です。

## 開発について

実装にあたっては生成AIエージェント（Claude Code）を活用しつつ、
設計判断や技術選定は自分で行いました。
