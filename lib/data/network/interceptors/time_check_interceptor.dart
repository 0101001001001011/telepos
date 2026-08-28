import 'request_interceptor.dart';

class HeaderTimeCheckInterceptor extends RequestInterceptor {
  HeaderTimeCheckInterceptor({
    this.thresholdSeconds = 125,
    this.onTimeDriftDetected,
    this.onTimeSynced,
  });

  final int thresholdSeconds;

  final void Function(int driftSeconds)? onTimeDriftDetected;

  final void Function(int driftSeconds)? onTimeSynced;

  int _lastDriftSeconds = 0;

  bool _isDriftDetected = false;

  @override
  String get name => 'HeaderTimeCheckInterceptor';

  @override
  int get priority => 80;

  int get lastDriftSeconds => _lastDriftSeconds;

  bool get isDriftDetected => _isDriftDetected;

  @override
  Future<NetworkResponse> onResponse(NetworkResponse response) async {
    final serverTimeHeader = response.getHeader('X-Server-Time');
    if (serverTimeHeader == null) {
      return response;
    }

    final serverTimeMs = int.tryParse(serverTimeHeader);
    if (serverTimeMs == null) {
      return response;
    }

    final localTimeMs = DateTime.now().millisecondsSinceEpoch;
    final driftMs = (localTimeMs - serverTimeMs).abs();
    final driftSeconds = (driftMs / 1000).round();

    _lastDriftSeconds = driftSeconds;

    if (driftSeconds > thresholdSeconds) {
      if (!_isDriftDetected) {
        _isDriftDetected = true;
        onTimeDriftDetected?.call(driftSeconds);
      }
    } else {
      if (_isDriftDetected) {
        _isDriftDetected = false;
        onTimeSynced?.call(driftSeconds);
      }
    }

    return response;
  }

  void reset() {
    _lastDriftSeconds = 0;
    _isDriftDetected = false;
  }
}

enum TimeDriftStatus { synced, driftDetected, unknown }

class TimeDriftInfo {
  const TimeDriftInfo({
    required this.status,
    required this.driftSeconds,
    required this.thresholdSeconds,
    this.lastCheckTime,
  });

  final TimeDriftStatus status;
  final int driftSeconds;
  final int thresholdSeconds;
  final DateTime? lastCheckTime;

  String get driftDescription {
    if (driftSeconds == 0) return 'Синхронизировано';

    final absSeconds = driftSeconds.abs();
    if (absSeconds < 60) return '$absSeconds сек';
    if (absSeconds < 3600) return '${absSeconds ~/ 60} мин';
    return '${absSeconds ~/ 3600} ч';
  }

  bool get isAcceptable => driftSeconds <= thresholdSeconds;
}
