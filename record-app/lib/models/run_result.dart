class RunResult {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final double totalDistanceKm;
  final int totalSteps;
  final int pointCount;

  const RunResult({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.totalDistanceKm,
    required this.totalSteps,
    required this.pointCount,
  });

  Duration get elapsed => endTime.difference(startTime);

  String get formattedDistance => totalDistanceKm.toStringAsFixed(2);

  String get formattedElapsed {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (totalDistanceKm <= 0 || elapsed.inSeconds <= 0) {
      return '--:--';
    }

    final paceMinutesPerKm = (elapsed.inSeconds / 60) / totalDistanceKm;
    final minutes = paceMinutesPerKm.floor();
    final seconds = ((paceMinutesPerKm - minutes) * 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    return '${startTime.year}-'
        '${startTime.month.toString().padLeft(2, '0')}-'
        '${startTime.day.toString().padLeft(2, '0')} '
        '${startTime.hour.toString().padLeft(2, '0')}:'
        '${startTime.minute.toString().padLeft(2, '0')}';
  }

  String get shareTitle => '今日跑步 $formattedDistance km';

  String get shareSubtitle =>
      '$formattedElapsed | 配速 $formattedPace | $totalSteps 步';

  String get shareText =>
      '今日跑步 $formattedDistance km，用时 $formattedElapsed，平均配速 $formattedPace，累计 $totalSteps 步。';
}
