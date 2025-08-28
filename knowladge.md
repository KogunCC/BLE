# プロジェクト技術知見ドキュメント

このドキュメントは、`BLE Status` プロジェクトに関する技術的な知見、アーキテクチャ、および実装の詳細をまとめた開発者向けの内部資料です。

## 1. プロジェクト概要

- **名称**: BLE Status
- **目的**: Bluetooth Low Energy (BLE) デバイスの接続状態を管理し、紛失を防ぐためのFlutterアプリケーション。汎用的なBLEデバイス管理機能に加え、専用デバイス「AreraNaiTag」と連携することで、より高度な機能を提供する。

## 2. アーキテクチャと技術スタック

- **フレームワーク**: Flutter
- **言語**: Dart
- **主要ライブラリ**:
    - `flutter_blue_plus`: BLE通信のコア機能（スキャン, 接続, データ送受信）。
    - `shared_preferences`: ペアリング済みデバイス情報や最終位置情報など、少量のキーバリューデータを永続化。
    - `permission_handler`: Bluetoothや位置情報に関するOSレベルの権限要求を管理。
    - `geolocator`: スマートフォンのGPS位置情報を取得。
    - `url_launcher`: 外部の地図アプリを起動し、位置情報を表示。
    - `provider`: `ChangeNotifierProvider` を用いたテーマ管理 (`ThemeManager`) など、シンプルな状態管理に使用。
    - `flutter_foreground_task`: アプリがバックグラウンドにある間もBLE接続を監視し、切断時に通知や位置情報記録を行うためのフォアグラウンドサービスを実行。

## 3. プロジェクト構造

アプリケーションの主要なソースコードは `lib/` ディレクトリに格納されています。

- `main.dart`: アプリのエントリーポイント。メイン画面のUI、デバイスリストの表示、および各種サービスの初期化を行う。
- `pairing.dart`: 新規BLEデバイスのスキャンとペアリング処理を行う画面。
- `connect_page.dart`: 接続済みデバイスの詳細情報を表示し、対話する画面（RSSI、バッテリー電圧など）。
- `models/paired_device.dart`: ペアリング済みデバイスのデータモデル。デバイスID、名前、最終位置情報などを保持する。
- `utils/`: アプリケーション全体で利用されるユーティリティクラス群。
    - `app_constants.dart`: 定数管理（UUID、`shared_preferences`のキーなど）。
    - `foreground_service_handler.dart`: フォアグラウンドサービスのタスク処理を定義するハンドラ。
    - `location_service.dart`: `geolocator` をラップし、位置情報の取得と地図アプリ連携を担う。
    - `notification_service.dart`: ローカル通知の表示を管理。
    - `theme_manager.dart`: `ChangeNotifier` を利用してアプリのテーマ（ライト/ダーク）を管理。

## 4. 主要機能と実装詳細

### 4.1. 状態管理 (`Provider` & `ValueNotifier`)

- **テーマ管理**: `ChangeNotifierProvider` と `ThemeManager` (`ChangeNotifier`を継承) を使用し、アプリ全体のテーマ状態を管理。UIは `Provider.of<ThemeManager>(context)` を通じてテーマの変更をリッスンする。
- **UIイベント通知**: `ValueNotifier<SnackBarEvent?>` を利用して、ビジネスロジック層からUI層へ `SnackBar` の表示イベントを通知。`main.dart`で `ValueNotifier` をリッスンし、イベント発生時に `ScaffoldMessenger` を使って `SnackBar` を表示する。これにより、UIコードからビジネスロジックを分離している。

### 4.2. BLE通信 (`flutter_blue_plus`)

- **デバイススキャン**: `pairing.dart` で `FlutterBluePlus.startScan` を呼び出し、非同期ストリームでデバイスを検出。
- **接続と状態監視**: `BluetoothDevice.connect` で接続を確立。`device.connectionState.listen` を用いて接続状態の変化をリアルタイムに監視し、UI（`_deviceConnectionStatus`）を更新する。
- **データ永続化**: 接続に成功したデバイスは `PairedDevice` オブジェクトとして `shared_preferences` にJSON形式で保存される。

### 4.3. バックグラウンド処理 (`flutter_foreground_task`)

- **目的**: アプリがバックグラウンド状態でもBLEデバイスの接続が切れたことを検知し、ユーザーに通知したり、最終位置を記録したりするため。
- **実装**: 
    1.  `main()` で `FlutterForegroundTask.init()` を呼び出し、フォアグラウンドサービスを初期化。
    2.  BLEデバイスに接続成功後、`_startForegroundService()` を呼び出してサービスを開始。
    3.  `@pragma('vm:entry-point')` を付与したトップレベル関数 `startCallback()` がサービスのエントリーポイントとなる。
    4.  `ForegroundServiceHandler` クラスが実際のバックグラウンドタスクを処理する。現在はサービスの停止ボタンを処理するのみだが、定期的な接続確認などのロジックを実装可能。
    5.  `didChangeAppLifecycleState` でアプリのライフサイクルを監視し、バックグラウンド移行時に通知を出すなどの処理を実装。

### 4.4. エラーハンドリングとユーザーフィードバック

- **仕組み**: `GlobalKey<ScaffoldMessengerState>` を `MaterialApp` に設定し、アプリのどこからでも `SnackBar` を表示できるようにしている。`_showSnackBar` メソッドが `ValueNotifier` にイベントを発行し、それをリッスンしている `_handleSnackBarEvent` が `SnackBar` を表示する。
- **シナリオ**: 
    - **権限拒否**: `permission_handler` で権限が拒否された場合、`SnackBar` でユーザーに通知。
    - **Bluetooth/位置情報無効**: `SnackBar` で有効化を促すメッセージを表示。
    - **接続失敗/切断**: `SnackBar` でリアルタイムにフィードバック。
    - **位置情報取得失敗**: `LocationService` 内で `try-catch` を行い、`Exception` の種類に応じて `SnackBar` で具体的なエラー内容（サービス無効、権限拒否など）を通知。

## 5. プラットフォーム固有設定

### 5.1. iOS (`ios/Runner/Info.plist`)

- **Bluetooth**: `NSBluetoothAlwaysUsageDescription` - バックグラウンドでのBLE通信のために必要。
- **Location**: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` - 位置情報の取得とバックグラウンドでの追跡に必要。
- **Background Modes**: バックグラウンドでBLE通信を継続するために、`UIBackgroundModes` に `bluetooth-central` を追加する必要がある。

### 5.2. Android (`android/app/src/main/AndroidManifest.xml`)

- **Permissions**:
    - `android.permission.BLUETOOTH_SCAN`, `android.permission.BLUETOOTH_CONNECT` (Android 12+)
    - `android.permission.ACCESS_FINE_LOCATION`
    - `android.permission.ACCESS_BACKGROUND_LOCATION` (Android 10+)
    - `android.permission.FOREGROUND_SERVICE`
- **Foreground Service**: `flutter_foreground_task` のために、`AndroidManifest.xml` にサービス定義が追加される。

## 6. 開発とテスト

- **開発ワークフロー**:
  ```bash
  # 依存関係のインストール
  flutter pub get
  
  # アプリの実行
  flutter run
  
  # 静的コード解析
  flutter analyze
  
  # テストの実行
  flutter test
  ```
- **テスト戦略**:
    - **Widget Test**: `test/widget_test.dart` にサンプルあり。UIコンポーネントのレンダリングとインタラクションを検証。
    - **Unit Test**: `PairedDevice` の `toJson`/`fromJson` など、モデルクラスのロジックを単体で検証。
    - **Integration Test**: `flutter_blue_plus` や `geolocator` などのプラグインをモック化し、機能間の連携をテストする。

---
*このドキュメントはプロジェクトの理解を深めるためのものであり、コードの変更に応じて随時更新されるべきです。*