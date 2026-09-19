import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/receipt_requisites.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';

/// Кассовая печать слипа сертификата — решение заказчика 2026-09-16.
///
/// Собирает документ из того же, из чего касса собирает чек: установка
/// (`ThisPos`), реквизиты продавца (`buildReceiptRequisites`), имя кассира из
/// таблицы пользователей. Ширину ленты, шапку и подвал шаблона документ здесь
/// не знает вовсе — их даёт `ReceiptPrintService`, ровно как чеку продажи.
///
/// # Ничего не ждёт и ничего не роняет
///
/// [printIssued] ловит **всё**: выпуск уже состоялся, обязательство уже взято,
/// а при возврате деньги уже отданы. Единственный след неудачи — запись в
/// журнале и [takeTroubles] для того, кто спросит.
class LocalCertificateSlipPrinter implements CertificateSlipPrinter {
  LocalCertificateSlipPrinter({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  /// Сколько бед держится без читателя. Число, а не слово «немного»: тот же
  /// предел и тот же довод, что у `LocalPaymentService._troublesKept`.
  static const int _troublesKept = 16;

  final List<CertificateSlipTrouble> _troubles = <CertificateSlipTrouble>[];

  Future<void> _pending = Future<void>.value();

  @override
  Future<void> get pending => _pending;

  @override
  List<CertificateSlipTrouble> takeTroubles() {
    final found = List<CertificateSlipTrouble>.unmodifiable(_troubles);
    _troubles.clear();
    return found;
  }

  @override
  Future<void> printIssued({
    required GiftCertificate certificate,
    int? userId,
    int? refundLocalId,
    String? sourceNumber,
  }) {
    // Цепочка, а не `Future.wait`: слипы одного возврата печатаются по
    // очереди, и `pending` у пробы означает «все отправлены», а не «последний
    // отправлен».
    final job = _pending.then(
      (_) => _printOne(
        certificate: certificate,
        userId: userId,
        refundLocalId: refundLocalId,
        sourceNumber: sourceNumber,
      ),
    );
    _pending = job;
    return job;
  }

  Future<void> _printOne({
    required GiftCertificate certificate,
    required int? userId,
    required int? refundLocalId,
    required String? sourceNumber,
  }) async {
    try {
      if (!GetIt.I.isRegistered<ReceiptPrintService>()) return;
      final printService = GetIt.I<ReceiptPrintService>();

      final thisPos = await _db.thisPosDao.get();

      var cashierName = 'Cashier';
      final byUser = userId ?? certificate.issuedByUserId;
      if (byUser != null) {
        final users = await (_db.select(
          _db.users,
        )..where((u) => u.id.equals(byUser))).get();
        if (users.isNotEmpty) cashierName = users.first.name ?? 'Cashier';
      }

      // Реквизиты продавца — те же, что на чеке. Фискальный блок слипу не
      // нужен и не спрашивается: документ нефискальный по построению, и
      // operationId здесь `null` намеренно.
      final req = await buildReceiptRequisites(
        _db,
        posId: thisPos?.id,
        operationId: null,
        isSale: true,
      );

      final expiresAt = certificate.expiresAt;
      final data = CertificateSlipData(
        number: certificate.number,
        // **Остаток, а не номинал**: у бумажки, выпущенной возвратом, они
        // равны, а у обычной — тоже (её только что выпустили). Остаток верен
        // в обоих случаях, номинал — только в одном.
        amount: certificate.balance,
        dateTime: DateTime.now(),
        posId: thisPos?.id ?? 1,
        posName: thisPos?.cashBoxName ?? 'POS',
        storeName: thisPos?.companyName ?? '',
        cashierName: cashierName,
        expiresAt: expiresAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
        hasPin: certificate.pinHash != null,
        seller: req.seller,
        refundLocalId: refundLocalId,
        sourceNumber: sourceNumber,
      );

      final submitted = await printService.printCertificateSlip(data);
      if (!submitted.isRejected) return;

      // Очередь **не приняла** задание — значит бумажки не будет, пока кассир
      // не напечатает слип заново. Причина едет и в журнал, и тому, кто
      // спросит [takeTroubles].
      _logger.error(
        'Certificate: слип ${certificate.number} не принят в очередь печати — '
        '${submitted.message}. Сертификат выпущен; бумажку надо выдать '
        'иначе.',
      );
      _remember(
        CertificateSlipTrouble(
          number: certificate.number,
          message: submitted.message,
        ),
      );
    } catch (e, stack) {
      final safe = safeErrorText(e);
      _logger.error(
        'Certificate: печать слипа ${certificate.number} не состоялась — '
        '$safe. Сертификат выпущен и годен.',
        e,
        stack,
      );
      _remember(
        CertificateSlipTrouble(number: certificate.number, message: safe),
      );
    }
  }

  void _remember(CertificateSlipTrouble trouble) {
    _troubles.add(trouble);
    while (_troubles.length > _troublesKept) {
      _troubles.removeAt(0);
    }
  }
}
