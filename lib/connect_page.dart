import 'dart:async';
import 'dart:math'; // pow 関数を使用するためにインポート
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:bleapp/utils/app_constants.dart';

// main.dart はこのConnectPageに遷移する際、BluetoothDeviceオブジェクトを渡す必要があります。
// 例: Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectPage(device: yourConnectedDevice)));

class ConnectPage extends StatefulWidget {
  final BluetoothDevice device; // 接続済みデバイスを受け取るためのフィールド

  // コンストラクタでデバイスを受け取るように変更
  const ConnectPage({super.key, required this.device});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

// Stateクラスのメンバー変数として宣言
class _ConnectPageState extends State<ConnectPage> {
  bool _notificationOn = false;
  String _deviceName = '接続中...';
  int? _rssi;
  // _connectedDevice はコンストラクタで受け取った widget.device を使用するため、不要
  Timer? _rssiTimer;

  @override
  void initState() {
    super.initState();
    // 渡されたデバイスから名前を設定
    _deviceName = widget.device.platformName.isNotEmpty
        ? widget.device.platformName
        : widget.device.remoteId.str;
    // RSSI監視を開始
    _startRssiMonitoring();
    // デバイスの接続状態を監視
    _listenToConnectionState();
  }

  @override
  void dispose() {
    _rssiTimer?.cancel(); // タイマーをキャンセル
    super.dispose();
  }

  // デバイスの接続状態をリッスンする
  void _listenToConnectionState() {
    widget.device.connectionState.listen((BluetoothConnectionState state) {
      if (!mounted) return; // ウィジェットがマウントされているか確認
      if (state == BluetoothConnectionState.disconnected) {
        setState(() {
          _deviceName = '${widget.device.platformName.isNotEmpty ? widget.device.platformName : widget.device.remoteId.str} (切断されました)';
          _rssi = null; // 切断されたらRSSIをクリア
        });
        _rssiTimer?.cancel(); // 切断されたらタイマーを停止
        _showOverlayMessage('デバイスが切断されました', AppColors.errorColor);
      } else if (state == BluetoothConnectionState.connected) {
         // 再接続された場合はRSSI監視を再開
         _startRssiMonitoring();
         _showOverlayMessage('デバイスが再接続されました', AppColors.successColor);
         setState(() {
            _deviceName = widget.device.platformName.isNotEmpty
                ? widget.device.platformName
                : widget.device.remoteId.str;
         });
      }
    });
  }

  // RSSIの定期的な監視を開始
  Future<void> _startRssiMonitoring() async {
    // 既存のタイマーがあればキャンセル
    _rssiTimer?.cancel();

    // デバイスが接続状態であるか確認
    if (widget.device.isConnected) {
      _rssiTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          int rssi = await widget.device.readRssi();
          if (!mounted) return; // ウィジェットがマウントされているか確認
          setState(() {
            _rssi = rssi;
          });
        } catch (e) {
          
          if (!mounted) return;
          setState(() {
            _rssi = null; // エラー発生時はRSSIをクリア
          });
        }
      });
    } else {
      // 接続されていない場合の初期表示
      if (!mounted) return;
      setState(() {
        _deviceName = '${widget.device.platformName.isNotEmpty ? widget.device.platformName : widget.device.remoteId.str} (未接続)';
        _rssi = null;
      });
    }
  }

  // 画面上部に一時的なオーバーレイメッセージを表示
  void _showOverlayMessage(String message, Color bgColor) {
    if (!mounted) return; // ウィジェットがマウントされているか確認

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
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
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
      if (overlayEntry.mounted) { // オーバーレイがまだ存在するか確認してから削除
        overlayEntry.remove();
      }
    });
  }

  // 通知オン/オフを切り替える
  void _toggleNotification() {
    setState(() {
      _notificationOn = !_notificationOn;
    });
    _showOverlayMessage(
        _notificationOn ? '通知をONにしました' : '通知をOFFにしました',
        _notificationOn ? AppColors.successColor : AppColors.errorColor);
    // ここに実際の通知設定ロジックを追加（例: デバイスの特性への書き込み）
  }

  // RSSI から推定距離（m）を計算する関数
  // この計算は一般的なモデルであり、環境やデバイスに強く依存するため、あくまで「推定」です。
  String _estimateDistance(int rssi) {
    // txPower: 1mの距離でのRSSI値（理想的な環境での測定値）
    // この値はBLEデバイスの種類や環境によって調整する必要があります。
    const int txPower = -59;
    // N: 環境要因。通常2〜4の範囲。2は屋外、4は壁が多い屋内。
    // ここでは一般的な値として2.0を使用しています。
    const double n = 2.0;

    if (rssi == 0) {
      return "不明"; // RSSIが0の場合は距離を計算できない
    }

    // 距離計算式: d = 10^((TxPower - RSSI) / (10 * N))
    double distance = pow(10, (txPower - rssi) / (10 * n)).toDouble();

    return distance.toStringAsFixed(2); // 小数第2位まで表示
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('接続状態', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), // アイコンの色も白に
          onPressed: () {
            // 前の画面に戻る（main.dartのMyAppを再生成しない）
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _deviceName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
                textAlign: TextAlign.center, // 中央揃え
              ),
              const SizedBox(height: 20),
              Text(
                _rssi != null ? 'RSSI強度: $_rssi dBm' : 'RSSI未取得',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 10),
              // RSSIが取得できている場合のみ推定距離を表示
              if (_rssi != null)
                Text(
                  '推定距離: ${_estimateDistance(_rssi!)} m',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textColor,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                _rssi != null && _deviceName != '接続されたデバイスがありません (未接続)' ? '接続済み' : '未接続', // RSSIが取得できていれば「接続済み」
                style: TextStyle(
                    fontSize: 18,
                    color: (_rssi != null && _deviceName != '接続されたデバイスがありません (未接続)') ? AppColors.textColor : AppColors.errorColor), // 未接続なら赤色
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _toggleNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _notificationOn ? AppColors.successColor : AppColors.disconnectedColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _notificationOn ? '通知をOFFにする' : '通知をONにする',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startRssiMonitoring, // 再スキャンではなくRSSI監視を再開
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'RSSIを更新', // テキストを「RSSIを更新」に変更
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
