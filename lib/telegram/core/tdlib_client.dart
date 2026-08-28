import 'dart:async';
import 'dart:io';

import 'package:libtdjson/libtdjson.dart' as libtdjson;
import 'package:path_provider/path_provider.dart';

import 'package:telepos/telegram/core/tdlib_config.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_config.dart';

enum TdLibClientState {
  uninitialized,
  initializing,
  waitingForTdlibParameters,
  waitingForPhoneNumber,
  waitingForCode,
  waitingForPassword,
  waitingForRegistration,
  ready,
  loggingOut,
  closing,
  closed,
  error,
}

class TdLibClient {
  final TdLibLogger _logger;

  TdLibClientState _state = TdLibClientState.uninitialized;
  libtdjson.Service? _service;

  final _updateController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<TdLibClientState>.broadcast();

  TdLibClient({required TdLibLogger logger}) : _logger = logger;

  TdLibClientState get state => _state;

  Stream<Map<String, dynamic>> get updates => _updateController.stream;

  Stream<TdLibClientState> get stateChanges => _stateController.stream;

  bool get isReady => _state == TdLibClientState.ready;

  bool get isRunning => _service?.isRunning ?? false;

  Future<void> initialize(TelegramConfig config) async {
    if (_state != TdLibClientState.uninitialized) {
      _logger.logError(
        'initialize',
        'Client already initialized (state=$_state)',
      );
      return;
    }

    final errors = TdLibConfigProvider.validate(config);
    if (errors.isNotEmpty) {
      _logger.logError('initialize', 'Invalid config: ${errors.join(", ")}');
      throw ArgumentError('Invalid TDLib config: ${errors.join(", ")}');
    }

    _setState(TdLibClientState.initializing);
    _logger.logConnection('Initializing TDLib client with libtdjson...');

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      final databaseDir = config.databaseDirectory.isNotEmpty
          ? config.databaseDirectory
          : '${appDir.path}/tdlib';
      final filesDir = config.filesDirectory.isNotEmpty
          ? config.filesDirectory
          : '${tempDir.path}/tdlib_files';

      await Directory(databaseDir).create(recursive: true);
      await Directory(filesDir).create(recursive: true);

      String? libraryDir;
      String? libraryFile;

      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final possiblePaths = [
          '$exeDir/tdjson.dll',
          '${Directory.current.path}/tdjson.dll',
          '${Directory.current.path}/windows/tdjson.dll',
          '${appDir.path}/tdjson.dll',
          'C:/TDLib/bin/tdjson.dll',
        ];

        for (final path in possiblePaths) {
          if (await File(path).exists()) {
            libraryFile = path;
            _logger.logConnection('Found tdjson.dll at: $path');
            break;
          }
        }

        if (libraryFile == null) {
          throw TdLibException(
            code: -1,
            message:
                'tdjson.dll not found. Please download TDLib for Windows and place tdjson.dll in project root or C:/TDLib/bin/',
          );
        }
      }

      _service = libtdjson.Service(
        dir: libraryDir,
        file: libraryFile,
        start: false,
        newVerbosityLevel: 2,
        tdlibParameters: {
          'api_id': config.apiId,
          'api_hash': config.apiHash,
          'database_directory': databaseDir,
          'files_directory': filesDir,
          'use_test_dc': config.useTestDc,
          'database_encryption_key': config.storageEncryptionKey ?? '',
          'use_file_database': config.useFileDatabase,
          'use_chat_info_database': config.useChatInfoDatabase,
          'use_message_database': config.useMessageDatabase,
          'system_language_code': config.systemLanguageCode,
          'device_model': config.deviceModel,
          'system_version': config.systemVersion,
          'application_version': config.applicationVersion,
          'enable_storage_optimizer': true,
        },
        beforeSend: (obj) {
          _logger.logRequest(obj['@type'] as String? ?? 'unknown', obj);
        },
        afterReceive: _handleUpdate,
        onReceiveError: (error) {
          _logger.logError('receive', error.toString());
        },
      );

      await _service!.start();

      _logger.logConnection('TDLib client initialized with libtdjson');
    } catch (e, st) {
      _setState(TdLibClientState.error);
      _logger.logError('initialize', e, st);
      rethrow;
    }
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final type = update['@type'] as String?;
    _logger.logUpdate(type ?? 'unknown');

    if (type == 'updateAuthorizationState') {
      _handleAuthorizationState(update['authorization_state']);
    }

    if (!_updateController.isClosed) {
      _updateController.add(update);
    }
  }

  void _handleAuthorizationState(Map<String, dynamic>? authState) {
    if (authState == null) return;

    final type = authState['@type'] as String?;
    _logger.logConnection('Authorization state: $type');

    switch (type) {
      case 'authorizationStateWaitTdlibParameters':
        _setState(TdLibClientState.waitingForTdlibParameters);
        break;
      case 'authorizationStateWaitPhoneNumber':
        _setState(TdLibClientState.waitingForPhoneNumber);
        break;
      case 'authorizationStateWaitCode':
        _setState(TdLibClientState.waitingForCode);
        break;
      case 'authorizationStateWaitPassword':
        _setState(TdLibClientState.waitingForPassword);
        break;
      case 'authorizationStateWaitRegistration':
        _setState(TdLibClientState.waitingForRegistration);
        break;
      case 'authorizationStateReady':
        _setState(TdLibClientState.ready);
        break;
      case 'authorizationStateLoggingOut':
        _setState(TdLibClientState.loggingOut);
        break;
      case 'authorizationStateClosing':
        _setState(TdLibClientState.closing);
        break;
      case 'authorizationStateClosed':
        _setState(TdLibClientState.closed);
        break;
    }
  }

  Future<void> send(Map<String, dynamic> request) async {
    _ensureInitialized();
    _logger.logRequest(request['@type'] as String? ?? 'unknown', request);
    await _service!.send(request);
  }

  Future<Map<String, dynamic>> sendSync(Map<String, dynamic> request) async {
    _ensureInitialized();
    _logger.logRequest(request['@type'] as String? ?? 'unknown', request);

    try {
      final response = await _service!.sendSync(request);
      _logger.logResponse(response['@type'] as String? ?? 'unknown', response);
      return response;
    } catch (e) {
      if (e is libtdjson.Error) {
        throw TdLibException(code: e.code, message: e.message);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    _ensureInitialized();
    _logger.logRequest(request['@type'] as String? ?? 'unknown', request);

    try {
      final response = await _service!.execute(request);
      _logger.logResponse(response['@type'] as String? ?? 'unknown', response);
      return response;
    } catch (e) {
      if (e is libtdjson.Error) {
        throw TdLibException(code: e.code, message: e.message);
      }
      rethrow;
    }
  }

  Future<void> setAuthenticationPhoneNumber(String phoneNumber) async {
    await sendSync({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phoneNumber,
      'settings': {
        'allow_flash_call': false,
        'allow_missed_call': false,
        'is_current_phone_number': false,
        'allow_sms_retriever_api': false,
      },
    });
  }

  Future<void> checkAuthenticationCode(String code) async {
    await sendSync({'@type': 'checkAuthenticationCode', 'code': code});
  }

  Future<void> checkAuthenticationPassword(String password) async {
    await sendSync({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  Future<Map<String, dynamic>> requestQrCodeAuthentication(
    List<int>? otherUserIds,
  ) async {
    return await sendSync({
      '@type': 'requestQrCodeAuthentication',
      'other_user_ids': otherUserIds ?? [],
    });
  }

  Future<void> registerUser(String firstName, [String? lastName]) async {
    await sendSync({
      '@type': 'registerUser',
      'first_name': firstName,
      'last_name': lastName ?? '',
    });
  }

  Future<void> logOut() async {
    await sendSync({'@type': 'logOut'});
  }

  Future<Map<String, dynamic>> getChats({
    int limit = 100,
    int? offsetOrder,
    int? offsetChatId,
  }) async {
    return await sendSync({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': limit,
    });
  }

  Future<Map<String, dynamic>> getChat(int chatId) async {
    return await sendSync({'@type': 'getChat', 'chat_id': chatId});
  }

  Future<Map<String, dynamic>> sendMessage({
    required int chatId,
    required String text,
    int? replyToMessageId,
  }) async {
    return await sendSync({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'reply_to_message_id': replyToMessageId ?? 0,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    });
  }

  Future<Map<String, dynamic>> getChatHistory({
    required int chatId,
    int fromMessageId = 0,
    int offset = 0,
    int limit = 50,
  }) async {
    return await sendSync({
      '@type': 'getChatHistory',
      'chat_id': chatId,
      'from_message_id': fromMessageId,
      'offset': offset,
      'limit': limit,
      'only_local': false,
    });
  }

  Future<Map<String, dynamic>> createChannel({
    required String title,
    String? description,
  }) async {
    return await sendSync({
      '@type': 'createNewSupergroupChat',
      'title': title,
      'is_channel': true,
      'description': description ?? '',
    });
  }

  Future<Map<String, dynamic>> createGroup({
    required String title,
    required List<int> userIds,
  }) async {
    return await sendSync({
      '@type': 'createNewBasicGroupChat',
      'title': title,
      'user_ids': userIds,
    });
  }

  Future<void> close() async {
    if (_state == TdLibClientState.closed) return;

    _setState(TdLibClientState.closing);
    _logger.logConnection('Closing TDLib client...');

    try {
      await _service?.stop();
      _service = null;

      _setState(TdLibClientState.closed);
      _logger.logConnection('TDLib client closed');
    } catch (e, st) {
      _logger.logError('close', e, st);
      _setState(TdLibClientState.error);
    }

    await _updateController.close();
    await _stateController.close();
  }

  void _ensureInitialized() {
    if (_service == null) {
      throw StateError('TDLib client is not initialized');
    }
    if (!_service!.isRunning) {
      throw StateError('TDLib event loop is not running');
    }
  }

  void _setState(TdLibClientState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}

class TdLibException implements Exception {
  final int code;
  final String message;

  TdLibException({required this.code, required this.message});

  @override
  String toString() => 'TdLibException($code): $message';
}
