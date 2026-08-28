import 'dart:async';

import 'package:telepos/domain/entities/telegram/auth_state.dart';
import 'package:telepos/telegram/auth/telegram_auth_service.dart';
import 'package:telepos/telegram/automation/auto_channel_creator.dart';
import 'package:telepos/telegram/automation/auto_bot_deployer.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/encryption/key_exchange_service.dart';

enum SetupStage {
  notStarted,
  authenticating,
  verifyingIdentity,
  searchingChannels,
  creatingChannels,
  deployingBot,
  exchangingKeys,
  establishingSecretChat,
  initialSync,
  completed,
  failed,
}

class SetupProgress {
  final SetupStage stage;
  final double progress;
  final String message;
  final Object? error;

  SetupProgress({
    required this.stage,
    required this.progress,
    required this.message,
    this.error,
  });
}

class AutoSetupService {
  final TelegramAuthService _authService;
  final AutoChannelCreator _channelCreator;
  final AutoBotDeployer _botDeployer;
  final KeyExchangeService _keyExchange;
  final TdLibLogger _logger;

  final _progressController = StreamController<SetupProgress>.broadcast();
  SetupStage _currentStage = SetupStage.notStarted;

  AutoSetupService({
    required TelegramAuthService authService,
    required AutoChannelCreator channelCreator,
    required AutoBotDeployer botDeployer,
    required KeyExchangeService keyExchange,
    required TdLibLogger logger,
  }) : _authService = authService,
       _channelCreator = channelCreator,
       _botDeployer = botDeployer,
       _keyExchange = keyExchange,
       _logger = logger;

  SetupStage get currentStage => _currentStage;

  Stream<SetupProgress> get progress => _progressController.stream;

  Future<bool> startSetup({
    required String storeName,
    required String posId,
    int? serverUserId,
  }) async {
    _logger.logConnection('Auto setup started for $storeName (POS: $posId)');

    try {
      _updateProgress(
        SetupStage.authenticating,
        0.1,
        'Ожидание авторизации...',
      );

      if (!_authService.isAuthorized) {
        await _authService.stateStream
            .firstWhere((state) => state is TelegramAuthStateAuthorized)
            .timeout(const Duration(minutes: 10));
      }

      _updateProgress(
        SetupStage.verifyingIdentity,
        0.2,
        'Проверка личности...',
      );

      _updateProgress(
        SetupStage.searchingChannels,
        0.3,
        'Поиск каналов организации...',
      );
      final existingChannels = await _channelCreator.findExistingChannels(
        storeName,
      );

      if (existingChannels.isEmpty) {
        _updateProgress(
          SetupStage.creatingChannels,
          0.4,
          'Создание системных каналов...',
        );
        await _channelCreator.createAll(storeName: storeName, posId: posId);
      } else {
        _updateProgress(
          SetupStage.creatingChannels,
          0.4,
          'Подключение к существующим каналам...',
        );
        await _channelCreator.joinExistingChannels(existingChannels);
      }

      _updateProgress(SetupStage.deployingBot, 0.5, 'Настройка бота...');
      await _botDeployer.deploy(storeName: storeName);

      _updateProgress(
        SetupStage.exchangingKeys,
        0.6,
        'Обмен ключами шифрования...',
      );
      if (serverUserId != null) {
        await _keyExchange.initiateKeyExchange(serverUserId);
      }

      _updateProgress(
        SetupStage.establishingSecretChat,
        0.7,
        'Установка защищённого канала...',
      );

      _updateProgress(
        SetupStage.initialSync,
        0.8,
        'Первичная синхронизация...',
      );

      _updateProgress(SetupStage.completed, 1.0, 'Настройка завершена!');
      _logger.logConnection('Auto setup completed successfully');
      return true;
    } catch (e, st) {
      _logger.logError('autoSetup', e, st);
      _updateProgress(SetupStage.failed, 0.0, 'Ошибка: $e', error: e);
      return false;
    }
  }

  Future<bool> retryFromStage(
    SetupStage stage, {
    required String storeName,
    required String posId,
    int? serverUserId,
  }) async {
    _logger.logConnection('Retrying setup from stage: ${stage.name}');

    try {
      switch (stage) {
        case SetupStage.notStarted:
        case SetupStage.authenticating:
          return startSetup(
            storeName: storeName,
            posId: posId,
            serverUserId: serverUserId,
          );

        case SetupStage.verifyingIdentity:
          _updateProgress(
            SetupStage.verifyingIdentity,
            0.2,
            'Проверка личности...',
          );
          return _continueFromSearching(
            storeName: storeName,
            posId: posId,
            serverUserId: serverUserId,
          );

        case SetupStage.searchingChannels:
          return _continueFromSearching(
            storeName: storeName,
            posId: posId,
            serverUserId: serverUserId,
          );

        case SetupStage.creatingChannels:
          _updateProgress(
            SetupStage.creatingChannels,
            0.4,
            'Создание системных каналов...',
          );
          await _channelCreator.createAll(storeName: storeName, posId: posId);
          return _continueFromDeployingBot(
            storeName: storeName,
            serverUserId: serverUserId,
          );

        case SetupStage.deployingBot:
          return _continueFromDeployingBot(
            storeName: storeName,
            serverUserId: serverUserId,
          );

        case SetupStage.exchangingKeys:
          _updateProgress(
            SetupStage.exchangingKeys,
            0.6,
            'Обмен ключами шифрования...',
          );
          if (serverUserId != null) {
            await _keyExchange.initiateKeyExchange(serverUserId);
          }
          return _continueFromSecretChat();

        case SetupStage.establishingSecretChat:
          return _continueFromSecretChat();

        case SetupStage.initialSync:
          _updateProgress(
            SetupStage.initialSync,
            0.8,
            'Первичная синхронизация...',
          );
          _updateProgress(SetupStage.completed, 1.0, 'Настройка завершена!');
          return true;

        case SetupStage.completed:
          return true;

        case SetupStage.failed:
          return startSetup(
            storeName: storeName,
            posId: posId,
            serverUserId: serverUserId,
          );
      }
    } catch (e, st) {
      _logger.logError('retryFromStage', e, st);
      _updateProgress(SetupStage.failed, 0.0, 'Ошибка: $e', error: e);
      return false;
    }
  }

  Future<bool> _continueFromSearching({
    required String storeName,
    required String posId,
    int? serverUserId,
  }) async {
    _updateProgress(
      SetupStage.searchingChannels,
      0.3,
      'Поиск каналов организации...',
    );
    final existingChannels = await _channelCreator.findExistingChannels(
      storeName,
    );

    if (existingChannels.isEmpty) {
      _updateProgress(
        SetupStage.creatingChannels,
        0.4,
        'Создание системных каналов...',
      );
      await _channelCreator.createAll(storeName: storeName, posId: posId);
    } else {
      _updateProgress(
        SetupStage.creatingChannels,
        0.4,
        'Подключение к существующим каналам...',
      );
      await _channelCreator.joinExistingChannels(existingChannels);
    }

    return _continueFromDeployingBot(
      storeName: storeName,
      serverUserId: serverUserId,
    );
  }

  Future<bool> _continueFromDeployingBot({
    required String storeName,
    int? serverUserId,
  }) async {
    _updateProgress(SetupStage.deployingBot, 0.5, 'Настройка бота...');
    await _botDeployer.deploy(storeName: storeName);

    _updateProgress(
      SetupStage.exchangingKeys,
      0.6,
      'Обмен ключами шифрования...',
    );
    if (serverUserId != null) {
      await _keyExchange.initiateKeyExchange(serverUserId);
    }

    return _continueFromSecretChat();
  }

  Future<bool> _continueFromSecretChat() async {
    _updateProgress(
      SetupStage.establishingSecretChat,
      0.7,
      'Установка защищённого канала...',
    );

    _updateProgress(SetupStage.initialSync, 0.8, 'Первичная синхронизация...');

    _updateProgress(SetupStage.completed, 1.0, 'Настройка завершена!');
    _logger.logConnection('Auto setup retry completed successfully');
    return true;
  }

  Future<void> dispose() async {
    await _progressController.close();
  }

  void _updateProgress(
    SetupStage stage,
    double progress,
    String message, {
    Object? error,
  }) {
    _currentStage = stage;
    if (!_progressController.isClosed) {
      _progressController.add(
        SetupProgress(
          stage: stage,
          progress: progress,
          message: message,
          error: error,
        ),
      );
    }
  }
}
