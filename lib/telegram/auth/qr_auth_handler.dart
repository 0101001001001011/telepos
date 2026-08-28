import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class QrCodeData {
  final String link;
  final DateTime expiresAt;

  QrCodeData({required this.link, required this.expiresAt});
}

class QrAuthHandler {
  final TdLibClient _client;
  final TdLibLogger _logger;

  Timer? _refreshTimer;

  QrAuthHandler({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  Future<QrCodeData> requestQrCode() async {
    _logger.logAuthState('Requesting QR code for auth');

    final result = await _client.requestQrCodeAuthentication([]);

    final link = result['link'] as String? ?? '';
    final expiresIn = result['expires_in'] as int? ?? 300;

    return QrCodeData(
      link: link,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  void startAutoRefresh({
    required Duration interval,
    required void Function(QrCodeData) onNewCode,
    required void Function(Object error) onError,
  }) {
    stopAutoRefresh();

    _refreshTimer = Timer.periodic(interval, (_) async {
      try {
        final data = await requestQrCode();
        onNewCode(data);
      } catch (e) {
        onError(e);
      }
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<Map<String, dynamic>> confirmQrCode(String link) async {
    _logger.logAuthState('Confirming QR code');

    return _client.sendSync({
      '@type': 'confirmQrCodeAuthentication',
      'link': link,
    });
  }
}
