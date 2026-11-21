/// 校园卡充值入口 URL 构建。
///
/// 逆向结论（brief Source coverage S12–S15，2026-11-08 真机动态分析）：
/// 官方 App 在 WKWebView 中打开完美校园（17wanxiao）校园卡轻应用，入口为
/// `hub.17wanxiao.com/bsacs/light.action?flag=<学校标识>&ecardFunc=index&token=<X-Id-Token>`，
/// 其中 token 与 portal / 热水等接口使用的 `X-Id-Token` 为同一凭证。
/// 金额输入、支付方式（微信 / 农行掌银）与收银台均由该 H5 内建提供。
class CampusCardApi {
  const CampusCardApi._();

  /// 学校专属标识（官方 App 同款常量）。
  static const String schoolFlag = 'supwisdomapp_hngydxsw';

  /// 完美校园轻应用入口地址。
  static const String entryBaseUrl =
      'https://hub.17wanxiao.com/bsacs/light.action';

  /// 原支付宝小程序充值兜底入口（既有路径，保留作回落）。
  static const String alipayFallbackUrl =
      'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index';

  /// 微信 H5 支付（MWEB）收银台域名。
  static const String wechatPayHost = 'wx.tenpay.com';

  /// 商户平台配置的 H5 支付授权域名（收银台 Referer 校验值）。
  ///
  /// 微信 H5 支付校验收银台请求的 `Referer` 是否为商户平台【开发配置】
  /// 中的「H5 支付域名」，缺失或不匹配时报「商户配置错误，请联系商户
  /// 解决」。iOS WKWebView 页面内跳转自动携带该来源 Referer 并实测走通，
  /// 说明商户配置包含 `ecardh5.17wanxiao.com`；Android WebView 不会自动
  /// 携带，需显式附加（2026-11-21 fix-wechat-pay-merchant-error）。
  static const String wechatPayRefererOrigin = 'https://ecardh5.17wanxiao.com/';

  /// 返回微信收银台请求应附加的 Referer；null 表示不需要干预、直接放行。
  ///
  /// [androidPlatform] 由调用方按运行平台传入（`Platform.isAndroid`）：
  /// 仅 Android WebView 需要；iOS 等平台 WebView 自动携带页面来源
  /// Referer，行为保持现状。收银台域名含子域一并命中，其余域不干预。
  static String? wechatPayRefererHeader(
    Uri url, {
    required bool androidPlatform,
  }) {
    if (!androidPlatform) {
      return null;
    }
    final host = url.host.toLowerCase();
    final isTenpay = host == wechatPayHost || host.endsWith('.$wechatPayHost');
    return isTenpay ? wechatPayRefererOrigin : null;
  }

  /// 用当前登录态 [token] 构建校园卡 H5 入口 URL。
  ///
  /// [token] 为空或纯空白时抛出 [CampusCardTokenMissingException]。
  static Uri buildEntryUrl(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw const CampusCardTokenMissingException();
    }
    return Uri.parse(entryBaseUrl).replace(
      queryParameters: <String, String>{
        'flag': schoolFlag,
        'ecardFunc': 'index',
        'token': trimmed,
      },
    );
  }
}

/// 登录态缺失（无法取得 X-Id-Token）时构建入口 URL 的异常。
class CampusCardTokenMissingException implements Exception {
  const CampusCardTokenMissingException();

  @override
  String toString() => 'CampusCardTokenMissingException: X-Id-Token is empty';
}
