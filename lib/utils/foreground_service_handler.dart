// lib/utils/foreground_service_handler.dart

import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundServiceHandler extends TaskHandler {
  SendPort? _sendPort;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    // You can use the sendPort to send messages back to the main isolate.
    _sendPort?.send(timestamp);
  }

  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    // This is where you would put your background BLE logic.
    // For now, we'll just send a message back to the main isolate.
    FlutterForegroundTask.updateService(
      notificationTitle: 'BLE Service',
      notificationText: 'Running in background...',
    );
    _sendPort?.send(timestamp);
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // Repeat events sent by the TaskHandler.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // Clean up any resources used by the task.
    await FlutterForegroundTask.clearAllData();
  }

  
  void onButtonPressed(String id) {
    // Called when the notification button on the Android platform is pressed.
    print('onButtonPressed >> id: $id');
    if (id == 'stopButton') {
      _sendPort?.send('stopButton');
    }
  }

  @override
  void onNotificationPressed() {
    // Called when the notification itself on the Android platform is pressed.
    FlutterForegroundTask.launchApp();
    _sendPort?.send('onNotificationPressed');
  }
}
