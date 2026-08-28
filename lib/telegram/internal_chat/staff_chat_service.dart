import 'dart:async';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/media_service.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/telegram/messaging/realtime_updates.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';

class StaffChatService {
  final MessageService _messageService;
  final MediaService? _mediaService;
  final RealtimeUpdates _realtimeUpdates;
  final TdLibLogger _logger;

  int? _staffChatId;

  StaffChatService({
    required MessageService messageService,
    MediaService? mediaService,
    required RealtimeUpdates realtimeUpdates,
    required TdLibLogger logger,
  }) : _messageService = messageService,
       _mediaService = mediaService,
       _realtimeUpdates = realtimeUpdates,
       _logger = logger;

  bool get isConfigured => _staffChatId != null;

  void configure(int chatId) {
    _staffChatId = chatId;
    _logger.logConnection('Staff chat configured: $chatId');
  }

  Future<TelegramMessage> sendMessage(String text) async {
    _ensureConfigured();
    return _messageService.sendText(_staffChatId!, text);
  }

  Future<TelegramMessage> replyTo(int messageId, String text) async {
    _ensureConfigured();
    return _messageService.sendReply(_staffChatId!, messageId, text);
  }

  Future<List<TelegramMessage>> getHistory({
    int limit = 50,
    int fromMessageId = 0,
  }) async {
    _ensureConfigured();
    return _messageService.getHistory(
      _staffChatId!,
      limit: limit,
      fromMessageId: fromMessageId,
    );
  }

  Stream<TelegramMessage> get messages {
    _ensureConfigured();
    return _realtimeUpdates.messagesForChat(_staffChatId!);
  }

  Future<List<TelegramMessage>> search(String query) async {
    _ensureConfigured();
    return _messageService.searchMessages(_staffChatId!, query);
  }

  Future<void> markAsRead(int upToMessageId) async {
    _ensureConfigured();
    await _messageService.markAsRead(_staffChatId!, upToMessageId);
  }

  Future<bool> deleteMessage(int messageId) async {
    _ensureConfigured();
    try {
      await _messageService.deleteMessage(_staffChatId!, messageId);
      _logger.logConnection('Message deleted: $messageId');
      return true;
    } catch (e) {
      _logger.logError('deleteMessage', e);
      return false;
    }
  }

  Future<bool> editMessage(int messageId, String newText) async {
    _ensureConfigured();
    try {
      await _messageService.editMessage(_staffChatId!, messageId, newText);
      _logger.logConnection('Message edited: $messageId');
      return true;
    } catch (e) {
      _logger.logError('editMessage', e);
      return false;
    }
  }

  Future<bool> sendPhoto(String filePath, {String? caption}) async {
    _ensureConfigured();
    if (_mediaService == null) {
      _logger.logError('sendPhoto', 'MediaService not available');
      return false;
    }
    try {
      await _mediaService.sendPhoto(_staffChatId!, filePath, caption: caption);
      _logger.logConnection('Photo sent to staff chat');
      return true;
    } catch (e) {
      _logger.logError('sendPhoto', e);
      return false;
    }
  }

  Future<bool> sendDocument(String filePath, {String? caption}) async {
    _ensureConfigured();
    if (_mediaService == null) {
      _logger.logError('sendDocument', 'MediaService not available');
      return false;
    }
    try {
      await _mediaService.sendDocument(
        _staffChatId!,
        filePath,
        caption: caption,
      );
      _logger.logConnection('Document sent to staff chat');
      return true;
    } catch (e) {
      _logger.logError('sendDocument', e);
      return false;
    }
  }

  Future<bool> sendLocation(double latitude, double longitude) async {
    _ensureConfigured();
    if (_mediaService == null) {
      _logger.logError('sendLocation', 'MediaService not available');
      return false;
    }
    try {
      await _mediaService.sendLocation(_staffChatId!, latitude, longitude);
      _logger.logConnection(
        'Location sent to staff chat: $latitude,$longitude',
      );
      return true;
    } catch (e) {
      _logger.logError('sendLocation', e);
      return false;
    }
  }

  void _ensureConfigured() {
    if (_staffChatId == null) {
      throw StateError('Staff chat not configured. Call configure() first.');
    }
  }
}
