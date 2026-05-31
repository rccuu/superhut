import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/login/webview_login_screen.dart';

void main() {
  test('official webview login error message hides raw page details', () {
    const rawMessage =
        '登录接口失败: https://jwxtsj.hut.edu.cn/sjd/login?token=secret-token';

    expect(
      resolveOfficialWebViewLoginErrorMessage(rawMessage),
      officialWebViewLoginFailureMessage,
    );
    expect(
      resolveOfficialWebViewLoginErrorMessage(Exception('WebView crashed')),
      officialWebViewLoginFailureMessage,
    );
    expect(officialWebViewLoginFailureMessage, isNot(contains('token=')));
    expect(officialWebViewLoginFailureMessage, isNot(contains('http')));
  });
}
