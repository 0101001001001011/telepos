import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/device/terminal_device_binding_resolver.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/payment/qr_payment_provider.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/refund/refund_tender_gateway.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_config.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_service.dart';

/// Разговор с платёжным терминалом о возврате — шов ради проб, тем же
/// приёмом, что `CardTerminalDriver` у оплаты.
typedef CardRefundDriver =
    Future<TenderReturn> Function(
      KaspiPosConfig config, {
      required int amountTiyn,
      required String transactionId,
      required String refundKey,
    });

/// Какой платёжный терминал у рабочего места.
typedef PaymentTerminalLookup =
    Future<KaspiPosConfig?> Function(int? terminalId);

/// Кассовая реализация [RefundTenderGateway] — задача 26.
///
/// Карта — через `KaspiPosService` по сокету, QR — через `QrPaymentDesk` и
/// `HttpQrPaymentProvider` по HTTP. Эмулируется **зависимость, а не
/// адаптер**: пробы подставляют адрес эмулятора, а не этот класс.
class LocalRefundTenderGateway implements RefundTenderGateway {
  LocalRefundTenderGateway({
    required AppDatabase db,
    required Talker logger,
    QrPaymentDesk? qr,
    CardRefundDriver? cardDriver,
    PaymentTerminalLookup? terminalConfig,
  }) : _db = db,
       _logger = logger,
       _qr = qr,
       _card = cardDriver ?? kaspiRefundDriver,
       _terminalConfig = terminalConfig;

  final AppDatabase _db;
  final Talker _logger;
  final QrPaymentDesk? _qr;
  final CardRefundDriver _card;
  final PaymentTerminalLookup? _terminalConfig;

  static final _hundred = Decimal.fromInt(100);

  @override
  Future<TenderReturn> returnCard({
    required int? terminalId,
    required String transactionId,
    required Decimal amount,
    required String refundKey,
  }) async {
    final lookup = _terminalConfig ?? _boundTerminal;
    final config = await lookup(terminalId);
    if (config == null) {
      return const TenderReturn.refused(
        refundCashlessUnavailableCode,
        'к рабочему месту не привязан платёжный терминал — вернуть на карту '
        'нечем',
      );
    }
    final reply = await _card(
      config,
      amountTiyn: (amount * _hundred).round().toBigInt().toInt(),
      transactionId: transactionId,
      refundKey: refundKey,
    );
    _logger.info('Refund: card return $amount by $transactionId → $reply');
    return reply;
  }

  @override
  Future<TenderReturn> returnQr({
    required String providerIntentId,
    required Decimal amount,
    required String refundKey,
  }) async {
    final qr = _qr;
    if (qr == null) {
      return const TenderReturn.refused(
        refundCashlessUnavailableCode,
        'провайдер QR на кассе не подключён — вернуть через QR нечем',
      );
    }
    final reply = await qr.refund(
      providerIntentId: providerIntentId,
      amount: amount,
      refundKey: refundKey,
    );
    _logger.info('Refund: QR return $amount by $providerIntentId → $reply');
    final refusal = reply.refusal;
    if (refusal == null) {
      return TenderReturn.done(transactionId: reply.value!.providerIntentId);
    }
    return TenderReturn.refused(
      refusal.code == qrNotConfiguredCode
          ? refundCashlessUnavailableCode
          : refundCashlessRefusedCode,
      'провайдер QR не вернул деньги: ${refusal.message}',
    );
  }

  /// Привязка платёжного терминала к рабочему месту — то же правило, что у
  /// оплаты (`LocalPaymentService._kaspiConfig`): ровно одна привязка с
  /// адресом, иначе «проводить нечем».
  ///
  /// **Повтор, а не вызов — и это названо.** Метод оплаты приватный и живёт
  /// в файле, который сейчас правит соседняя дорожка (G1); вынести его в
  /// общее место — одна правка после слияния, записанная в отчёте задачи 26.
  Future<KaspiPosConfig?> _boundTerminal(int? terminalId) async {
    if (terminalId == null) return null;
    try {
      final bindings = await resolveTerminalDeviceBindings(
        database: _db,
        terminalId: terminalId,
        catalog: BuiltinDeviceProfileCatalog(),
        deviceClass: DeviceClass.paymentTerminal,
      );
      if (bindings.length != 1) return null;
      final binding = bindings.single;
      final host = binding.parameters['ipAddress']?.trim();
      if (host == null || host.isEmpty) return null;
      final port =
          int.tryParse(binding.parameters['port'] ?? '') ??
          KaspiPosConfig.defaultPort;
      final config = KaspiPosConfig(host: host, port: port, enabled: true);
      return config.isValid ? config : null;
    } catch (e) {
      _logger.warning('Refund: payment terminal binding unreadable: $e');
      return null;
    }
  }

  /// Настоящий разговор с терминалом Kaspi — умолчание [CardRefundDriver].
  static Future<TenderReturn> kaspiRefundDriver(
    KaspiPosConfig config, {
    required int amountTiyn,
    required String transactionId,
    required String refundKey,
  }) async {
    final service = KaspiPosService(config: config);
    try {
      final result = await service.requestRefund(
        amountKopeiki: amountTiyn,
        transactionId: transactionId,
        refundKey: refundKey,
      );
      if (result.success) {
        return TenderReturn.done(
          transactionId: result.transactionId,
          approvalCode: result.approvalCode,
        );
      }
      return TenderReturn.refused(
        refundCashlessRefusedCode,
        'терминал отказал в возврате на карту: '
        '${result.errorMessage ?? 'причина не названа'}',
      );
    } finally {
      await service.disconnect();
    }
  }
}
