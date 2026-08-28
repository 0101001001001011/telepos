import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

typedef TdLibUpdateHandler = void Function(Map<String, dynamic> update);

class TdLibEventLoop {
  final TdLibClient _client;
  final TdLibLogger _logger;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _isRunning = false;

  final Map<String, List<TdLibUpdateHandler>> _handlers = {};

  TdLibUpdateHandler? _defaultHandler;

  TdLibEventLoop({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _logger.logConnection('Event loop started');

    _subscription = _client.updates.listen(
      _handleUpdate,
      onError: (error, stackTrace) {
        _logger.logError('event_loop', error, stackTrace);
      },
      onDone: () {
        _isRunning = false;
        _logger.logConnection('Event loop stopped (stream closed)');
      },
    );
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    await _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
    _logger.logConnection('Event loop stopped');
  }

  void on(String updateType, TdLibUpdateHandler handler) {
    _handlers.putIfAbsent(updateType, () => []).add(handler);
  }

  void off(String updateType, TdLibUpdateHandler handler) {
    _handlers[updateType]?.remove(handler);
  }

  void offAll(String updateType) {
    _handlers.remove(updateType);
  }

  void setDefaultHandler(TdLibUpdateHandler handler) {
    _defaultHandler = handler;
  }

  Future<Map<String, dynamic>> waitFor(
    String updateType, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    final completer = Completer<Map<String, dynamic>>();

    late TdLibUpdateHandler handler;
    handler = (update) {
      if (!completer.isCompleted) {
        off(updateType, handler);
        completer.complete(update);
      }
    };

    on(updateType, handler);

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        off(updateType, handler);
        throw TimeoutException('Timeout waiting for $updateType', timeout);
      },
    );
  }

  Stream<Map<String, dynamic>> where(String updateType) {
    return _client.updates.where((update) => update['@type'] == updateType);
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'] as String?;
    if (type == null) return;

    final handlers = _handlers[type];
    if (handlers != null && handlers.isNotEmpty) {
      for (final handler in List.of(handlers)) {
        try {
          handler(update);
        } catch (e, st) {
          _logger.logError('handler:$type', e, st);
        }
      }
    } else {
      _defaultHandler?.call(update);
    }
  }
}
