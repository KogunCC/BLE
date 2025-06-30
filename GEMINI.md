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
