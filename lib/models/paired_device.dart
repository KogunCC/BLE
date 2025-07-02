
class PairedDevice {
  final String id;
  final String name;

  PairedDevice({required this.id, required this.name});

  // MapからPairedDeviceオブジェクトを生成するファクトリコンストラクタ
  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    return PairedDevice(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  // PairedDeviceオブジェクトをMapに変換するメソッド
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
