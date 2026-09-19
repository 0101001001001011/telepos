import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Refunds extends Table {
  IntColumn get localId => integer().autoIncrement()();

  IntColumn get serverId => integer().nullable().unique()();

  IntColumn get saleId => integer().nullable()();

  IntColumn get saleReceiptNo => integer().nullable()();

  IntColumn get salePosId => integer().nullable()();

  IntColumn get userId => integer()();

  RealColumn get amount =>
      real().map(const DecimalConverter()).withDefault(const Constant(0.0))();

  RealColumn get cashbackAmount =>
      real().nullable().map(const DecimalConverter())();

  IntColumn get time => integer()();

  IntColumn get state => integer().nullable()();

  IntColumn get customerLocalId => integer().nullable()();

  IntColumn get customerServerId => integer().nullable()();

  IntColumn get weightProductRoundType => integer().nullable()();

  IntColumn get discountsRoundType => integer().nullable()();

  BoolColumn get isOfd => boolean().withDefault(const Constant(false))();

  /// **Один чек — один возврат, и это денежное ограничение, а не порядок.**
  ///
  /// Замер 2026-09-19 (ревизия, пункт 17): раскладка возврата
  /// (`RefundAllocation.allocate`) отдаёт каждой строке оплаты чека всё, что
  /// та принесла, и про прежние возвраты не знает ничего. Пока эта пара
  /// уникальна, знать и не нужно — второго возврата того же чека попросту не
  /// существует. Снимут ключ — и повторный частичный возврат выдаст те же
  /// деньги второй раз: диверсия, снявшая его, получила с чека «300
  /// сертификатом + 700 наличными» **две** новые бумажки по 300 за одну
  /// строку оплаты на 300.
  ///
  /// Сторож — `test/data/refund/refund_repeat_partial_test.dart`: он
  /// меряет ограничение **прямой записью**, мимо сервисов, потому что
  /// проверки в `LocalRefundService` (`findBySale`) останутся зелёными и без
  /// ключа.
  ///
  /// # Чего ключ НЕ закрывает
  ///
  /// Возврат **без чека**: там `saleReceiptNo` пуст, а в SQLite `NULL` не
  /// равен `NULL`, и таких строк бывает сколько угодно. Раскладке там нечего
  /// повторять — строк оплаты чека нет вовсе, всё уходит из ящика, — но
  /// ограничение об этом случае не говорит ничего.
  @override
  List<Set<Column>> get uniqueKeys => [
    {saleReceiptNo, salePosId},
  ];
}

class RefundProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get refundLocalId => integer().nullable()();

  IntColumn get refundServerId => integer().nullable()();

  IntColumn get ucode => integer()();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get quantity => real().map(const DecimalConverter())();

  IntColumn get weightProductRoundType => integer().nullable()();

  IntColumn get discountsRoundType => integer().nullable()();

  RealColumn get inSaleQuantity =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get inSalePrice =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get inSalePriceBefore =>
      real().nullable().map(const DecimalConverter())();
}

class RefundProductMarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get mark => text().nullable()();

  IntColumn get refundProductId => integer().nullable()();
}
