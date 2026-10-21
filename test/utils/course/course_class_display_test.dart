import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/utils/course/get_course.dart';

/// 真实抓取样本（2026-10-21，当前学期 2026-2027-1，第 7 周），
/// 与 change 产物目录 `sample/` 下的留证文件同源。
/// 样本中的 `jx0408id` / `xmid` / `pcid` 已在留证时脱敏。
const String _realCurriculumWeek7Json = '''
{"Msg":"success~","code":"1","data":[{"date":[{"xqmc":"一","mxrq":"2026-10-19","zc":"all","xqid":1},{"xqmc":"二","mxrq":"2026-10-20","zc":"all","xqid":2},{"xqmc":"三","mxrq":"2026-10-21","zc":"all","xqid":3},{"xqmc":"四","mxrq":"2026-10-22","zc":"all","xqid":4},{"xqmc":"五","mxrq":"2026-10-23","zc":"all","xqid":5},{"xqmc":"六","mxrq":"2026-10-24","zc":"all","xqid":6},{"xqmc":"日","mxrq":"2026-10-25","zc":"all","xqid":7}],"item":[{"classWeek":"7-10,13-16","teacherName":"曾丹","xqName":"河西校区","weekNoteDetail":"105,106","buttonCode":"0","xqNumber":"2","ktmc":"智能建造2304班","classTime":"10506","jx0408id":"REDACTED","kch":"03127771","courseName":"工程造价与管理","isRepeatCode":"0","zxs":16,"peopleNumber":30,"maxClassTime":"第三大节","khfs":"考试","startTime":"14:00","endTIme":"15:40","location":"公共423","classWeekDetails":",7,8,9,10,13,14,15,16,","coursesNote":1},{"classWeek":"7-10,13-14","teacherName":"姚丁","xqName":"河西校区","weekNoteDetail":"107,108","buttonCode":"0","xqNumber":"2","ktmc":"智能建造[2303-2304]班","classTime":"10708","jx0408id":"REDACTED","kch":"03153761","courseName":"工程结构大数据及应用","isRepeatCode":"0","zxs":12,"peopleNumber":64,"maxClassTime":"第四大节","khfs":"考查","startTime":"16:00","endTIme":"17:40","location":"公共314","classWeekDetails":",7,8,9,10,13,14,","coursesNote":1},{"classWeek":"7-9","teacherName":"左明汉","xqName":"河西校区","weekNoteDetail":"305,306","buttonCode":"0","xqNumber":"2","ktmc":"智能建造[2303-2304]班","classTime":"30506","jx0408id":"REDACTED","kch":"03153740","courseName":"结构试验与工程监测技术","isRepeatCode":"0","zxs":6,"peopleNumber":64,"maxClassTime":"第三大节","khfs":"考试","startTime":"14:00","endTIme":"15:40","location":"公共402","classWeekDetails":",7,8,9,","coursesNote":1},{"classWeek":"7-10,13-16","teacherName":"曾丹","xqName":"河西校区","weekNoteDetail":"405,406","buttonCode":"0","xqNumber":"2","ktmc":"智能建造2304班","classTime":"40506","jx0408id":"REDACTED","kch":"03127771","courseName":"工程造价与管理","isRepeatCode":"0","zxs":16,"peopleNumber":30,"maxClassTime":"第三大节","khfs":"考试","startTime":"14:00","endTIme":"15:40","location":"公共416","classWeekDetails":",7,8,9,10,13,14,15,16,","coursesNote":1},{"classWeek":"7-8","teacherName":"左明汉","xqName":"河西校区","weekNoteDetail":"407,408","buttonCode":"0","xqNumber":"2","ktmc":"智能建造[2303-2304]班","classTime":"40708","jx0408id":"REDACTED","kch":"03153740","courseName":"结构试验与工程监测技术","isRepeatCode":"0","zxs":4,"peopleNumber":64,"maxClassTime":"第四大节","khfs":"考试","startTime":"16:00","endTIme":"17:40","location":"公共323","classWeekDetails":",7,8,","coursesNote":1},{"classWeek":"7-10,13-16","teacherName":"曾丹","xqName":"河西校区","weekNoteDetail":"505,506","buttonCode":"0","xqNumber":"2","ktmc":"智能建造2304班","classTime":"50506","jx0408id":"REDACTED","kch":"03127771","courseName":"工程造价与管理","isRepeatCode":"0","zxs":16,"peopleNumber":30,"maxClassTime":"第三大节","khfs":"考试","startTime":"14:00","endTIme":"15:40","location":"公共122","classWeekDetails":",7,8,9,10,13,14,15,16,","coursesNote":1}],"week":7,"weekday":"三"}],"nowWeek":"7","jcdatalist":[{"XJMC":"01,02","DJMC":"第一大节"},{"XJMC":"03,04","DJMC":"第二大节"},{"XJMC":"05,06","DJMC":"第三大节"},{"XJMC":"07,08","DJMC":"第四大节"},{"XJMC":"09,10","DJMC":"第五大节"}],"nkbList":[{"kch":"03143010","kcmc":"毕业实习","jgxm":"杨柳依依","xqname":"河西校区","zc":"3-6","tzdlb":"2","sjzcbz":""},{"kch":"03140010","kcmc":"生产实习","jgxm":"杨柳依依","xqname":"河西校区","zc":"1-2","tzdlb":"2","sjzcbz":""},{"kch":"03146190","kcmc":"智能建造综合实训","jgxm":"徐卓君","xqname":"河西校区","zc":"11-12","tzdlb":"2","sjzcbz":""},{"kch":"03153761","kcmc":"工程结构大数据及应用","jgxm":"姚丁","xqname":"河西校区","zc":"7-10,13-14","tzdlb":"2","sjzcbz":""},{"kch":"03146180","kcmc":"工程造价与管理课程设计","jgxm":"曾丹","xqname":"河西校区","zc":"17-18","tzdlb":"2","sjzcbz":""},{"kch":"03153740","kcmc":"结构试验与工程监测技术","jgxm":"左明汉","xqname":"河西校区","zc":"7-10,13-14","tzdlb":"2","sjzcbz":""}]}
''';

/// 实验课表真实样本（同一次抓取，第 7 周）。
/// `ktmc` 覆盖两种真实形态：
///  - 「智能建造[2303-2304]班」：纯班级串
///  - 「智能建造2304班0315374031」：班级 + 课程号 03153740 + 组号 31
const String _realExperimentWeek7Json = '''
{"data":[{"date":[{"xqmc":"一","mxrq":"2026-10-19","zc":"7","xqid":1},{"xqmc":"二","mxrq":"2026-10-20","zc":"7","xqid":2},{"xqmc":"三","mxrq":"2026-10-21","zc":"7","xqid":3},{"xqmc":"四","mxrq":"2026-10-22","zc":"7","xqid":4},{"xqmc":"五","mxrq":"2026-10-23","zc":"7","xqid":5},{"xqmc":"六","mxrq":"2026-10-24","zc":"7","xqid":6},{"xqmc":"日","mxrq":"2026-10-25","zc":"7","xqid":7}],"courses":[{"teacherName":"姚丁","syxmName":"工程结构大数据及应用","weekNoteDetail":"109,110","xmid":"REDACTED","ktmc":"智能建造[2303-2304]班","buildingName":"唐永豪","kch":"03153761","courseName":"工程结构大数据及应用","peopleNumber":"64","classroomName":"崇仁楼202","weekDay":1,"maxClassTime":"","pcid":"REDACTED","startTime":"","endTIme":"","kkzc":"7","coursesNote":2},{"teacherName":"左明汉","syxmName":"简支钢绗架非破损实验(1）","weekNoteDetail":"401,402,403,404","xmid":"REDACTED","ktmc":"智能建造2304班0315374031","buildingName":"唐永豪","kch":"03153740","courseName":"结构试验与工程监测技术","peopleNumber":"15","classroomName":"实训中心110","weekDay":4,"maxClassTime":"","pcid":"REDACTED","startTime":"","endTIme":"","kkzc":"10","coursesNote":4}],"nowWeeked":"7","qsxq":"1"}],"jcdatalist":[{"XJMC":"01,02","DJMC":"第一大节"},{"XJMC":"03,04","DJMC":"第二大节"},{"XJMC":"05,06","DJMC":"第三大节"},{"XJMC":"07,08","DJMC":"第四大节"},{"XJMC":"09,10","DJMC":"第五大节"},{"XJMC":"11,12","DJMC":"第六大节"}],"code":"1","Msg":"success"}
''';

Map<String, dynamic> _decode(String raw) {
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  group('真实课表样本解析', () {
    test('普通课表样本：班级串全部取自 ktmc，无一条为空', () {
      final parser = GetSingleWeekClass(orgdata: _decode(_realCurriculumWeek7Json));
      parser.initData();
      parser.getWeekDate();
      final weekData = parser.getSingleClass();

      final courses = weekData.values.expand((list) => list).toList();
      expect(courses, hasLength(6));
      expect(courses.every((course) => course.className.isNotEmpty), isTrue);
      expect(
        courses.map((course) => course.className).toSet(),
        {'智能建造2304班', '智能建造[2303-2304]班'},
      );
    });

    test('普通课表样本：上课人数、学时、考核方式取自真实字段', () {
      final parser = GetSingleWeekClass(orgdata: _decode(_realCurriculumWeek7Json));
      parser.initData();
      parser.getWeekDate();
      final courses =
          parser.getSingleClass().values.expand((list) => list).toList();

      final course = courses.firstWhere(
        (item) => item.name == '工程造价与管理' && item.location == '公共423',
      );
      expect(course.peopleCount, '30');
      expect(course.creditHours, '16');
      expect(course.assessmentType, '考试');

      final exam = courses.firstWhere(
        (item) => item.name == '工程结构大数据及应用',
      );
      expect(exam.peopleCount, '64');
      expect(exam.creditHours, '12');
      expect(exam.assessmentType, '考查');
    });

    test('实验课样本：班级串剥离课程号后缀，纯班级串原样保留', () {
      final parser = GetSingleWeekExpClass(
        orgdata: _decode(_realExperimentWeek7Json),
      );
      parser.initData();
      parser.getWeekDate();
      final courses =
          parser.getSingleClass().values.expand((list) => list).toList();

      expect(courses, hasLength(2));

      final grouped = courses.firstWhere(
        (item) => item.name.contains('结构试验与工程监测技术'),
      );
      expect(grouped.className, '智能建造2304班');
      expect(grouped.peopleCount, '15');
      expect(grouped.isExp, isTrue);

      final plain = courses.firstWhere(
        (item) => item.name.contains('工程结构大数据及应用'),
      );
      expect(plain.className, '智能建造[2303-2304]班');
      expect(plain.peopleCount, '64');
    });
  });

  group('班级串后缀剥离规则', () {
    Map<String, dynamic> buildCourse(Map<String, dynamic> course) {
      return {
        'code': '1',
        'data': [
          {
            'date': [
              {'xqid': 1, 'mxrq': '2026-10-19'},
            ],
            'courses': [course],
          },
        ],
        'jcdatalist': [
          {'XJMC': '01,02', 'DJMC': '第一大节'},
        ],
      };
    }

    Map<String, dynamic> baseCourse() {
      return {
        'teacherName': '李老师',
        'syxmName': '网络实验',
        'weekNoteDetail': '101,102',
        'coursesNote': 2,
        'courseName': '软件工程',
        'classroomName': '实验楼101',
        'weekDay': 1,
        'kkzc': '1',
      };
    }

    test('ktmc 以课程号开头时剥离课程号与组号后缀', () {
      final course = baseCourse()
        ..['kch'] = '03153740'
        ..['ktmc'] = '智能建造2304班0315374031';

      final parser = GetSingleWeekExpClass(orgdata: buildCourse(course));
      parser.initData();
      parser.getWeekDate();
      final parsed =
          parser.getSingleClass()['2026-10-19']?.single;

      expect(parsed?.className, '智能建造2304班');
    });

    test('ktmc 不以课程号开头时原样保留', () {
      final course = baseCourse()
        ..['kch'] = '03153761'
        ..['ktmc'] = '智能建造[2303-2304]班';

      final parser = GetSingleWeekExpClass(orgdata: buildCourse(course));
      parser.initData();
      parser.getWeekDate();
      final parsed =
          parser.getSingleClass()['2026-10-19']?.single;

      expect(parsed?.className, '智能建造[2303-2304]班');
    });

    test('ktmc 缺失或为空白时班级串为空串', () {
      for (final ktmc in <Object?>[null, '', '   ']) {
        final course = baseCourse()
          ..['kch'] = '03153740'
          ..['ktmc'] = ktmc;

        final parser = GetSingleWeekExpClass(orgdata: buildCourse(course));
        parser.initData();
        parser.getWeekDate();
        final parsed =
            parser.getSingleClass()['2026-10-19']?.single;

        expect(parsed?.className, isEmpty);
      }
    });
  });
}
