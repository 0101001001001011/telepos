import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/payment_kind_catalog_impl.dart';
import 'package:telepos/domain/fiscal/bonus_account_types.dart';
import 'package:telepos/domain/refund/refund_allocation.dart';
import 'package:telepos/domain/refund/refund_service.dart';

/// Строки оплаты чека → раскладка возврата — задача 26.
///
/// Единственный читатель базы для [RefundAllocation]: его зовут и проведение
/// (`RefundUseCaseImpl`), и снимок черновика (`LocalRefundService`), поэтому
/// «куда уйдут деньги» на экране и «куда ушли» в базе — один ответ, а не
/// два.
///
/// # Что добавили решения 2026-09-16
///
/// План читает ещё и **бумажки, проданные этим чеком** ([soldCertificates]).
/// Без этого чтения возврат чека, которым сертификат купили, возвращал бы
/// его полную цену деньгами — включая ту часть, которую покупатель уже
/// отоварил. Разбор — в докстринге [refundable].
class RefundPlan {
  const RefundPlan({
    required this.parts,
    required this.rows,
    required this.amount,
    this.soldCertificates = const [],
  });

  final List<RefundPart> parts;

  /// Строка оплаты продажи по [RefundSource.seq].
  final Map<int, Payment> rows;

  /// Сумма, названная возвратом, — цена возвращаемых строк.
  final Decimal amount;

  /// Бумажки, **проданные** возвращаемым чеком (решение 1, 2026-09-16).
  ///
  /// Пусто у подавляющего большинства чеков: сертификаты продаются редко, а
  /// связь ведётся по `gift_certificates.issued_receipt_no`.
  final List<SoldCertificate> soldCertificates;

  /// Сколько на самом деле уйдёт **деньгами**.
  ///
  /// # Потраченное деньгами не возвращается, и это решение, а не округление
  ///
  /// Бумажка на 5000, с которой уже отоварили 1200: покупатель приносит чек
  /// её продажи и просит деньги назад. Вернуть 5000 значит отдать 1200
  /// дважды — один раз товаром, который он унёс, второй раз деньгами.
  /// Поэтому деньгами уходит **остаток** (3800), а бумажка гасится целиком.
  ///
  /// Считается здесь, а не в `RefundUseCaseImpl`, ровно по той причине, по
  /// которой здесь живёт вся раскладка: это число кассир обязан увидеть
  /// **до** подтверждения, а снимок черновика берёт его отсюда же
  /// ([destinations] раскладываются уже от него). Посчитай его проведение
  /// само — экран показывал бы одну сумму, а касса отдавала бы другую.
  Decimal get refundable {
    var spent = Decimal.zero;
    for (final c in soldCertificates) {
      spent += c.spent;
    }
    final left = amount - spent;
    return left > Decimal.zero ? left : Decimal.zero;
  }

  /// Раскладка [amount] по строкам чека [receiptNo]/[posId]. Без чека —
  /// весь возврат из ящика.
  static Future<RefundPlan> of(
    AppDatabase db, {
    required Decimal amount,
    int? receiptNo,
    int? posId,
  }) async {
    final rows = receiptNo == null || posId == null
        ? const <Payment>[]
        : await db.paymentDao.findBySale(receiptNo, posId);
    final catalog = PaymentKindCatalogImpl(db);
    final sources = <RefundSource>[];
    final byIndex = <int, Payment>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final kindId = row.kindId;
      final kind = kindId == null ? null : await catalog.byId(kindId);
      final account = await db.accountDao.findById(row.payeeAccountId);
      sources.add(
        RefundSource(
          seq: i,
          route: RefundAllocation.routeOf(
            kind: kind,
            bonusAccount:
                account != null && BonusAccountTypes.isBonus(account.type),
            transactionId: row.terminalTransactionId,
          ),
          paid: row.amount,
          kindId: kindId,
          kindName: kind?.name,
          payeeAccountId: row.payeeAccountId,
          reference: row.reference,
          transactionId: row.terminalTransactionId,
          cardMask: row.cardMask,
          refundAllowed: kind?.refundAllowed ?? true,
        ),
      );
      byIndex[i] = row;
    }

    // Бумажки, проданные этим чеком. Связь — только `issued_receipt_no`
    // (докстринг `CertificateDao.byIssuedReceipt`).
    final sold = <SoldCertificate>[];
    if (receiptNo != null) {
      for (final c in await db.certificateDao.byIssuedReceipt(
        receiptNo: receiptNo,
        posId: posId,
      )) {
        sold.add(
          SoldCertificate(
            number: c.number,
            balance: c.balance,
            spent: c.spent,
            liabilityAccountId: c.liabilityAccountId,
          ),
        );
      }
    }

    var spent = Decimal.zero;
    for (final c in sold) {
      spent += c.spent;
    }
    var money = amount - spent;
    if (money < Decimal.zero) money = Decimal.zero;

    return RefundPlan(
      // Раскладывается **то, что уйдёт деньгами**, а не названная сумма:
      // иначе строки оплаты чека отдали бы и уже отоваренную часть.
      parts: RefundAllocation.allocate(amount: money, sources: sources),
      rows: byIndex,
      amount: amount,
      soldCertificates: List.unmodifiable(sold),
    );
  }

  /// Строки «куда уйдут деньги» для снимка черновика.
  List<RefundDestination> get destinations => [
    for (final part in parts)
      if (part.amount > Decimal.zero)
        RefundDestination(
          route: part.route,
          amount: part.amount,
          kindId: part.source?.kindId,
          kindName: part.source?.kindName,
          detail: switch (part.route) {
            RefundRoute.certificate => part.source?.reference,
            RefundRoute.card || RefundRoute.manual => part.source?.cardMask,
            _ => null,
          },
        ),
  ];
}

/// Бумажка, **проданная** возвращаемым чеком — решение заказчика
/// 2026-09-16, пункт 1.
///
/// Здесь ровно то, что нужно возврату, и ничего сверх: сколько на ней
/// осталось ([balance] — столько уйдёт деньгами), сколько уже отоварено
/// ([spent] — столько не уйдёт), и на каком счёте лежит обязательство
/// ([liabilityAccountId] — его надо закрыть).
@immutable
class SoldCertificate {
  const SoldCertificate({
    required this.number,
    required this.balance,
    required this.spent,
    required this.liabilityAccountId,
  });

  final String number;

  /// Остаток: столько касса обязана вернуть деньгами.
  final Decimal balance;

  /// Уже отоварено: столько **не** возвращается — оно ушло товаром.
  final Decimal spent;

  final int? liabilityAccountId;

  @override
  String toString() => 'SoldCertificate($number, остаток $balance)';
}
