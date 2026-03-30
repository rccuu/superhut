import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/services/course_sync_service.dart';
import 'package:superhut/utils/course/course_sync_progress.dart';
import 'package:superhut/utils/course/coursemain.dart';

void main() {
  test(
    'CourseSyncService publishes running progress and terminal success',
    () async {
      final completer = Completer<CourseSyncResult>();
      final service = CourseSyncService(
        terminalStateDuration: const Duration(minutes: 1),
        runner: (token, {onProgress}) async {
          onProgress?.call(
            const CourseSyncProgress(
              phase: CourseSyncPhase.courseWeeks,
              completedUnits: 5,
              totalUnits: 42,
              message: '正在获取普通课表（第4周）',
              currentWeek: 4,
              totalWeeks: 20,
            ),
          );
          return completer.future;
        },
      );
      addTearDown(service.dispose);

      final firstStart = service.startManualSync('jwxt-token');
      await Future<void>.delayed(Duration.zero);

      expect(service.state.status, CourseSyncTaskStatus.running);
      expect(service.state.progress, closeTo(5 / 42, 0.0001));
      expect(service.state.currentWeek, 4);
      expect(service.state.totalWeeks, 20);

      final secondStart = await service.startManualSync('jwxt-token');
      expect(secondStart, isFalse);

      completer.complete(const CourseSyncResult.success('课表已刷新'));

      expect(await firstStart, isTrue);
      expect(service.state.status, CourseSyncTaskStatus.success);
      expect(service.state.message, '课表已刷新');
      expect(service.state.eventId, 1);
    },
  );

  test('CourseSyncService emits failure state for empty token', () async {
    final service = CourseSyncService(
      terminalStateDuration: const Duration(minutes: 1),
      runner: (_, {onProgress}) async {
        fail('runner should not be called when token is empty');
      },
    );
    addTearDown(service.dispose);

    final started = await service.startManualSync('   ');

    expect(started, isFalse);
    expect(service.state.status, CourseSyncTaskStatus.failure);
    expect(service.state.message, '登录信息已失效，请重新登录后再试');
    expect(service.state.eventId, 1);
  });
}
