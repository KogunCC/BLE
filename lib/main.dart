// main.dart: BLEデバイスの接続状態を管理し、UIに表示するメイン画面


import 'dart:async';
import 'dart:convert'; // JSONエンコード/デコード用
import 'dart:io'; // プラットフォーム判定のため
import 'package:bleapp/models/paired_device.dart';// PairedDeviceモデルをインポート
import 'package:bleapp/utils/notification_service.dart';// 通知サービスをインポート
import 'package:bleapp/utils/theme_manager.dart';
import 'package:flutter/cupertino.dart'; // Cupertinoデザインのため
import 'package:flutter/material.dart';// Flutterの基本ウィジェットライブラリ
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // BLE操作ライブラリ
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ローカルストレージ用
import 'connect_page.dart'; // ConnectPageへの遷移を仮定
import 'pairing.dart';     // ParingPageへの遷移を仮定
import 'package:bleapp/utils/app_constants.dart'; // 新しい定数ファイル

// アプリのエントリーポイント
void main() async {
  // Flutterウィジェットバインディングを初期化し、プラットフォームチャネルが利用可能であることを保証
  WidgetsFlutterBinding.ensureInitialized();

  // 通知サービスを初期化
  await NotificationService.initialize();

  // ⭐ FlutterBluePlusのオプション設定 ⭐
  // 'BluetoothAdapterOptions'が未定義エラーになるため、
  // もし将来的に restoreIdentifierKey を設定する必要が出た場合、
  // flutter_blue_plus の最新ドキュメントや CHANGELOG を参照し、
  // 正しい setOptions の引数形式を確認する必要があります。
  FlutterBluePlus.setOptions(); // 引数なしで呼び出す形式

  // アプリケーションを実行
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeManager(),
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    if (Platform.isIOS) {
      return CupertinoApp(
        title: 'BLE Status', // アプリのタイトル
        theme: CupertinoThemeData(
          brightness: themeManager.themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        ),
        home: const BLEStatusScreen(), // アプリのホーム画面
        debugShowCheckedModeBanner: false, // デバッグバナーを非表示
        routes: {
          '/paring': (context) => const ParingPage(), // ペアリング画面へのルート定義
        },
      );
    } else {
      return MaterialApp(
        title: 'BLE Status', // アプリのタイトル
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeManager.themeMode,
        home: const BLEStatusScreen(), // アプリのホーム画面
        debugShowCheckedModeBanner: false, // デバッグバナーを非表示
        routes: {
          '/paring': (context) => const ParingPage(), // ペアリング画面へのルート定義
        },
      );
    }
  }
}

// BLEデバイスの接続状態を表示するメインスクリーン
class BLEStatusScreen extends StatefulWidget {
  const BLEStatusScreen({super.key});

  @override
  State<BLEStatusScreen> createState() => _BLEStatusScreenState();
}

class _BLEStatusScreenState extends State<BLEStatusScreen> with WidgetsBindingObserver {
  List<PairedDevice> _pairedDevices = [];
  // 現在スキャンが進行中かどうかを示すフラグ。UIの制御に使用。
  bool _isScanning = false;
  // 各デバイスの現在の接続状態をリアルタイムで追跡するマップ。
  final Map<String, bool> _deviceConnectionStatus = {};
  // 各デバイスの接続状態監視を管理するマップ
  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  // アプリがバックグラウンドにあるかどうかを示すフラグ
  bool _isInBackground = false;


  @override
  void initState() {
    super.initState();
    // ライフサイクル監視を開始
    WidgetsBinding.instance.addObserver(this);
    _loadPairedDevices().then((_) {
      // ロード後にデバイスの接続状態監視を開始
      _setupAllDeviceListeners();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiateDeviceDiscovery();
    });
  }

  // アプリのライフサイクルが変更されたときに呼び出される
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _isInBackground = state == AppLifecycleState.paused;
    });
  }


  /* ========= SharedPreferences による永続化 =========== */

  Future<void> _savePairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    // PairedDeviceオブジェクトのリストをMapのリストに変換してからJSONにエンコード
    final List<Map<String, dynamic>> data = _pairedDevices.map((device) => device.toJson()).toList();
    await prefs.setString('paired_devices', jsonEncode(data));
    print('SharedPreferencesに保存されるペアリング済みデバイス: $data');
  }

  Future<void> _loadPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('paired_devices');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      setState(() {
        // JSON MapのリストからPairedDeviceオブジェクトのリストを生成
        _pairedDevices = decoded.map((item) => PairedDevice.fromJson(item)).toList();
        for (var dev in _pairedDevices) {
          _deviceConnectionStatus[dev.id] = false;
        }
        print('SharedPreferencesからロードされたペアリング済みデバイス: $_pairedDevices');
      });
    }
  }

  Future<void> _resetPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('paired_devices'); // SharedPreferencesから情報を削除
    // 既存のリスナーをすべてキャンセル
    _cancelAllDeviceListeners();
    if (!mounted) return;
    setState(() {
      // UIの状態をすべてリセット
      _pairedDevices.clear();
      _deviceConnectionStatus.clear();
    });
    // 状態がクリアされた後、UIが更新されてからメッセージを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOverlayMessage('すべてのペアリング情報がリセットされました', AppColors.infoColor);
    });
    print('ペアリング情報がリセットされました。');
  }

  /* ========= UI フィードバックのためのオーバーレイメッセージ =========== */

  void _showOverlayMessage(String message, Color bgColor) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 1), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  /* ========= BLEスキャンと接続ロジック =========== */

  // 特定のデバイスの接続状態を監視するリスナーをセットアップ
  void _setupDeviceListener(PairedDevice pDevice) {
    // 既存のリスナーがあればキャンセル
    _connectionSubscriptions[pDevice.id]?.cancel();

    final device = BluetoothDevice(remoteId: DeviceIdentifier(pDevice.id));
    _connectionSubscriptions[pDevice.id] = device.connectionState.listen((state) {
      if (!mounted) return;

      final isConnected = state == BluetoothConnectionState.connected;
      // 接続状態が変化した場合のみUIを更新
      if (_deviceConnectionStatus[pDevice.id] != isConnected) {
        setState(() {
          _deviceConnectionStatus[pDevice.id] = isConnected;
        });
      }

      // バックグラウンドで切断された場合に通知を送信
      if (!isConnected && _isInBackground) {
        NotificationService.showNotification(
          id: pDevice.id.hashCode, // デバイスごとにユニークなID
          title: 'デバイス接続エラー',
          body: '${pDevice.name} との接続が切れました。',
        );
      }
    });
  }

  // すべてのペアリング済みデバイスのリスナーをセットアップ
  void _setupAllDeviceListeners() {
    for (var pDevice in _pairedDevices) {
      _setupDeviceListener(pDevice);
    }
  }

  // すべてのリスナーをキャンセル
  void _cancelAllDeviceListeners() {
    for (var sub in _connectionSubscriptions.values) {
      sub.cancel();
    }
    _connectionSubscriptions.clear();
  }

  // 特定のデバイスのペアリングを解除する
  Future<void> _unpairDevice(String deviceId) async {
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

    // 接続中の場合は切断する
    if (device.isConnected) {
      await device.disconnect();
    }

    // 接続監視をキャンセル
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);

    if (!mounted) return;
    setState(() {
      // リストからデバイスを削除
      _pairedDevices.removeWhere((d) => d.id == deviceId);
      _deviceConnectionStatus.remove(deviceId);
    });

    // 永続化
    await _savePairedDevices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOverlayMessage('デバイスのペアリングを解除しました', AppColors.infoColor);
    });
  }


  Future<void> _initiateDeviceDiscovery() async {
    if (_isScanning) return;
    if (!mounted) return;

    setState(() {
      _isScanning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOverlayMessage('デバイスのスキャンと接続を試行中...', AppColors.infoColor);
      });
    });

    try {
      await FlutterBluePlus.adapterState.firstWhere((state) => state == BluetoothAdapterState.on);

      // 既存のペアリング済みデバイスの接続状態を更新
      await _updateDeviceConnectionStatus();

      // 新しいデバイスのスキャンと接続
      await _performBleScan();

      if (!mounted) return;
      setState(() {
        // _deviceConnectionStatus は _updateDeviceConnectionStatus と _performBleScan で更新されるため、ここではクリアしない
        // UIの更新をトリガーするためにsetStateを呼び出す
      });
      await _savePairedDevices();

      print('デバイス探索後の最終的なペアリング済みデバイス: $_pairedDevices');

    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOverlayMessage('スキャンまたは接続中にエラーが発生しました: ${e.toString()}', AppColors.errorColor);
      });
      
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _updateDeviceConnectionStatus() async {
    final List<PairedDevice> currentPairedDevices = List.from(_pairedDevices);
    final Map<String, bool> tempConnectionStatus = {};

    for (var dev in currentPairedDevices) {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(dev.id));
      try {
        if (device.isConnected) {
          tempConnectionStatus[dev.id] = true;
        } else {
          await device.connect(timeout: const Duration(seconds: 5));
          tempConnectionStatus[dev.id] = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverlayMessage('${dev.name} に再接続しました', AppColors.successColor);
          });
        }
      } catch (_) {
        tempConnectionStatus[dev.id] = false;
      }
      // 接続状態が更新された後、リスナーを再設定
      _setupDeviceListener(dev);
    }

    if (!mounted) return;
    setState(() {
      _deviceConnectionStatus.clear();
      _deviceConnectionStatus.addAll(tempConnectionStatus);
    });
  }

  Future<void> _performBleScan() async {
    // スキャンを開始し、5秒後に停止
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    // スキャンが停止するまで待機
    await FlutterBluePlus.isScanning.firstWhere((isScanning) => isScanning == false);
  }

  // リセット確認ダイアログを表示する
  Future<void> _showResetConfirmationDialog() async {
    if (Platform.isIOS) {
      return showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('確認'),
          content: const Text('すべてのペアリング情報が削除されます。よろしいですか？'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('リセット'),
              onPressed: () {
                print("リセットボタンが押されました。");
                Navigator.of(context).pop(); // ダイアログを閉じる
                _resetPairedDevices();      // リセット処理を実行
              },
            ),
          ],
        ),
      );
    } else {
      return showDialog<void>(
        context: context,
        barrierDismissible: false, // ダイアログ外をタップしても閉じない
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('確認'),
            content: const SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text('すべてのペアリング情報が削除されます。'),
                  Text('よろしいですか？'),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('リセット', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  print("リセットボタンが押されました。");
                  Navigator.of(context).pop(); // ダイアログを閉じる
                  _resetPairedDevices();      // リセット処理を実行
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    // ライフサイクル監視と接続監視を終了
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllDeviceListeners();
    super.dispose();
  }

  String _generateUniqueDeviceName(String baseName) {
    String name = baseName;
    int count = 1;
    final existingNames = _pairedDevices.map((d) => d.name).toSet();
    while (existingNames.contains(name)) {
      name = '$baseName ($count)';
      count++;
    }
    return name;
  }

  /* ========= デバイスステータス表示カードのビルド =========== */

  Widget _buildStatusCard(String title, String id, bool connected, {VoidCallback? onTap}) {
    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: AppColors.cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded( // 1. 左側のセクションをExpandedでラップして、利用可能なスペースを埋めるようにする
              child: Row(
                children: [
                  Icon(
                    connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: connected ? AppColors.connectedColor : AppColors.disconnectedColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded( // 2. デバイス名のTextウィジェットをExpandedでラップ
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis, // 3. はみ出したテキストを「...」で省略
                      softWrap: false, // 4. テキストを折り返さないように設定
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8), // 5. 左右のセクション間にスペースを追加
            Text(
              connected ? 'Connected' : 'Disconnected',
              style: TextStyle(fontSize: 16, color: connected ? AppColors.connectedColor : Colors.black54),
            ),
          ],
        ),
      ),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: card) : card;
  }

  /* ========= UIレイアウトのビルド =========== */

  Widget _buildBody() {
    return SafeArea(
      child: ListView(
          padding: const EdgeInsets.only(bottom: 100), // フローティングボタンとの重なりを避ける
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
              child: Text('接続済み', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ..._pairedDevices
                .where((dev) => _deviceConnectionStatus[dev.id] == true)
                .map((dev) => _buildStatusCard(
              dev.name,
              dev.id,
              _deviceConnectionStatus[dev.id] ?? false,
              onTap: () async {
                List<BluetoothDevice> connected = FlutterBluePlus.connectedDevices;
                BluetoothDevice? targetDevice;
                for (var connectedDev in connected) {
                  if (connectedDev.remoteId.str == dev.id) {
                    targetDevice = connectedDev;
                    break;
                  }
                }

                if (targetDevice != null) {
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectPage(device: targetDevice!, onUnpair: _unpairDevice)));
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _showOverlayMessage('${dev.name} は現在接続されていません。再スキャンを試してください。', AppColors.warningColor);
                  });
                  setState(() {
                    _deviceConnectionStatus[dev.id] = false;
                  });
                  await _savePairedDevices();
                }
              },
            )),

            const Padding(
              padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
              child: Text('接続が切れたデバイス', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ..._pairedDevices
                .where((dev) => _deviceConnectionStatus[dev.id] != true)
                .map((dev) => _buildStatusCard(
              dev.name,
              dev.id,
              _deviceConnectionStatus[dev.id] ?? false,
              onTap: () async {
                final device = BluetoothDevice(remoteId: DeviceIdentifier(dev.id));
                try {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _showOverlayMessage('${dev.name} に再接続を試行中...', AppColors.infoColor);
                  });
                  await device.connect(timeout: const Duration(seconds: 5));
                  if (!mounted) return;
                  setState(() {
                    _deviceConnectionStatus[dev.id] = true;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showOverlayMessage('${dev.name} に再接続しました', AppColors.successColor);
                  });
                  await _savePairedDevices();
                } catch (e) {
                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showOverlayMessage('${dev.name} の再接続に失敗しました', AppColors.errorColor);
                  });
                  // 再接続に失敗した場合、_deviceConnectionStatus は false のまま
                  setState(() {});
                }
              },
            )),

            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _initiateDeviceDiscovery,
                icon: const Icon(Icons.refresh),
                label: Text(_isScanning ? 'スキャン中...' : '再スキャン'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning
                      ? null
                      : () async {
                          final result = await Navigator.pushNamed(context, '/paring');
                          print('ペアリング画面から返された結果: $result');
                          if (result is PairedDevice) {
                            if (!_pairedDevices.any((d) => d.id == result.id)) {
                              if (!mounted) return;
                              // 接続前にユニークな名前を生成
                              final uniqueName = _generateUniqueDeviceName(result.name);
                              final newDevice = PairedDevice(id: result.id, name: uniqueName);
                              setState(() {
                                _pairedDevices.add(newDevice);
                                _deviceConnectionStatus[result.id] = true;
                              });
                              // 新しいデバイスのリスナーをセットアップ
                              _setupDeviceListener(newDevice);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _showOverlayMessage('ペアリング成功: $uniqueName', AppColors.successColor);
                              });
                              await _savePairedDevices();
                            } else {
                              if (!mounted) return;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _showOverlayMessage(
                                    '${result.name} は既にペアリングされています', AppColors.warningColor);
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('ペアリング画面へ', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 10), // ボタン間のスペース
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  label: const Text('ペアリング情報をリセット', style: TextStyle(fontSize: 16, color: Colors.white)),
                  onPressed: _showResetConfirmationDialog, // 確認ダイアログを表示
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorColor, // 注意を引く色
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('BLE Status'),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(
              themeManager.themeMode == ThemeMode.dark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
            ),
            onPressed: () {
              themeManager.toggleTheme(themeManager.themeMode == ThemeMode.light);
            },
          ),
        ),
        child: _buildBody(),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('BLE Status'),
          actions: [
            IconButton(
              icon: Icon(
                themeManager.themeMode == ThemeMode.dark ? Icons.wb_sunny : Icons.nights_stay,
              ),
              onPressed: () {
                themeManager.toggleTheme(themeManager.themeMode == ThemeMode.light);
              },
            ),
          ],
        ),
        body: _buildBody(),
      );
    }
  }
}
