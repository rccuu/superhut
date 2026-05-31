import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/login/hut_login_system.dart';

void main() {
  group('CAS JWXT token extraction', () {
    const initialIdToken = 'hut-id-token';
    const jwxtToken = 'jwxt-final-token';

    test(
      'ignores intermediate loginSso token that matches the HUT idToken',
      () {
        final token = extractJwxtTokenFromCasUrl(
          'https://jwxtsj.hut.edu.cn/njwhd/loginSso?token=$initialIdToken',
          initialIdToken: initialIdToken,
        );

        expect(token, isNull);
      },
    );

    test('extracts final JWXT token from CAS fragment URL', () {
      final token = extractJwxtTokenFromCasUrl(
        'https://jwxtsj.hut.edu.cn/sjd/#/casLogin?token=$jwxtToken&userType=2&toMenu=null',
        initialIdToken: initialIdToken,
      );

      expect(token, jwxtToken);
    });

    test('extracts final JWXT token from CAS loginSso HTML redirect', () {
      final token = extractJwxtTokenFromCasHtml(
        "<script>window.location.href='https://jwxtsj.hut.edu.cn/sjd/#/casLogin?token=$jwxtToken&userType=2&toMenu=null'</script>",
        initialIdToken: initialIdToken,
      );

      expect(token, jwxtToken);
    });
  });

  group('HUT login error messages', () {
    test('credential extraction failure hides raw exception', () {
      final message = hutLoginCredentialExtractionFailureMessage(
        StateError('cookie unavailable'),
      );

      expect(message, '提取登录凭据失败，请稍后重试');
      expect(message, isNot(contains('cookie unavailable')));
    });

    test('page load failure hides raw webview description', () {
      final message = hutLoginPageLoadFailureMessage(
        Exception('net::ERR_NAME_NOT_RESOLVED'),
      );

      expect(message, '页面加载失败，请稍后重试');
      expect(message, isNot(contains('ERR_NAME_NOT_RESOLVED')));
    });
  });
}
