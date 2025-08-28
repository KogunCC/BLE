import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer; // for logging

class LocationService {
  static const String _tag = "LocationService";

  // 位置情報サービスが有効か確認
  static Future<bool> isLocationServiceEnabled() async {
    developer.log('Checking if location service is enabled...', name: _tag);
    return await Geolocator.isLocationServiceEnabled();
  }

  // 位置情報パーミッションの状態を確認し、必要であれば要求する
  static Future<LocationPermission> checkAndRequestPermission() async {
    developer.log('Checking location permission...', name: _tag);
    LocationPermission permission = await Geolocator.checkPermission();
    developer.log('Initial permission status: $permission', name: _tag);

    if (permission == LocationPermission.denied) {
      developer.log('Permission denied, requesting permission...', name: _tag);
      permission = await Geolocator.requestPermission();
      developer.log('Permission status after request: $permission', name: _tag);
    }
    return permission;
  }

  // 現在位置を取得する
  static Future<Position> getCurrentPosition() async {
    developer.log('Attempting to get current position...', name: _tag);
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('Location service is not enabled.', name: _tag);
        throw const LocationServiceDisabledException();
      }

      final permission = await checkAndRequestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        developer.log('Location permission denied.', name: _tag);
        throw PermissionDeniedException('Location permission was denied.');
      }
      
      developer.log('All checks passed, getting position...', name: _tag);
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );
      Position position = await Geolocator.getCurrentPosition(locationSettings: locationSettings);
      developer.log('Got position: $position', name: _tag);
      return position;

    } on LocationServiceDisabledException {
      rethrow; // 呼び出し元で処理できるように再スロー
    } on PermissionDeniedException {
      rethrow; // 呼び出し元で処理できるように再スロー
    } catch (e) {
      developer.log('Error in getCurrentPosition: ${e.toString()}', name: _tag);
      // その他の予期せぬエラー
      throw Exception('An unexpected error occurred while getting location: ${e.toString()}');
    }
  }

  // 指定された緯度経度を地図アプリで表示する
  static Future<void> showLocationOnMap(double latitude, double longitude) async {
    try {
      final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
      developer.log('Attempting to launch URL for specific location: $googleMapsUrl', name: _tag);
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
        developer.log('URL launched successfully.', name: _tag);
      } else {
        developer.log('Could not launch URL.', name: _tag);
        throw Exception('Could not launch map application.');
      }
    } catch (e) {
      developer.log('Error in showLocationOnMap: ${e.toString()}', name: _tag);
      throw Exception('An error occurred while trying to show location on map: ${e.toString()}');
    }
  }
}
