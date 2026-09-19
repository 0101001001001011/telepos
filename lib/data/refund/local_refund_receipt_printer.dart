import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/payment_kind_catalog_impl.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/refund/refund_receipt_printer.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/data/print/receipt_requisites.dart';

/// Чек возврата на кассе — задача 20 плана «Продажа с браузерного терминала».
///
/// # Откуда этот код взялся
///
/// Он целиком приехал из `refund_screen._printRefundReceipt` и
/// `_buildRefundPaymentLines` — полутора сотен строк работы с базой и
/// деньгами, живших в презентационном слое. Логика не переписана, а
/// перенесена: разнос суммы возврата по счетам исходного чека, последняя
/// строка добирает остаток, наличными считается счёт типа 0 или 2 (а также
/// счёт, которого не нашлось), пустой список платежей даёт одну наличную
/// строку.
///
/// **С задачи 26 разноса здесь больше нет**: строки оплаты чека читаются из
/// строк сторно возврата (`_paymentLines`), которые раскладывает
/// `RefundAllocation`. Второе мнение о том, чем вернули, разошлось с деньгами
/// на первом же частичном возврате смешанного чека.
///
/// # Что изменилось по существу
///
/// Кассира берём из смены, как и раньше. Данные, которых у экрана было две
/// штуки и брались они из состояния экрана (`selectedItems`,
/// `selectedTotal`), теперь приходят доводами от того, кто возврат провёл, —
/// то есть от кассы. Разницы в числах нет, а мнение о том, «что вернули»,
/// стало одно: до этой правки экран печатал **свой** набор строк, а деньги
/// отдавала касса по **своему** черновику, и совпадали они лишь потому, что
/// путь был один.
///
/// # Оговорка про импорт снята слиянием
///
/// Здесь стояло: «`buildReceiptRequisites` физически лежит в
/// `lib/presentation/screens/payment/receipt_data_enricher.dart`, хотя
/// презентацией не является вовсе; её место — рядом с чеком, в `lib/data/`,
/// и переезд назван работой узла оплаты (задачи 15–16), которая этот файл и
/// без того переписывает». Переезд **состоялся**: функция живёт в
/// `lib/data/print/receipt_requisites.dart`, и ввоз указывает туда.
///
/// Расхождение было молчаливым: конфликта слияние не дало — файл возврата
/// новый, а переехавший он не трогал, — и нашлось оно анализатором,
/// `Target of URI doesn't exist`. Дублировать функцию здесь было бы хуже
/// в любом случае: два читателя одних реквизитов расходятся молча.
class LocalRefundReceiptPrinter implements RefundReceiptPrinter {
  LocalRefundReceiptPrinter({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  /// Наличными считается счёт типа 0 (касса) или 2 (наличные прочие), а
  /// также счёт, которого в базе не нашлось: неизвестный счёт печатается
  /// наличными, потому что так вёл себя экран, а менять поведение печати
  /// заодно с переносом было бы правкой втихую.
  static const _cashAccountTypes = {0, 2};

  @override
  Future<void> printRefund({
    required RefundOutcome outcome,
    required List<RefundLine> lines,
    required int userId,
  }) async {
    try {
      if (!GetIt.I.isRegistered<ReceiptPrintService>()) return;
      final printService = GetIt.I<ReceiptPrintService>();

      final thisPos = await _db.thisPosDao.get();

      String cashierName = 'Cashier';
      final users = await (_db.select(
        _db.users,
      )..where((u) => u.id.equals(userId))).get();
      if (users.isNotEmpty) {
        cashierName = users.first.name ?? 'Cashier';
      }

      final products = lines
          .map(
            (line) => ReceiptProductLine(
              name: line.name,
              quantity: line.quantity,
              price: line.price,
              total: line.total,
            ),
          )
          .toList();

      final payments = await _paymentLines(outcome);

      final req = await buildReceiptRequisites(
        _db,
        posId: thisPos?.id,
        operationId: outcome.saleReceiptNo,
        isSale: false,
      );

      final receiptData = RefundReceiptData(
        refundId: outcome.refundLocalId,
        originalReceiptNo: outcome.saleReceiptNo,
        posId: thisPos?.id ?? 1,
        posName: thisPos?.cashBoxName ?? 'POS',
        storeName: thisPos?.companyName ?? '',
        dateTime: DateTime.now(),
        cashierName: cashierName,
        products: products,
        payments: payments,
        totalAmount: outcome.amount,
        seller: req.seller,
        fiscal: req.fiscal,
        isVatPayer: req.isVatPayer,
        vatAmount: req.vatFromGross(outcome.amount),
        vatRatePercent: req.vatRatePercent,
        currencySymbol: req.currencySymbol,
      );

      // Сдача в очередь: недоступный принтер оставляет задание в хранилище, а
      // не теряет чек возврата вместе с локальными переменными.
      final submitted = await printService.printRefundReceipt(receiptData);
      if (submitted.isRejected) {
        _logger.warning(
          'Чек возврата не принят в очередь печати: ${submitted.message}',
        );
      }
    } catch (e, stack) {
      // Печать не имеет права отменить состоявшийся возврат: деньги уже
      // отданы, товар уже на остатке.
      _logger.warning(
        'Refund receipt print failed (non-blocking): $e',
        e,
        stack,
      );
    }
  }

  /// Строки оплаты чека возврата — **по строкам сторно этого возврата**,
  /// задача 26.
  ///
  /// Прежде здесь стояла своя пропорция по строкам продажи — второе мнение
  /// о том, чем вернули. С раскладкой задачи 26 оно разошлось с деньгами
  /// сразу: чек «500 сертификатом + 500 наличными» при возврате половины
  /// печатал 250 наличными, а из ящика не выходило ничего. Теперь чек
  /// читает то, что записано, и расходиться ему не с чем.
  Future<List<ReceiptPaymentLine>> _paymentLines(RefundOutcome outcome) async {
    final refundTotal = outcome.amount;

    List<ReceiptPaymentLine> cashOnly() => [
      ReceiptPaymentLine(name: 'Cash', amount: refundTotal, isCash: true),
    ];

    try {
      final rows = await _db.paymentDao.findByRefund(outcome.refundLocalId);
      if (rows.isEmpty) return cashOnly();

      final catalog = PaymentKindCatalogImpl(_db);
      final lines = <ReceiptPaymentLine>[];
      for (final row in rows) {
        final amount = -row.amount;
        if (amount <= Decimal.zero) continue;
        final kindId = row.kindId;
        final kind = kindId == null ? null : await catalog.byId(kindId);
        final account = await _db.accountDao.findById(row.payeeAccountId);
        final isCash = kind == null
            ? account == null || _cashAccountTypes.contains(account.type)
            : kind.id == SystemPaymentKindIds.cash;
        final name =
            kind?.name ?? account?.name ?? (isCash ? 'Cash' : 'Card');
        lines.add(
          ReceiptPaymentLine(name: name, amount: amount, isCash: isCash),
        );
      }

      return lines.isEmpty ? cashOnly() : lines;
    } catch (e) {
      _logger.warning('Refund payment-line build failed, using cash: $e');
      return cashOnly();
    }
  }
}
