/// `LocalAuthRepository.login` — единственная реализация проверки PIN в
/// системе (докстринг класса) — точка вставки задачи 21 закрытия долга
/// безопасности: каждая попытка входа, удачная или нет, пишет ровно одну
/// запись `auth.login` в журнал событий безопасности.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';

void main() {
  late AppDatabase db;
  late SecurityJournal journal;
  late LocalAuthRepository auth;
  late int terminalId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    journal = SecurityJournal(db.securityEventDao);
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
    final terminal = (await LocalTerminalRepository(
      db,
    ).register(name: 'Касса 1')).terminal;
    terminalId = terminal.id;
    auth = LocalAuthRepository(
      db: db,
      sessions: SessionRegistry(),
      throttle: LoginThrottle(),
      securityJournal: journal,
    );
  });

  tearDown(() => db.close());

  Future<int> addUser({required String name, String? pin, int role = 3}) => db
      .into(db.users)
      .insert(
        UsersCompanion.insert(
          name: Value(name),
          role: Value(role),
          status: const Value('active'),
          passwordEnc: Value(pin == null ? null : PinCredential.create(pin)),
        ),
      );

  test(
    'ГЛАВНЫЙ ТЕСТ: верный PIN пишет auth.login/success с userId вошедшего',
    () async {
      final id = await addUser(name: 'Айгуль', pin: '1234');

      await auth.login(
        AuthAttempt(pin: '1234', userId: id, terminalId: terminalId),
      );

      final rows = await db.securityEventDao.findAll();
      expect(rows, hasLength(1));
      expect(rows.single.eventType, SecurityEventType.authLogin);
      expect(rows.single.outcome, SecurityOutcome.success);
      expect(rows.single.userId, id);
      expect(rows.single.terminalId, terminalId);
    },
  );

  test(
    'ГЛАВНЫЙ ТЕСТ: неверный PIN пишет auth.login/wrongPin, не success — '
    'ровно то, из чего складывается видимая серия неудач замка попыток',
    () async {
      final id = await addUser(name: 'Айгуль', pin: '1234');

      await auth.login(
        AuthAttempt(pin: '0000', userId: id, terminalId: terminalId),
      );

      final rows = await db.securityEventDao.findAll();
      expect(rows, hasLength(1));
      expect(rows.single.eventType, SecurityEventType.authLogin);
      expect(rows.single.outcome, 'wrongPin');
      expect(rows.single.userId, id);
    },
  );

  test('несколько неудач одного userId дают несколько строк с этим userId '
      '— журнал, по которому видна серия (раздел 16 архитектуры)', () async {
    final id = await addUser(name: 'Айгуль', pin: '1234');

    for (var i = 0; i < 3; i++) {
      await auth.login(
        AuthAttempt(pin: '0000', userId: id, terminalId: terminalId),
      );
    }

    final rows = await db.securityEventDao.findAll();
    expect(rows, hasLength(3));
    expect(rows.every((r) => r.userId == id && r.outcome == 'wrongPin'), isTrue);
  });

  test('walk-up без userId пишет запись с userId=null — не выдумывает '
      'личность по неверному PIN', () async {
    await addUser(name: 'Айгуль', pin: '1234');
    await db.thisPosDao.saveAuthSettings(walkUpEnabled: true);

    await auth.login(AuthAttempt(pin: '0000', terminalId: terminalId));

    final rows = await db.securityEventDao.findAll();
    expect(rows, hasLength(1));
    expect(rows.single.userId, isNull);
  });

  // ГЛАВНЫЙ ТЕСТ файла (пункт 7 брифа закрытия долга безопасности,
  // 2026-08-22): до этой правки И68 проверялась тестом
  // (`test/data/database/security_journal_test.dart`), который сам
  // составлял `correlationId` и никогда не передавал PIN в настоящую точку
  // вставки — он не мог покраснеть ни при каком поведении боевого кода.
  // Этот тест гоняет реальный PIN через единственную настоящую реализацию
  // проверки (`LocalAuthRepository.login`, докстринг класса) и смотрит,
  // что реально легло в журнал — и на успешном, и на неудачном входе.
  test(
    'ГЛАВНЫЙ ТЕСТ: запись о входе не несёт сырой PIN ни при успехе, ни при '
    'отказе',
    () async {
      const rawPin = '4269';
      final id = await addUser(name: 'Айгуль', pin: rawPin);

      await auth.login(
        AuthAttempt(pin: rawPin, userId: id, terminalId: terminalId),
      );
      await auth.login(
        AuthAttempt(pin: '0000', userId: id, terminalId: terminalId),
      );

      final rows = await db.securityEventDao.findAll();
      expect(rows, hasLength(2));
      for (final row in rows) {
        // `previousFingerprint` — не проверяется здесь: это отпечаток
        // ЦЕПОЧКИ (хэш служебных полей записи, не PIN), а не поле, куда
        // `login()` мог бы что-то записать напрямую, и его значение —
        // псевдослучайный hex, который может случайно содержать любую
        // короткую цифровую подстроку (genesis сам — 68 нулей). Проверяются
        // ровно те поля, которые `SecurityJournal.record`/`login()`
        // действительно наполняют содержимым.
        final everyTextField = [
          row.eventType,
          row.outcome,
          row.correlationId,
        ].join('|');
        expect(
          everyTextField.contains(rawPin),
          isFalse,
          reason: 'ни один текстовый столбец записи ${row.id} не имеет '
              'права нести сырой PIN',
        );
      }
    },
  );
}
