import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/services/first_launch_service.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/encryption/data_encryption_service.dart';
import 'package:telepos/telegram/messaging/message_service.dart';

class BackupMetadata {
  final String posKey;
  final String posName;
  final String organizationName;
  final DateTime createdAt;
  final String checksum;
  final int sizeBytes;
  final String version;
  final String description;

  BackupMetadata({
    required this.posKey,
    required this.posName,
    required this.organizationName,
    required this.createdAt,
    required this.checksum,
    required this.sizeBytes,
    this.version = '1.0',
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'posKey': posKey,
    'posName': posName,
    'organizationName': organizationName,
    'createdAt': createdAt.toIso8601String(),
    'checksum': checksum,
    'sizeBytes': sizeBytes,
    'version': version,
    'description': description,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) => BackupMetadata(
    posKey: json['posKey'] as String? ?? '',
    posName: json['posName'] as String? ?? '',
    organizationName: json['organizationName'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    checksum: json['checksum'] as String? ?? '',
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    version: json['version'] as String? ?? '1.0',
    description: json['description'] as String? ?? '',
  );

  String toMessage() {
    return '__TELEPOS_BACKUP__:${jsonEncode(toJson())}';
  }

  static BackupMetadata? fromMessage(String text) {
    if (!text.startsWith('__TELEPOS_BACKUP__:')) return null;

    try {
      final jsonPart = text.substring('__TELEPOS_BACKUP__:'.length);
      final json = jsonDecode(jsonPart) as Map<String, dynamic>;
      return BackupMetadata.fromJson(json);
    } catch (e) {
      return null;
    }
  }
}

class TelegramBackupService {
  final TdLibClient _client;
  final MessageService _messageService;
  final ChannelRegistry _channelRegistry;
  final DataEncryptionService _encryption;
  final TdLibLogger _logger;
  final String _databasePath;

  // ignore: unused_field - зарезервировано для формата метаданных бэкапа
  static const String _backupPrefix = '__TELEPOS_BACKUP__:';

  TelegramBackupService({
    required TdLibClient client,
    required MessageService messageService,
    required ChannelRegistry channelRegistry,
    required DataEncryptionService encryption,
    required TdLibLogger logger,
    required String databasePath,
  }) : _client = client,
       _messageService = messageService,
       _channelRegistry = channelRegistry,
       _encryption = encryption,
       _logger = logger,
       _databasePath = databasePath;

  Future<bool> isConnected() async {
    try {
      return _client.isReady;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasExistingOrganization() async {
    try {
      return _channelRegistry.count > 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<FoundBackup>> listBackups() async {
    final chatId = _channelRegistry.getChatId(SystemChannelType.posBackup);
    if (chatId == null) {
      _logger.logWarning('Backup channel not found');
      return [];
    }

    try {
      final backups = <FoundBackup>[];

      final messages = await _getChannelMessages(chatId, limit: 100);

      for (final message in messages) {
        final text = message['text'] as String? ?? '';
        final metadata = BackupMetadata.fromMessage(text);

        if (metadata != null) {
          backups.add(
            FoundBackup(
              posKey: metadata.posKey,
              posName: metadata.posName,
              organizationName: metadata.organizationName,
              createdAt: metadata.createdAt,
              messageId: message['id'] as int,
              checksum: metadata.checksum,
              sizeBytes: metadata.sizeBytes,
            ),
          );
        }
      }

      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _logger.logSync('Found ${backups.length} backups');
      return backups;
    } catch (e, st) {
      _logger.logError('listBackups', e, st);
      return [];
    }
  }

  Future<Uint8List?> downloadBackup(int messageId) async {
    final chatId = _channelRegistry.getChatId(SystemChannelType.posBackup);
    if (chatId == null) return null;

    try {
      final message = await _getMessage(chatId, messageId);
      if (message == null) return null;

      final document = message['content']?['document'] as Map<String, dynamic>?;
      if (document == null) {
        _logger.logWarning('Message has no document attachment');
        return null;
      }

      final fileId = document['document']?['id'] as int?;
      if (fileId == null) return null;

      final localPath = await _downloadFile(fileId);
      if (localPath == null) return null;

      final file = File(localPath);
      final encryptedData = await file.readAsBytes();

      final decrypted = await _encryption.decryptBytes(encryptedData);

      final decompressed = GZipDecoder().decodeBytes(decrypted);

      await file.delete();

      return Uint8List.fromList(decompressed);
    } catch (e, st) {
      _logger.logError('downloadBackup', e, st);
      return null;
    }
  }

  Future<bool> restoreDatabase(Uint8List backupData) async {
    try {
      final currentDb = File(_databasePath);
      if (await currentDb.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await currentDb.copy('$_databasePath.pre_restore_$timestamp.bak');
      }

      await currentDb.writeAsBytes(backupData);

      AppDatabase.deleteWalSidecars(_databasePath);

      _logger.logSync('Database restored successfully');
      return true;
    } catch (e, st) {
      _logger.logError('restoreDatabase', e, st);
      return false;
    }
  }

  Future<bool> createAndUploadBackup({String? description}) async {
    final chatId = _channelRegistry.getChatId(SystemChannelType.posBackup);
    if (chatId == null) {
      _logger.logWarning('Backup channel not found');
      return false;
    }

    try {
      try {
        if (GetIt.I.isRegistered<AppDatabase>()) {
          await GetIt.I<AppDatabase>().checkpointWal();
        }
      } catch (e) {
        _logger.logWarning('Backup: WAL checkpoint failed (non-critical): $e');
      }

      final dbFile = File(_databasePath);
      if (!await dbFile.exists()) {
        _logger.logWarning('Database file not found');
        return false;
      }

      final dbData = await dbFile.readAsBytes();

      final compressed = GZipEncoder().encode(dbData);
      if (compressed == null) return false;

      final encrypted = await _encryption.encryptBytes(
        Uint8List.fromList(compressed),
      );

      final checksum = _computeChecksum(encrypted);

      final timestamp = DateTime.now();
      final tempPath =
          '${Directory.systemTemp.path}/telepos_backup_'
          '${timestamp.millisecondsSinceEpoch}.enc';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(encrypted);

      final metadata = await _createBackupMetadata(
        checksum: checksum,
        sizeBytes: encrypted.length,
        description: description,
      );

      await _messageService.sendText(chatId, metadata.toMessage());

      await _uploadFile(chatId, tempPath, 'telepos_backup.enc');

      await tempFile.delete();

      _logger.logSync('Backup uploaded successfully');
      return true;
    } catch (e, st) {
      _logger.logError('createAndUploadBackup', e, st);
      return false;
    }
  }

  static const String _globalSyncUnsupportedMessage =
      'Загрузка глобальных данных через Telegram пока недоступна';

  Future<void> syncGlobalUsers() async {
    _logger.logSync('syncGlobalUsers: not implemented');
    throw UnsupportedError(_globalSyncUnsupportedMessage);
  }

  Future<void> syncGlobalAgents() async {
    _logger.logSync('syncGlobalAgents: not implemented');
    throw UnsupportedError(_globalSyncUnsupportedMessage);
  }

  Future<void> syncGlobalCategories() async {
    _logger.logSync('syncGlobalCategories: not implemented');
    throw UnsupportedError(_globalSyncUnsupportedMessage);
  }

  Future<void> syncGlobalProducts() async {
    _logger.logSync('syncGlobalProducts: not implemented');
    throw UnsupportedError(_globalSyncUnsupportedMessage);
  }

  Future<void> syncGlobalConfig() async {
    _logger.logSync('syncGlobalConfig: not implemented');
    throw UnsupportedError(_globalSyncUnsupportedMessage);
  }

  Future<BackupMetadata> _createBackupMetadata({
    required String checksum,
    required int sizeBytes,
    String? description,
  }) async {
    final identity = _resolveIdentity();

    return BackupMetadata(
      posKey: identity.posKey,
      posName: identity.posName,
      organizationName: identity.organizationName,
      createdAt: DateTime.now(),
      checksum: checksum,
      sizeBytes: sizeBytes,
      description: description ?? '',
    );
  }

  _PosIdentity _resolveIdentity() {
    try {
      final channels = _channelRegistry.allChannels;

      String? storeName;
      String? posId;
      for (final channel in channels) {
        storeName ??=
            (channel.storeName != null && channel.storeName!.trim().isNotEmpty)
            ? channel.storeName!.trim()
            : null;
        posId ??= (channel.posId != null && channel.posId!.trim().isNotEmpty)
            ? channel.posId!.trim()
            : null;
        if (storeName != null && posId != null) break;
      }

      final org = storeName ?? 'UNKNOWN';
      final pos = posId ?? '';
      final posKey = pos.isNotEmpty
          ? 'TELEPOS-${org.toUpperCase()}-$pos'
          : 'TELEPOS-${org.toUpperCase()}';

      return _PosIdentity(
        posKey: posKey,
        posName: pos.isNotEmpty ? 'POS-$pos' : org,
        organizationName: org,
      );
    } catch (e) {
      _logger.logError('_resolveIdentity', e);
      return const _PosIdentity(
        posKey: 'TELEPOS-UNKNOWN',
        posName: 'POS',
        organizationName: 'UNKNOWN',
      );
    }
  }

  String _computeChecksum(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc >> 1) ^ (crc & 1 != 0 ? 0xEDB88320 : 0);
      }
    }
    return (~crc).toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  Future<List<Map<String, dynamic>>> _getChannelMessages(
    int chatId, {
    int limit = 100,
  }) async {
    try {
      final result = await _client.sendSync({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'from_message_id': 0,
        'offset': 0,
        'limit': limit,
        'only_local': false,
      });

      final messages = result['messages'] as List<dynamic>? ?? [];
      return messages.cast<Map<String, dynamic>>();
    } catch (e) {
      _logger.logError('_getChannelMessages', e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getMessage(int chatId, int messageId) async {
    try {
      final result = await _client.sendSync({
        '@type': 'getMessage',
        'chat_id': chatId,
        'message_id': messageId,
      });

      return result;
    } catch (e) {
      _logger.logError('_getMessage', e);
      return null;
    }
  }

  Future<String?> _downloadFile(int fileId) async {
    try {
      final result = await _client.sendSync({
        '@type': 'downloadFile',
        'file_id': fileId,
        'priority': 1,
        'offset': 0,
        'limit': 0,
        'synchronous': true,
      });

      return result['local']?['path'] as String?;
    } catch (e) {
      _logger.logError('_downloadFile', e);
      return null;
    }
  }

  Future<void> _uploadFile(int chatId, String filePath, String fileName) async {
    try {
      await _client.send({
        '@type': 'sendMessage',
        'chat_id': chatId,
        'input_message_content': {
          '@type': 'inputMessageDocument',
          'document': {'@type': 'inputFileLocal', 'path': filePath},
          'caption': {'@type': 'formattedText', 'text': fileName},
        },
      });
    } catch (e) {
      _logger.logError('_uploadFile', e);
    }
  }
}

class _PosIdentity {
  final String posKey;
  final String posName;
  final String organizationName;

  const _PosIdentity({
    required this.posKey,
    required this.posName,
    required this.organizationName,
  });
}
