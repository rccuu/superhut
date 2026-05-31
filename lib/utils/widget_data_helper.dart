import '../core/services/app_logger.dart';
import 'course/coursemain.dart';

/// 小组件数据助手类
/// 用于保存和管理桌面小组件所需的数据
class WidgetDataHelper {
  /// 保存课程数据到本地文件，供桌面小组件读取
  ///
  /// [courseData] 的格式为 `Map<String, List<Map<String, dynamic>>>`
  /// 其中外层 Map 的键为日期字符串（格式：yyyy-MM-dd）
  /// 值为当天的课程列表
  static Future<bool> saveCourseDataForWidget(
    Map<String, List<Map<String, dynamic>>> courseData,
  ) async {
    try {
      final normalizedCourseData = <String, List<Course>>{};
      for (final entry in courseData.entries) {
        final courses = entry.value;
        final normalizedCourses = <Course>[];
        for (final course in courses) {
          normalizedCourses.add(
            Course(
              name: course['name'],
              teacherName: course['teacherName'] ?? '',
              weekDuration: course['weekDuration'] ?? '',
              location: course['location'],
              startSection: course['startSection'],
              duration: course['duration'],
              isExp: course['isExp'] ?? false,
              pcid: course['pcid'] ?? '',
            ),
          );
        }
        normalizedCourseData[entry.key] = normalizedCourses;
      }

      await saveCourseDataToJson(normalizedCourseData);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('保存课程数据失败', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// 示例方法：创建今日课程数据
  /// 可以在获取课程数据后调用 saveCourseDataForWidget 方法保存
  static Future<bool> saveExampleCourseData() async {
    // 获取今天的日期字符串
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 创建示例课程数据
    final courseData = {
      dateStr: [
        {
          'name': '高等数学',
          'location': '教学楼A-101',
          'startSection': 1,
          'duration': 2,
        },
        {
          'name': '大学英语',
          'location': '教学楼B-202',
          'startSection': 3,
          'duration': 2,
        },
        {
          'name': '计算机原理',
          'location': '实验楼C-303',
          'startSection': 5,
          'duration': 2,
        },
      ],
    };

    return await saveCourseDataForWidget(courseData);
  }
}
