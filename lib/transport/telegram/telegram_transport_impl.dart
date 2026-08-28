import 'dart:async';

import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/messaging/media_service.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/telegram/messaging/realtime_updates.dart';
import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/domain/entities/telegram/sync_packet.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';
import 'package:telepos/telegram/reports/report_generator.dart';
import 'package:telepos/telegram/reports/report_sender.dart';

import '../interface/transport_interface_exports.dart';
import 'telegram_transport.dart';

class TelegramTransportImpl implements TelegramTransport {
  final TdLibClient _tdLibClient;
  final TelegramSyncEngine _syncEngine;
  final NotificationService _notificationService;
  final MessageService _messageService;
  final ChannelManager _channelManager;
  final ChannelRegistry _channelRegistry;
  final MediaService _mediaService;
  final ReportSender _reportSender;
  final RealtimeUpdates _realtimeUpdates;

  TransportStatus _status = TransportStatus.disconnected;

  final _statusController = StreamController<TransportStatus>.broadcast();
  final _updatesController = StreamController<TransportUpdate>.broadcast();

  StreamSubscription<TdLibClientState>? _clientStateSubscription;

  TelegramTransportImpl({
    required TdLibClient tdLibClient,
    required TelegramSyncEngine syncEngine,
    required NotificationService notificationService,
    required MessageService messageService,
    required ChannelManager channelManager,
    required ChannelRegistry channelRegistry,
    required MediaService mediaService,
    required ReportSender reportSender,
    required RealtimeUpdates realtimeUpdates,
  }) : _tdLibClient = tdLibClient,
       _syncEngine = syncEngine,
       _notificationService = notificationService,
       _messageService = messageService,
       _channelManager = channelManager,
       _channelRegistry = channelRegistry,
       _mediaService = mediaService,
       _reportSender = reportSender,
       _realtimeUpdates = realtimeUpdates {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _clientStateSubscription = _tdLibClient.stateChanges.listen((state) {
      final newStatus = _mapTdLibState(state);
      _updateStatus(newStatus);
    });
  }

  TransportStatus _mapTdLibState(TdLibClientState state) {
    return switch (state) {
      TdLibClientState.uninitialized => TransportStatus.disconnected,
      TdLibClientState.initializing => TransportStatus.connecting,
      TdLibClientState.waitingForTdlibParameters => TransportStatus.connecting,
      TdLibClientState.waitingForPhoneNumber => TransportStatus.connecting,
      TdLibClientState.waitingForCode => TransportStatus.connecting,
      TdLibClientState.waitingForPassword => TransportStatus.connecting,
      TdLibClientState.waitingForRegistration => TransportStatus.connecting,
      TdLibClientState.ready => TransportStatus.connected,
      TdLibClientState.loggingOut => TransportStatus.disconnected,
      TdLibClientState.closing => TransportStatus.disconnected,
      TdLibClientState.closed => TransportStatus.disconnected,
      TdLibClientState.error => TransportStatus.error,
    };
  }

  @override
  String get name => 'telegram';

  @override
  TransportStatus get currentStatus => _status;

  @override
  Stream<TransportStatus> get statusStream => _statusController.stream;

  @override
  Stream<TransportUpdate> get updates => _updatesController.stream;

  @override
  Future<bool> isAvailable() async {
    return _tdLibClient.isReady;
  }

  @override
  Future<void> initialize() async {
    _updateStatus(TransportStatus.connecting);
    if (_tdLibClient.isReady) {
      _updateStatus(TransportStatus.connected);
    }
  }

  @override
  Future<void> dispose() async {
    await _clientStateSubscription?.cancel();
    await _statusController.close();
    await _updatesController.close();
  }

  @override
  Future<TransportResult<void>> uploadSales(
    List<Map<String, dynamic>> sales,
  ) async {
    return _executeUpload(ExchangeType.sale, sales);
  }

  @override
  Future<TransportResult<void>> uploadRefunds(
    List<Map<String, dynamic>> refunds,
  ) async {
    return _executeUpload(ExchangeType.refund, refunds);
  }

  @override
  Future<TransportResult<void>> uploadShifts(
    List<Map<String, dynamic>> shifts,
  ) async {
    return _executeUpload(ExchangeType.shift, shifts);
  }

  @override
  Future<TransportResult<void>> uploadCashOperations(
    List<Map<String, dynamic>> operations,
  ) async {
    return _executeUpload(ExchangeType.fiscal, operations);
  }

  Future<TransportResult<void>> _executeUpload(
    ExchangeType type,
    List<Map<String, dynamic>> data,
  ) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final sessionId = 'upload_${DateTime.now().millisecondsSinceEpoch}';
      final config = _syncEngine.config;

      await _syncEngine.sendPacket(
        sourceId: config.posId,
        targetId: config.serverId,
        type: type,
        data: data,
        sessionId: sessionId,
      );

      return TransportResult.success(
        data: null,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadProducts({
    DateTime? since,
  }) async {
    return _executeDownload(ExchangeType.product, since: since);
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadPrices({
    DateTime? since,
  }) async {
    return _executeDownload(ExchangeType.price, since: since);
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadAgents({
    DateTime? since,
  }) async {
    return _executeDownload(ExchangeType.agent, since: since);
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadCategories({
    DateTime? since,
  }) async {
    return _executeDownload(ExchangeType.product, since: since);
  }

  @override
  Future<TransportResult<Map<String, dynamic>>> downloadConfig() async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      await _syncEngine.syncAll();

      return TransportResult.success(
        data: <String, dynamic>{},
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> downloadUsers() async {
    return _executeDownload(ExchangeType.config, since: null);
  }

  Future<TransportResult<List<Map<String, dynamic>>>> _executeDownload(
    ExchangeType type, {
    DateTime? since,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      await _syncEngine.syncAll();

      return TransportResult.success(
        data: <Map<String, dynamic>>[],
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<String>> uploadBackup({
    required String filePath,
    required Map<String, dynamic> metadata,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final chatId = _channelRegistry.getChatId(SystemChannelType.posReports);
      if (chatId == null) {
        return TransportResult.failure(
          error: const TransportError.unknown('Reports channel not found'),
          attemptedTransport: TransportType.telegram,
          duration: stopwatch.elapsed,
        );
      }

      final backupId = 'backup_${DateTime.now().millisecondsSinceEpoch}';
      final caption =
          '📦 POS Backup\n'
          '📅 ${DateTime.now().toIso8601String()}\n'
          '🏪 POS ID: ${metadata['posId']}\n'
          '📱 Version: ${metadata['version']}\n'
          '🔑 ID: $backupId';

      await _mediaService.sendDocument(chatId, filePath, caption: caption);

      return TransportResult.success(
        data: backupId,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<String>> downloadBackup(String backupId) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final chatId = _channelRegistry.getChatId(SystemChannelType.posReports);
      if (chatId == null) {
        return TransportResult.failure(
          error: const TransportError.unknown('Reports channel not found'),
          attemptedTransport: TransportType.telegram,
          duration: stopwatch.elapsed,
        );
      }

      final messages = await _messageService.getHistory(chatId, limit: 100);
      final backupMessage = messages.firstWhere(
        (m) => m.text.contains('ID: $backupId'),
        orElse: () => throw Exception('Backup not found: $backupId'),
      );

      final localPath = await _mediaService.downloadFile(
        backupMessage.messageId,
      );

      return TransportResult.success(
        data: localPath,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<List<Map<String, dynamic>>>> listBackups() async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final chatId = _channelRegistry.getChatId(SystemChannelType.posReports);
      if (chatId == null) {
        return TransportResult.success(
          data: <Map<String, dynamic>>[],
          usedTransport: TransportType.telegram,
          duration: stopwatch.elapsed,
        );
      }

      final messages = await _messageService.getHistory(chatId, limit: 100);

      final backups = messages.where((m) => m.text.contains('POS Backup')).map((
        m,
      ) {
        final idMatch = RegExp(r'ID: (backup_\d+)').firstMatch(m.text);
        return {
          'id': idMatch?.group(1) ?? m.messageId.toString(),
          'name': 'backup.db',
          'date': m.date.toIso8601String(),
          'caption': m.text,
        };
      }).toList();

      return TransportResult.success(
        data: backups,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<void>> deleteBackup(String backupId) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final chatId = _channelRegistry.getChatId(SystemChannelType.posReports);
      if (chatId == null) {
        return TransportResult.failure(
          error: const TransportError.unknown('Reports channel not found'),
          attemptedTransport: TransportType.telegram,
          duration: stopwatch.elapsed,
        );
      }

      await _messageService.deleteMessage(chatId, int.parse(backupId));

      return TransportResult.success(
        data: null,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<void>> sendNotification({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final notificationType = NotificationType.values.firstWhere(
        (t) => t.name == type,
        orElse: () => NotificationType.system,
      );

      final config = _syncEngine.config;

      await _notificationService.send(
        NotificationPayload(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          type: notificationType,
          title: title,
          body: body,
          posId: config.posId,
          timestamp: DateTime.now(),
        ),
      );

      return TransportResult.success(
        data: null,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<void>> sendReport({
    required String type,
    required Map<String, dynamic> data,
    String? filePath,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final reportType = ReportType.values.firstWhere(
        (t) => t.name == type,
        orElse: () => ReportType.shift,
      );

      final report = GeneratedReport(
        type: reportType,
        title: data['title'] as String? ?? 'Отчёт',
        content: data['content'] as String? ?? '',
        generatedAt: DateTime.now(),
        rawData: data,
      );

      await _reportSender.sendToReportsChannel(report);

      if (filePath != null) {
        final chatId = _channelRegistry.getChatId(SystemChannelType.posReports);
        if (chatId != null) {
          await _mediaService.sendDocument(
            chatId,
            filePath,
            caption: report.title,
          );
        }
      }

      return TransportResult.success(
        data: null,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<void> subscribeToUpdates(List<String> types) async {}

  @override
  Future<void> unsubscribeFromUpdates() async {}

  @override
  Future<bool> isAuthorized() async {
    return _tdLibClient.isReady;
  }

  @override
  Future<int?> getCurrentUserId() async {
    if (!_tdLibClient.isReady) return null;
    try {
      final result = await _tdLibClient.sendSync({'@type': 'getMe'});
      return result['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TransportResult<List<String>>> getSystemChannels() async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final channels = _channelRegistry.allChannels;
      final channelIds = channels.map((c) => c.chatId.toString()).toList();

      return TransportResult.success(
        data: channelIds,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<int>> sendChannelMessage(
    String channelId,
    String message,
  ) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final result = await _messageService.sendMarkdown(
        int.parse(channelId),
        message,
      );

      return TransportResult.success(
        data: result.messageId,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<int>> sendChannelFile(
    String channelId,
    String filePath, {
    String? caption,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      await _mediaService.sendDocument(
        int.parse(channelId),
        filePath,
        caption: caption,
      );

      final messageId = DateTime.now().millisecondsSinceEpoch;

      return TransportResult.success(
        data: messageId,
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<TransportResult<String>> createPrivateChannel(
    String title,
    String description,
  ) async {
    final stopwatch = Stopwatch()..start();

    if (!await isAvailable()) {
      return TransportResult.failure(
        error: const TransportError.notAvailable('telegram'),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }

    try {
      final channel = await _channelManager.createChannel(
        title: title,
        description: description,
        channelType: SystemChannelType.posSystem,
      );

      return TransportResult.success(
        data: channel.chatId.toString(),
        usedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TransportResult.failure(
        error: TransportError.unknown(e),
        attemptedTransport: TransportType.telegram,
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  Stream<TelegramChannelUpdate> subscribeToChannel(String channelId) {
    return _realtimeUpdates.messagesForChat(int.parse(channelId)).map((msg) {
      final text = msg.text;
      return TelegramChannelUpdate(
        messageId: msg.messageId,
        channelId: channelId,
        text: text,
        senderId: msg.senderId,
        timestamp: msg.date,
        isSyncData: text.startsWith('__TELEPOS_DATA__:'),
        isProtocolMessage: text.startsWith('__TELEPOS_PROTO__:'),
      );
    });
  }

  void _updateStatus(TransportStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }
}
