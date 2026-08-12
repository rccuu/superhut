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

String normalizeHutMobile(String mobile) => mobile.trim().replaceAll(' ', '');

/// Persisted auth method marker (SharedPreferences key `hutAuthMethod`).
///
/// Distinguishes password vs SMS sessions explicitly so [checkTokenValidity]
/// and [refreshToken] can branch on how the session was established, instead
/// of inferring it from whether `hutUsername` is empty (which breaks on
/// account switch: a prior password login leaves `hutUsername` around and a
/// fresh SMS token would be re-validated with the stale username).
const String kHutAuthMethodPassword = 'password';
const String kHutAuthMethodSms = 'sms';

/// True when [token] is a JWT whose `exp` has passed (or it is malformed).
///
/// SMS sessions carry a mycas `idToken` (a JWT). [checkTokenValidity] uses this
/// to decide validity without a network round-trip, so an expired/revoked/
/// corrupted token is no longer permanently trusted. Malformed input (not a
/// 3-segment JWT, bad base64, non-JSON payload, missing/invalid `exp`) returns
/// `true` — i.e. treated as expired — so the caller clears login state and
/// asks the user to re-authenticate, rather than silently trusting garbage.
/// [clockSkew] lets callers tolerate minor client/server clock drift.
bool isHutJwtExpired(String token, {Duration clockSkew = Duration.zero}) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return true;
  }
  final payload = parts[1];
  Uint8List bytes;
  try {
    bytes = base64Url.decode(base64Url.normalize(payload));
  } catch (_) {
    return true;
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } catch (_) {
    return true;
  }
  if (decoded is! Map) {
    return true;
  }
  final exp = decoded['exp'];
  if (exp == null) {
    return true;
  }
  final expSeconds = num.tryParse(exp.toString());
  if (expSeconds == null) {
    return true;
  }
  final expMillis = (expSeconds * 1000).toInt();
  final nowMillis = DateTime.now().millisecondsSinceEpoch;
  return expMillis <= nowMillis + clockSkew.inMilliseconds;
}

/// Extracts the stable account identifier used by mycas from a JWT `sub`.
///
/// The official app stores the raw SMS token unchanged, then decodes only its
/// claims and persists `sub` separately so `userOnlineDetect` has an account
/// to validate against. Returns `null` when [token] is not a 3-segment JWT
/// with a non-empty `sub` claim.
String? extractHutJwtSubject(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      return null;
    }
    final subject = decoded['sub']?.toString().trim() ?? '';
    return subject.isEmpty ? null : subject;
  } catch (_) {
    return null;
  }
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

/// Verdict of an online mycas `userOnlineDetect` check, injected for tests.
typedef HutOnlineTokenValidator =
    Future<bool> Function({
      required String token,
      required String account,
      required String deviceId,
    });

abstract class _HutUserApiCore {
  AppAuthStorage get _storage;
  RequestManager get _request;
  Map<String, dynamic> get _token;

  HutOnlineTokenValidator? get _onlineTokenValidator;

  Future<bool> userLogin({required String username, required String password});

  Future<String> getToken();

  Future<String> getPortalTicket();

  Future<bool> checkTokenValidity();

  Future<List<String>> getOpenid();

  Future<_HutOpenIdSession> _getOpenIdSession();
}

class HutUserApi extends _HutUserApiCore
    with _HutAuthMixin, _HutSessionMixin, _HutWaterMixin, _HutPortalMixin {
  HutUserApi({HutOnlineTokenValidator? onlineTokenValidator})
    : _onlineTokenValidator = onlineTokenValidator;

  @override
  final HutOnlineTokenValidator? _onlineTokenValidator;

  @override
  final AppAuthStorage _storage = AppAuthStorage.instance;

  @override
  final RequestManager _request = RequestManager();

  @override
  final Map<String, dynamic> _token = {"idToken": ""};
}
