import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';

import 'payment_connector.dart';

class NfcPaymentConnector implements PaymentConnector {
  NfcPaymentConnector({PaymentConnectorConfig? config})
    : _config =
          config ??
          const PaymentConnectorConfig(
            connectionType: PaymentConnectionType.nfc,
          );

  // ignore: unused_field
  final PaymentConnectorConfig _config;
  final _statusController =
      StreamController<PaymentConnectionStatus>.broadcast();
  PaymentConnectionStatus _status = PaymentConnectionStatus.disconnected;

  bool _sessionActive = false;

  @override
  PaymentConnectionType get connectionType => PaymentConnectionType.nfc;

  @override
  PaymentConnectionStatus get status => _status;

  @override
  Stream<PaymentConnectionStatus> get statusStream => _statusController.stream;

  @override
  bool get isConnected => _status == PaymentConnectionStatus.connected;

  Future<bool> isNfcAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isNfcEnabled() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<NfcSessionResult> startPaymentSession({
    required int amountKopeiki,
    String? orderId,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final available = await isNfcAvailable();
    if (!available) {
      return NfcSessionResult.failure('NFC недоступен на этом устройстве');
    }

    if (_sessionActive) {
      return NfcSessionResult.failure('NFC сессия уже активна');
    }

    final completer = Completer<NfcSessionResult>();
    Timer? timeoutTimer;

    try {
      _sessionActive = true;
      _updateStatus(PaymentConnectionStatus.connecting);

      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          _sessionActive = false;
          _updateStatus(PaymentConnectionStatus.disconnected);
          completer.complete(NfcSessionResult.timeout());
        }
      });

      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso18092},
        onDiscovered: (NfcTag tag) async {
          try {
            _sessionActive = false;
            timeoutTimer?.cancel();
            _updateStatus(PaymentConnectionStatus.disconnected);

            await NfcManager.instance.stopSession();

            if (!completer.isCompleted) {
              completer.complete(
                NfcSessionResult.failure(
                  'NFC-оплата не реализована: списание средств не выполнено. '
                  'Требуется EMV/NDEF и авторизация эквайринга.',
                ),
              );
            }
          } catch (e) {
            _sessionActive = false;
            timeoutTimer?.cancel();
            _updateStatus(PaymentConnectionStatus.disconnected);

            if (!completer.isCompleted) {
              completer.complete(
                NfcSessionResult.failure('Ошибка чтения NFC: $e'),
              );
            }
          }
        },
      );

      return await completer.future;
    } catch (e) {
      _sessionActive = false;
      timeoutTimer?.cancel();
      _updateStatus(PaymentConnectionStatus.disconnected);
      return NfcSessionResult.failure('Ошибка запуска NFC: $e');
    }
  }

  Future<void> stopSession() async {
    try {
      if (_sessionActive) {
        await NfcManager.instance.stopSession();
        _sessionActive = false;
      }
    } catch (_) {}
    _updateStatus(PaymentConnectionStatus.disconnected);
  }

  @override
  Future<ConnectionResult> connect({
    required String address,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _updateStatus(PaymentConnectionStatus.error);
    return ConnectionResult.failure(
      'NFC uses tap-to-pay, not persistent connection',
      code: 'NOT_APPLICABLE',
    );
  }

  @override
  Future<void> disconnect() async {
    await stopSession();
  }

  @override
  Future<TransferResult> send(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return TransferResult.failure(
      'NFC does not support direct send. Use startPaymentSession().',
    );
  }

  @override
  Future<TransferResult> receive({
    Duration timeout = const Duration(seconds: 30),
    int expectedLength = 0,
  }) async {
    return TransferResult.failure(
      'NFC does not support direct receive. Use startPaymentSession().',
    );
  }

  @override
  Future<TransferResult> sendAndReceive(
    Uint8List data, {
    Duration responseTimeout = const Duration(seconds: 30),
  }) async {
    return TransferResult.failure(
      'NFC does not support sendAndReceive. Use startPaymentSession().',
    );
  }

  void _updateStatus(PaymentConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  @override
  void dispose() {
    if (_sessionActive) {
      NfcManager.instance.stopSession().catchError((_) {});
      _sessionActive = false;
    }
    _statusController.close();
  }
}

class NfcSessionResult {
  const NfcSessionResult({
    required this.success,
    this.transactionId,
    this.cardType,
    this.maskedPan,
    this.errorMessage,
  });

  final bool success;

  final String? transactionId;

  final String? cardType;

  final String? maskedPan;

  final String? errorMessage;

  factory NfcSessionResult.success({
    required String transactionId,
    String? cardType,
    String? maskedPan,
  }) {
    return NfcSessionResult(
      success: true,
      transactionId: transactionId,
      cardType: cardType,
      maskedPan: maskedPan,
    );
  }

  factory NfcSessionResult.failure(String message) {
    return NfcSessionResult(success: false, errorMessage: message);
  }

  factory NfcSessionResult.cancelled() {
    return const NfcSessionResult(
      success: false,
      errorMessage: 'Session cancelled by user',
    );
  }

  factory NfcSessionResult.timeout() {
    return const NfcSessionResult(
      success: false,
      errorMessage: 'Waiting for card timed out',
    );
  }

  @override
  String toString() {
    if (success) {
      return 'NfcSessionResult(success, txId: $transactionId)';
    }
    return 'NfcSessionResult(failed: $errorMessage)';
  }
}
