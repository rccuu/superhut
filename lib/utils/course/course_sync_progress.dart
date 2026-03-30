enum CourseSyncPhase {
  preparing,
  semester,
  courseWeeks,
  experimentWeeks,
  saving,
}

class CourseSyncProgress {
  const CourseSyncProgress({
    required this.phase,
    required this.completedUnits,
    required this.totalUnits,
    required this.message,
    this.currentWeek,
    this.totalWeeks,
  });

  final CourseSyncPhase phase;
  final int completedUnits;
  final int totalUnits;
  final String message;
  final int? currentWeek;
  final int? totalWeeks;

  double? get value {
    if (totalUnits <= 0) {
      return null;
    }
    final normalized = completedUnits.clamp(0, totalUnits);
    return normalized / totalUnits;
  }
}

typedef CourseSyncProgressCallback = void Function(CourseSyncProgress progress);
