import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/score_semester_cache.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read returns null when no cache exists', () async {
    final result = await ScoreSemesterCache.instance.read('2021001');
    expect(result, isNull);
  });

  test('read returns null when userId is empty', () async {
    final result = await ScoreSemesterCache.instance.read('');
    expect(result, isNull);
  });

  test('write then read returns same data', () async {
    const data = ScoreSemesterCacheData(
      semesterIds: ['2024-2025-1', '2024-2025-2'],
      selectedId: '2024-2025-1',
      nowSemesterId: '2024-2025-2',
      zxf: '40',
      zxfjd: '120',
      pjjd: '3.5',
      courseCount: 12,
    );

    await ScoreSemesterCache.instance.write('2021001', data);
    final result = await ScoreSemesterCache.instance.read('2021001');

    expect(result, isNotNull);
    expect(result!.semesterIds, ['2024-2025-1', '2024-2025-2']);
    expect(result.selectedId, '2024-2025-1');
    expect(result.nowSemesterId, '2024-2025-2');
    expect(result.zxf, '40');
    expect(result.zxfjd, '120');
    expect(result.pjjd, '3.5');
    expect(result.courseCount, 12);
  });

  test('different userId isolation', () async {
    const data = ScoreSemesterCacheData(
      semesterIds: ['2024-2025-1'],
      selectedId: 'all',
      nowSemesterId: '2024-2025-1',
      zxf: '10',
      zxfjd: '30',
      pjjd: '3.0',
      courseCount: 3,
    );

    await ScoreSemesterCache.instance.write('2021001', data);
    final other = await ScoreSemesterCache.instance.read('2021002');
    expect(other, isNull);
  });

  test('clear removes specific user cache', () async {
    const data = ScoreSemesterCacheData(
      semesterIds: ['2024-2025-1'],
      selectedId: 'all',
      nowSemesterId: '2024-2025-1',
      zxf: '10',
      zxfjd: '30',
      pjjd: '3.0',
      courseCount: 3,
    );

    await ScoreSemesterCache.instance.write('2021001', data);
    await ScoreSemesterCache.instance.write('2021002', data);
    await ScoreSemesterCache.instance.clear('2021001');

    expect(await ScoreSemesterCache.instance.read('2021001'), isNull);
    expect(await ScoreSemesterCache.instance.read('2021002'), isNotNull);
  });

  test('clearAll removes all user caches', () async {
    const data = ScoreSemesterCacheData(
      semesterIds: ['2024-2025-1'],
      selectedId: 'all',
      nowSemesterId: '2024-2025-1',
      zxf: '10',
      zxfjd: '30',
      pjjd: '3.0',
      courseCount: 3,
    );

    await ScoreSemesterCache.instance.write('2021001', data);
    await ScoreSemesterCache.instance.write('2021002', data);
    await ScoreSemesterCache.instance.clearAll();

    expect(await ScoreSemesterCache.instance.read('2021001'), isNull);
    expect(await ScoreSemesterCache.instance.read('2021002'), isNull);
  });

  test('read returns null when semesterIds is empty (corrupted)', () async {
    SharedPreferences.setMockInitialValues({
      'score_cache_2021001_semesters': <String>[],
      'score_cache_2021001_selectedId': 'all',
      'score_cache_2021001_nowId': '',
      'score_cache_2021001_zxf': '10',
      'score_cache_2021001_zxfjd': '30',
      'score_cache_2021001_pjjd': '3.0',
      'score_cache_2021001_courseCount': 0,
    });

    final result = await ScoreSemesterCache.instance.read('2021001');
    expect(result, isNull);
  });

  test('clearAll is callable without error on empty prefs', () async {
    await ScoreSemesterCache.instance.clearAll();
  });
}
