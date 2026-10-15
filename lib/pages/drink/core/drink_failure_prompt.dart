import '../../../core/ui/app_snack_bar.dart';
import '../api/drink_result.dart';

/// 一条 798 提示的呈现内容。
class DrinkPrompt {
  const DrinkPrompt({
    required this.title,
    required this.message,
    required this.type,
  });

  final String title;
  final String message;
  final AppSnackBarType type;

  /// 消息条正文：与本页其它提示同形制（标题：正文）。
  String get text => '$title：$message';
}

/// 把服务端返回转成用户可读的提示。
///
/// 登录态过期（`code == -99`）单独引导重新登录；其他失败透出服务端 `msg`；
/// 两者都缺失时退回 [fallback]，不再一律提示设备无响应。
DrinkPrompt drinkFailurePrompt(DrinkResult result, {required String fallback}) {
  if (result.isSessionExpired) {
    return const DrinkPrompt(
      title: '登录已过期',
      message: '请重新登录后再试',
      type: AppSnackBarType.warning,
    );
  }

  return DrinkPrompt(
    title: '操作失败',
    message: result.message ?? fallback,
    type: AppSnackBarType.error,
  );
}

/// 登录失败提示。
///
/// `code` 为 null 说明请求根本没完成或响应无法解析，标题要说成「登录异常」，
/// 否则用户会以为是自己输错了验证码。
DrinkPrompt drinkLoginFailurePrompt(
  DrinkResult result, {
  required String fallback,
}) {
  return DrinkPrompt(
    title: result.code == null ? '登录异常' : '登录失败',
    message: result.message ?? fallback,
    type: AppSnackBarType.error,
  );
}

/// 短信验证码发送失败提示。服务端拒绝时用服务端原因，不再一律说成「图形验证码错误」。
DrinkPrompt drinkSendFailurePrompt(DrinkResult result) {
  return DrinkPrompt(
    title: result.code == null ? '发送异常' : '发送失败',
    message: result.message ?? '短信验证码发送失败，请稍后重试',
    type: AppSnackBarType.error,
  );
}
