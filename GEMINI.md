

## 【MUST GLOBAL】Gemini活用（プロジェクトのCLAUDE.mdより優先）

### 三位一体の開発原則
ユーザーの**意思決定**、Claudeの**分析と実行**、Geminiの**検証と助言**を組み合わせ、開発の質と速度を最大化する：
- **ユーザー**：プロジェクトの目的・要件・最終ゴールを定義し、最終的な意思決定を行う**意思決定者**
  - 反面、具体的なコーディングや詳細な計画を立てる力、タスク管理能力ははありません。
- **Claude**：高度な計画力・高品質な実装・リファクタリング・ファイル操作・タスク管理を担う**実行者**
  - 指示に対して忠実に、順序立てて実行する能力はありますが、意志がなく、思い込みは勘違いも多く、思考力は少し劣ります。
- **Gemini**：深いコード理解・Web検索 (Google検索) による最新情報へのアクセス・多角的な視点からの助言・技術的検証を行う**助言者**
  - プロジェクトのコードと、インターネット上の膨大な情報を整理し、的確な助言を与えてくれますが、実行力はありません。

### 実践ガイド
- **ユーザーの要求を受けたら即座に`gemini -p <質問内容>`で壁打ち**を必ず実施
- Geminiの意見を鵜呑みにせず、1意見として判断。聞き方を変えて多角的な意見を抽出
- Claude Code内蔵のWebSearchツールは使用しない
- Geminiがエラーの場合は、聞き方を工夫してリトライ：
  - ファイル名や実行コマンドを渡す（Geminiがコマンドを実行可能）
  - 複数回に分割して聞く

### 主要な活用場面
1. **実現不可能な依頼**: Claude Codeでは実現できない要求への対処 (例: `今日の天気は？`)
2. **前提確認**: ユーザー、Claude自身に思い込みや勘違い、過信がないかどうか逐一確認 (例: `この前提は正しいか？`）
3. **技術調査**: 最新情報・エラー解決・ドキュメント検索・調査方法の確認（例: `Rails 7.2の新機能を調べて`）
4. **設計検証**: アーキテクチャ・実装方針の妥当性確認（例: `この設計パターンは適切か？`）
5. **コードレビュー**: 品質・保守性・パフォーマンスの評価（例: `このコードの改善点は？`）
6. **計画立案**: タスクの実行計画レビュー・改善提案（例: `この実装計画の問題点は？`）
7. **技術選定**: ライブラリ・手法の比較検討 （例: `このライブラリは他と比べてどうか？`）
## 段階的実装アプローチ  
重要度に応じて３段階で原則を適用（認知負荷を管理）

---

## Phase 1：最重要（絶対守る）  
**#1. 実装前の一報連絡 → 実装開始**：diff表記後は必ず「承認をお待ちします」と明記し、「OK」「実装して」「良い」「承認」などを待つ  
**#2. 単体実装の1Unit/test実装**：品質担保の最低条件  
**#3. 明確な下限側の完全禁止**：データ損失防止  
**#4. 深い思考をする**

---

## Phase 2：重要（意識的に実行）  
**#5. 判断理由の記録**：なぜその選択をしたかの3行メモ  
**#6. 既存コードの事前調査**：機能実装なら既存コード3-5ファイルを確認し、命名規則・アーキテクチャパターン・コードスタイルを踏襲

---

## Phase 3：理想（余裕がある時）  
**#7. 中長期パフォーマンス最適化**：可読性・保守性・バグリスクを評価し許容範囲内で実行  
**#8. 詳細コメント記述**：単純説明ではなく技術的意図を説明

---

## 深い思考の自動実行（毎回必須）  
毎回自動で以下を実行：

---

### 1. 思考トリガー（自問自答）  
（Why-Why-Why分析）  
- 「なぜそれに気づけたか？」or「なぜ迷ったか？」  
- 「本当にこれが最良だといえるのか？」を考えたか？  
- 「もっと良いやり方はないか？」る発想がある？

---

### 2. 多角的検討（3つの視点を必須検討）  
- 性能、実装難度、保守性 → 安全性、保守性  
- 設計意図との一致、現実との一致、期待との一致  
- 他の設計と矛盾しないか？

---

### 3. 品質の自己採点（各項目4点以上で合格）  
- 品質：実装難度、保守性、安全性（5点満点）  
- 判定：3項目すべて 4点以上
# Gemini Project Context: BLE App

This document provides context for the Gemini agent about the Flutter BLE application.

## Project Overview

This is a Flutter application named `bleapp` designed to scan, connect to, and manage Bluetooth Low Energy (BLE) devices. The core functionality involves discovering devices, maintaining a list of paired devices, and displaying their connection status.

## Tech Stack

- **Framework:** Flutter
- **Language:** Dart
- **Core Dependencies:**
  - `flutter_blue_plus`: For all Bluetooth Low Energy interactions.
  - `shared_preferences`: To persist the list of paired devices locally on the device.
  - `permission_handler`: To request necessary Bluetooth and location permissions from the user.

## Project Structure

- `lib/main.dart`: The main entry point of the application. It displays the lists of connected and disconnected devices.
- `lib/connect_page.dart`: (Assumed) A page to interact with a connected BLE device.
- `lib/pairing.dart`: (Assumed) A page that handles the scanning and pairing process for new devices.
- `pubspec.yaml`: Defines all project dependencies and metadata.
- `analysis_options.yaml`: Contains Dart linting rules, configured to use `flutter_lints`.

## Development Workflow & Commands

- **Install Dependencies:**
  ```bash
  flutter pub get
  ```
- **Run the Application:**
  ```bash
  flutter run
  ```
- **Run Tests:**
  ```bash
  flutter test
  ```
- **Analyze Code (Linting):**
  ```bash
  flutter analyze
  ```

## Coding Conventions

- The project follows standard Flutter and Dart coding conventions.
- All code should adhere to the linting rules defined in `analysis_options.yaml`.
- UI components should maintain a consistent style, using the color scheme and widget structure found in `lib/main.dart` (e.g., `Scaffold`, `Card`, `AppBar` with `Color(0xFF66B2A3)`).
