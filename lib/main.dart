// main.dart (Overlayエラー修正)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connect_page.dart'; // connect_page.dart が存在すると仮定
import 'pairing.dart';     // pairing.dart が存在すると仮定

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Status',
      home: const BLEStatusScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/paring': (context) => const ParingPage(),
      },
    );
  }
}

class BLEStatusScreen extends StatefulWidget {
  const BLEStatusScreen({super.key});

  @override
  State<BLEStatusScreen> createState() => _BLEStatusScreenState();
}

class _BLEStatusScreenState extends State<BLEStatusScreen> {
  List<Map<String, String>> _pairedDevices = [];
  List<Map<String, String>> _disconnectedDevices = [];
  bool _isScanning = false;
  final Map<String, bool> _deviceConnectionStatus = {};

  @override
  void initState() {
    super.initState();
    _loadPairedDevices();
    // ここで直接_startScanを呼び出すのではなく、
    // 次のフレームで実行されるようにスケジュールする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

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

  Future<void> _startScan() async {
    if (_isScanning) return;
    if (!mounted) return;

    setState(() {
      _isScanning = true;
      _showOverlayMessage('デバイスのスキャンと接続を試行中...', Colors.blue); // この呼び出しも遅延処理が必要
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
          // ここも遅延させる
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverlayMessage('${dev['name']} に接続しました', Colors.green);
          });
        } catch (e) {
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
          // ここも遅延させる
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverlayMessage('${dev['name']} に再接続しました', Colors.green);
          });
        } catch (e) {
          // currentConnectionStatus[dev['id']!] = false;
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
      WidgetsBinding.instance.addPostFrameCallback((_) { // ここも遅延させる
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
            onTap: () {
              // ここで実際に接続されたBluetoothDeviceインスタンスを渡す必要があります
              // DevideIdentifierからBluetoothDeviceを再構築
              final bluetoothDevice = BluetoothDevice(remoteId: DeviceIdentifier(dev['id']!));
              // ConnectPage に BluetoothDevice オブジェクトを渡す
              Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectPage(device: bluetoothDevice)));
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
                WidgetsBinding.instance.addPostFrameCallback((_) { // ここも遅延させる
                  _showOverlayMessage('${dev['name']} に再接続を試行中...', Colors.blue);
                });
                await device.connect(timeout: const Duration(seconds: 5));
                if (!mounted) return;
                setState(() {
                  _pairedDevices.add(dev);
                  _disconnectedDevices.removeWhere((d) => d['id'] == dev['id']);
                  _deviceConnectionStatus[dev['id']!] = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) { // ここも遅延させる
                  _showOverlayMessage('${dev['name']} に再接続しました', Colors.green);
                });
                await _savePairedDevices();
              } catch (e) {
                if (!mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) { // ここも遅延させる
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
                        WidgetsBinding.instance.addPostFrameCallback((_) { // ここも遅延させる
                          _showOverlayMessage('ペアリング成功: $name', Colors.green);
                        });
                        await _savePairedDevices();
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) { // ここも遅延させる
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
