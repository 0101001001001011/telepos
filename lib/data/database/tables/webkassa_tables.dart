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

  @override
  Set<Column> get primaryKey => {operationId};
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
