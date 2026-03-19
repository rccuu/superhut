import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
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

abstract class _HutUserApiCore {
  AppAuthStorage get _storage;
  RequestManager get _request;
  Map<String, dynamic> get _token;

  Future<bool> userLogin({required String username, required String password});

  Future<String> getToken();

  Future<bool> checkTokenValidity();

  Future<List> getOpenid();

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
