import 'package:telepos/domain/startup/boot_stage.dart';
import 'package:uuid/uuid.dart';

import 'package:telepos/app/config/local_properties.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/telegram/backup/telegram_backup_service.dart';

export 'package:telepos/domain/startup/first_launch_repository.dart'
    show FirstLaunchResult, FoundBackup;

/// The local implementation of [FirstLaunchRepository]: reads the database and
/// asks Telegram what backups exist. This is the binding a desktop till uses.
class FirstLaunchService implements FirstLaunchRepository {
  final LocalProperties _localProperties;
  final AppDatabase _database;
  final TelegramBackupService? _backupService;

  FirstLaunchService({
    required LocalProperties localProperties,
    required AppDatabase database,
    TelegramBackupService? backupService,
  }) : _localProperties = localProperties,
       _database = database,
       _backupService = backupService;

  String generatePosKey() {
    const uuid = Uuid();
    final uuidPart = uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return 'TELEPOS-$uuidPart-$timestamp';
  }

  void savePosKey(String posKey) {
    _localProperties.posKey = posKey;
  }

  String? get currentPosKey => _localProperties.posKey;

  @override
  Future<String> startNewPos() async {
    final key = generatePosKey();
    savePosKey(key);
    return key;
  }

  Future<bool> isPosConfigured() async {
    try {
      final posConfigExists = await _database.thisPosDao.exists();
      if (!posConfigExists) return false;

      final hasUsers = await _database.userDao.hasUsers();
      if (!hasUsers) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isTelegramAuthorized() async {
    final backupService = _backupService;
    if (backupService == null) return false;
    return await backupService.isConnected();
  }

  @override
  Future<List<FoundBackup>> findAvailableBackups() async {
    final backupService = _backupService;
    if (backupService == null) return [];

    try {
      return await backupService.listBackups();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<FirstLaunchResult> determineResult() async {
    if (await isPosConfigured()) {
      return FirstLaunchResult.alreadyConfigured;
    }

    final hasPosKey = currentPosKey != null && currentPosKey!.isNotEmpty;

    final telegramAuthorized = await isTelegramAuthorized();

    if (!telegramAuthorized) {
      if (!hasPosKey) {
        final newKey = generatePosKey();
        savePosKey(newKey);
      }
      return FirstLaunchResult.offlineMode;
    }

    final backups = await findAvailableBackups();

    if (backups.isEmpty) {
      final hasOrganization = await _checkExistingOrganization();

      if (hasOrganization) {
        return FirstLaunchResult.existingUserNewPos;
      }

      if (!hasPosKey) {
        final newKey = generatePosKey();
        savePosKey(newKey);
      }

      return FirstLaunchResult.newPosNoBackups;
    }

    return FirstLaunchResult.newPosWithBackups;
  }

  Future<bool> _checkExistingOrganization() async {
    final backupService = _backupService;
    if (backupService == null) return false;

    try {
      return await backupService.hasExistingOrganization();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> restoreFromBackup(
    FoundBackup backup, {
    BootProgress? onProgress,
  }) async {
    final backupService = _backupService;
    if (backupService == null) return false;

    try {
      onProgress?.call(0.1, BootStage.downloadingBackup);

      final backupData = await backupService.downloadBackup(backup.messageId);
      if (backupData == null) {
        onProgress?.call(0.0, BootStage.backupDownloadFailed);
        return false;
      }

      onProgress?.call(0.5, BootStage.restoringDatabase);

      final restored = await backupService.restoreDatabase(backupData);
      if (!restored) {
        onProgress?.call(0.0, BootStage.databaseRestoreFailed);
        return false;
      }

      onProgress?.call(0.8, BootStage.applyingPosKey);

      savePosKey(backup.posKey);

      onProgress?.call(1.0, BootStage.restoreDone);
      return true;
    } catch (e) {
      onProgress?.call(0.0, BootStage.failed, safeErrorText(e));
      return false;
    }
  }

  @override
  Future<bool> loadGlobalData({BootProgress? onProgress}) async {
    final backupService = _backupService;
    if (backupService == null) return false;

    try {
      onProgress?.call(0.1, BootStage.loadingUsers);
      await backupService.syncGlobalUsers();

      onProgress?.call(0.3, BootStage.loadingAgents);
      await backupService.syncGlobalAgents();

      onProgress?.call(0.5, BootStage.loadingCategories);
      await backupService.syncGlobalCategories();

      onProgress?.call(0.7, BootStage.loadingProducts);
      await backupService.syncGlobalProducts();

      onProgress?.call(0.9, BootStage.loadingSettings);
      await backupService.syncGlobalConfig();

      onProgress?.call(1.0, BootStage.syncDone);
      return true;
    } catch (e) {
      onProgress?.call(0.0, BootStage.failed, safeErrorText(e));
      return false;
    }
  }

  Future<bool> createAndUploadBackup({
    String? description,
    BootProgress? onProgress,
  }) async {
    final backupService = _backupService;
    if (backupService == null) return false;

    try {
      onProgress?.call(0.3, BootStage.creatingBackup);
      final uploaded = await backupService.createAndUploadBackup(
        description: description,
      );

      if (uploaded) {
        onProgress?.call(1.0, BootStage.backupDone);
      } else {
        onProgress?.call(0.0, BootStage.backupCreateFailed);
      }

      return uploaded;
    } catch (e) {
      onProgress?.call(0.0, BootStage.failed, safeErrorText(e));
      return false;
    }
  }
}
