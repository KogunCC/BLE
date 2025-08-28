// main.dart: BLEデバイスの接続状態を管理し、UIに表示するメイン画面


import 'dart:async';
import 'dart:convert'; // JSONエンコード/デコード用
import 'dart:io'; // プラットフォーム判定のため
import 'dart:isolate'; // ReceivePortのために追加
import 'package:bleapp/models/paired_device.dart';// PairedDeviceモデルをインポート
import 'package:bleapp/utils/notification_service.dart';// 通知サービスをインポート
import 'package:bleapp/utils/theme_manager.dart';// テーマ管理クラスをインポート
import 'package:flutter/cupertino.dart'; // Cupertinoデザインのため
import 'package:flutter/material.dart';// Flutterの基本ウィジェットライブラリ
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // BLE操作ライブラリ
import 'package:provider/provider.dart';// プロバイダーパッケージを使用して状態管理
import 'package:shared_preferences/shared_preferences.dart'; // ローカルストレージ用
import 'connect_page.dart'; // ConnectPageへの遷移を仮定
import 'pairing.dart';     // ParingPageへの遷移を仮定
import 'package:bleapp/utils/app_constants.dart'; // 新しい定数ファイル
import 'package:bleapp/utils/location_service.dart';// 位置情報サービスをインポート
import 'package:geolocator/geolocator.dart';// 位置情報取得のためのパッケージ
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:bleapp/utils/foreground_service_handler.dart';
import 'package:permission_handler/permission_handler.dart';

// The callback function should always be a top-level function.
@pragma('vm:entry-point')
void startCallback() {
  // The setTaskHandler function must be called to handle the task in the background.
  FlutterForegroundTask.setTaskHandler(ForegroundServiceHandler());
}

// SnackBarに表示するメッセージと色を管理するクラス
class SnackBarEvent {
  final String message;
  final Color color;
  SnackBarEvent(this.message, this.color);
}

// GlobalKey for ScaffoldMessenger
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// アプリのエントリーポイント
void main() async {
  // Flutterウィジェットバインディングを初期化し、プラットフォームチャネルが利用可能であることを保証
  WidgetsFlutterBinding.ensureInitialized();

  // フォアグラウンドサービスの初期化
  _initForegroundTask();

  // 通知サービスを初期化
  await NotificationService.initialize();
  FlutterBluePlus.setOptions(); 

  // アプリケーションを実行
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeManager(),
      child: const MyApp(),
    ),
  );
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'foreground_service',
      channelName: 'Foreground Service Notification',
      channelDescription: 'This notification appears when the foreground service is running.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      buttons: [
        const NotificationButton(id: 'stopButton', text: 'Stop Service'),
      ],
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);

    // Use MaterialApp for both platforms to ensure ScaffoldMessenger is available.
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey, // Set the global key
      title: 'BLE Status',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeManager.themeMode,
      home: const WithForegroundTask(
        child: BLEStatusScreen(),
      ),
      debugShowCheckedModeBanner: false,
      routes: {
        '/paring': (context) => const ParingPage(),
      },
    );
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
  bool _isScanning = false;
  final Map<String, bool> _deviceConnectionStatus = {};
  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  bool _isInBackground = false;
  ReceivePort? _receivePort;

  // SnackBar表示イベントを管理するValueNotifier
  final ValueNotifier<SnackBarEvent?> _snackBarNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerReceivePort(FlutterForegroundTask.receivePort);
    
    // ValueNotifierをリッスンしてSnackBarを表示
    _snackBarNotifier.addListener(_handleSnackBarEvent);

    // 最初のフレーム描画後にすべての初期化処理を行う
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPairedDevices().then((_) {
        _setupAllDeviceListeners();
        // デバイスをロードした後にスキャンを開始
        _initiateDeviceDiscovery();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snackBarNotifier.removeListener(_handleSnackBarEvent);
    _snackBarNotifier.dispose();
    _cancelAllDeviceListeners();
    _closeReceivePort();
    super.dispose();
  }

  void _handleSnackBarEvent() {
    final event = _snackBarNotifier.value;
    if (event != null && mounted) {
      final snackBar = SnackBar(
        content: Text(event.message, style: const TextStyle(color: Colors.white)),
        backgroundColor: event.color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 50),
        duration: const Duration(seconds: 2),
      );
      scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
      scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
      // イベントを消費済みにする
      _snackBarNotifier.value = null;
    }
  }

  void _registerReceivePort(ReceivePort? newReceivePort) {
    if (newReceivePort == null) return;
    _closeReceivePort();
    _receivePort = newReceivePort;
    _receivePort?.listen((data) {
      if (data is String && data == 'stopButton') {
        _stopForegroundService();
      }
    });
  }

  void _closeReceivePort() {
    _receivePort?.close();
    _receivePort = null;
  }

  Future<void> _startForegroundService() async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'BLE Service Active',
        notificationText: 'Monitoring BLE connections',
        callback: startCallback,
      );
    }
  }

  Future<void> _stopForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _isInBackground = state == AppLifecycleState.paused;
    });
  }

  Future<void> _savePairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> data = _pairedDevices.map((device) => device.toJson()).toList();
    await prefs.setString('paired_devices', jsonEncode(data));
  }

  Future<void> _loadPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('paired_devices');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      if (!mounted) return;
      setState(() {
        _pairedDevices = decoded.map((item) => PairedDevice.fromJson(item)).toList();
        for (var dev in _pairedDevices) {
          _deviceConnectionStatus[dev.id] = false;
        }
      });
    }
  }

  Future<void> _resetPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('paired_devices');
    _cancelAllDeviceListeners();
    if (!mounted) return;
    setState(() {
      _pairedDevices.clear();
      _deviceConnectionStatus.clear();
    });
    _showSnackBar('すべてのペアリング情報がリセットされました', AppColors.infoColor);
  }

  // SnackBarイベントをNotifierに通知する
  void _showSnackBar(String message, Color bgColor) {
    _snackBarNotifier.value = SnackBarEvent(message, bgColor);
  }

  void _setupDeviceListener(PairedDevice pDevice) {
    _connectionSubscriptions[pDevice.id]?.cancel();
    final device = BluetoothDevice(remoteId: DeviceIdentifier(pDevice.id));
    _connectionSubscriptions[pDevice.id] = device.connectionState.listen((state) {
      if (!mounted) return;
      final isConnected = state == BluetoothConnectionState.connected;
      final wasConnected = _deviceConnectionStatus[pDevice.id] ?? false;

      if (wasConnected != isConnected) {
        setState(() {
          _deviceConnectionStatus[pDevice.id] = isConnected;
        });

        if (isConnected) {
          _showSnackBar('${pDevice.name} に接続しました', AppColors.successColor);
          _startForegroundService();
        } else {
          _showSnackBar('${pDevice.name} との接続が切れました', AppColors.errorColor);
          final anyDeviceConnected = _deviceConnectionStatus.values.any((status) => status);
          if (!anyDeviceConnected) {
            _stopForegroundService();
          }
        }
      }

      if (!isConnected && _isInBackground) {
        NotificationService.showNotification(
          id: pDevice.id.hashCode,
          title: 'デバイス接続エラー',
          body: '${pDevice.name} との接続が切れました。',
        );
      }

      if (!isConnected && wasConnected) {
        _recordDeviceLocationOnDisconnect(pDevice.id);
      }
    });
  }

  void _setupAllDeviceListeners() {
    for (var pDevice in _pairedDevices) {
      _setupDeviceListener(pDevice);
    }
  }

  void _cancelAllDeviceListeners() {
    for (var sub in _connectionSubscriptions.values) {
      sub.cancel();
    }
    _connectionSubscriptions.clear();
  }

  Future<void> _unpairDevice(String deviceId) async {
    final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    if (device.isConnected) {
      await device.disconnect();
    }
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);
    if (!mounted) return;
    setState(() {
      _pairedDevices.removeWhere((d) => d.id == deviceId);
      _deviceConnectionStatus.remove(deviceId);
    });

    final anyDeviceConnected = _deviceConnectionStatus.values.any((status) => status);
    if (!anyDeviceConnected) {
      _stopForegroundService();
    }
    await _savePairedDevices();
    _showSnackBar('デバイスのペアリングを解除しました', AppColors.infoColor);
  }

  Future<void> _recordDeviceLocationOnDisconnect(String deviceId) async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        final index = _pairedDevices.indexWhere((d) => d.id == deviceId);
        if (index != -1) {
          final oldDevice = _pairedDevices[index];
          _pairedDevices[index] = PairedDevice(
            id: oldDevice.id,
            name: oldDevice.name,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          _showSnackBar('${oldDevice.name} の最終位置を記録しました。', AppColors.infoColor);
        }
      });
      await _savePairedDevices();
    } on Exception catch (e) {
      if (!mounted) return;
      if (e.toString().contains('LocationServiceDisabledException')) {
        _showSnackBar('位置情報サービスが無効のため、最終位置を記録できませんでした。', AppColors.warningColor);
      } else if (e.toString().contains('PermissionDeniedException')) {
        _showSnackBar('位置情報へのアクセスが拒否されているため、最終位置を記録できませんでした。', AppColors.warningColor);
      } else {
        _showSnackBar('位置情報の記録に失敗しました: ${e.toString()}', AppColors.errorColor);
      }
    }
  }

  Future<void> _initiateDeviceDiscovery() async {
    if (_isScanning) return;

    // 権限リクエスト
    if (Platform.isAndroid) {
      if (await Permission.bluetoothScan.request().isDenied ||
          await Permission.bluetoothConnect.request().isDenied) {
        _showSnackBar('Bluetooth権限が許可されていません。', AppColors.errorColor);
        return;
      }
    } else if (Platform.isIOS) {
      if (await Permission.bluetooth.request().isDenied) {
        _showSnackBar('Bluetooth権限が許可されていません。', AppColors.errorColor);
        return;
      }
    }

    if (await Permission.locationWhenInUse.request().isDenied) {
      _showSnackBar('位置情報権限が許可されていません。', AppColors.errorColor);
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _showSnackBar('Bluetoothをオンにしてください。', AppColors.errorColor);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isScanning = true;
    });
    _showSnackBar('デバイスのスキャンと接続を試行中...', AppColors.infoColor);

    try {
      await _updateDeviceConnectionStatus();
      await _performBleScan();
      if (!mounted) return;
      setState(() {});
      await _savePairedDevices();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('スキャンまたは接続中にエラーが発生しました: ${e.toString()}', AppColors.errorColor);
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
          // This SnackBar is now safe to call
        }
      } catch (_) {
        tempConnectionStatus[dev.id] = false;
      }
      _setupDeviceListener(dev);
    }

    if (!mounted) return;
    setState(() {
      _deviceConnectionStatus.clear();
      _deviceConnectionStatus.addAll(tempConnectionStatus);
    });
  }

  Future<void> _performBleScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    await FlutterBluePlus.isScanning.firstWhere((isScanning) => isScanning == false);
  }

  Future<void> _showResetConfirmationDialog() async {
    if (Platform.isIOS) {
      return showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => CupertinoAlertDialog(
          title: const Text('確認'),
          content: const Text('すべてのペアリング情報が削除されます。よろしいですか？'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('リセット'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _resetPairedDevices();
              },
            ),
          ],
        ),
      );
    } else {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
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
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: const Text('リセット', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _resetPairedDevices();
                },
              ),
            ],
          );
        },
      );
    }
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

  Widget _buildStatusCard(String title, String id, bool connected, {VoidCallback? onTap}) {
    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: AppColors.cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: connected ? AppColors.connectedColor : AppColors.disconnectedColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              connected ? 'Connected' : 'Disconnected',
              style: TextStyle(fontSize: 16, color: connected ? AppColors.connectedColor : Colors.black54),
            ),
            if (!connected && onTap != null)
              IconButton(
                icon: const Icon(Icons.location_on, color: AppColors.accentColor),
                onPressed: () {
                  _showLastKnownLocation(id);
                },
              ),
          ],
        ),
      ),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: card) : card;
  }

  Future<void> _showLastKnownLocation(String deviceId) async {
    final device = _pairedDevices.firstWhere((d) => d.id == deviceId);
    if (device.latitude != null && device.longitude != null) {
      try {
        await LocationService.showLocationOnMap(device.latitude!, device.longitude!);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('地図アプリを起動できませんでした。', AppColors.errorColor);
      }
    } else {
      _showSnackBar('このデバイスの最終位置情報は記録されていません。', AppColors.warningColor);
    }
  }

  Widget _buildBody() {
    return SafeArea(
      child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
              child: Text('接続済みデバイス', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.none)),
            ),
            ..._pairedDevices
                .where((dev) => _deviceConnectionStatus[dev.id] == true)
                .map((dev) => _buildStatusCard(
              dev.name,
              dev.id,
              _deviceConnectionStatus[dev.id] ?? false,
              onTap: () {
                final targetDevice = BluetoothDevice(remoteId: DeviceIdentifier(dev.id));
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConnectPage(device: targetDevice, onUnpair: _unpairDevice),
                  ),
                );
              },
            )),

            const Padding(
              padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
              child: Text('接続が切れたデバイス', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black,decoration: TextDecoration.none)),
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
                  _showSnackBar('${dev.name} に再接続を試行中...', AppColors.infoColor);
                  await device.connect(timeout: const Duration(seconds: 5));
                  if (!mounted) return;
                  setState(() {
                    _deviceConnectionStatus[dev.id] = true;
                  });
                  _showSnackBar('${dev.name} に再接続しました', AppColors.successColor);
                  await _savePairedDevices();
                } catch (e) {
                  if (!mounted) return;
                  _showSnackBar('${dev.name} の再接続に失敗しました', AppColors.errorColor);
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
                          if (result is PairedDevice) {
                            if (!_pairedDevices.any((d) => d.id == result.id)) {
                              if (!mounted) return;
                              final uniqueName = _generateUniqueDeviceName(result.name);
                              Position? currentPosition;
                              try {
                                currentPosition = await LocationService.getCurrentPosition();
                              } on Exception catch (e) {
                                if (!mounted) return;
                                if (e.toString().contains('LocationServiceDisabledException')) {
                                  _showSnackBar('位置情報サービスが無効のため、初期位置を記録できませんでした。', AppColors.warningColor);
                                } else if (e.toString().contains('PermissionDeniedException')) {
                                  _showSnackBar('位置情報へのアクセスが拒否されているため、初期位置を記録できませんでした。', AppColors.warningColor);
                                } else {
                                  _showSnackBar('初期位置の取得に失敗しました: ${e.toString()}', AppColors.errorColor);
                                }
                              }

                              final newDevice = PairedDevice(
                                id: result.id,
                                name: uniqueName,
                                latitude: currentPosition?.latitude,
                                longitude: currentPosition?.longitude,
                              );

                              if (!mounted) return;
                              setState(() {
                                _pairedDevices.add(newDevice);
                                _deviceConnectionStatus[result.id] = true;
                              });
                              
                              _setupDeviceListener(newDevice);

                              if (currentPosition != null) {
                                _showSnackBar('ペアリング成功: $uniqueName (初期位置を記録しました)', AppColors.successColor);
                              } else {
                                _showSnackBar('ペアリング成功: $uniqueName (位置情報は取得できませんでした)', AppColors.warningColor);
                              }
                              
                              await _savePairedDevices();
                            } else {
                              if (!mounted) return;
                              _showSnackBar(
                                  '${result.name} は既にペアリングされています', AppColors.warningColor);
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
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  label: const Text('ペアリング情報をリセット', style: TextStyle(fontSize: 16, color: Colors.white)),
                  onPressed: _showResetConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorColor,
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
    // BLEStatusScreen now builds its own Scaffold, so we just return the body.
    // The platform-specific scaffold/app bar is handled within this build method.
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
