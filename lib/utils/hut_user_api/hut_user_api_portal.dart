part of '../hut_user_api.dart';

mixin _HutPortalMixin on _HutUserApiCore {
  Future<List<Map>> getFunctionList() async {
    final isLogin = await checkTokenValidity();
    if (!isLogin) {
      final userName = await _storage.readHutUsername();
      final orgPassword = await _storage.readHutPassword();
      if (userName.isEmpty || orgPassword.isEmpty) {
        return [];
      }
      await userLogin(username: userName, password: orgPassword);
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

    final response = await dio.post('/portal-api/v1/service/list', data: {});
    final Map data = response.data;
    final List functionList = data['data'];
    final resultList = <Map>[];

    for (final element in functionList) {
      final String label = element['label'];
      final List services = element['services'];
      final tempList = <FunctionItem>[];

      if (services.isNotEmpty) {
        for (final service in services) {
          tempList.add(
            FunctionItem(
              id: service['id'],
              serviceName: service['serviceName'],
              servicePicUrl: service['servicePicUrl'],
              serviceUrl: service['serviceUrl'],
              serviceType: service['serviceType'],
              tokenAccept: service['tokenAccept'],
              iconUrl: service['iconUrl'],
            ),
          );
        }
        resultList.add({'label': label, 'services': tempList});
      }
    }

    return resultList;
  }
}
