import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';

import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/data/payment/payment_kind_resolver_impl.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/receipt_requisites.dart';
import 'package:telepos/domain/discount/discount_origin.dart';
import 'package:telepos/domain/sale/payment_service.dart' show FiscalState;
import 'package:telepos/domain/services/receipt_print_service.dart';

/// Собрать чек оплаченной продажи **из базы кассы** — задача 16.
///
/// # Почему из базы, а не из состояния экрана
///
/// До задачи 16 чек собирал `payment_screen._printSaleReceipt` из
/// `saleControllerProvider`: строки, суммы, вид оплаты и сдача брались из
/// памяти экрана. У браузерного терминала памяти экрана касса не видит, а
/// печатает — она; значит источник обязан быть тот же, из которого
/// выведены деньги, — строки чека в базе кассы.
///
/// Это не только совместимость с проводом, но и починка: экран печатал
/// **то, что показывал**, а касса записывала **то, что посчитала**, и
/// расхождение между ними (округление, потолок бонуса, отвергнутый счёт)
/// уезжало в чек молча.
///
/// # Предел, названный прямо
///
/// Имя товара берётся из карточки (`ProductInfos.name`) по `ucode`, а не
/// из строки чека: в `SaleProducts` имени нет вовсе. Товар,
/// переименованный между продажей и печатью, напечатается новым именем.
/// Так было и до задачи (экран читал имя из своей строки, которую сам же
/// и собрал из карточки), и чинится это колонкой в `SaleProducts`, а не
/// здесь.
class SaleReceiptComposer {
  const SaleReceiptComposer({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  /// `null` — чека нет или он пуст: печатать нечего, и это не отказ.
  ///
  /// [fiscalState] — чем кончилась фискализация **этого** чека, если её
  /// спрашивали. Умолчание `null` значит «не спрашивали», и это не то же
  /// самое, что [FiscalState.notRequired]: дубликат, печатаемый из
  /// истории, о причине не знает ничего, а `Sales` исхода фискализации
  /// пока не хранит (колонка — задача 14). Пока её нет, состояние
  /// доезжает сюда **значением от того, кто только что фискализовал**, а
  /// не догадкой по базе.
  Future<SaleReceiptData?> compose({
    required int receiptNo,
    required int posId,
    FiscalState? fiscalState,
  }) async {
    final sale = await _db.saleDao.findByKey(receiptNo, posId);
    if (sale == null) {
      _logger.warning('Receipt: чека $receiptNo на кассе $posId нет');
      return null;
    }

    final lines = await _db.saleProductDao.findBySale(receiptNo, posId);
    if (lines.isEmpty) return null;

    // Происхождение скидок чека — **читатель `SaleDiscounts`** (задача 13).
    // Разность `priceBefore − price`, которой скидка считается ниже, не
    // помнит, откуда взялась: покупатель, которому пообещали «две пачки —
    // третья даром», видел в чеке скидку без имени и не мог проверить, что
    // акцию ему применили вовсе.
    final provenance = <int, List<SaleDiscount>>{};
    for (final d in await _db.saleDiscountDao.findBySale(receiptNo, posId)) {
      (provenance[d.saleProductId] ??= <SaleDiscount>[]).add(d);
    }

    final products = <ReceiptProductLine>[];
    for (final line in lines) {
      final info = await _db.productInfoDao.findByUcode(line.ucode);
      final discount = line.priceBefore > line.price
          ? (line.priceBefore - line.price) * line.quantity
          : Decimal.zero;
      products.add(
        ReceiptProductLine(
          name: info?.name ?? 'Товар ${line.ucode}',
          quantity: line.quantity,
          price: line.price,
          total: line.price * line.quantity,
          discountAmount: discount,
          originalPrice: discount > Decimal.zero ? line.priceBefore : null,
          discountLabel: _discountLabel(provenance[line.id]),
        ),
      );
    }

    // Вид оплаты — по **счёту получателя**, а не по названному терминалом
    // виду: `PaymentRequest.type` это заявка, а строки `Payments` —
    // запись кассы о том, куда деньги на самом деле легли.
    //
    // **Три вида, а не два (круг правки 1).** Первая редакция звала
    // «Картой» всё, что не счёт кассы, — и печатала «Карта» на сумму
    // списанного бонуса, который лежит на `agentCashback`. Чек называл
    // деньги не тем, чем они были.
    final rows = await _db.paymentDao.findBySale(receiptNo, posId);
    final payments = <ReceiptPaymentLine>[];
    final resolver = PaymentKindResolver(_db);
    for (final row in rows) {
      payments.add(
        _paymentLine(
          kind: await resolver.resolve(
            kindId: row.kindId,
            payeeAccountId: row.payeeAccountId,
          ),
          amount: row.amount,
          mask: row.cardMask,
        ),
      );
    }

    // Покупатель. Старый экран передавал его из состояния, и он
    // печатается строкой «Клиент:»; композитор терял его до круга правки
    // 1.
    //
    // Берётся из **строк оплаты**, а не из `Sales.customerLocalId`, и это
    // выбор круга правки 2: `Payments.customerLocalId` пишется на каждой
    // строке оплаты и не читается ничем, что двигает деньги, а
    // `Sales.customerLocalId` читает возврат и **безусловно** правит по
    // нему баланс покупателя (`refund_use_case_impl.dart:111`). Разбор —
    // в `LocalPaymentService._plan`.
    //
    // Агент, привязанный к самой корзине, тоже находится: `perform`
    // пишет его и в `Sales.customerLocalId`, и в строки оплаты.
    String? customerName;
    String? customerPhone;
    final customerId = rows
        .map((r) => r.customerLocalId)
        .firstWhere((id) => id != null, orElse: () => sale.customerLocalId);
    if (customerId != null) {
      final agent = await _db.agentDao.findByLocalId(customerId);
      customerName = agent?.name;
      customerPhone = agent?.phone?.toString();
    }

    final thisPos = await _db.thisPosDao.get();
    final requisites = await buildReceiptRequisites(
      _db,
      posId: posId,
      operationId: receiptNo,
      isSale: true,
    );

    return SaleReceiptData(
      receiptNo: receiptNo,
      posId: posId,
      posName: thisPos?.cashBoxName ?? 'POS',
      storeName: thisPos?.companyName ?? '',
      dateTime: DateTime.now(),
      cashierName: await _cashierName(),
      products: products,
      payments: payments,
      totalAmount: sale.amount,
      change: sale.change,
      customerName: customerName,
      customerPhone: customerPhone,
      seller: requisites.seller,
      fiscal: requisites.fiscal,
      isVatPayer: requisites.isVatPayer,
      vatAmount: requisites.vatFromGross(sale.amount),
      vatRatePercent: requisites.vatRatePercent,
      currencySymbol: requisites.currencySymbol,
      fiscalState: fiscalState,
    );
  }

  /// Строка оплаты по типу счёта получателя.
  ///
  /// `null` у типа — счёт из-под нас исчез; это не «карта», а «оплата»
  /// без обещания вида: назвать неизвестное картой значит соврать на
  /// бумаге, которую покупатель уносит с собой.
  ReceiptPaymentLine _paymentLine({
    required PaymentKind? kind,
    required Decimal amount,
    required String? mask,
  }) {
    // **Имя берётся из справочника, а не выводится по роду счёта** —
    // задача 14. Здесь стояло второе (после `AccountPosting`) место, где
    // руками было сказано «эти рода счёта — бонус», и стояло оно ровно с
    // тем последствием, о котором предупреждал сторож
    // `bonus_account_types_guard_test`: баланс считал по одному правилу,
    // бумага печатала по другому. Теперь оба читают одну строку.
    //
    // Заодно чек впервые способен назвать **настроенное** имя: оператор,
    // переименовавший «Карту» в «Банковскую карту», увидит своё слово на
    // бумаге, а не наше.
    if (kind == null) {
      // Вида не записано и вывести не из чего — счёт из-под нас исчез.
      // Это не «карта»: назвать неизвестное картой значит соврать на
      // бумаге, которую покупатель уносит с собой.
      return ReceiptPaymentLine(name: 'Оплата', amount: amount, isCash: false);
    }
    // «Наличность» на бумаге — это **сдача из ящика**, а не род расчёта:
    // строка `isCash` включает подсчёт «получено / сдача». Отсюда
    // `givesChange`, а не `settlement == tender`.
    if (kind.givesChange) {
      return ReceiptPaymentLine(name: kind.name, amount: amount, isCash: true);
    }
    if (mask != null && kind.requiresAcquiring) {
      return ReceiptPaymentLine(
        name: '${kind.name} $mask',
        amount: amount,
        isCash: false,
      );
    }
    return ReceiptPaymentLine(name: kind.name, amount: amount, isCash: false);
  }

  /// Происхождение скидок строки — словами.
  ///
  /// Источников у строки сегодня не бывает больше одного (акция раздаёт
  /// подарки только строкам без ручной скидки), но правило это чужое:
  /// несколько источников печатаются через запятую, а не «первый попавшийся».
  ///
  /// `null` — происхождения нет: чек продан до v40 либо скидки на строке не
  /// было. Выдумывать имя нельзя — «скидка кассира» на подарке акции хуже
  /// молчания.
  String? _discountLabel(List<SaleDiscount>? rows) {
    if (rows == null || rows.isEmpty) return null;
    final names = <String>[];
    for (final r in rows) {
      final name = DiscountOrigin.nameOf(r.origin);
      if (!names.contains(name)) names.add(name);
    }
    return names.join(', ');
  }

  Future<String> _cashierName() async {
    final shift = await _db.shiftDao.findOpenedShift();
    if (shift == null) return 'Cashier';
    final users = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(shift.userId))).get();
    if (users.isEmpty) return 'Cashier';
    return users.first.name ?? 'Cashier';
  }
}
