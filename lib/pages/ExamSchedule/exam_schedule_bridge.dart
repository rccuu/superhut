import 'package:dio/dio.dart';
import 'package:superhut/utils/withhttp.dart';

import '../../core/services/app_logger.dart';

class ExamScheduleResult {
  final List<Map<String, dynamic>> schedules;
  final String? errorMessage;

  const ExamScheduleResult({required this.schedules, this.errorMessage});
}

Future<ExamScheduleResult> getSchedule() async {
  try {
    final Response<dynamic> response = await postDioWithCookie(
      '/njwhd/student/examinationArrangement',
      {},
    );
    final data = mapFromResponseData(response.data);
    if (data == null || data['code']?.toString() != '1') {
      return ExamScheduleResult(
        schedules: const [],
        errorMessage: responseMessageOf(response.data) ?? '考试安排加载失败',
      );
    }

    final schedules =
        (data['data'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    return ExamScheduleResult(schedules: schedules);
  } on DioException catch (error, stackTrace) {
    AppLogger.error(
      'Failed to load exam schedule',
      error: error,
      stackTrace: stackTrace,
    );
    return ExamScheduleResult(
      schedules: const [],
      errorMessage: '考试安排加载失败，请检查网络后重试',
    );
  } catch (error, stackTrace) {
    AppLogger.error(
      'Exam schedule response parsing failed',
      error: error,
      stackTrace: stackTrace,
    );
    return const ExamScheduleResult(
      schedules: [],
      errorMessage: '考试安排数据异常，请稍后重试',
    );
  }
}
