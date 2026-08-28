import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_event_loop.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/core/telegram_credentials.dart';
import 'package:telepos/telegram/models/telegram_config.dart';

enum TelegramInitStatus {
  notInitialized,

  initializingTdLib,

  nativeLibraryNotFound,

  readyForAuth,

  ready,

  error,
}

class TelegramInitializer {
  final TdLibClient _client;
  final TdLibEventLoop _eventLoop;
  final TelegramCredentials _credentials;
  final TdLibLogger _logger;

  final _statusController = StreamController<TelegramInitStatus>.broadcast();
  TelegramInitStatus _status = TelegramInitStatus.notInitialized;
  String? _lastError;
  TelegramConfig? _currentConfig;

  TelegramInitializer({
    required TdLibClient client,
    required TdLibEventLoop eventLoop,
    required TelegramCredentials credentials,
    required TdLibLogger logger,
  }) : _client = client,
       _eventLoop = eventLoop,
       _credentials = credentials,
       _logger = logger;

  TelegramInitStatus get status => _status;

  Stream<TelegramInitStatus> get statusStream => _statusController.stream;

  String? get lastError => _lastError;

  TelegramConfig? get currentConfig => _currentConfig;

  Future<TelegramInitStatus> initialize() async {
    _setStatus(TelegramInitStatus.initializingTdLib);
    _lastError = null;

    try {
      final result = await _credentials.loadCredentials();

      if (!result.isValid) {
        _lastError = 'Invalid credentials';
        _setStatus(TelegramInitStatus.error);
        return _status;
      }

      final config = await _credentials.createConfig(
        posId: result.posId,
        storeName: result.storeName,
      );
      _currentConfig = config;

      await _client.initialize(config);

      if (!_eventLoop.isRunning) {
        _eventLoop.start();
      }

      if (_client.isReady) {
        _setStatus(TelegramInitStatus.ready);
      } else {
        _setStatus(TelegramInitStatus.readyForAuth);
      }

      _logger.logConnection('Telegram initialized successfully');
      return _status;
    } catch (e, st) {
      _logger.logError('initialize', e, st);
      _lastError = e.toString();

      final errorStr = e.toString();
      if (errorStr.contains('tdjson.dll not found') ||
          errorStr.contains('libtdjson') ||
          errorStr.contains('TDLib')) {
        _setStatus(TelegramInitStatus.nativeLibraryNotFound);
      } else {
        _setStatus(TelegramInitStatus.error);
      }

      return _status;
    }
  }

  Future<void> reset() async {
    _setStatus(TelegramInitStatus.notInitialized);
    _lastError = null;
    _currentConfig = null;
  }

  Future<void> dispose() async {
    await _statusController.close();
  }

  void _setStatus(TelegramInitStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}
