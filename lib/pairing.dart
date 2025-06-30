import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // パーミッションハンドリングのため追加

class ParingPage extends StatefulWidget {
  const ParingPage({super.key});

  @override
  State<ParingPage> createState() => _ParingPageState();
}

class _ParingPageState extends State<ParingPage> {
  // 検出されたデバイスのリスト（名前とIDを保持）
  final List<Map<String, String>> _deviceList = [];
  // スキャン中かどうかを示すフラグ
  bool _isScanning = false;
  // スキャン結果の購読を管理するためのStreamSubscription
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  // スキャン状態の変更を購読するためのStreamSubscription
  StreamSubscription<bool>? _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    // アプリ起動時にパーミッションをチェックし、スキャンを開始
    // initStateからの直接呼び出しではなく、次のフレームで実行されるようにスケジュール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndStartScan();
    });
  }

  // Bluetooth関連のパーミッションをチェックし、要求する
  Future<void> _checkPermissionsAndStartScan() async {
    // Android 12 (API 31) 以降では新しいBluetoothパーミッションが必要
    if (Theme.of(context).platform == TargetPlatform.android) {
        // 各パーミッションの要求結果をprintで出力
        final bool bluetoothScanGranted = await Permission.bluetoothScan.request().isGranted;
        final bool bluetoothConnectGranted = await Permission.bluetoothConnect.request().isGranted;
        final bool locationWhenInUseGranted = await Permission.locationWhenInUse.request().isGranted;

        print('Permission Status for Android:');
        print('  Bluetooth Scan: $bluetoothScanGranted');
        print('  Bluetooth Connect: $bluetoothConnectGranted');
        print('  Location When In Use: $locationWhenInUseGranted');

        if (bluetoothScanGranted && bluetoothConnectGranted && locationWhenInUseGranted) {
            _startScan();
        } else {
            // パーミッションが許可されなかった場合の処理
            WidgetsBinding.instance.addPostFrameCallback((_) {
                _showSnackBar('Bluetoothおよび位置情報のパーミッションが必要です。設定から許可してください。', Colors.red);
            });
            if (!mounted) return;
            setState(() {
                _isScanning = false; // スキャン状態をリセット
            });
        }
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        // iOSの場合の位置情報パーミッションの要求結果をprintで出力
        final bool locationWhenInUseGranted = await Permission.locationWhenInUse.request().isGranted;

        print('Permission Status for iOS:');
        print('  Location When In Use: $locationWhenInUseGranted');

        if (locationWhenInUseGranted) {
            // iOSでは位置情報パーミッションのみでBLEスキャンが可能（Info.plistの設定も重要）
            _startScan();
        } else {
            // パーミッションが許可されなかった場合の処理
            WidgetsBinding.instance.addPostFrameCallback((_) {
                _showSnackBar('位置情報のパーミッションが必要です。設定から許可してください。', Colors.red);
            });
            if (!mounted) return;
            setState(() {
                _isScanning = false; // スキャン状態をリセット
            });
        }
    } else {
      // その他のプラットフォーム（Web/Desktopなど）の一般的な処理
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackBar('このプラットフォームではBluetoothまたは位置情報パーミッションの自動要求はサポートされていません。', Colors.orange);
      });
      if (!mounted) return;
      setState(() {
        _isScanning = false; // スキャン状態をリセット
      });
    }
  }

  // BLEデバイスのスキャンを開始する
  void _startScan() async {
    // 既にスキャン中の場合は何もしない
    if (_isScanning) return;
    // ウィジェットがマウントされていない場合は何もしない
    if (!mounted) return;

    // UIをスキャン中状態に更新
    setState(() {
      _isScanning = true;
      _deviceList.clear(); // 新しいスキャンの前にリストをクリア
    });

    // BluetoothアダプターがONになるまで待機
    await FlutterBluePlus.adapterState
        .firstWhere((state) => state == BluetoothAdapterState.on);

    try {
      // スキャンを開始 (タイムアウトを5秒に設定)
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      // スキャン結果を購読し、デバイスリストに追加
      _scanResultsSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          for (var result in results) {
            final device = result.device;
            // platformNameが空でない場合のみデバイスを追加
            // 'Unknown Device'という名前を割り当てる必要がなくなります
            if (device.platformName.isNotEmpty && !_deviceList.any((d) => d['id'] == device.remoteId.str)) {
              _deviceList.add({'name': device.platformName, 'id': device.remoteId.str});
            }
          }
        });
      });

      // スキャン状態の変更を購読
      _isScanningSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
        if (!mounted) return;
        setState(() {
          _isScanning = isScanning;
        });
        // スキャンが停止したらスキャン結果の購読も解除
        if (!isScanning) {
          _scanResultsSubscription?.cancel();
          _scanResultsSubscription = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) { // ここも遅延させる
        _showSnackBar('スキャン開始中にエラーが発生しました: ${e.toString()}', Colors.red);
      });
      print('BLE Scan Start Error: $e'); // デバッグ用にコンソールに出力
      setState(() {
        _isScanning = false; // エラー発生時はスキャン状態をリセット
      });
    }
  }

  // スナックバーメッセージを表示するヘルパー関数
  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    // 画面が破棄されるときにスキャンを停止し、購読を解除
    FlutterBluePlus.stopScan();
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF66B2A3),
        title: const Text('ペアリング', style: TextStyle(color: Colors.white)), // タイトルを「ペアリング」に変更
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan, // スキャン中はボタンを無効化
              icon: _isScanning ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ) : const Icon(Icons.bluetooth_searching),
              label: Text(_isScanning ? 'スキャン中...' : 'デバイスをスキャン'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66B2A3),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50), // ボタンの幅を最大にし、高さを設定
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // スキャン中でない、かつデバイスが何も見つからなかった場合のメッセージ
          if (!_isScanning && _deviceList.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'デバイスが見つかりませんでした。\nBluetoothがオンになっているか確認してください。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          // デバイスリストを表示
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _deviceList.length,
              itemBuilder: (context, index) {
                final device = _deviceList[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      elevation: 2,
                      side: const BorderSide(color: Colors.teal),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final id = device['id'];
                      final name = device['name'];
                      // 接続中のUIフィードバック
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showSnackBar('$name に接続を試行中...', Colors.blue);
                      });

                      try {
                        final bluetoothDevice =
                            BluetoothDevice(remoteId: DeviceIdentifier(id!));

                        // 既に接続済みか確認
                        if (await bluetoothDevice.isConnected) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _showSnackBar('$name は既に接続済みです', Colors.orange);
                          });
                          if (!mounted) return;
                          Navigator.pop(context, {'id': id, 'name': name});
                          return;
                        }

                        await bluetoothDevice.connect(
                          timeout: const Duration(seconds: 10), // 接続タイムアウトを少し長く設定
                        );

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showSnackBar('$name に接続しました', Colors.green);
                        });

                        // 接続成功時にデバイス情報を main に返す
                        if (!mounted) return;
                        Navigator.pop(context, {'id': id, 'name': name});
                      } catch (e) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showSnackBar('接続に失敗しました: ${e.toString()}', Colors.red);
                        });
                        print('Connection Error: $e'); // デバッグ用にエラーをコンソールに出力
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(device['name'] ?? '不明なデバイス')),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
