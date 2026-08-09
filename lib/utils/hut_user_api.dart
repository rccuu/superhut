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
  String clientId = 'CLIENT_ID',
}) {
  return '/token/passwordless/smsLogin?'
      'mobile=${Uri.encodeQueryComponent(mobile)}'
      '&smscode=${Uri.encodeQueryComponent(smscode)}'
      '&appId=${Uri.encodeQueryComponent(appId)}'
      '&deviceId=${Uri.encodeQueryComponent(deviceId)}'
      '&osType=${Uri.encodeQueryComponent(osType)}'
      '&geo=${Uri.encodeQueryComponent(geo)}'
      '&nonce=${Uri.encodeQueryComponent(nonce)}'
      '&clientId=${Uri.encodeQueryComponent(clientId)}';
}

/// Path for the federation binding step that mints the final HUT session
/// token from the intermediate `smsLogin` idToken.
///
/// Reverse-engineered from the official iOS client: after `passwordless/smsLogin`
/// returns an intermediate `data.idToken`, the official app POSTs to
/// `/token/federation/federatedBinding` with `X-Id-Token: <idToken>` and a
/// form body containing `nonce`. The response's `data.idToken` is the token
/// actually persisted and used by `userOnlineDetect` / CAS. Skipping this step
/// leaves the session in an intermediate state that mycas rejects as invalid.
String buildHutFederatedBindingPath() => '/token/federation/federatedBinding';

String normalizeHutMobile(String mobile) => mobile.trim().replaceAll(' ', '');

/// Chooses the `username` query value for `userOnlineDetect`.
///
/// Password/SMS HUT sessions are both identified by a token-bearing session,
/// but only password login persists `hutUsername`. SMS login persists
/// `hutMobile` instead. mycas rejects an empty username with
/// `{"code":-1,"message":"请求不合法","error":{"error":"请求不合法（username error）"}}`,
/// which made [checkTokenValidity] falsely invalidate an otherwise-valid fresh
/// SMS idToken — the root cause of the post-login
/// "智慧工大登录状态已失效，请重新登录后再试" screen.
///
/// Falls back to the bound mobile so SMS sessions keep a non-empty username.
String resolveHutOnlineDetectUsername(String username, String mobile) {
  final user = username.trim();
  if (user.isNotEmpty) {
    return user;
  }
  return mobile.trim();
}

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

  // Some deployments rotate/echo nonce on send success; prefer it when present.
  final sendNonce = payloadMap?['nonce']?.toString();
  return HutAuthResult(
    success: true,
    message: message == _kDefaultHutAuthFailureMessage ? '' : message,
    nonce: (sendNonce != null && sendNonce.isNotEmpty) ? sendNonce : null,
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

const String _kHutSmsSessionInvalidMessage = '验证码已失效，请重新获取';

/// True when mycas returned a bare/opaque failure that usually means the SMS
/// session (nonce) is no longer usable for login.
bool isHutSmsSessionInvalidMessage(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final lower = trimmed.toLowerCase();
  if (lower == 'bad request' ||
      lower == 'badrequest' ||
      lower.contains('nonce invalid') ||
      lower.contains('nonce expire') ||
      lower.contains('invalid nonce')) {
    return true;
  }
  return trimmed == '请求无效' ||
      trimmed == '请求参数错误' ||
      trimmed.contains('验证码已失效') ||
      trimmed.contains('验证码已过期') ||
      trimmed.contains('验证码失效') ||
      trimmed.contains('验证码过期') ||
      (trimmed.contains('nonce') &&
          (trimmed.contains('无效') ||
              trimmed.contains('过期') ||
              trimmed.contains('失效')));
}

String localizeHutAuthMessage(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return _kDefaultHutAuthFailureMessage;
  }
  if (isHutSmsSessionInvalidMessage(trimmed)) {
    return _kHutSmsSessionInvalidMessage;
  }

  final lower = trimmed.toLowerCase();
  if (lower.contains('phone number not equals') ||
      trimmed.contains('与接收验证码的手机号码不一致')) {
    return '手机号与获取验证码时不一致，请使用原手机号或重新获取';
  }
  if (lower.contains('secure mobile invalid') || trimmed.contains('安全手机无效')) {
    return '该手机号未绑定智慧工大安全手机';
  }
  if (lower == 'unauthorized' ||
      lower.contains('bad credentials') ||
      trimmed == '未授权') {
    return '账号或密码错误';
  }
  if (lower == 'request parameter error' || trimmed == '请求参数错误') {
    return '请求参数错误，请重新获取验证码后再试';
  }
  return trimmed;
}

String _hutAuthMessage(
  Map<dynamic, dynamic> envelope, [
  Map<dynamic, dynamic>? data,
]) {
  final fromData = data?['message']?.toString().trim();
  if (fromData != null && fromData.isNotEmpty) {
    return localizeHutAuthMessage(fromData);
  }
  final fromEnvelope = envelope['message']?.toString().trim();
  if (fromEnvelope != null && fromEnvelope.isNotEmpty) {
    return localizeHutAuthMessage(fromEnvelope);
  }
  // mycas passwordless endpoints often return {"code":-1,"error":"..."} only.
  final fromError = envelope['error']?.toString().trim();
  if (fromError != null &&
      fromError.isNotEmpty &&
      fromError.toLowerCase() != 'bad request' &&
      fromError.toLowerCase() != 'unauthorized' &&
      fromError.toLowerCase() != 'internal server error') {
    return localizeHutAuthMessage(fromError);
  }
  // Fall through: Spring often puts useful text only in message already handled;
  // bare error:"Bad Request" is useless — treat as session invalid when path-ish.
  if (fromError != null && fromError.toLowerCase() == 'bad request') {
    return _kHutSmsSessionInvalidMessage;
  }
  return _kDefaultHutAuthFailureMessage;
}

/// Maps a Dio/transport failure into [HutAuthResult].
///
/// HUT mycas often encodes business failures as HTTP 4xx/5xx with a JSON body
/// (`code` / `error` / `message`). Those must surface the body text — not the
/// generic network copy — because the server may already have side effects
/// (e.g. SMS already sent) before returning a non-2xx status.
HutAuthResult hutAuthResultFromTransportError({
  int? statusCode,
  dynamic responseData,
}) {
  if (responseData != null) {
    if (responseData is Map) {
      final envelope = Map<dynamic, dynamic>.from(responseData);
      final payload = envelope['data'];
      final payloadMap =
          payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
      final message = _hutAuthMessage(envelope, payloadMap);
      return HutAuthResult(
        success: false,
        message: message,
        needMfa: hutResponseIndicatesNeedMfa(envelope),
      );
    }
    final text = responseData.toString().trim();
    if (text.isNotEmpty) {
      return HutAuthResult(
        success: false,
        message: localizeHutAuthMessage(text),
      );
    }
  }
  // No usable body: genuine transport / timeout / DNS failure.
  // statusCode alone is not enough to invent a business message.
  return const HutAuthResult(success: false, message: '网络异常，请稍后重试');
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
