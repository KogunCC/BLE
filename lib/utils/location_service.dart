
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bleapp/utils/app_constants.dart';

class LocationService {
  // 位置情報サービスが有効か確認し、無効な場合はユーザーに有効化を促す
  static Future<bool> _checkLocationServiceEnabled(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showOverlayMessage(context, '位置情報サービスが無効です。有効にしてください。', AppColors.errorColor);
      return false;
    }
    return true;
  }

  // 位置情報パーミッションの状態を確認し、必要であれば要求する
  static Future<bool> _checkLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showOverlayMessage(context, '位置情報へのアクセスが拒否されました。', AppColors.errorColor);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showOverlayMessage(context, '位置情報へのアクセスが永続的に拒否されています。設定から許可してください。', AppColors.errorColor);
      return false;
    }
    return true;
  }

  // 現在位置を取得し、地図アプリで表示する
  static Future<void> showCurrentLocation(BuildContext context) async {
    _showOverlayMessage(context, '現在位置を取得中...', AppColors.infoColor);
    try {
      Position? position = await getCurrentPosition(context);
      if (position == null) return;

      final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
      } else {
        _showOverlayMessage(context, '地図アプリを起動できませんでした。', AppColors.errorColor);
      }
    } catch (e) {
      _showOverlayMessage(context, '現在位置の取得中にエラーが発生しました: ${e.toString()}', AppColors.errorColor);
    }
  }

  // 現在位置を取得する
  static Future<Position?> getCurrentPosition(BuildContext context) async {
    try {
      if (!await _checkLocationServiceEnabled(context) || !await _checkLocationPermission(context)) {
        return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      _showOverlayMessage(context, '位置情報の取得中にエラーが発生しました: ${e.toString()}', AppColors.errorColor);
      return null;
    }
  }

  // 指定された緯度経度を地図アプリで表示する
  static Future<void> showLocationOnMap(BuildContext context, double latitude, double longitude) async {
    try {
      final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
      } else {
        _showOverlayMessage(context, '地図アプリを起動できませんでした。', AppColors.errorColor);
      }
    } catch (e) {
      _showOverlayMessage(context, '位置情報の表示中にエラーが発生しました: ${e.toString()}', AppColors.errorColor);
    }
  }

  // 画面上部に一時的なオーバーレイメッセージを表示
  static void _showOverlayMessage(BuildContext context, String message, Color bgColor) {
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
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}
