import 'package:flutter/foundation.dart';

/// A singleton service for tracking and logging performance metrics.
class PerformanceLogger {
  static final PerformanceLogger _instance = PerformanceLogger._internal();
  factory PerformanceLogger() => _instance;
  PerformanceLogger._internal();

  final Map<String, _PerformanceEntry> _activeTimers = {};
  final List<PerformanceLog> _logs = [];

  /// Starts a timer for a given operation.
  void startTimer(String operationName) {
    _activeTimers[operationName] = _PerformanceEntry(
      name: operationName,
      startTime: DateTime.now(),
    );
    debugPrint('⏱️ [PERF] Started: $operationName');
  }

  /// Stops a timer and logs the duration.
  Duration? stopTimer(String operationName, {String? details}) {
    final entry = _activeTimers.remove(operationName);
    if (entry == null) {
      debugPrint('⚠️ [PERF] No active timer found for: $operationName');
      return null;
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(entry.startTime);

    final log = PerformanceLog(
      operationName: operationName,
      startTime: entry.startTime,
      endTime: endTime,
      duration: duration,
      details: details,
    );

    _logs.add(log);

    final durationMs = duration.inMilliseconds;
    final emoji = durationMs < 500 ? '🟢' : (durationMs < 2000 ? '🟡' : '🔴');
    debugPrint(
      '$emoji [PERF] Completed: $operationName in ${durationMs}ms ${details ?? ''}',
    );

    return duration;
  }

  /// Logs an intermediate step within a larger operation.
  void logStep(String operationName, String stepName) {
    final entry = _activeTimers[operationName];
    if (entry == null) {
      debugPrint(
        '⚠️ [PERF] No active timer found for step: $operationName -> $stepName',
      );
      return;
    }
    final elapsed = DateTime.now().difference(entry.startTime).inMilliseconds;
    debugPrint('   ├─ [PERF] Step "$stepName" at ${elapsed}ms');
  }

  /// Returns all collected logs.
  List<PerformanceLog> get logs => List.unmodifiable(_logs);

  /// Clears all logs.
  void clearLogs() {
    _logs.clear();
    debugPrint('🧹 [PERF] Logs cleared.');
  }

  /// Prints a summary report to the console.
  void printReport() {
    debugPrint('\n');
    debugPrint(
      '╔════════════════════════════════════════════════════════════════╗',
    );
    debugPrint(
      '║               PERFORMANCE REPORT                               ║',
    );
    debugPrint(
      '╠════════════════════════════════════════════════════════════════╣',
    );

    if (_logs.isEmpty) {
      debugPrint(
        '║  No logs recorded.                                             ║',
      );
    } else {
      // Group by operation name
      final Map<String, List<PerformanceLog>> grouped = {};
      for (var log in _logs) {
        grouped.putIfAbsent(log.operationName, () => []).add(log);
      }

      for (var entry in grouped.entries) {
        final name = entry.key;
        final operationLogs = entry.value;
        final avgMs =
            operationLogs
                .map((l) => l.duration.inMilliseconds)
                .reduce((a, b) => a + b) ~/
            operationLogs.length;
        final minMs = operationLogs
            .map((l) => l.duration.inMilliseconds)
            .reduce((a, b) => a < b ? a : b);
        final maxMs = operationLogs
            .map((l) => l.duration.inMilliseconds)
            .reduce((a, b) => a > b ? a : b);

        final emoji = avgMs < 500 ? '🟢' : (avgMs < 2000 ? '🟡' : '🔴');
        debugPrint(
          '║ $emoji ${_padRight(name, 40)} Avg: ${_padLeft('$avgMs', 5)}ms ║',
        );
        debugPrint(
          '║    Calls: ${operationLogs.length}, Min: ${minMs}ms, Max: ${maxMs}ms'
                  .padRight(65) +
              '║',
        );
      }
    }

    debugPrint(
      '╚════════════════════════════════════════════════════════════════╝',
    );
    debugPrint('\n');
  }

  String _padRight(String s, int width) =>
      s.length >= width ? s.substring(0, width) : s.padRight(width);
  String _padLeft(String s, int width) => s.padLeft(width);
}

class _PerformanceEntry {
  final String name;
  final DateTime startTime;
  _PerformanceEntry({required this.name, required this.startTime});
}

class PerformanceLog {
  final String operationName;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String? details;

  PerformanceLog({
    required this.operationName,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.details,
  });

  @override
  String toString() {
    return 'PerformanceLog(op: $operationName, duration: ${duration.inMilliseconds}ms, details: $details)';
  }
}
