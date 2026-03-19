import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_logger.dart';
import '../../utils/withhttp.dart';

class Score {
  final String curriculumAttributes;
  final String state;
  final String examName;
  final String courseNature;
  final String fraction;
  final String courseName;
  final String examinationNature;
  final String gradePoints;
  final String credit;

  Score({
    required this.curriculumAttributes,
    required this.state,
    required this.examName,
    required this.courseNature,
    required this.fraction,
    required this.courseName,
    required this.examinationNature,
    required this.gradePoints,
    required this.credit,
  });
}

class SemesterListResult {
  final List<String> idList;
  final String nowId;
  final String? errorMessage;

  const SemesterListResult({
    required this.idList,
    required this.nowId,
    this.errorMessage,
  });
}

class ScoreLoadResult {
  final List<Score> achievement;
  final String yxzxf;
  final String zxfjd;
  final String pjxfjd;
  final String? errorMessage;

  const ScoreLoadResult({
    required this.achievement,
    required this.yxzxf,
    required this.zxfjd,
    required this.pjxfjd,
    this.errorMessage,
  });
}

Future<SemesterListResult> semesterIdfc() async {
  try {
    final Response<dynamic> response = await postDioWithCookie(
      '/njwhd/semesterList',
      {},
    );
    final data = mapFromResponseData(response.data);
    if (data == null || data['code']?.toString() != '1') {
      return SemesterListResult(
        idList: const [],
        nowId: '',
        errorMessage: responseMessageOf(response.data) ?? '学期列表加载失败',
      );
    }

    final List<dynamic> iddata = data['data'] as List? ?? const [];
    final idlist = <String>[];
    String nowid = '';
    for (var i = 0; i < iddata.length; i++) {
      final tempMap = mapFromResponseData(iddata[i]);
      if (tempMap == null) {
        continue;
      }

      final semesterId = tempMap['semesterId']?.toString() ?? '';
      if (semesterId.isEmpty) {
        continue;
      }
      idlist.add(semesterId);
      if (tempMap['nowXq']?.toString() == '1') {
        nowid = semesterId;
      }
    }

    return SemesterListResult(idList: idlist, nowId: nowid);
  } on DioException catch (error, stackTrace) {
    AppLogger.error(
      'Failed to load semester list',
      error: error,
      stackTrace: stackTrace,
    );
    return const SemesterListResult(
      idList: [],
      nowId: '',
      errorMessage: '学期列表加载失败，请检查网络后重试',
    );
  } catch (error, stackTrace) {
    AppLogger.error(
      'Semester list parsing failed',
      error: error,
      stackTrace: stackTrace,
    );
    return const SemesterListResult(
      idList: [],
      nowId: '',
      errorMessage: '学期列表数据异常，请稍后重试',
    );
  }
}

Future<ScoreLoadResult> getScore(String semesterId) async {
  try {
    final Response<dynamic> response = await postDioWithCookie(
      '/njwhd/student/termGPA?semester=$semesterId&type=1',
      {},
    );
    final data = mapFromResponseData(response.data);
    if (data == null || data['code']?.toString() != '1') {
      return ScoreLoadResult(
        achievement: const [],
        yxzxf: '-',
        zxfjd: '-',
        pjxfjd: '-',
        errorMessage: responseMessageOf(response.data) ?? '成绩加载失败',
      );
    }

    final List<dynamic> scorelist = data['data'] as List? ?? const [];
    if (scorelist.isEmpty) {
      return const ScoreLoadResult(
        achievement: [],
        yxzxf: '-',
        zxfjd: '-',
        pjxfjd: '-',
      );
    }

    final firstItem = mapFromResponseData(scorelist.first);
    if (firstItem == null) {
      return const ScoreLoadResult(
        achievement: [],
        yxzxf: '-',
        zxfjd: '-',
        pjxfjd: '-',
        errorMessage: '成绩数据格式异常',
      );
    }

    final List<dynamic> achievementList =
        firstItem['achievement'] as List? ?? const [];
    final reList = <Score>[];

    final String yxzxf = firstItem['yxzxf']?.toString() ?? '-';
    final String zxfjd = firstItem['zxfjd']?.toString() ?? '-';
    final String pjxfjd = firstItem['pjxfjd']?.toString() ?? '-';

    for (final item in achievementList) {
      final itemMap = mapFromResponseData(item);
      if (itemMap == null) {
        continue;
      }
      reList.add(
        Score(
          curriculumAttributes:
              itemMap['curriculumAttributes']?.toString() ?? '',
          state: itemMap['sfjg']?.toString() ?? '',
          examName: itemMap['examName']?.toString() ?? '',
          courseNature: itemMap['courseNature']?.toString() ?? '',
          fraction: itemMap['fraction']?.toString() ?? '',
          courseName: itemMap['courseName']?.toString() ?? '',
          examinationNature: itemMap['examinationNature']?.toString() ?? '',
          gradePoints: itemMap['jd']?.toString() ?? '',
          credit: itemMap['credit']?.toString() ?? '',
        ),
      );
    }
    AppLogger.debug('Loaded ${reList.length} score items');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yxzxf', yxzxf);
    await prefs.setString('zxfjd', zxfjd);
    await prefs.setString('pjxfjd', pjxfjd);

    return ScoreLoadResult(
      achievement: reList,
      yxzxf: yxzxf,
      zxfjd: zxfjd,
      pjxfjd: pjxfjd,
    );
  } on DioException catch (error, stackTrace) {
    AppLogger.error(
      'Failed to load score list',
      error: error,
      stackTrace: stackTrace,
    );
    return const ScoreLoadResult(
      achievement: [],
      yxzxf: '-',
      zxfjd: '-',
      pjxfjd: '-',
      errorMessage: '成绩加载失败，请检查网络后重试',
    );
  } catch (error, stackTrace) {
    AppLogger.error(
      'Score response parsing failed',
      error: error,
      stackTrace: stackTrace,
    );
    return const ScoreLoadResult(
      achievement: [],
      yxzxf: '-',
      zxfjd: '-',
      pjxfjd: '-',
      errorMessage: '成绩数据异常，请稍后重试',
    );
  }
}
