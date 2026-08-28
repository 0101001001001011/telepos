import 'dart:async';
import 'dart:convert';

import 'package:telepos/telegram/core/tdlib_logger.dart';

class BotWebhookHandler {
  final TdLibLogger _logger;

  final _updateController = StreamController<Map<String, dynamic>>.broadcast();

  BotWebhookHandler({required TdLibLogger logger}) : _logger = logger;

  Stream<Map<String, dynamic>> get updates => _updateController.stream;

  void handleWebhook(String jsonBody) {
    try {
      final data = jsonDecode(jsonBody) as Map<String, dynamic>;
      _logger.logUpdate('webhook', data);
      _updateController.add(data);
    } catch (e, st) {
      _logger.logError('webhook', e, st);
    }
  }

  bool validateRequest(String? secretToken, String expectedToken) {
    if (secretToken == null) return false;
    return secretToken == expectedToken;
  }

  Future<void> dispose() async {
    await _updateController.close();
  }
}
