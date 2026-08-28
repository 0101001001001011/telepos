import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_service.dart';

class QueuedMessage {
  final String id;
  final int chatId;
  final String text;
  final bool isSilent;
  final DateTime createdAt;
  int retryCount;
  String? error;

  QueuedMessage({
    required this.id,
    required this.chatId,
    required this.text,
    this.isSilent = false,
    DateTime? createdAt,
    this.retryCount = 0,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatId': chatId,
    'text': text,
    'isSilent': isSilent,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'error': error,
  };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) => QueuedMessage(
    id: json['id'] as String,
    chatId: json['chatId'] as int,
    text: json['text'] as String,
    isSilent: json['isSilent'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
    error: json['error'] as String?,
  );
}

class MessageQueue {
  final MessageService _messageService;
  final TdLibLogger _logger;
  final String _persistPath;

  final Queue<QueuedMessage> _queue = Queue();
  Timer? _processTimer;
  bool _isProcessing = false;
  bool _isOnline = true;

  static const _maxRetries = 5;
  static const _processInterval = Duration(seconds: 5);
  static const _maxQueueSize = 1000;

  MessageQueue({
    required MessageService messageService,
    required TdLibLogger logger,
    required String persistPath,
  }) : _messageService = messageService,
       _logger = logger,
       _persistPath = persistPath;

  int get length => _queue.length;

  bool get isNotEmpty => _queue.isNotEmpty;

  bool get isProcessing => _isProcessing;

  void enqueue(QueuedMessage message) {
    if (_queue.length >= _maxQueueSize) {
      _logger.logError(
        'enqueue',
        'Queue is full ($_maxQueueSize), dropping oldest',
      );
      _queue.removeFirst();
    }
    _queue.add(message);
    _logger.logSync('Message queued', packetId: message.id);
  }

  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    if (isOnline && _queue.isNotEmpty) {
      _processQueue();
    }
  }

  void startProcessing() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(_processInterval, (_) {
      if (_isOnline && _queue.isNotEmpty) {
        _processQueue();
      }
    });
    _logger.logSync('Message queue processing started');
  }

  void stopProcessing() {
    _processTimer?.cancel();
    _processTimer = null;
    _logger.logSync('Message queue processing stopped');
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    _logger.logSync('Processing queue (${_queue.length} messages)');

    while (_queue.isNotEmpty && _isOnline) {
      final message = _queue.first;

      try {
        if (message.isSilent) {
          await _messageService.sendSilent(message.chatId, message.text);
        } else {
          await _messageService.sendText(message.chatId, message.text);
        }

        _queue.removeFirst();
        _logger.logSync('Message sent from queue', packetId: message.id);
      } catch (e) {
        message.retryCount++;
        message.error = e.toString();

        if (message.retryCount >= _maxRetries) {
          _queue.removeFirst();
          _logger.logError(
            'queue',
            'Message dropped after $_maxRetries retries: ${message.id}',
          );
        } else {
          _queue.removeFirst();
          _queue.add(message);
          break;
        }
      }
    }

    _isProcessing = false;
  }

  Future<void> persist() async {
    final data = _queue.map((m) => m.toJson()).toList();
    final file = File(_persistPath);
    final dir = file.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(data));
    _logger.logSync('Queue persisted (${_queue.length} messages)');
  }

  Future<void> restore() async {
    final file = File(_persistPath);
    if (!file.existsSync()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as List;
      for (final item in data) {
        _queue.add(QueuedMessage.fromJson(item as Map<String, dynamic>));
      }
      _logger.logSync('Queue restored (${_queue.length} messages)');
    } catch (e, st) {
      _logger.logError('restore', e, st);
    }
  }

  void clear() {
    _queue.clear();
    _logger.logSync('Queue cleared');
  }

  Future<void> dispose() async {
    stopProcessing();
    await persist();
  }
}
