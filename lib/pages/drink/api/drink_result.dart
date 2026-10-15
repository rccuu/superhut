/// 798 设备操作与登录的结果。
///
/// 携带服务端返回码与信息文案，使调用方能区分「登录已过期」「设备离线」
/// 「余额不足」等不同原因，而不是一律提示设备无响应。
class DrinkResult {
  const DrinkResult({required this.success, this.code, this.message});

  /// 服务端返回码为 0 时为真。
  final bool success;

  /// 服务端返回码；请求未完成或响应无法解析时为 null。
  final int? code;

  /// 服务端返回的 `msg`；服务端没给原因、请求未完成或响应无法解析时为 null。
  final String? message;

  /// 登录态过期。服务端以 -99 表示。
  bool get isSessionExpired => code == -99;
}
