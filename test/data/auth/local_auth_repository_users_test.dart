import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';

void main() {
  late AppDatabase db;
  late LocalAuthRepository auth;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Полный список доводов `insertInitialConfig` — сигнатуры в брифе не
    // было ('posKey' не существует), взято из `test/unit/data/auth_settings_migration_test.dart`.
    await db.thisPosDao.insertInitialConfig(
      companyName: 'ЖШС «Тест»',
      iinbin: null,
      cashBoxName: 'test-pos',
      countryCode: null,
      currencyCode: null,
      currencySymbol: null,
      currencyNameShort: null,
      paperWidth: null,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );
    auth = LocalAuthRepository(
      db: db,
      sessions: SessionRegistry(),
      throttle: LoginThrottle(),
    );
  });

  tearDown(() => db.close());

  Future<int> addUser({
    required String name,
    String? pin,
    int role = 3,
    String status = 'active',
  }) => db.into(db.users).insert(
    UsersCompanion.insert(
      name: Value(name),
      role: Value(role),
      status: Value(status),
      passwordEnc: Value(pin == null ? null : PinCredential.create(pin)),
    ),
  );

  test('список кассиров не содержит ни одного хэша', () async {
    await addUser(name: 'Айгуль', pin: '1234');

    final users = await auth.watchUsers().first;

    expect(users, hasLength(1));
    expect(users.single.name, 'Айгуль');
    expect(users.single.hasPin, isTrue);
    // Единственный способ убедиться, что хэш не уехал: у типа нет поля, куда
    // его положить, и в строковом виде его нет.
    expect(users.single.toString(), isNot(contains('pbkdf2')));
  });

  test('кассир без PIN виден, но помечен', () async {
    await addUser(name: 'Без пина');

    final users = await auth.watchUsers().first;

    expect(users.single.hasPin, isFalse);
  });

  test('уволенный кассир в список не попадает', () async {
    await addUser(name: 'Уволен', pin: '1234', status: 'inactive');

    expect(await auth.watchUsers().first, isEmpty);
  });

  test('заведённый кассир доезжает до подписчика без вопроса', () async {
    final seen = <int>[];
    final sub = auth.watchUsers().listen((users) => seen.add(users.length));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await addUser(name: 'Новенькая', pin: '4321');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Ровно ради этого менялся транспорт: касса говорит первой. Живая
    // подписка на drift `.watch()` обязана прислать снимок сразу при
    // подключении (0) и второе событие при вставке строки (1) — без
    // перечитывания списка вручную. Реализация через одноразовый `.get()`
    // (или `Stream.value(...)`) дала бы здесь только `[0]`: второго события
    // взяться неоткуда.
    expect(seen, [0, 1]);
    await sub.cancel();
  });

  test('выход гасит сеанс, и подписка об этом узнаёт', () async {
    final sessions = SessionRegistry();
    final repo = LocalAuthRepository(db: db, sessions: sessions, throttle: LoginThrottle());
    final session = sessions.mint(
      userId: 1, name: 'A', role: 'cashier', permissions: const {},
      operatingMode: 0, pointMode: 'cashier', shiftOpen: false,
      terminalId: 1,
    );

    final seen = <bool>[];
    final sub = repo.watchSession(session.token).listen((s) => seen.add(s != null));
    await Future<void>.delayed(Duration.zero);

    await repo.logout(session.token);
    await Future<void>.delayed(Duration.zero);

    // Первое значение — живой сеанс сразу при подписке (true), второе —
    // после logout() (false). Проверяет, что logout() зовёт именно
    // sessions.revoke() (а не, скажем, ничего не делает и не проксирует
    // сеанс мимо реестра): без вызова revoke() второго события не было бы
    // вовсе, и `seen` осталось бы `[true]`.
    expect(seen, [true, false]);
    await sub.cancel();
  });
}
