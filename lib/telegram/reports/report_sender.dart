import 'dart:async';

import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/media_service.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/telegram/reports/report_generator.dart';

class ReportSender {
  final MessageService _messageService;
  final MediaService _mediaService;
  final ChannelRegistry _channelRegistry;
  final TdLibLogger _logger;

  ReportSender({
    required MessageService messageService,
    required MediaService mediaService,
    required ChannelRegistry channelRegistry,
    required TdLibLogger logger,
  }) : _messageService = messageService,
       _mediaService = mediaService,
       _channelRegistry = channelRegistry,
       _logger = logger;

  Future<void> sendToReportsChannel(GeneratedReport report) async {
    final chatId = _channelRegistry.getChatId(SystemChannelType.posReports);
    if (chatId == null) {
      _logger.logError('sendReport', 'Reports channel not found');
      return;
    }

    await _messageService.sendText(chatId, report.content);
    _logger.logConnection('Report sent: ${report.title}');
  }

  Future<void> sendToChat(int chatId, GeneratedReport report) async {
    await _messageService.sendText(chatId, report.content);
  }

  Future<void> sendAsFile(
    int chatId,
    GeneratedReport report, {
    String? fileName,
  }) async {
    final name = fileName ?? '${report.type.name}_${_dateStamp()}.txt';

    await _mediaService.sendDataAsFile(
      chatId,
      report.content,
      name,
      caption: report.title,
    );

    _logger.logConnection('Report sent as file: $name');
  }

  Future<void> broadcast(GeneratedReport report) async {
    await sendToReportsChannel(report);

    if (report.type == ReportType.fiscal) {
      final fiscalChatId = _channelRegistry.getChatId(
        SystemChannelType.posFiscal,
      );
      if (fiscalChatId != null) {
        await _messageService.sendSilent(fiscalChatId, report.content);
      }
    }
  }

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}
