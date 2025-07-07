// conect_page.dart
//RSSIの取得と表示、通知のオン/オフ切り替え、接続状態の監視を行う

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // pow 関数を使用するためにインポート
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:bleapp/utils/app_constants.dart';

// main.dart はこのConnectPageに遷移する際、BluetoothDeviceオブジェクトを渡す必要があります。
// 例: Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectPage(device: yourConnectedDevice)));

class ConnectPage extends StatefulWidget {
  final BluetoothDevice device; // 接続済みデバイスを受け取るためのフィールド
  final Future<void> Function(String) onUnpair; // ペアリング解除のためのコールバック関数

  // コンストラクタでデバイスとコールバックを受け取るように変更
  const ConnectPage({super.key, required this.device, required this.onUnpair});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

// Stateクラスのメンバー変数として宣言
class _ConnectPageState extends State<ConnectPage> {
  bool _notificationOn = false;
  String _deviceName = '接続中...';
  int? _rssi;
  String? _batteryVoltage;
  StreamSubscription<List<int>>? _batterySubscription;
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
    // サービスを探索し、バッテリー電圧の通知を購読
    _discoverServicesAndSubscribe();
  }

  @override
  void dispose() {
    _rssiTimer?.cancel(); // タイマーをキャンセル
    _batterySubscription?.cancel(); // バッテリー通知の購読をキャンセル
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
          _batteryVoltage = null; // 切断されたらバッテリー電圧をクリア
        });
        _rssiTimer?.cancel(); // 切断されたらタイマーを停止
        _showOverlayMessage('デバイスが切断されました', AppColors.errorColor);
      } else if (state == BluetoothConnectionState.connected) {
         // 再接続された場合はRSSI監視とサービス探索を再開
         _startRssiMonitoring();
         _discoverServicesAndSubscribe();
         _showOverlayMessage('デバイスが再接続されました', AppColors.successColor);
         setState(() {
            _deviceName = widget.device.platformName.isNotEmpty
                ? widget.device.platformName
                : widget.device.remoteId.str;
         });
      }
    });
  }

  // サービスを探索し、バッテリー電圧キャラクタリスティックを入手する
  Future<void> _discoverServicesAndSubscribe() async {
    if (!widget.device.isConnected) return;

    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        if (service.uuid.str.toLowerCase() == BleUuids.featherTagService) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.str.toLowerCase() == BleUuids.batteryVoltageCharacteristic) {
              // 初期の電圧を読み取り
              List<int> value = await characteristic.read();
              if(mounted) {
                setState(() {
                  _batteryVoltage = utf8.decode(value);
                });
              }
              // 通知を購読
              await characteristic.setNotifyValue(true);
              _batterySubscription = characteristic.onValueReceived.listen((value) {
                if (mounted) {
                  setState(() {
                    _batteryVoltage = utf8.decode(value);
                  });
                }
              });
              return; // キャラクタリスティックが見つかったらループを抜ける
            }
          }
        }
      }
    } catch (e) {
      _showOverlayMessage('サービスの探索に失敗しました: ${e.toString()}', AppColors.errorColor);
    }
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

  Widget _buildBody() {
    return Center(
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
              // バッテリー電圧を表示
              Text(
                _batteryVoltage != null ? 'バッテリー容量: $_batteryVoltage V' : 'バッテリー容量: 未取得',
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
              if (Platform.isIOS)
                CupertinoButton(
                  onPressed: _toggleNotification,
                  color: _notificationOn ? CupertinoColors.activeGreen : CupertinoColors.destructiveRed,
                  child: Text(
                    _notificationOn ? '通知をOFFにする' : '通知をONにする',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                )
              else
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
              if (Platform.isIOS)
                CupertinoButton(
                  onPressed: _startRssiMonitoring,
                  color: CupertinoColors.activeBlue,
                  child: const Text(
                    'RSSIを更新',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                )
              else
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
              const SizedBox(height: 20),
              // ペアリング解除ボタン
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off, color: Colors.white),
                label: const Text('ペアリングを解除', style: TextStyle(fontSize: 16, color: Colors.white)),
                onPressed: _showUnpairConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorColor,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ペアリング解除の確認ダイアログを表示
  Future<void> _showUnpairConfirmationDialog() async {
    if (Platform.isIOS) {
      return showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('確認'),
          content: const Text('このデバイスとのペアリングを解除します。よろしいですか？'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('解除する'),
              onPressed: () async {
                print("ペアリング解除ボタンが押されました。");
                Navigator.of(context).pop(); // ダイアログを閉じる
                await widget.onUnpair(widget.device.remoteId.str); // コールバックを実行
                if (!mounted) return; // 非同期処理後にウィジェットがまだ存在するか確認
                Navigator.of(context).pop(); // ConnectPageを閉じてメイン画面に戻る
              },
            ),
          ],
        ),
      );
    } else {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('確認'),
            content: const SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text('このデバイスとのペアリングを解除します。'),
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
                child: const Text('解除する', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  print("ペアリング解除ボタンが押されました。");
                  Navigator.of(context).pop(); // ダイアログを閉じる
                  await widget.onUnpair(widget.device.remoteId.str); // コールバックを実行
                  if (!mounted) return; // 非同期処理後にウィジェットがまだ存在するか確認
                  Navigator.of(context).pop(); // ConnectPageを閉じてメイン画面に戻る
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('接続状態'),
          leading: CupertinoNavigationBarBackButton(
            onPressed: () => Navigator.pop(context),
          ),
        ),
        child: _buildBody(),
      );
    } else {
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
        body: _buildBody(),
      );
    }
  }
}
