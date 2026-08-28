import 'dart:async';

import 'package:telepos/telegram/automation/auto_setup_service.dart';
import 'package:telepos/telegram/channels/auto_channel_factory.dart';
import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/encryption/encryption_key_store.dart';

class ProvisioningService {
  final AutoChannelFactory _channelFactory;
  final AutoSetupService _setupService;
  final TdLibLogger _logger;
  final ChannelManager? _channelManager;
  final ChannelRegistry? _channelRegistry;
  final EncryptionKeyStore? _keyStore;

  ProvisioningService({
    required AutoChannelFactory channelFactory,
    required AutoSetupService setupService,
    required TdLibLogger logger,
    ChannelManager? channelManager,
    ChannelRegistry? channelRegistry,
    EncryptionKeyStore? keyStore,
  }) : _channelFactory = channelFactory,
       _setupService = setupService,
       _logger = logger,
       _channelManager = channelManager,
       _channelRegistry = channelRegistry,
       _keyStore = keyStore;

  Future<bool> provisionNewPos({
    required String storeName,
    required String posId,
    int? serverUserId,
  }) async {
    _logger.logConnection('Provisioning new POS: $posId at $storeName');

    try {
      await _channelFactory.createPosStatusChannel(
        storeName: storeName,
        posId: posId,
      );

      final result = await _setupService.startSetup(
        storeName: storeName,
        posId: posId,
        serverUserId: serverUserId,
      );

      if (result) {
        _logger.logConnection('POS provisioned successfully: $posId');
      } else {
        _logger.logError('provisioning', 'POS provisioning failed: $posId');
      }

      return result;
    } catch (e, st) {
      _logger.logError('provisionNewPos', e, st);
      return false;
    }
  }

  Future<void> deactivatePos({required String posId}) async {
    _logger.logConnection('Deactivating POS: $posId');

    try {
      final registry = _channelRegistry;
      if (registry != null) {
        final posStatusChatId = registry.getChatId(
          SystemChannelType.posTerminalStatus,
        );
        if (posStatusChatId != null) {
          final channelManager = _channelManager;
          if (channelManager != null) {
            _logger.logSync('Deleting POS status channel: $posStatusChatId');
            await channelManager.deleteChannel(posStatusChatId);
          }
        }
      }

      final channelManager = _channelManager;
      if (channelManager != null && registry != null) {
        final systemChannelTypes = [
          SystemChannelType.posSystem,
          SystemChannelType.posSales,
          SystemChannelType.posAlerts,
          SystemChannelType.posReports,
          SystemChannelType.posSync,
          SystemChannelType.posFiscal,
          SystemChannelType.staffChat,
          SystemChannelType.posDataExchange,
        ];

        for (final channelType in systemChannelTypes) {
          final chatId = registry.getChatId(channelType);
          if (chatId != null) {
            _logger.logSync('Leaving channel: ${channelType.name}');
            await channelManager.leaveChannel(chatId);
          }
        }
      }

      final keyStore = _keyStore;
      if (keyStore != null) {
        _logger.logEncryption('Revoking encryption keys for POS: $posId');
        await keyStore.revokeKey(posId);
        await keyStore.clearAll();
      }

      if (registry != null) {
        await registry.clear();
      }

      _logger.logConnection('POS deactivated successfully: $posId');
    } catch (e, st) {
      _logger.logError('deactivatePos', e, st);
      rethrow;
    }
  }

  Future<void> relocatePos({
    required String posId,
    required String fromStore,
    required String toStore,
  }) async {
    _logger.logConnection('Relocating POS $posId: $fromStore → $toStore');

    try {
      final channelManager = _channelManager;
      final registry = _channelRegistry;

      if (channelManager != null && registry != null) {
        final channelTypesToLeave = [
          SystemChannelType.posSystem,
          SystemChannelType.posSales,
          SystemChannelType.posAlerts,
          SystemChannelType.posReports,
          SystemChannelType.posSync,
          SystemChannelType.posFiscal,
          SystemChannelType.staffChat,
          SystemChannelType.posDataExchange,
        ];

        for (final channelType in channelTypesToLeave) {
          final chatId = registry.getChatId(channelType);
          if (chatId != null) {
            _logger.logSync('Leaving $fromStore channel: ${channelType.name}');
            await channelManager.leaveChannel(chatId);
          }
        }

        final oldPosStatusChatId = registry.getChatId(
          SystemChannelType.posTerminalStatus,
        );
        if (oldPosStatusChatId != null) {
          await channelManager.deleteChannel(oldPosStatusChatId);
        }

        await registry.clear();
      }

      _logger.logConnection('Provisioning for new store: $toStore');
      final success = await provisionNewPos(storeName: toStore, posId: posId);

      if (success) {
        _logger.logConnection('POS relocated successfully: $posId → $toStore');
      } else {
        throw StateError('Failed to provision POS for new store: $toStore');
      }
    } catch (e, st) {
      _logger.logError('relocatePos', e, st);
      rethrow;
    }
  }

  Future<ProvisioningStatus> getStatus({required String posId}) async {
    final registry = _channelRegistry;
    if (registry == null) {
      return ProvisioningStatus.notProvisioned;
    }

    final hasSystem = registry.getChatId(SystemChannelType.posSystem) != null;
    final hasDataExchange =
        registry.getChatId(SystemChannelType.posDataExchange) != null;
    final hasPosStatus =
        registry.getChatId(SystemChannelType.posTerminalStatus) != null;

    if (hasSystem && hasDataExchange && hasPosStatus) {
      return ProvisioningStatus.fullyProvisioned;
    } else if (hasSystem || hasDataExchange) {
      return ProvisioningStatus.partiallyProvisioned;
    } else {
      return ProvisioningStatus.notProvisioned;
    }
  }
}

enum ProvisioningStatus {
  notProvisioned,

  partiallyProvisioned,

  fullyProvisioned,
}
