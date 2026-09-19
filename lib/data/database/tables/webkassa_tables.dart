import 'package:drift/drift.dart';

class WebkassaReceipts extends Table {
  IntColumn get operationId => integer()();

  IntColumn get receiptNo => integer().nullable()();

  TextColumn get fiscalNo => text().nullable()();

  TextColumn get wkReceiptNo => text().nullable()();

  IntColumn get wkTime => integer().nullable()();

  BoolColumn get wkOfflineMode => boolean().nullable()();

  TextColumn get ticketUrl => text().nullable()();

  BoolColumn get isSale => boolean().nullable()();

  TextColumn get registrationNumber => text().nullable()();

  TextColumn get originalTotal => text().nullable()();

  /// Род документа (v50) — индекс `FiscalDocKind`.
  ///
  /// Не украшение, а **вторая половина ключа**: `operationId` приходит из
  /// трёх разных последовательностей (чек продажи, возврат, кассовая
  /// проводка аванса), и на новой кассе они начинаются с единицы все
  /// сразу. Разбор и замер — в докстринге `FiscalDocKind`.
  ///
  /// Умолчание `0` (продажа) стоит здесь ради строк старше v50: миграция
  /// проставляет возвратам `1` по колонке `is_sale`, всё остальное в
  /// таблице до v50 было продажей.
  IntColumn get docKind => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {operationId, docKind};
}

class FiscalQueueEntries extends Table {
  TextColumn get idempotencyKey => text()();

  IntColumn get opType => integer()();

  TextColumn get payload => text()();

  IntColumn get occurredAt => integer()();

  IntColumn get status => integer().withDefault(const Constant(0))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {idempotencyKey};
}

class WebkassaConfigs extends Table {
  IntColumn get posId => integer()();

  IntColumn get wkAccountId => integer().nullable()();

  TextColumn get posFactoryNo => text().nullable()();

  TextColumn get taxDeptRegNo => text().nullable()();

  TextColumn get ofdId => text().nullable()();

  TextColumn get taxpayerName => text().nullable()();

  TextColumn get iinBin => text().nullable()();

  TextColumn get address => text().nullable()();

  TextColumn get ofdName => text().nullable()();

  TextColumn get ofdHost => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(false))();

  BoolColumn get isTaxpayer => boolean().withDefault(const Constant(false))();

  TextColumn get taxpayerVatSerialNo => text().nullable()();

  TextColumn get taxpayerVatNo => text().nullable()();

  IntColumn get lastErrorTime => integer().nullable()();

  TextColumn get errorString => text().nullable()();

  @override
  Set<Column> get primaryKey => {posId};
}

/// **Z-отчёт, который касса задолжала оператору** (v52).
///
/// # Зачем хранилище, если Z можно просто отправить
///
/// Нельзя. Закрытие смены с 2026-09-19 не отправляет Z, пока документы
/// смены не у оператора (разбор — `ShiftServiceImpl.fiscalCloseShift`):
/// отчёт, ушедший раньше них, поставил бы их в следующую смену оператора,
/// и выручка одного дня встала бы в отчёт другого. Решение верное, но у
/// него был хвост: **задержанный Z никто не досылал**. Хранилища «Z
/// должен» не было вовсе, и отчёт посылало только следующее закрытие
/// смены — а смена оператора, простоявшая открытой дольше суток, отвечает
/// кодом 12 на первой продаже следующего дня.
///
/// Поэтому долг записывается, переживает перезапуск кассы и гасится при
/// **следующем открытии смены** — единственный момент, когда это
/// безопасно (разбор — `ShiftServiceImpl.settleOwedZReport`).
///
/// # Почему таблица, а не поле в `Shifts`
///
/// Долг относится к смене **оператора**, а не к смене кассы. Одна смена
/// оператора накрывает столько смен кассы, сколько их прошло без Z, и
/// гасится он одним отчётом на все. Колонка в `Shifts` заставила бы
/// выбирать, в чьей строке она правда.
class FiscalOwedReports extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Смена кассы, чьё закрытие Z не отправило. Нужна для разбора — «с
  /// какого дня висит», — а не для поиска: гасится долг целиком.
  IntColumn get shiftId => integer()();

  /// Когда долг записан, секунды эпохи.
  IntColumn get owedAt => integer()();

  /// Сколько документов не доехало к моменту закрытия. Число **на тот
  /// момент**, и позже оно не обновляется: это запись о причине, а не
  /// счётчик очереди.
  IntColumn get documentsWaiting => integer().withDefault(const Constant(0))();

  /// Сколько раз касса пробовала догасить долг.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Почему последняя попытка не удалась — названной причиной, не текстом
  /// исключения (И144).
  TextColumn get lastError => text().nullable()();

  /// Когда долг погашен. Пусто — висит.
  IntColumn get settledAt => integer().nullable()();

  /// Чем именно погашен: отчётом досылки или отчётом следующего закрытия.
  /// Строка **не удаляется** — у денежного расхождения должен остаться
  /// след, а не пустое место.
  TextColumn get settledBy => text().nullable()();
}
