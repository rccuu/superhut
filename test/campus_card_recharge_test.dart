import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/campuscard/campus_card_api.dart';
import 'package:superhut/pages/campuscard/campus_card_recharge_page.dart';

void main() {
  group('CampusCardApi.buildEntryUrl（A1）', () {
    test('用 X-Id-Token 构建完美校园 light.action 入口 URL', () {
      final url = CampusCardApi.buildEntryUrl('token-abc');
      expect(url.scheme, 'https');
      expect(url.host, 'hub.17wanxiao.com');
      expect(url.path, '/bsacs/light.action');
      expect(url.queryParameters['flag'], CampusCardApi.schoolFlag);
      expect(url.queryParameters['ecardFunc'], 'index');
      expect(url.queryParameters['token'], 'token-abc');
    });

    test('schoolFlag 为学校专属常量', () {
      expect(CampusCardApi.schoolFlag, 'supwisdomapp_hngydxsw');
    });

    test('token 两侧空白会被裁剪', () {
      final url = CampusCardApi.buildEntryUrl('  token-abc \n');
      expect(url.queryParameters['token'], 'token-abc');
    });

    test('token 含保留字符时正确转义', () {
      final url = CampusCardApi.buildEntryUrl('a/b?c=d e');
      expect(url.queryParameters['token'], 'a/b?c=d e');
      // Uri 的 queryParameters 按表单编码转义：/ ? 转义，空格编码为 +。
      expect(url.toString(), contains('token=a%2Fb%3Fc%3Dd+e'));
    });

    test('token 缺失（空串）抛 CampusCardTokenMissingException', () {
      expect(
        () => CampusCardApi.buildEntryUrl(''),
        throwsA(isA<CampusCardTokenMissingException>()),
      );
    });

    test('token 缺失（纯空白）抛 CampusCardTokenMissingException', () {
      expect(
        () => CampusCardApi.buildEntryUrl('   '),
        throwsA(isA<CampusCardTokenMissingException>()),
      );
    });
  });

  group('支付宝兜底入口（A7）', () {
    test('保留既有支付宝小程序跳转路径', () {
      final url = Uri.parse(CampusCardApi.alipayFallbackUrl);
      expect(url.scheme, 'alipays');
      expect(url.host, 'platformapi');
      expect(url.queryParameters['appId'], '2019030163398604');
      expect(url.queryParameters['page'], 'pages/index/index');
    });
  });

  group('微信 H5 收银台 Referer 决策（A1 / A2 / A4）', () {
    const expectedReferer = 'https://ecardh5.17wanxiao.com/';

    test('Android + wx.tenpay.com 收银台返回商户域名 Referer（A1）', () {
      final referer = CampusCardApi.wechatPayRefererHeader(
        Uri.parse(
          'https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb'
          '?prepay_id=wx20261121&package=1234567890',
        ),
        androidPlatform: true,
      );
      expect(referer, expectedReferer);
    });

    test('Android + wx.tenpay.com 子域同样命中（A1）', () {
      final referer = CampusCardApi.wechatPayRefererHeader(
        Uri.parse('https://api.wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb'),
        androidPlatform: true,
      );
      expect(referer, expectedReferer);
    });

    test('Android + 其他域不干预（A3）', () {
      // 校园卡 H5 页面本身不附加头，保持 WebView 内直接放行。
      expect(
        CampusCardApi.wechatPayRefererHeader(
          Uri.parse('https://ecardh5.17wanxiao.com/recharge.html#/payWays'),
          androidPlatform: true,
        ),
        isNull,
      );
      // 仅匹配 wx.tenpay.com 及其子域，前缀相似域不误判。
      expect(
        CampusCardApi.wechatPayRefererHeader(
          Uri.parse('https://notwx.tenpay.com.example.com/'),
          androidPlatform: true,
        ),
        isNull,
      );
    });

    test('非 Android 平台不干预（A2：iOS 行为保持现状）', () {
      expect(
        CampusCardApi.wechatPayRefererHeader(
          Uri.parse('https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb'),
          androidPlatform: false,
        ),
        isNull,
      );
    });

    test('Referer 域名为商户 H5 支付配置常量', () {
      expect(CampusCardApi.wechatPayHost, 'wx.tenpay.com');
      expect(CampusCardApi.wechatPayRefererOrigin, expectedReferer);
    });
  });

  group('CampusCardErrorView（A7 UI）', () {
    testWidgets('展示失败信息与重试、支付宝兜底按钮', (tester) async {
      var retryCalls = 0;
      var fallbackCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusCardErrorView(
              message: '网络连接失败',
              onRetry: () => retryCalls++,
              onAlipayFallback: () => fallbackCalls++,
            ),
          ),
        ),
      );

      expect(find.text('校园卡页面加载失败'), findsOneWidget);
      expect(find.text('网络连接失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('改用支付宝小程序'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.tap(find.text('改用支付宝小程序'));
      await tester.pump();

      expect(retryCalls, 1);
      expect(fallbackCalls, 1);
    });
  });
}
