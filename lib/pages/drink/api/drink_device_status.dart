import 'package:flutter/foundation.dart';

/// 设备运行状态（`ui/app/dev/status` 响应数据的解析结果）。
///
/// 字段语义经官方客户端运行时实测（上游 cc2562/superhut `61c5e076`）：
/// - `device.status`：设备链路状态，`0` 表示离线；
/// - `device.gene.status`：业务状态，`99` 空闲、`98` 禁用、其余视为运行中。
@immutable
class DrinkDeviceStatus {
  const DrinkDeviceStatus({
    required this.deviceStatus,
    required this.geneStatus,
  });

  /// 设备链路状态，`0` 表示离线。
  final int deviceStatus;

  /// 业务状态，`99` 空闲、`98` 禁用、其余视为运行中。
  final int geneStatus;

  bool get isOffline => deviceStatus == 0;

  bool get isDisabled => geneStatus == 98;

  /// 设备空闲，可以开始接水。
  bool get isAvailable => deviceStatus != 0 && geneStatus == 99;

  /// 从 `ui/app/dev/status` 的 `data` 字段解析；形状异常时按不可用处理。
  factory DrinkDeviceStatus.fromJson(dynamic data) {
    if (data is! Map) {
      return const DrinkDeviceStatus(deviceStatus: -1, geneStatus: -1);
    }
    final dynamic device = data['device'];
    final dynamic gene = device is Map ? device['gene'] : null;
    return DrinkDeviceStatus(
      deviceStatus: _toInt(device is Map ? device['status'] : null),
      geneStatus: _toInt(gene is Map ? gene['status'] : null),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }
}

/// 设备状态查询的结果：服务端码语义（与 [DrinkApi] 其他结果一致）加一个
/// 解析出的 [DrinkDeviceStatus]。
@immutable
class DeviceStatusResult {
  const DeviceStatusResult({
    required this.success,
    this.code,
    this.message,
    this.status,
  });

  /// 服务端返回码为 0 时为真。
  final bool success;

  /// 服务端返回码；请求未完成或响应无法解析时为 null。
  final int? code;

  /// 服务端返回的 `msg`；服务端没给原因、请求未完成或响应无法解析时为 null。
  final String? message;

  /// 解析出的设备状态；响应形状异常时为 null。
  final DrinkDeviceStatus? status;

  /// 登录态过期。服务端以 -99 表示。
  bool get isSessionExpired => code == -99;
}
