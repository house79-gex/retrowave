/// Gruppo salvato localmente (subset di MAC).
class DeviceGroup {
  DeviceGroup({required this.id, required this.name, required this.deviceMacs});

  final String id;
  final String name;
  final List<String> deviceMacs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deviceMacs': deviceMacs,
      };

  factory DeviceGroup.fromJson(Map<String, dynamic> j) {
    return DeviceGroup(
      id: j['id'] as String,
      name: j['name'] as String,
      deviceMacs: (j['deviceMacs'] as List<dynamic>).map((e) => e.toString()).toList(),
    );
  }
}
