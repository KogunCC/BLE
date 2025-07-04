// ParingPage.dart
//// BLEデバイスのペアリングを行うページ
// ユーザーがBLEデバイスをスキャンし、接続するためのページです。
// パーミッションのチェック、スキャンの開始、デバイスのリスト表示、接続処理を行います。
import 'dart:async';// Dartの非同期処理用
import 'dart:io';
import 'package:bleapp/models/paired_device.dart'; // PairedDeviceモデルをインポート
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';// Flutterの基本ウィジェットライブラリ
import 'package:flutter_blue_plus/flutter_blue_plus.dart';// BLE操作ライブラリ
import 'package:permission_handler/permission_handler.dart'; // パーミッションハンドリング
import 'package:bleapp/utils/app_constants.dart';

class ParingPage extends StatefulWidget {
  const ParingPage({super.key});

  @override
  State<ParingPage> createState() => _ParingPageState();
}

class _ParingPageState extends State<ParingPage> {
  // 検出されたデバイスのリスト（PairedDeviceオブジェクトを保持）
  final List<PairedDevice> _deviceList = [];
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
    if (Platform.isAndroid) {
        final bool bluetoothScanGranted = await Permission.bluetoothScan.request().isGranted;
        final bool bluetoothConnectGranted = await Permission.bluetoothConnect.request().isGranted;
        final bool locationWhenInUseGranted = await Permission.locationWhenInUse.request().isGranted;

        

        if (bluetoothScanGranted && bluetoothConnectGranted && locationWhenInUseGranted) {
            _startScan();
        } else {
            // パーミッションが許可されなかった場合の処理
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _showSnackBar('Bluetoothおよび位置情報のパーミッションが必要です。設定から許可してください。', AppColors.errorColor);
            });
            if (!mounted) return;
            setState(() {
                _isScanning = false; // スキャン状態をリセット
            });
        }
    } else if (Platform.isIOS) {
        // iOSの場合の位置情報パーミッションの要求結果をprintで出力
        final bool locationWhenInUseGranted = await Permission.locationWhenInUse.request().isGranted;

        

        if (locationWhenInUseGranted) {
            // iOSでは位置情報パーミッションのみでBLEスキャンが可能（Info.plistの設定も重要）
            _startScan();
        } else {
            // パーミッションが許可されなかった場合の処理
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _showSnackBar('位置情報のパーミッションが必要です。設定から許可してください。', AppColors.errorColor);
            });
            if (!mounted) return;
            setState(() {
                _isScanning = false; // スキャン状態をリセット
            });
        }
    } else {
      // その他のプラットフォーム（Web/Desktopなど）の一般的な処理
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSnackBar('このプラットフォームではBluetoothまたは位置情報パーミッションの自動要求はサポートされていません。', AppColors.warningColor);
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

      // スキャン結果の購読を一度だけ行い、見つかったデバイスを一括で処理する
      _scanResultsSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (!mounted) return;
        
        // 新しく見つかったデバイスのリストを一時的に作成
        final List<PairedDevice> foundDevices = [];
        for (var result in results) {
          final device = result.device;
          // platformNameが空でなく、まだリストにないデバイスのみを追加
          if (device.platformName.isNotEmpty && 
              !_deviceList.any((d) => d.id == device.remoteId.str) &&
              !foundDevices.any((d) => d.id == device.remoteId.str)) {
            foundDevices.add(PairedDevice(name: device.platformName, id: device.remoteId.str));
          }
        }

        // UIの更新は一度だけ行う
        setState(() {
          _deviceList.addAll(foundDevices);
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
        if (!mounted) return;
        _showSnackBar('スキャン開始中にエラーが発生しました: ${e.toString()}', AppColors.errorColor);
      });
      
      setState(() {
        _isScanning = false; // エラー発生時はスキャン状態をリセット
      });
    }
  }

  // スナックバーメッセージを表示するヘルパー関数
  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    // 画面が破棄されるときにスキャンを停止し、購読を解除
    FlutterBluePlus.stopScan();
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  Widget _buildBody() {
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Platform.isIOS
                ? CupertinoButton.filled(
                    onPressed: _isScanning ? null : _startScan,
                    child: Text(_isScanning ? 'スキャン中...' : 'デバイスをスキャン'),
                  )
                : ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan, // スキャン中はボタンを無効化
                    icon: _isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(_isScanning ? 'スキャン中...' : 'デバイスをスキャン'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
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
                      'デバイスが見つかりませんでした。Bluetoothがオンになっているか確認してください。',
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
                  child: Platform.isIOS
                      ? CupertinoListTile(
                          title: Text(device.name),
                          onTap: () => _connectToDevice(device),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cardColor,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            elevation: 2,
                            side: const BorderSide(color: AppColors.cardBorderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _connectToDevice(device),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(device.name)),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      );
  }

  Future<void> _connectToDevice(PairedDevice device) async {
    final deviceToPair = device;
    // 接続中のUIフィードバック
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showSnackBar('${deviceToPair.name} に接続を試行中...', AppColors.infoColor);
    });

    try {
      final bluetoothDevice =
          BluetoothDevice(remoteId: DeviceIdentifier(deviceToPair.id));

      // 既に接続済みか確認
      // ignore: await_only_futures
      if (await bluetoothDevice.isConnected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showSnackBar('${deviceToPair.name} は既に接続済みです', AppColors.warningColor);
        });
        if (!mounted) return;
        print('ペアリング画面からメイン画面へ返されるデバイス情報: ID=${deviceToPair.id}, 名前=${deviceToPair.name}');
        Navigator.pop(context, deviceToPair);
        return;
      }

      await bluetoothDevice.connect(
        timeout: const Duration(seconds: 10), // 接続タイムアウトを少し長く設定
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSnackBar('${deviceToPair.name} に接続しました', AppColors.successColor);
      });

      // 接続成功時にデバイス情報を main に返す
      if (!mounted) return;
      Navigator.pop(context, deviceToPair);
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSnackBar('接続に失敗しました: ${e.toString()}', AppColors.errorColor);
      });
      
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('ペアリング'),
        ),
        child: _buildBody(),
      );
    } else {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.primaryColor,
          title: const Text('ペアリング', style: TextStyle(color: Colors.white)), // タイトルを「ペアリング」に変更
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _buildBody(),
      );
    }
  }
}