import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../utils/course/course_sync_progress.dart';
import '../../utils/course/coursemain.dart';

enum CourseSyncTaskStatus { idle, running, success, failure }

class CourseSyncTaskSnapshot {
  const CourseSyncTaskSnapshot({
    required this.status,
    required this.message,
    required this.progress,
    required this.eventId,
    this.phase,
    this.currentWeek,
    this.totalWeeks,
  });

  const CourseSyncTaskSnapshot.idle()
    : this(
        status: CourseSyncTaskStatus.idle,
        message: '',
        progress: null,
        eventId: 0,
      );

  final CourseSyncTaskStatus status;
  final String message;
  final double? progress;
  final int eventId;
  final CourseSyncPhase? phase;
  final int? currentWeek;
  final int? totalWeeks;

  bool get isRunning => status == CourseSyncTaskStatus.running;
  bool get isVisible => status != CourseSyncTaskStatus.idle;

  CourseSyncTaskSnapshot copyWith({
    CourseSyncTaskStatus? status,
    String? message,
    double? progress,
    int? eventId,
    CourseSyncPhase? phase,
    int? currentWeek,
    int? totalWeeks,
    bool clearPhase = false,
    bool clearWeeks = false,
  }) {
    return CourseSyncTaskSnapshot(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      eventId: eventId ?? this.eventId,
      phase: clearPhase ? null : (phase ?? this.phase),
      currentWeek: clearWeeks ? null : (currentWeek ?? this.currentWeek),
      totalWeeks: clearWeeks ? null : (totalWeeks ?? this.totalWeeks),
    );
  }
}

typedef CourseSyncRunner =
    Future<CourseSyncResult> Function(
      String token, {
      CourseSyncProgressCallback? onProgress,
    });

class CourseSyncService {
  CourseSyncService({
    CourseSyncRunner? runner,
    Duration terminalStateDuration = const Duration(seconds: 3),
  }) : _runner = runner ?? saveClassToLocal,
       _terminalStateDuration = terminalStateDuration;

  static final CourseSyncService instance = CourseSyncService();

  final CourseSyncRunner _runner;
  final Duration _terminalStateDuration;
  final ValueNotifier<CourseSyncTaskSnapshot> stateListenable =
      ValueNotifier<CourseSyncTaskSnapshot>(
        const CourseSyncTaskSnapshot.idle(),
      );

  Timer? _resetTimer;
  int _eventSeed = 0;

  CourseSyncTaskSnapshot get state => stateListenable.value;

  Future<bool> startManualSync(String token) async {
    if (state.isRunning) {
      return false;
    }

    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      _emitTerminal(
        status: CourseSyncTaskStatus.failure,
        message: '登录信息已失效，请重新登录后再试',
      );
      return false;
    }

    _cancelResetTimer();
    stateListenable.value = const CourseSyncTaskSnapshot(
      status: CourseSyncTaskStatus.running,
      message: '正在准备同步课表',
      progress: 0,
      eventId: 0,
      phase: CourseSyncPhase.preparing,
    );

    try {
      final result = await _runner(
        normalizedToken,
        onProgress: _handleProgress,
      );
      _emitTerminal(
        status:
            result.success
                ? CourseSyncTaskStatus.success
                : CourseSyncTaskStatus.failure,
        message: result.message,
      );
      return result.success;
    } catch (_) {
      _emitTerminal(
        status: CourseSyncTaskStatus.failure,
        message: '课表同步失败，请稍后重试',
      );
      return false;
    }
  }

  void reset() {
    _cancelResetTimer();
    stateListenable.value = const CourseSyncTaskSnapshot.idle();
  }

  void dispose() {
    _cancelResetTimer();
    stateListenable.dispose();
  }

  void _handleProgress(CourseSyncProgress progress) {
    _cancelResetTimer();
    stateListenable.value = CourseSyncTaskSnapshot(
      status: CourseSyncTaskStatus.running,
      message: progress.message,
      progress: progress.value,
      eventId: state.eventId,
      phase: progress.phase,
      currentWeek: progress.currentWeek,
      totalWeeks: progress.totalWeeks,
    );
  }

  void _emitTerminal({
    required CourseSyncTaskStatus status,
    required String message,
  }) {
    final progress =
        status == CourseSyncTaskStatus.success ? 1.0 : state.progress;
    stateListenable.value = CourseSyncTaskSnapshot(
      status: status,
      message: message,
      progress: progress,
      eventId: ++_eventSeed,
    );
    _resetTimer = Timer(_terminalStateDuration, reset);
  }

  void _cancelResetTimer() {
    _resetTimer?.cancel();
    _resetTimer = null;
  }
}
