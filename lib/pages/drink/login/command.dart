import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/api/drink_result.dart';

import '../../../core/ui/app_snack_bar.dart';
import '../core/drink_failure_prompt.dart';

/// 登录页当前所处步骤。两步在同一页面内切换，不再是两条路由。
enum DrinkLoginStep { phone, sms }

class DrinkLoginCommand {
  DrinkLoginCommand({DrinkLoginApiClient? api}) : api = api ?? DrinkApi() {
    _reset();
  }

  final DrinkLoginApiClient api;
  String _doubleRandom = "0";
  String _timestamp = "";
  bool _first = true;
  int _captchaGeneration = 0;
  Future<Uint8List>? _captchaLoad;
  Future<void>? _messageCodeSend;
  Future<void>? _loginSubmit;

  /// 当前步骤，登录页据此就地切换面板。
  final ValueNotifier<DrinkLoginStep> step = ValueNotifier<DrinkLoginStep>(
    DrinkLoginStep.phone,
  );

  /// 已提交短信验证码的手机号，短信码面板用它回显。
  final ValueNotifier<String> submittedPhone = ValueNotifier<String>('');

  /// 取一次新的图形验证码。返回空字节表示这一步不需要重新拉取。
  Future<Uint8List> getImageCaptcha() {
    final inFlight = _captchaLoad;
    if (inFlight != null) {
      return inFlight;
    }

    if (!_first) {
      return Future<Uint8List>.value(Uint8List(0));
    }

    _doubleRandom = Random().nextDouble().toString();
    final captchaGeneration = _captchaGeneration;
    late final Future<Uint8List> load;
    load = _runImageCaptchaLoad(
      captchaGeneration: captchaGeneration,
      doubleRandom: _doubleRandom,
      timestamp: _timestamp,
      currentLoad: () => load,
    );
    _captchaLoad = load;
    return load;
  }

  Future<Uint8List> _runImageCaptchaLoad({
    required int captchaGeneration,
    required String doubleRandom,
    required String timestamp,
    required Future<Uint8List> Function() currentLoad,
  }) async {
    try {
      return await _loadImageCaptcha(
        captchaGeneration: captchaGeneration,
        doubleRandom: doubleRandom,
        timestamp: timestamp,
      );
    } finally {
      if (identical(_captchaLoad, currentLoad())) {
        _captchaLoad = null;
      }
    }
  }

  Future<Uint8List> _loadImageCaptcha({
    required int captchaGeneration,
    required String doubleRandom,
    required String timestamp,
  }) async {
    final data = await api.userCaptcha(
      doubleRandom: doubleRandom,
      timestamp: timestamp,
    );
    if (captchaGeneration == _captchaGeneration) {
      _first = false;
    }
    return data;
  }

  /// 返回上一步：回到手机号面板并换一张验证码。
  ///
  /// 验证码是一次性凭据，回到第一步后旧图不能复用。
  void resetToFirstStep() {
    resetCaptcha();
    step.value = DrinkLoginStep.phone;
  }

  /// 丢弃当前图形验证码状态，下一次取图会向服务端要一张新的。
  void resetCaptcha() {
    _captchaGeneration++;
    _doubleRandom = "0";
    _timestamp = DateTime.timestamp().millisecondsSinceEpoch.toString();
    _first = true;
    _captchaLoad = null;
  }

  Future<void> sendMessageCode(
    BuildContext context,
    String phoneNumber,
    String imageCode,
  ) {
    final inFlight = _messageCodeSend;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<void> send;
    send = _runMessageCodeSend(context, phoneNumber, imageCode, () => send);
    _messageCodeSend = send;
    return send;
  }

  Future<void> _runMessageCodeSend(
    BuildContext context,
    String phoneNumber,
    String imageCode,
    Future<void> Function() currentSend,
  ) async {
    try {
      await _sendMessageCode(context, phoneNumber, imageCode);
    } finally {
      if (identical(_messageCodeSend, currentSend())) {
        _messageCodeSend = null;
      }
    }
  }

  Future<void> _sendMessageCode(
    BuildContext context,
    String phoneNumber,
    String imageCode,
  ) async {
    final DrinkResult result = await api.userMessageCode(
      doubleRandom: _doubleRandom,
      photoCode: imageCode,
      phone: phoneNumber,
    );
    if (!context.mounted) {
      return;
    }

    if (result.success) {
      submittedPhone.value = phoneNumber;
      step.value = DrinkLoginStep.sms;
      return;
    }

    // 不再一律说成「验证码错误」：服务端给了原因就用原因，
    // 请求本身没完成就明说是发送异常。
    final prompt = drinkSendFailurePrompt(result);
    showAppSnackBar(
      context,
      message: prompt.text,
      type: prompt.type,
      duration: _failureDuration(result),
    );
  }

  Future<void> login(String phoneNumber, String code, BuildContext context) {
    final inFlight = _loginSubmit;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<void> submit;
    submit = _runLoginSubmit(phoneNumber, code, context, () => submit);
    _loginSubmit = submit;
    return submit;
  }

  Future<void> _runLoginSubmit(
    String phoneNumber,
    String code,
    BuildContext context,
    Future<void> Function() currentSubmit,
  ) async {
    try {
      await _login(phoneNumber, code, context);
    } finally {
      if (identical(_loginSubmit, currentSubmit())) {
        _loginSubmit = null;
      }
    }
  }

  Future<void> _login(
    String phoneNumber,
    String code,
    BuildContext context,
  ) async {
    final DrinkResult result = await api.userLogin(
      phone: phoneNumber,
      messageCode: code,
    );
    if (!context.mounted) {
      return;
    }

    if (result.success) {
      showAppSnackBar(context, message: '登录成功', type: AppSnackBarType.success);
      Navigator.pop(context);
      return;
    }

    final prompt = drinkLoginFailurePrompt(result, fallback: '登录失败，请稍后重试');
    showAppSnackBar(
      context,
      message: prompt.text,
      type: prompt.type,
      duration: _failureDuration(result),
    );
  }

  /// 请求没跑通时留出读完原因的时间，服务端明确拒绝按默认时长即可。
  static Duration _failureDuration(DrinkResult result) {
    return result.code == null
        ? const Duration(seconds: 8)
        : const Duration(seconds: 3);
  }

  // 清理方法，在页面销毁时调用
  void dispose() {
    _reset();
    step.dispose();
    submittedPhone.dispose();
  }

  void _reset() {
    _captchaGeneration++;
    _doubleRandom = "0";
    _timestamp = DateTime.timestamp().millisecondsSinceEpoch.toString();
    _first = true;
    _captchaLoad = null;
  }
}
