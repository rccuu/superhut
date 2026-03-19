import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_logger.dart';
import '../../utils/token.dart';
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

Future<Map> semesterIdfc() async {
  await getToken();
  await configureDioFromStorage();
  final Response<dynamic> response = await postDioWithCookie(
    '/njwhd/semesterList',
    {},
  );
  final Map data = response.data;
  final List iddata = data['data'];
  final List idlist = [];
  String nowid = '';
  for (var i = 0; i < iddata.length; i++) {
    final Map tempMap = iddata[i];
    idlist.add(tempMap['semesterId']);
    if (tempMap['nowXq'] == '1') {
      nowid = tempMap['semesterId'];
    }
  }
  return {'idlist': idlist, 'nowid': nowid};
}

Future<Map<String, Object>> getScore(String semesterId) async {
  await getToken();
  await configureDioFromStorage();
  final Response<dynamic> response = await postDioWithCookie(
    '/njwhd/student/termGPA?semester=$semesterId&type=1',
    {},
  );
  final Map data = response.data;
  List<Score> reList = [];
  final List scorelist = data['data'];

  final List achievementList = scorelist[0]['achievement'];

  final String yxzxf = scorelist[0]['yxzxf'];
  final String zxfjd = scorelist[0]['zxfjd'];
  final String pjxfjd = scorelist[0]['pjxfjd'];

  for (Map data in achievementList) {
    reList.add(
      Score(
        curriculumAttributes: data['curriculumAttributes'],
        state: data['sfjg'],
        examName: data['examName'],
        courseNature: data['courseNature'],
        fraction: data['fraction'],
        courseName: data['courseName'],
        examinationNature: data['examinationNature'],
        gradePoints: data['jd'].toString(),
        credit: data['credit'].toString(),
      ),
    );
  }
  AppLogger.debug('Loaded ${reList.length} score items');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('yxzxf', yxzxf);
  await prefs.setString('zxfjd', zxfjd);
  await prefs.setString('pjxfjd', pjxfjd);

  return {
    'achievement': reList,
    'yxzxf': yxzxf,
    'zxfjd': zxfjd,
    'pjxfjd': pjxfjd,
  };
}
