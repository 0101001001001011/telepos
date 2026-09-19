import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Sales extends Table {
  IntColumn get receiptNo => integer()();

  IntColumn get posId => integer()();

  IntColumn get saleId => integer().nullable().unique()();

  IntColumn get userId => integer()();

  RealColumn get amount => real().map(const DecimalConverter())();

  RealColumn get change => real().nullable().map(const DecimalConverter())();

  IntColumn get time => integer()();

  IntColumn get storeId => integer().nullable()();

  IntColumn get customerLocalId => integer().nullable()();

  IntColumn get customerServerId => integer().nullable()();

  IntColumn get loyalCustomerPhone => integer().nullable()();

  BoolColumn get isOfd => boolean().withDefault(const Constant(false))();

  IntColumn get state => integer().nullable()();

  BoolColumn get isWholesale => boolean().withDefault(const Constant(false))();

  IntColumn get weightProductRoundType => integer().nullable()();

  IntColumn get discountsRoundType => integer().nullable()();

  TextColumn get customerBin => text().nullable()();

  IntColumn get orderType => integer().nullable()();

  RealColumn get serviceCharge =>
      real().nullable().map(const DecimalConverter())();

  /// Рабочее место, которому принадлежит чек в работе (владелец, I156).
  ///
  /// **Правило смысла: владельца имеет только чек в работе.**
  /// В работе — это `state = 0` и он же, **занятый под оплату**
  /// (`state = 2`, задача 8): второе — не другая жизнь чека, а те
  /// несколько миллисекунд первой, пока идёт запись денег, и владельца
  /// чек на них не меняет и не теряет (см.
  /// `LocalPaymentService._stateClaimedForPayment`). Переход в любое
  /// другое состояние снимает владельца; переход в
  /// `state = 0` его проставляет — делает это тот, кто поднимает чек, а
  /// не сам переход состояния. Отложенный чек (`state = 3`) владельца
  /// не имеет и доступен любому рабочему месту своей кассы (I156);
  /// завершённые чеки (отправленные, синхронизированные) владельца тоже
  /// не имеют — они принадлежат смене и кассе, а не тому терминалу,
  /// который их набирал.
  ///
  /// Правило зафиксировано не только здесь: любая запись состояния
  /// в `Sales` обязана его соблюдать, а не полагаться на то, что
  /// колонку никто не читает вне `findInProgress`, — иначе объявленный
  /// здесь инвариант остаётся текстом, а не поведением, и данные
  /// молча лгут первому же читателю, который у колонки появится.
  /// `SaleDao.updateState`/`markSyncedByKey`/`setState` держат это сами
  /// (см. их докстринги); `deferSale`/`undeferSale`
  /// (`deferred_sale_service_impl.dart`) и вставка новой продажи
  /// (`sale_initiation_use_case_impl.dart`) пишут `terminalId` явно,
  /// в обход этих методов.
  ///
  /// До схемы v37 рабочее место у кассы было ровно одно, и колонки не
  /// существовало вовсе — `saleDao.findInProgress()` брала `state = 0` без
  /// всякой привязки к рабочему месту. С появлением браузерного терминала
  /// одной кассой может пользоваться больше одного рабочего места
  /// одновременно, и стало необходимо помнить, чья именно эта работа.
  IntColumn get terminalId => integer().nullable()();

  /// Версия снимка корзины — растёт на каждую применённую к чеку команду.
  ///
  /// Защита от команды, посчитанной от устаревшего снимка (I161): команда
  /// браузерного терминала несёт версию, от которой она посчитана, и
  /// применяется только если та совпадает с текущей — иначе корзина уже
  /// уехала вперёд (другая команда того же терминала, или чек был отдан
  /// другому рабочему месту) и применять её поверх нельзя.
  IntColumn get cartVersion => integer().withDefault(const Constant(0))();

  /// Ключ последней применённой к чеку команды — защита от повтора (I160).
  ///
  /// Хранится одна строка, а не журнал: правило «одна команда в полёте на
  /// корзину» (I161) означает, что оборваться и прийти повторно может
  /// только последняя отправленная команда — та, что уже применена и чей
  /// ключ здесь лежит. Более ранняя команда этого терминала уже дождалась
  /// ответа (иначе следующая не была бы отправлена) и повторной прийти не
  /// может; команда с чужим `cartVersion` отклоняется версией, до сверки
  /// ключа не доходя. Заводить таблицу-журнал команд под это не нужно —
  /// хранить в ней было бы нечего сверх этой одной строки.
  TextColumn get lastCommandKey => text().nullable()();

  @override
  Set<Column> get primaryKey => {receiptNo, posId};
}

class SaleProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get saleId => integer().nullable()();

  IntColumn get ucode => integer()();

  IntColumn get barcode => integer().nullable()();

  IntColumn get categoryId => integer().nullable()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get priceBefore => real().map(const DecimalConverter())();
}

class SaleProductMarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get mark => text().nullable()();

  IntColumn get saleProductId => integer().nullable()();
}

class SaleWithdrawals extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get saleId => integer().nullable()();

  IntColumn get agentAccountId => integer().nullable()();

  RealColumn get amount => real().nullable().map(const DecimalConverter())();
}

class SaleCustomFields extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get customFieldId => integer().nullable()();

  IntColumn get customFieldItemId => integer().nullable()();
}

class UniversalProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get refundLocalId => integer().nullable()();

  RealColumn get quantity => real().map(const DecimalConverter())();

  RealColumn get price => real().map(const DecimalConverter())();

  RealColumn get priceBefore =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get inSalePrice =>
      real().nullable().map(const DecimalConverter())();

  RealColumn get inSaleQuantity =>
      real().nullable().map(const DecimalConverter())();
}
