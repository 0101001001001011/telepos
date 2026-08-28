import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Users extends Table {
  IntColumn get id => integer()();

  TextColumn get name => text().nullable()();

  IntColumn get role => integer().nullable()();

  TextColumn get status => text().nullable()();

  IntColumn get editTime => integer().nullable()();

  TextColumn get passwordEnc => text().nullable()();

  IntColumn get telegramId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class UserPosSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer()();

  TextColumn get posKey => text()();

  IntColumn get lastLoginAt => integer().nullable()();

  IntColumn get loginCount => integer().withDefault(const Constant(0))();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  BoolColumn get isAllowedOnThisPos =>
      boolean().withDefault(const Constant(true))();

  IntColumn get localRoleOverride => integer().nullable()();

  TextColumn get uiPreferences => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

class Agents extends Table {
  IntColumn get localId => integer().autoIncrement()();

  IntColumn get serverId => integer().nullable()();

  IntColumn get type => integer().nullable()();

  IntColumn get storeId => integer().nullable()();

  TextColumn get name => text().nullable()();

  IntColumn get phone => integer().nullable()();

  TextColumn get bin => text().nullable()();

  TextColumn get legalType => text().nullable()();

  TextColumn get legalAddress => text().nullable()();

  TextColumn get actualAddress => text().nullable()();

  TextColumn get note => text().nullable()();

  TextColumn get legalName => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  IntColumn get editTime => integer().nullable()();

  IntColumn get serverEditTime => integer().nullable()();

  IntColumn get mainAccountId => integer().nullable()();

  IntColumn get cashbackAccountId => integer().nullable()();

  IntColumn get state => integer().nullable()();

  BoolColumn get supportsOnlineOrder =>
      boolean().withDefault(const Constant(false))();

  TextColumn get onlineOrderApiUrl => text().nullable()();

  TextColumn get onlineOrderApiKey => text().nullable()();

  TextColumn get orderEmail => text().nullable()();

  RealColumn get minOrderAmount =>
      real().nullable().map(const DecimalConverter())();

  IntColumn get deliveryDays => integer().nullable()();
}

class AgentLocalContacts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get agentLocalId => integer()();

  TextColumn get posKey => text()();

  TextColumn get contactName => text().nullable()();

  TextColumn get contactPhone => text().nullable()();

  TextColumn get contactEmail => text().nullable()();

  TextColumn get contactTelegram => text().nullable()();

  TextColumn get contactWhatsapp => text().nullable()();

  TextColumn get localNote => text().nullable()();

  TextColumn get preferredContactMethod => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();
}

class Accounts extends Table {
  IntColumn get id => integer()();

  IntColumn get type => integer()();

  IntColumn get acquirerId => integer().nullable()();

  TextColumn get name => text().nullable()();

  RealColumn get value => real().nullable().map(const DecimalConverter())();

  IntColumn get agentId => integer().nullable()();

  BoolColumn get visibleToPos => boolean().nullable()();

  IntColumn get updateTime => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PosEntries extends Table {
  IntColumn get id => integer()();

  TextColumn get name => text().nullable()();

  IntColumn get accountId => integer().nullable()();

  BoolColumn get deleted => boolean().nullable()();

  BoolColumn get isVirtual => boolean().nullable()();

  IntColumn get updateTime => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomFieldClassRelations extends Table {
  IntColumn get customFieldId => integer()();

  TextColumn get className => text()();

  @override
  Set<Column> get primaryKey => {customFieldId, className};
}
