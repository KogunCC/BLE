
class PairedDevice {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  PairedDevice({required this.id, required this.name, this.latitude, this.longitude});

  // MapからPairedDeviceオブジェクトを生成するファクトリコンストラクタ
  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    return PairedDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
    );
  }

  // PairedDeviceオブジェクトをMapに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
