import 'dart:async';

enum NetworkStatus { online, offline, checking, error }

class NetworkConnectionUseCase {
  NetworkConnectionUseCase();

  final _statusController = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _currentStatus = NetworkStatus.offline;
  Timer? _checkTimer;

  NetworkStatus get status => _currentStatus;

  Stream<NetworkStatus> get statusStream => _statusController.stream;

  bool get isOnline => _currentStatus == NetworkStatus.online;

  bool get isOffline => _currentStatus == NetworkStatus.offline;

  Future<bool> checkConnection() async {
    _updateStatus(NetworkStatus.checking);

    await Future<void>.delayed(const Duration(milliseconds: 100));

    _updateStatus(NetworkStatus.offline);
    return false;
  }

  void startPeriodicCheck({Duration interval = const Duration(seconds: 30)}) {
    stopPeriodicCheck();

    _updateStatus(NetworkStatus.offline);
  }

  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void forceStatus(NetworkStatus status) {
    _updateStatus(status);
  }

  void _updateStatus(NetworkStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    stopPeriodicCheck();
    _statusController.close();
  }
}

class NetworkResult<T> {
  const NetworkResult({
    required this.success,
    this.data,
    this.errorMessage,
    this.wasOffline = false,
  });

  final bool success;

  final T? data;

  final String? errorMessage;

  final bool wasOffline;

  factory NetworkResult.ok(T data) {
    return NetworkResult(success: true, data: data);
  }

  factory NetworkResult.offline() {
    return const NetworkResult(
      success: false,
      errorMessage: 'No network connection',
      wasOffline: true,
    );
  }

  factory NetworkResult.error(String message) {
    return NetworkResult(success: false, errorMessage: message);
  }

  @override
  String toString() {
    if (success) {
      return 'NetworkResult.ok($data)';
    }
    return 'NetworkResult.error($errorMessage, offline: $wasOffline)';
  }
}
