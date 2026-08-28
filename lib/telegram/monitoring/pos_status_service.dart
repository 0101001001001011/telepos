import 'dart:async';

import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_formatter.dart';
import 'package:telepos/telegram/messaging/message_service.dart';

class PosStatus {
  final String posId;
  final bool isOnline;
  final bool isShiftOpen;
  final String? currentCashier;
  final int salesToday;
  final num revenueTodayTotal;
  final String currency;
  final DateTime lastHeartbeat;
  final String appVersion;
  final num diskFreeSpaceMb;

  PosStatus({
    required this.posId,
    required this.isOnline,
    required this.isShiftOpen,
    this.currentCashier,
    this.salesToday = 0,
    this.revenueTodayTotal = 0,
    this.currency = 'KZT',
    required this.lastHeartbeat,
    this.appVersion = '',
    this.diskFreeSpaceMb = 0,
  });
}

class PosStatusService {
  final MessageService _messageService;
  final ChannelRegistry _channelRegistry;
  final MessageFormatter _formatter;
  final TdLibLogger _logger;

  Timer? _heartbeatTimer;
  int? _statusMessageId;
  static const _heartbeatInterval = Duration(minutes: 1);

  PosStatusService({
    required MessageService messageService,
    required ChannelRegistry channelRegistry,
    required TdLibLogger logger,
    MessageFormatter? formatter,
  }) : _messageService = messageService,
       _channelRegistry = channelRegistry,
       _formatter = formatter ?? const MessageFormatter(),
       _logger = logger;

  Future<void> publishStatus(PosStatus status) async {
    final chatId = _channelRegistry.getChatId(
      SystemChannelType.posTerminalStatus,
      status.posId,
    );
    if (chatId == null) return;

    final text = _formatStatus(status);

    if (_statusMessageId != null) {
      try {
        await _messageService.editMessage(chatId, _statusMessageId!, text);
        return;
      } catch (_) {}
    }

    final msg = await _messageService.sendSilent(chatId, text);
    _statusMessageId = msg.messageId;
  }

  void startHeartbeat(PosStatus Function() statusProvider) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      publishStatus(statusProvider()).catchError((e) {
        _logger.logError('heartbeat', e);
      });
    });
    _logger.logConnection('POS heartbeat started');
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _logger.logConnection('POS heartbeat stopped');
  }

  String _formatStatus(PosStatus status) {
    final onlineIcon = status.isOnline ? '🟢' : '🔴';
    final shiftIcon = status.isShiftOpen ? '✅' : '❌';

    return '$onlineIcon ${_formatter.bold("POS ${status.posId}")}\n\n'
        '📊 ${_formatter.bold("Статус")}\n'
        '  Онлайн: $onlineIcon ${status.isOnline ? "Да" : "Нет"}\n'
        '  Смена: $shiftIcon ${status.isShiftOpen ? "Открыта" : "Закрыта"}\n'
        '${status.currentCashier != null ? "  👤 Кассир: ${status.currentCashier}\n" : ""}'
        '\n'
        '💰 ${_formatter.bold("Сегодня")}\n'
        '  Продаж: ${status.salesToday}\n'
        '  Выручка: ${_formatter.money(status.revenueTodayTotal, status.currency)}\n'
        '\n'
        '⚙️ ${_formatter.bold("Система")}\n'
        '  Версия: ${status.appVersion}\n'
        '  Диск: ${status.diskFreeSpaceMb} MB свободно\n'
        '\n'
        '🕐 Обновлено: ${_formatter.dateTime(status.lastHeartbeat)}';
  }
}
