import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class ScoreSemesterCacheData {
  const ScoreSemesterCacheData({
    required this.semesterIds,
    required this.selectedId,
    required this.nowSemesterId,
    required this.zxf,
    required this.zxfjd,
    required this.pjjd,
    required this.courseCount,
  });

  final List<String> semesterIds;
  final String selectedId;
  final String nowSemesterId;
  final String zxf;
  final String zxfjd;
  final String pjjd;
  final int courseCount;
}

class ScoreSemesterCache {
  ScoreSemesterCache._();

  static final ScoreSemesterCache instance = ScoreSemesterCache._();

  static const _prefix = 'score_cache_';

  String _key(String userId, String field) => '$_prefix${userId}_$field';

  Future<ScoreSemesterCacheData?> read(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final semesterIds = prefs.getStringList(_key(userId, 'semesters'));
      if (semesterIds == null || semesterIds.isEmpty) return null;

      return ScoreSemesterCacheData(
        semesterIds: semesterIds,
        selectedId: prefs.getString(_key(userId, 'selectedId')) ?? 'all',
        nowSemesterId: prefs.getString(_key(userId, 'nowId')) ?? '',
        zxf: prefs.getString(_key(userId, 'zxf')) ?? '-',
        zxfjd: prefs.getString(_key(userId, 'zxfjd')) ?? '-',
        pjjd: prefs.getString(_key(userId, 'pjjd')) ?? '-',
        courseCount: prefs.getInt(_key(userId, 'courseCount')) ?? 0,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to read score semester cache',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> write(String userId, ScoreSemesterCacheData data) async {
    if (userId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(userId, 'semesters'), data.semesterIds);
      await prefs.setString(_key(userId, 'selectedId'), data.selectedId);
      await prefs.setString(_key(userId, 'nowId'), data.nowSemesterId);
      await prefs.setString(_key(userId, 'zxf'), data.zxf);
      await prefs.setString(_key(userId, 'zxfjd'), data.zxfjd);
      await prefs.setString(_key(userId, 'pjjd'), data.pjjd);
      await prefs.setInt(_key(userId, 'courseCount'), data.courseCount);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to write score semester cache',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final fields = [
      'semesters',
      'selectedId',
      'nowId',
      'zxf',
      'zxfjd',
      'pjjd',
      'courseCount',
    ];
    for (final field in fields) {
      await prefs.remove(_key(userId, field));
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
  }
}
