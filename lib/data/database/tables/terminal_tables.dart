import 'package:drift/drift.dart';

/// Рабочее место. Устройства принадлежат ему, а не установке.
///
/// До схемы 26 единственный принтер лежал в `ThisPosEntries`, то есть был один
/// на всю установку — это прямо противоречило требованию, что на одном сайте
/// работают несколько касс, каждая со своими устройствами. См.
/// docs/system-architecture.md, И27.
class Terminals extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// Ровно один терминал в базе помечен как этот. Личность клиента хранится у
  /// клиента (см. TerminalIdentity), а здесь отмечен тот, что живёт в этом
  /// процессе.
  BoolColumn get isSelf => boolean().withDefault(const Constant(false))();

  /// Имя значения `PointMode` (`cashier`, `selfService`, `unattended`,
  /// `kitchen`), а не порядковый номер: индекс меняет смысл, стоит вставить
  /// новый режим не в конец `PointMode.values`, и тогда все уже сохранённые
  /// терминалы молча получат чужой режим — а режим определяет права доступа.
  /// Провод (`lib/domain/wire/terminal_wire.dart`) уже читает и пишет это поле по
  /// имени; хранилище обязано подчиняться тому же правилу.
  TextColumn get pointMode => text().withDefault(const Constant('cashier'))();

  IntColumn get createdAt => integer()();

  /// Отпечаток секрета терминала — задача 4 плана «знакомство терминала с
  /// кассой» (схема v36). Формат — `sha256$<соль>$<свёртка>`,
  /// [TerminalSecret.fingerprint] (`lib/domain/terminal/terminal_secret.dart`).
  /// Значение секрета здесь не хранится никогда и нигде — только у
  /// терминала, которому его выдали ([LocalTerminalRepository.register],
  /// один раз).
  ///
  /// `nullable()`, а не `NOT NULL`: строки, заведённые до схемы v36
  /// (миграция `if (from < 36)`, `app_database.dart`), не несут секрета —
  /// он не мог быть выдан до появления самого механизма, и придумать его
  /// задним числом означало бы либо соврать о том, что терминал его
  /// получал, либо разослать новый секрет терминалу, который его не просил
  /// и о нём не знает. Такая строка остаётся с `secretFingerprint == null`
  /// навсегда — задача 6 обязана считать это «секрета нет», а не «любой
  /// секрет подходит».
  TextColumn get secretFingerprint => text().nullable()();

  /// Виды оплаты, разрешённые этому рабочему месту, — имена значений
  /// `PaymentType` через запятую (схема v38, задача 15 плана «продажа с
  /// браузерного терминала», решение заказчика №5).
  ///
  /// **Имена, а не индексы и не битовая маска** — то же правило, что у
  /// `pointMode` выше: индекс меняет смысл, стоит вставить новый вид оплаты
  /// не в конец `PaymentType.values`, и тогда терминал, которому разрешили
  /// карту, молча начал бы принимать долг. Разбор — `paymentTypesFromNames`
  /// (`lib/domain/terminal/terminal.dart`), он же отказывается угадывать
  /// незнакомое имя.
  ///
  /// **`withDefault('')`, а не `nullable()`, и пустая строка означает «все
  /// виды».** Колонка появляется у каждой уже существующей строки пустой:
  /// набора видов до этой версии не существовало, и придумать его задним
  /// числом означало бы решить за оператора, чем его касса торгует. Читать
  /// пустое как «ничего нельзя» значило бы онеметь всю установку в момент
  /// обновления — см. докстринг `Terminal.allowedPaymentTypes` и пробу
  /// `migration_v38_test.dart`.
  TextColumn get allowedPaymentTypes =>
      text().withDefault(const Constant(''))();
}

/// "Этот терминал, этот класс устройства → этот профиль, эти параметры" —
/// docs/system-architecture.md, раздел 8, И141/И142. Схема v27
/// (`lib/data/database/app_database.dart`).
///
/// **Не одна строка на класс.** Fix round 1: класс — не
/// однослотовый; у терминала может быть больше одной привязки одного класса
/// одновременно — два принтера этикеток, второй чековый принтер, несколько
/// периферийных устройств на неукомплектованной точке. Уникальный ключ
/// ниже — `(terminalId, deviceClass, bindingKey)`, а не `(terminalId,
/// deviceClass)` — существует именно чтобы это разрешить, а не запретить.
/// Схема живёт на не влитой ветке, так что держать это сейчас бесплатно, а
/// добавить после слияния стоило бы новой версии схемы и переноса данных.
/// Заменяет как блоб `hardware_settings` (`SharedPreferences`), так и
/// колонки `ThisPosEntries.paperWidth`/`printerPort` — оба переносятся сюда
/// миграцией v27, когда профиль можно выбрать однозначно
/// (`lib/data/database/migrations/device_binding_migration.dart`).
///
/// **Заменяет семь сырых колонок `Terminals`**, которые схема v27 несла ещё
/// какое-то время после появления этой таблицы (`printerType`,
/// `printerAddress`, `scannerType`, `scalePort`, `scaleBaudRate`,
/// `drawerViaPrinter`, `displayPort`) — план 2, задача 2 сознательно не
/// удаляла их сразу, потому что пять файлов вне её собственности ещё читали
/// их напрямую (`TerminalRepository.setDevices`/`TerminalDevices`,
/// `LocalTerminalRepository`, HTTP-контракт); план 2, задача 5 перевела все
/// пять на эту таблицу и удалила колонки в той же миграции v27 (после того,
/// как `_migrateDeviceBindings()` уже прочитала их как источник) —
/// задача 5 плана 2. Держать оба представления живыми одновременно было
/// бы ровно тем параллельным состоянием, которое план запрещает.
class TerminalDeviceBindings extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get terminalId =>
      integer().references(Terminals, #id, onDelete: KeyAction.cascade)();

  /// Имя значения `DeviceClass` (`lib/domain/device/device_class.dart`), а
  /// не порядковый номер — то же правило, что у `pointMode` в `Terminals`
  /// выше: новый класс не в конец перечисления не должен молча менять класс
  /// уже сохранённых привязок.
  TextColumn get deviceClass => text()();

  /// `DeviceProfile.id` в каталоге, против которого эта привязка
  /// проверяется (`DeviceBinding.validateAgainst`,
  /// `lib/domain/terminal/device_binding.dart`).
  TextColumn get profileId => text()();

  /// JSON-объект `Map<String, String>` — `DeviceBinding.parameters`.
  TextColumn get parametersJson => text().withDefault(const Constant('{}'))();

  /// JSON-объект `Map<String, String>` — `DeviceBinding.options`.
  TextColumn get optionsJson => text().withDefault(const Constant('{}'))();

  /// Отличает друг от друга привязки одного класса на одном терминале
  /// (fix round 1). `DeviceBinding` (`lib/domain/terminal/device_binding.dart`,
  /// файл задачи 1, не этой) пока не несёт собственного поля-идентификатора
  /// — миграция заполняет эту колонку значением `profileId` привязки. Этого
  /// достаточно, когда у сиблингов разные профили (например, два разных
  /// принтера этикеток), но это не общее решение: две привязки одного
  /// класса **и** одного профиля (например, два одинаковых принтера) этой
  /// колонкой, как она заполняется сейчас, неразличимы. Названа обобщённо,
  /// чтобы принять настоящий ключ/имя от `DeviceBinding`, когда оно
  /// появится, без новой миграции схемы.
  TextColumn get bindingKey => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {terminalId, deviceClass, bindingKey},
  ];
}
