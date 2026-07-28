import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:uuid/uuid.dart';

import '../core/services/app_auth_storage.dart';
import '../core/services/app_logger.dart';

part 'hut_user_api/hut_user_api_support.dart';
part 'hut_user_api/hut_user_api_auth.dart';
part 'hut_user_api/hut_user_api_session.dart';
part 'hut_user_api/hut_user_api_water.dart';
part 'hut_user_api/hut_user_api_portal.dart';

/// Result of a pure HUT SMS auth path/response helper (no storage side effects).
class HutAuthResult {
  const HutAuthResult({
    required this.success,
    this.message = '',
    this.nonce,
    this.needMfa = false,
  });

  final bool success;
  final String message;
  final String? nonce;
  final bool needMfa;
}

const String _kDefaultHutAuthFailureMessage = '操作失败，请稍后重试';

String buildHutSmsInitPath() => '/token/passwordless/smsInit';

String buildHutSmsSendPath({required String mobile, required String nonce}) {
  return '/token/passwordless/smsSend?'
      'mobile=${Uri.encodeQueryComponent(mobile)}'
      '&nonce=${Uri.encodeQueryComponent(nonce)}';
}

String buildHutSmsLoginPath({
  required String mobile,
  required String smscode,
  required String appId,
  required String deviceId,
  required String osType,
  required String geo,
  required String nonce,
}) {
  return '/token/passwordless/smsLogin?'
      'mobile=${Uri.encodeQueryComponent(mobile)}'
      '&smscode=${Uri.encodeQueryComponent(smscode)}'
      '&appId=${Uri.encodeQueryComponent(appId)}'
      '&deviceId=${Uri.encodeQueryComponent(deviceId)}'
      '&osType=${Uri.encodeQueryComponent(osType)}'
      '&geo=${Uri.encodeQueryComponent(geo)}'
      '&nonce=${Uri.encodeQueryComponent(nonce)}';
}

String normalizeHutMobile(String mobile) => mobile.trim().replaceAll(' ', '');

bool isPlausibleHutMobile(String mobile) {
  return RegExp(r'^1\d{10}$').hasMatch(normalizeHutMobile(mobile));
}

HutAuthResult parseHutSmsInitResponse(dynamic data) {
  if (data is! Map) {
    return const HutAuthResult(
      success: false,
      message: _kDefaultHutAuthFailureMessage,
    );
  }

  final envelope = Map<dynamic, dynamic>.from(data);
  final payload = envelope['data'];
  final payloadMap =
      payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
  final message = _hutAuthMessage(envelope, payloadMap);
  final needMfa = hutResponseIndicatesNeedMfa(envelope);

  if (!_isHutSuccessCode(envelope['code']) || payloadMap == null) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  final nonce = payloadMap['nonce']?.toString();
  if (nonce == null || nonce.isEmpty) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  return HutAuthResult(
    success: true,
    message: message == _kDefaultHutAuthFailureMessage ? '' : message,
    nonce: nonce,
    needMfa: needMfa,
  );
}

HutAuthResult parseHutSmsSendResponse(dynamic data) {
  if (data is! Map) {
    return const HutAuthResult(
      success: false,
      message: _kDefaultHutAuthFailureMessage,
    );
  }

  final envelope = Map<dynamic, dynamic>.from(data);
  final payload = envelope['data'];
  final payloadMap =
      payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
  final message = _hutAuthMessage(envelope, payloadMap);
  final needMfa = hutResponseIndicatesNeedMfa(envelope);

  if (!_isHutSuccessCode(envelope['code'])) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  return HutAuthResult(
    success: true,
    message: message == _kDefaultHutAuthFailureMessage ? '' : message,
    needMfa: needMfa,
  );
}

HutAuthResult parseHutSmsLoginTokenData(dynamic data) {
  if (data is! Map) {
    return const HutAuthResult(
      success: false,
      message: _kDefaultHutAuthFailureMessage,
    );
  }

  final envelope = Map<dynamic, dynamic>.from(data);
  final payload = envelope['data'];
  final payloadMap =
      payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
  final message = _hutAuthMessage(envelope, payloadMap);
  final needMfa = hutResponseIndicatesNeedMfa(envelope);

  if (!_isHutSuccessCode(envelope['code']) || payloadMap == null) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  final session = HutPortalSession.fromLoginData(payloadMap);
  if (session.token.isEmpty) {
    return HutAuthResult(success: false, message: message, needMfa: needMfa);
  }

  return HutAuthResult(
    success: true,
    message: message == _kDefaultHutAuthFailureMessage ? '' : message,
    needMfa: needMfa,
  );
}

bool hutResponseIndicatesNeedMfa(dynamic data) {
  if (data is! Map) {
    return false;
  }

  final envelope = Map<dynamic, dynamic>.from(data);
  if (_mapIndicatesNeedMfa(envelope)) {
    return true;
  }

  final payload = envelope['data'];
  if (payload is Map) {
    return _mapIndicatesNeedMfa(Map<dynamic, dynamic>.from(payload));
  }
  return false;
}

bool _isHutSuccessCode(dynamic code) => code?.toString() == '0';

bool _isTruthyHutFlag(dynamic value) {
  if (value == true || value == 1) {
    return true;
  }
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1';
}

bool _mapIndicatesNeedMfa(Map<dynamic, dynamic> map) {
  if (_isTruthyHutFlag(map['needMfa']) ||
      _isTruthyHutFlag(map['need_mfa']) ||
      _isTruthyHutFlag(map['need'])) {
    return true;
  }

  // Conservative: mfaEnabled without a parseable token still means MFA.
  if (_isTruthyHutFlag(map['mfaEnabled'])) {
    final session = HutPortalSession.fromLoginData(map);
    if (session.token.isEmpty) {
      return true;
    }
  }
  return false;
}

String _hutAuthMessage(
  Map<dynamic, dynamic> envelope, [
  Map<dynamic, dynamic>? data,
]) {
  final fromData = data?['message']?.toString().trim();
  if (fromData != null && fromData.isNotEmpty) {
    return fromData;
  }
  final fromEnvelope = envelope['message']?.toString().trim();
  if (fromEnvelope != null && fromEnvelope.isNotEmpty) {
    return fromEnvelope;
  }
  return _kDefaultHutAuthFailureMessage;
}

abstract class _HutUserApiCore {
  AppAuthStorage get _storage;
  RequestManager get _request;
  Map<String, dynamic> get _token;

  Future<bool> userLogin({required String username, required String password});

  Future<String> getToken();

  Future<String> getPortalTicket();

  Future<bool> checkTokenValidity();

  Future<List<String>> getOpenid();

  Future<_HutOpenIdSession> _getOpenIdSession();
}

class HutUserApi extends _HutUserApiCore
    with _HutAuthMixin, _HutSessionMixin, _HutWaterMixin, _HutPortalMixin {
  @override
  final AppAuthStorage _storage = AppAuthStorage.instance;

  @override
  final RequestManager _request = RequestManager();

  @override
  final Map<String, dynamic> _token = {"idToken": ""};
}
