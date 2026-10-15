/// 798 设备行的轻量存取。
///
/// 设备行沿用服务端 `favos` 的 Map 形状（`id` / `name`），顺序与备注都以
/// `id` 为键，因此这里只集中放取 id、取名称和排序三件事，不再引入一层模型。
library;

String drinkDeviceId(dynamic device) {
  if (device is! Map) {
    return '';
  }
  return device['id']?.toString() ?? '';
}

String drinkDeviceName(dynamic device) {
  if (device is! Map) {
    return '未知设备';
  }
  return device['name']?.toString() ?? '未知设备';
}

/// 按 [orderIds] 重排 [devices]。
/// - 已知名按 [orderIds] 中的相对顺序排前
/// - 未知名保持原有相对顺序追加在后
/// - [orderIds] 中已不存在的 id 忽略
List<Map> applyDrinkDeviceOrder(List<Map> devices, List<String> orderIds) {
  if (devices.isEmpty) return <Map>[];
  if (orderIds.isEmpty) return List<Map>.from(devices);

  final byId = <String, Map>{
    for (final device in devices)
      if (drinkDeviceId(device).isNotEmpty) drinkDeviceId(device): device,
  };

  final ordered = <Map>[];
  final used = <String>{};

  for (final id in orderIds) {
    final device = byId[id];
    if (device == null || !used.add(id)) continue;
    ordered.add(device);
  }

  for (final device in devices) {
    final id = drinkDeviceId(device);
    if (id.isEmpty || used.contains(id)) continue;
    ordered.add(device);
    used.add(id);
  }

  return ordered;
}
