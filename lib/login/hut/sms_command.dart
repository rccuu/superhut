import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../utils/hut_user_api.dart';

typedef HutSmsInit = Future<HutAuthResult> Function();
typedef HutSmsSend = Future<HutAuthResult> Function({
  required String mobile,
  required String nonce,
});
typedef HutSmsLogin = Future<HutAuthResult> Function({
  required String mobile,
  required String smscode,
  required String nonce,
});

class HutSmsLoginCommand {
  HutSmsLoginCommand({
    HutSmsInit? smsInit,
    HutSmsSend? smsSend,
    HutSmsLogin? smsLogin,
    this.countdownSeconds = 60,
  })  : _smsInit = smsInit ?? (() => HutUserApi().smsInit()),
        _smsSend = smsSend ??
            (({required mobile, required nonce}) {
              return HutUserApi().smsSend(mobile: mobile, nonce: nonce);
            }),
        _smsLogin = smsLogin ??
            (({required mobile, required smscode, required nonce}) {
              return HutUserApi().smsLogin(
                mobile: mobile,
                smscode: smscode,
                nonce: nonce,
              );
            });

  final int countdownSeconds;
  final HutSmsInit _smsInit;
  final HutSmsSend _smsSend;
  final HutSmsLogin _smsLogin;

  Timer? _timer;
  int _remainingSeconds = 0;
  String? _activeNonce;
  Future<HutAuthResult>? _requestInFlight;
  Future<HutAuthResult>? _loginInFlight;
  bool _disposed = false;

  VoidCallback? onCountdownChanged;

  int get remainingSeconds => _remainingSeconds;
  bool get isSending => _requestInFlight != null;
  bool get isLoggingIn => _loginInFlight != null;

  @visibleForTesting
  String? get activeNonce => _activeNonce;

  Future<HutAuthResult> requestCode(String mobile) {
    final normalized = normalizeHutMobile(mobile);
    if (!isPlausibleHutMobile(normalized)) {
      return Future.value(
        const HutAuthResult(success: false, message: '请输入正确的手机号'),
      );
    }

    if (_remainingSeconds > 0) {
      return Future.value(
        const HutAuthResult(success: false, message: '请稍后再获取验证码'),
      );
    }

    final inFlight = _requestInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<HutAuthResult> request;
    request = _runRequestCode(normalized, () => request);
    _requestInFlight = request;
    return request;
  }

  Future<HutAuthResult> _runRequestCode(
    String mobile,
    Future<HutAuthResult> Function() currentRequest,
  ) async {
    try {
      final initResult = await _smsInit();
      if (!initResult.success) {
        return initResult;
      }

      final nonce = initResult.nonce;
      if (nonce == null || nonce.isEmpty) {
        return const HutAuthResult(
          success: false,
          message: '获取验证码失败，请稍后重试',
        );
      }

      _activeNonce = nonce;

      final sendResult = await _smsSend(mobile: mobile, nonce: nonce);
      if (sendResult.success) {
        _startCountdown();
      }
      return sendResult;
    } finally {
      if (identical(_requestInFlight, currentRequest())) {
        _requestInFlight = null;
      }
    }
  }

  Future<HutAuthResult> login({
    required String mobile,
    required String smscode,
  }) {
    final nonce = _activeNonce;
    if (nonce == null || nonce.isEmpty) {
      return Future.value(
        const HutAuthResult(success: false, message: '请先获取验证码'),
      );
    }

    final inFlight = _loginInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final normalized = normalizeHutMobile(mobile);
    late final Future<HutAuthResult> submit;
    submit = _runLogin(
      mobile: normalized,
      smscode: smscode,
      nonce: nonce,
      currentLogin: () => submit,
    );
    _loginInFlight = submit;
    return submit;
  }

  Future<HutAuthResult> _runLogin({
    required String mobile,
    required String smscode,
    required String nonce,
    required Future<HutAuthResult> Function() currentLogin,
  }) async {
    try {
      final result = await _smsLogin(
        mobile: mobile,
        smscode: smscode,
        nonce: nonce,
      );
      if (!result.success && _isNonceExpiredMessage(result.message)) {
        _activeNonce = null;
        return HutAuthResult(
          success: false,
          message: result.message.isEmpty
              ? '验证码已失效，请重新获取'
              : '${result.message}，请重新获取',
          needMfa: result.needMfa,
        );
      }
      return result;
    } finally {
      if (identical(_loginInFlight, currentLogin())) {
        _loginInFlight = null;
      }
    }
  }

  bool _isNonceExpiredMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('过期') ||
        lower.contains('失效') ||
        lower.contains('无效') ||
        lower.contains('expire');
  }

  void _startCountdown() {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _remainingSeconds = countdownSeconds;
    onCountdownChanged?.call();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapseSecond();
    });
  }

  void _elapseSecond() {
    if (_disposed) {
      return;
    }
    if (_remainingSeconds <= 1) {
      _remainingSeconds = 0;
      _timer?.cancel();
      _timer = null;
    } else {
      _remainingSeconds -= 1;
    }
    onCountdownChanged?.call();
  }

  @visibleForTesting
  void debugElapseSecond() => _elapseSecond();

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    onCountdownChanged = null;
  }
}
