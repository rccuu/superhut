import 'package:flutter/services.dart';

import 'core/services/app_logger.dart';

/// 小组件刷新服务类
/// 用于刷新桌面小组件
class WidgetRefreshService {
  static const MethodChannel _channel = MethodChannel(
    'com.superhut.rice.superhut/coursetable_widget',
  );

  /// 刷新课程表小组件
  static Future<bool> refreshCourseTableWidget() async {
    try {
      final bool result = await _channel.invokeMethod(
        'refreshCourseTableWidget',
      );
      return result;
    } on MissingPluginException catch (_) {
      AppLogger.debug('当前平台未接入课表小组件刷新，跳过刷新操作');
      return false;
    } on PlatformException catch (e) {
      AppLogger.error('刷新小组件失败', error: e.message);
      return false;
    } catch (error, stackTrace) {
      AppLogger.error('刷新小组件出现未预期错误', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
