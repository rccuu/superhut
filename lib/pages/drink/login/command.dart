import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';

import '../../../core/ui/app_snack_bar.dart';
import 'loginpart2.dart';

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

  void _reset() {
    _captchaGeneration++;
    _doubleRandom = "0";
    _timestamp = DateTime.timestamp().millisecondsSinceEpoch.toString();
    _first = true;
    _captchaLoad = null;
  }

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

  void to2Login(BuildContext context, String phoneNumber, String imageCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DrinkLoginPage2(
              phoneNumber: phoneNumber,
              doubleRandom: _doubleRandom,
              timestamp: _timestamp,
              imageCode: imageCode,
              command: this,
            ),
      ),
    );
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
    final bool value = await api.userMessageCode(
      doubleRandom: _doubleRandom,
      photoCode: imageCode,
      phone: phoneNumber,
    );
    if (!context.mounted) {
      return;
    }

    if (value) {
      to2Login(context, phoneNumber, imageCode);
    } else {
      showAppSnackBar(context, message: '验证码错误', type: AppSnackBarType.warning);
    }
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
    final bool value = await api.userLogin(
      phone: phoneNumber,
      messageCode: code,
    );
    if (!context.mounted) {
      return;
    }

    if (value) {
      showAppSnackBar(context, message: '登录成功', type: AppSnackBarType.success);
      Navigator.pop(context);
      Navigator.pop(context);
    } else {
      showAppSnackBar(context, message: '登录失败', type: AppSnackBarType.error);
    }
  }

  // 清理方法，在页面销毁时调用
  void dispose() {
    _reset();
  }
}
