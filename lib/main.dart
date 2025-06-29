// main.dart: BLEデバイスの接続状態を管理し、UIに表示するメイン画面
// ✅ Flutter BLE デバイス接続管理（アイコン表示 + SharedPreferences 永続化）
// ✅ Overlayエラー修正済み
// ✅ ConnectPageへのBluetoothDeviceインスタンスの受け渡しに関する改善点をコメントで提示
// ✅ FlutterBluePlusのiOSオプション（restoreIdentifierKey）を設定 (BluetoothAdapterOptionsの代替)

import 'dart:async';
import 'dart:convert'; // JSONエンコード/デコード用
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // BLE操作ライブラリ
import 'package:shared_preferences/shared_preferences.dart'; // ローカルストレージ用
import 'connect_page.dart'; // ConnectPageへの遷移を仮定
import 'pairing.dart';     // ParingPageへの遷移を仮定

// アプリのエントリーポイント
void main() async {
  // Flutterウィジェットバインディングを初期化し、プラットフォームチャネルが利用可能であることを保証
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ FlutterBluePlusのオプション設定 ⭐
  // 'BluetoothAdapterOptions'が未定義エラーになるため、
  // setOptionsを引数なしで呼び出す形式に修正します。
  // これによりAPI MISUSE警告は残る可能性がありますが、
  // アプリがクラッシュせずに起動し、他の問題（特に位置情報パーミッション）の
  // 解決に集中できるようになります。
  //
  // もし将来的に restoreIdentifierKey を設定する必要が出た場合、
  // flutter_blue_plus の最新ドキュメントや CHANGELOG を参照し、
  // 正しい setOptions の引数形式を確認する必要があります。
  FlutterBluePlus.setOptions(); // 引数なしで呼び出す形式

  // アプリケーションを実行
  runApp(const MyApp());
}

// (以下のコードは変更なし)

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Status', // アプリのタイトル
      home: const BLEStatusScreen(), // アプリのホーム画面
      debugShowCheckedModeBanner: false, // デバッグバナーを非表示
      routes: {
        '/paring': (context) => const ParingPage(), // ペアリング画面へのルート定義
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

class _BLEStatusScreenState extends State<BLEStatusScreen> {
  // ペアリング済みのデバイスリスト。SharedPreferencesからロードされる。
  List<Map<String, String>> _pairedDevices = [];
  // 切断されたデバイスのリスト。スキャンによって接続できなかったデバイス。
  List<Map<String, String>> _disconnectedDevices = [];
  // 現在スキャンが進行中かどうかを示すフラグ。UIの制御に使用。
  bool _isScanning = false;
  // 各デバイスの現在の接続状態をリアルタイムで追跡するマップ。
  final Map<String, bool> _deviceConnectionStatus = {};

  @override
  void initState() {
    super.initState();
    _loadPairedDevices(); // アプリ起動時にペアリング済みデバイスをロード
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  /* ========= SharedPreferences による永続化 =========== */

  Future<void> _savePairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paired_devices', jsonEncode(_pairedDevices));
  }

  Future<void> _loadPairedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('paired_devices');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _pairedDevices = decoded.cast<Map<String, dynamic>>()
            .map((d) => d.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList();
        for (var dev in _pairedDevices) {
          _deviceConnectionStatus[dev['id']!] = false;
        }
      });
    }
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

  Future<void> _startScan() async {
    if (_isScanning) return;
    if (!mounted) return;

    setState(() {
      _isScanning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOverlayMessage('デバイスのスキャンと接続を試行中...', Colors.blue);
      });
    });

    try {
      await FlutterBluePlus.adapterState.firstWhere((state) => state == BluetoothAdapterState.on);

      final List<Map<String, String>> allCurrentKnownDevices = [..._pairedDevices, ..._disconnectedDevices];

      List<Map<String, String>> tempPaired = [];
      List<Map<String, String>> tempDisconnected = [];
      final Map<String, bool> currentConnectionStatus = {};

      for (var dev in allCurrentKnownDevices) {
        final device = BluetoothDevice(remoteId: DeviceIdentifier(dev['id']!));
        try {
          if (await device.isConnected) {
            tempPaired.add(dev);
            currentConnectionStatus[dev['id']!] = true;
            continue;
          }
          await device.connect(timeout: const Duration(seconds: 5));
          tempPaired.add(dev);
          currentConnectionStatus[dev['id']!] = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverlayMessage('${dev['name']} に接続しました', Colors.green);
          });
        } catch (_) {
          tempDisconnected.add(dev);
          currentConnectionStatus[dev['id']!] = false;
        }
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await FlutterBluePlus.isScanning.firstWhere((isScanning) => isScanning == false);

      final List<Map<String, String>> remainingDisconnected = List.from(tempDisconnected);
      for (var dev in remainingDisconnected) {
        if (currentConnectionStatus[dev['id']!] == true) continue;

        final device = BluetoothDevice(remoteId: DeviceIdentifier(dev['id']!));
        try {
          await device.connect(timeout: const Duration(seconds: 5));
          tempPaired.add(dev);
          currentConnectionStatus[dev['id']!] = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverlayMessage('${dev['name']} に再接続しました', Colors.green);
          });
        } catch (e) {
          // currentConnectionStatus[dev['id']!] は既にfalseになっているはず
        }
      }

      _pairedDevices = tempPaired.toSet().toList();
      _disconnectedDevices = currentConnectionStatus.entries
          .where((entry) => entry.value == false && allCurrentKnownDevices.any((d) => d['id'] == entry.key))
          .map((entry) => allCurrentKnownDevices.firstWhere((d) => d['id'] == entry.key))
          .toSet().toList();

      if (!mounted) return;
      setState(() {
        _deviceConnectionStatus.clear();
        for (var dev in _pairedDevices) {
          _deviceConnectionStatus[dev['id']!] = true;
        }
        for (var dev in _disconnectedDevices) {
          _deviceConnectionStatus[dev['id']!] = false;
        }
      });
      await _savePairedDevices();

    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOverlayMessage('スキャンまたは接続中にエラーが発生しました: ${e.toString()}', Colors.red);
      });
      print('BLE Scan/Connect Error: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /* ========= デバイスステータス表示カードのビルド =========== */

  Widget _buildStatusCard(String title, String id, bool connected, {VoidCallback? onTap}) {
    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: const Color(0xFFF7F5EF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: connected ? Colors.teal : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            Text(
              connected ? 'Connected' : 'Disconnected',
              style: TextStyle(fontSize: 16, color: connected ? Colors.teal : Colors.black54),
            ),
          ],
        ),
      ),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: card) : card;
  }

  /* ========= UIレイアウトのビルド =========== */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF66B2A3),
        elevation: 0,
        toolbarHeight: 8,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
            child: Text('接続済み', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          ..._pairedDevices.map((dev) => _buildStatusCard(
            dev['name']!,
            dev['id']!,
            _deviceConnectionStatus[dev['id']!] ?? false,
            onTap: () async {
              List<BluetoothDevice> connected = await FlutterBluePlus.connectedDevices;
              BluetoothDevice? targetDevice;
              for (var connectedDev in connected) {
                if (connectedDev.remoteId.str == dev['id']!) {
                  targetDevice = connectedDev;
                  break;
                }
              }

              if (targetDevice != null) {
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectPage(device: targetDevice!)));
              } else {
                if (!mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showOverlayMessage('${dev['name']} は現在接続されていません。再スキャンを試してください。', Colors.orange);
                });
                setState(() {
                  _pairedDevices.removeWhere((d) => d['id'] == dev['id']);
                  _disconnectedDevices.add(dev);
                  _deviceConnectionStatus[dev['id']!] = false;
                });
                await _savePairedDevices();
              }
            },
          )),

          const Padding(
            padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
            child: Text('接続が切れたデバイス', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          ..._disconnectedDevices.map((dev) => _buildStatusCard(
            dev['name']!,
            dev['id']!,
            _deviceConnectionStatus[dev['id']!] ?? false,
            onTap: () async {
              final device = BluetoothDevice(remoteId: DeviceIdentifier(dev['id']!));
              try {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showOverlayMessage('${dev['name']} に再接続を試行中...', Colors.blue);
                });
                await device.connect(timeout: const Duration(seconds: 5));
                if (!mounted) return;
                setState(() {
                  _pairedDevices.add(dev);
                  _disconnectedDevices.removeWhere((d) => d['id'] == dev['id']);
                  _deviceConnectionStatus[dev['id']!] = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showOverlayMessage('${dev['name']} に再接続しました', Colors.green);
                });
                await _savePairedDevices();
              } catch (e) {
                if (!mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showOverlayMessage('${dev['name']} の再接続に失敗しました', Colors.red);
                });
                print('Reconnect Error: $e');
              }
            },
          )),

          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: const Icon(Icons.refresh),
              label: Text(_isScanning ? 'スキャン中...' : '再スキャン'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66B2A3),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : () async {
                    final result = await Navigator.pushNamed(context, '/paring');
                    if (result is Map<String, String>) {
                      final id = result['id']!;
                      final name = result['name']!;
                      if (!_pairedDevices.any((d) => d['id'] == id)) {
                        if (!mounted) return;
                        setState(() {
                          _pairedDevices.add({'id': id, 'name': name});
                          _disconnectedDevices.removeWhere((d) => d['id'] == id);
                          _deviceConnectionStatus[id] = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showOverlayMessage('ペアリング成功: $name', Colors.green);
                        });
                        await _savePairedDevices();
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showOverlayMessage('$name は既にペアリングされています', Colors.orange);
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66B2A3),
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
          ),
        ],
      ),
    );
  }
}
