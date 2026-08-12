part of '../hut_user_api.dart';

mixin _HutPortalMixin on _HutUserApiCore {
  Future<bool> _ensureHutPortalLogin() async {
    bool isLogin;
    try {
      isLogin = await checkTokenValidity();
    } catch (error, stackTrace) {
      // checkTokenValidity propagates transport failures by design (renewal
      // must not clear state on a transient flake). For the portal list a
      // network hiccup is not "logged out" either — degrade to the stored
      // re-login path below, or the empty list for SMS users.
      AppLogger.error(
        'HUT portal login validity check failed',
        error: error,
        stackTrace: stackTrace,
      );
      isLogin = false;
    }
    if (isLogin) {
      return true;
    }

    final userName = await _storage.readHutUsername();
    final orgPassword = await _storage.readHutPassword();
    if (userName.isEmpty || orgPassword.isEmpty) {
      return false;
    }
    return userLogin(username: userName, password: orgPassword);
  }

  Future<List<Map>> getFunctionList() async {
    if (!await _ensureHutPortalLogin()) {
      return [];
    }

    final token = await getToken();
    final dio = _createConfiguredDio(
      baseUrl: _kPortalBaseUrl,
      headers: {
        'User-Agent': _kPortalUserAgent,
        'Connection': 'Keep-Alive',
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'Content-Type': 'application/json',
        'X-Device-Info': 'Xiaomi24129PN74C1.9.9.81096',
        'X-Device-Infos':
            '{"packagename":__UNI__AA068AD,"version":1.1.3,"system":Android 15}',
        'X-Id-Token': token,
        'X-Terminal-Info': 'app',
      },
      followRedirects: true,
      validateStatus: _defaultValidateStatus,
    );

    final v1Response = await dio.post(
      '/portal-api/v1/service/list?kw=&showPublic=false&returnType=label',
      data: {},
    );
    final v1List = parseHutPortalFunctionList(v1Response.data);
    if (v1List.isNotEmpty) {
      return v1List;
    }

    final v2Response = await dio.post(
      '/portal-api/v2/service/serviceShowAll'
      '?keyWord=&showPublic=false&returnType=label'
      '&showType=all&my=false&serviceType=1,2,3,4,5',
      data: {},
    );
    return parseHutPortalFunctionList(v2Response.data);
  }
}

@visibleForTesting
List<Map> parseHutPortalFunctionList(dynamic responseData) {
  final data = _decodePortalResponseData(responseData);
  if (data is Map) {
    final code = data['code']?.toString();
    if (code != null && code != '0') {
      return [];
    }
  }

  final payload = data is Map ? data['data'] ?? data : data;
  final resultList = <Map>[];
  final flatItems = <FunctionItem>[];
  _appendFunctionCategories(payload, resultList, flatItems);
  if (flatItems.isNotEmpty) {
    _addFunctionCategory(resultList, '全部服务', flatItems);
  }
  return resultList;
}

dynamic _decodePortalResponseData(dynamic responseData) {
  if (responseData is String) {
    try {
      return jsonDecode(responseData);
    } catch (_) {
      return responseData;
    }
  }
  return responseData;
}

void _appendFunctionCategories(
  dynamic payload,
  List<Map> resultList,
  List<FunctionItem> flatItems,
) {
  if (payload is List) {
    for (final element in payload) {
      _appendFunctionCategoryOrItem(element, resultList, flatItems);
    }
    return;
  }

  if (payload is! Map) {
    return;
  }

  final directList = _readFirstList(payload, const [
    'data',
    'list',
    'records',
    'rows',
    'content',
    'children',
    'services',
    'serviceList',
    'service_list',
  ]);
  if (directList != null) {
    _appendFunctionCategories(directList, resultList, flatItems);
    return;
  }

  final item = FunctionItem.fromJson(payload);
  if (_isUsableFunctionItem(item)) {
    flatItems.add(item);
  }
}

void _appendFunctionCategoryOrItem(
  dynamic element,
  List<Map> resultList,
  List<FunctionItem> flatItems,
) {
  if (element is! Map) {
    return;
  }

  final label = _readString(element, const [
    'label',
    'name',
    'title',
    'serviceTagName',
    'tagName',
    'categoryName',
    'groupName',
  ]);

  final serviceData = _readFirstList(element, const [
    'services',
    'serviceList',
    'service_list',
    'items',
    'children',
  ]);
  if (serviceData != null) {
    final services = _parseFunctionItems(serviceData);
    if (services.isNotEmpty) {
      if (_looksLikeServiceItem(element)) {
        final item = FunctionItem.fromJson(element);
        if (_isUsableFunctionItem(item)) {
          flatItems.add(item);
        } else {
          flatItems.addAll(services);
        }
      } else if (label.isEmpty) {
        flatItems.addAll(services);
      } else {
        _addFunctionCategory(resultList, label, services);
      }
    }
    return;
  }

  final item = FunctionItem.fromJson(element);
  if (_isUsableFunctionItem(item)) {
    flatItems.add(item);
  }
}

List<dynamic>? _readFirstList(Map data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is List) {
      return value;
    }
  }
  return null;
}

void _addFunctionCategory(
  List<Map> resultList,
  String label,
  List<FunctionItem> services,
) {
  final normalizedLabel = label.trim().isEmpty ? '全部服务' : label.trim();
  final existingIndex = resultList.indexWhere(
    (item) => item['label'] == normalizedLabel,
  );
  if (existingIndex == -1) {
    resultList.add({'label': normalizedLabel, 'services': services});
    return;
  }

  final existingServices = resultList[existingIndex]['services'];
  if (existingServices is List<FunctionItem>) {
    existingServices.addAll(services);
  }
}

List<FunctionItem> _parseFunctionItems(dynamic serviceData) {
  final items = <FunctionItem>[];
  if (serviceData is List) {
    for (final service in serviceData) {
      if (service is! Map) {
        continue;
      }

      final nested = _readFirstList(service, const [
        'services',
        'serviceList',
        'service_list',
        'items',
        'children',
      ]);
      final looksLikeServiceItem = _looksLikeServiceItem(service);
      if (nested != null && !looksLikeServiceItem) {
        items.addAll(_parseFunctionItems(nested));
        continue;
      }

      final item = FunctionItem.fromJson(service);
      if (_isUsableFunctionItem(item)) {
        items.add(item);
      } else if (nested != null) {
        items.addAll(_parseFunctionItems(nested));
      }
    }
    return items;
  }

  if (serviceData is Map) {
    final item = FunctionItem.fromJson(serviceData);
    if (_isUsableFunctionItem(item)) {
      return [item];
    }

    for (final entry in serviceData.entries) {
      if (entry.value is List || entry.value is Map) {
        items.addAll(_parseFunctionItems(entry.value));
      }
    }
  }
  return items;
}

bool _isUsableFunctionItem(FunctionItem item) {
  return item.id.isNotEmpty &&
      item.serviceName.isNotEmpty &&
      (item.serviceUrl.isNotEmpty || item.serviceType == '5');
}

bool _looksLikeServiceItem(Map data) {
  return _readString(data, const [
        'serviceName',
        'service_name',
        'serviceUrl',
        'service_url',
        'serviceType',
        'service_type',
        'tokenAccept',
        'token_accept',
      ]).isNotEmpty ||
      (data.containsKey('id') &&
          (data.containsKey('serviceName') ||
              data.containsKey('service_name')));
}
