import 'package:flutter/services.dart';

import 'core/services/app_logger.dart';

/// 小组件刷新服务类
/// 用于刷新桌面小组件
class WidgetRefreshService {
  static const MethodChannel _channel = MethodChannel(
    'com.superhut.rice.superhut/coursetable_widget',
  );

  /// 同步课程表小组件所需数据，并触发系统刷新
  static Future<bool> syncCourseTableWidget({String? payloadJson}) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'syncCourseTableWidget',
        payloadJson == null
            ? null
            : <String, dynamic>{'payloadJson': payloadJson},
      );
      return result ?? false;
    } on MissingPluginException catch (_) {
      AppLogger.debug('当前平台未接入课表小组件同步，跳过同步操作');
      return false;
    } on PlatformException catch (e) {
      AppLogger.error('同步课表小组件失败', error: e.message);
      return false;
    } catch (error, stackTrace) {
      AppLogger.error('同步课表小组件出现未预期错误', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// 刷新课程表小组件
  static Future<bool> refreshCourseTableWidget() async {
    return syncCourseTableWidget();
  }
}
