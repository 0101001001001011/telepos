import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/security/legacy_pin_cipher.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_rejection.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/terminal/point_mode_permissions.dart';
import 'package:telepos/domain/terminal/terminal.dart';

void main() {
  late AppDatabase db;
  late LocalAuthRepository auth;
  late int cashierTerminalId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Полный список доводов `insertInitialConfig` — сигнатуры в брифе не
    // было ('posKey' не существует), взято из
    // `test/data/auth/local_auth_repository_users_test.dart` (задача 6).
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
    // `db.terminalDao.register(...)` не существует — терминал заводится через
    // `LocalTerminalRepository`, как это делает и настоящая касса
    // (`lib/data/terminal/terminal_repository_local.dart:56`).
    final terminal = (await LocalTerminalRepository(
      db,
    ).register(name: 'Касса 1')).terminal;
    cashierTerminalId = terminal.id;
    auth = LocalAuthRepository(
      db: db,
      sessions: SessionRegistry(),
      throttle: LoginThrottle(),
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

  /// Ставит `pointMode` терминалу напрямую в таблице: производственного
  /// сеттера нет, и заводить его эта работа не будет (задача 7 не задача 2).
  Future<void> setPointMode(int terminalId, String mode) =>
      (db.update(db.terminals)..where((t) => t.id.equals(terminalId))).write(
        TerminalsCompanion(pointMode: Value(mode)),
      );

  test('верный PIN выбранного кассира выписывает сеанс', () async {
    final id = await addUser(name: 'Айгуль', pin: '1234');

    final outcome = await auth.login(
      AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
    );

    expect(outcome, isA<AuthSession>());
    final session = outcome as AuthSession;
    expect(session.userId, id);
    expect(session.token, isNotEmpty);
    expect(session.expiresAt.isAfter(session.issuedAt), isTrue);
    // Задача 9 закрытия долга: это единственная точка, где `terminalId`
    // реально попадает в сеанс на рабочем пути — `LocalAuthRepository._issue`
    // передаёт его в `SessionRegistry.mint`. Без этой строки правка могла бы
    // сломаться (перестать прокидывать довод) незаметно для всего набора:
    // само поле обязательно на `AuthSession`, но обязательность типа не
    // ловит «передали не то значение».
    expect(session.terminalId, cashierTerminalId);
  });

  test('неверный PIN — названный отказ, а не исключение', () async {
    final id = await addUser(name: 'Айгуль', pin: '1234');

    final outcome = await auth.login(
      AuthAttempt(pin: '9999', userId: id, terminalId: cashierTerminalId),
    );

    expect((outcome as AuthRejection).reason, AuthRejectionReason.wrongPin);
  });

  test('у кассира без PIN — своя причина отказа', () async {
    final id = await addUser(name: 'Без пина');

    final outcome = await auth.login(
      AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
    );

    expect((outcome as AuthRejection).reason, AuthRejectionReason.noPinSet);
  });

  // До 40246c2 «Войти без PIN» решался прямо на экране (`selected != null
  // && userHasNoPassword` логинила без единого вызова проверки) и сюда,
  // в единственную оставшуюся реализацию, эквивалент не переехал: выбранный
  // явно кассир без PIN и пустой `pin` от экрана падали в тот же `noPinSet`,
  // что и опечатка выше, — кнопка «Войти без PIN» не могла войти никогда.
  // Красный без ветки в `LocalAuthRepository.login`, добавленной вместе с
  // этим тестом.
  test(
    'явно выбранный кассир без PIN входит пустым PIN — «Войти без PIN»',
    () async {
      final id = await addUser(name: 'Без пина');

      final outcome = await auth.login(
        AuthAttempt(pin: '', userId: id, terminalId: cashierTerminalId),
      );

      expect(outcome, isA<AuthSession>());
      expect((outcome as AuthSession).userId, id);
    },
  );

  // Найдено ревью: самая опасная граница новой ветки — не «нет пароля», а
  // «есть пароль». Ветка выше живёт по `attempt.pin.isEmpty`, и без этого
  // теста ничто не покраснеет, если порядок условий однажды сместится и
  // пустой PIN откроет дверь кассиру, у которого пароль есть. Здесь именно
  // это и проверяется напрямую, а не выводится рассуждением о коде: у
  // `candidates.single.passwordEnc` есть значение, `attempt.pin` пуст —
  // `_matchAll` дальше по функции честно сравнит пустую строку с реальным
  // хэшем и не найдёт совпадения (последний рубеж — `pin.isEmpty` в
  // `PinCredential.check`), так что результат обязан остаться отказом.
  test(
    'явно выбранный кассир с PIN пустым PIN не открывается — не «Войти без PIN»',
    () async {
      final id = await addUser(name: 'Айгуль', pin: '1234');

      final outcome = await auth.login(
        AuthAttempt(pin: '', userId: id, terminalId: cashierTerminalId),
      );

      expect(outcome, isA<AuthRejection>());
      expect((outcome as AuthRejection).reason, AuthRejectionReason.wrongPin);
    },
  );

  // Тот же пустой PIN, но без явного выбора (анонимный walk-up) — не тот же
  // случай: `attempt.userId == null` не должен молча превращаться в «войти
  // как единственный кассир без PIN» в обход `walkUpEnabled`, который решает
  // касса выше по функции.
  test(
    'пустой PIN без выбранного кассира — не вход, walk-up решает касса',
    () async {
      await addUser(name: 'Без пина');

      final outcome = await auth.login(
        AuthAttempt(pin: '', terminalId: cashierTerminalId),
      );

      expect(
        (outcome as AuthRejection).reason,
        AuthRejectionReason.walkUpDisabled,
      );
    },
  );

  test('walk-up выключен — PIN без имени не принимается', () async {
    await addUser(name: 'Айгуль', pin: '1234');

    final outcome = await auth.login(
      AuthAttempt(pin: '1234', terminalId: cashierTerminalId),
    );

    expect(
      (outcome as AuthRejection).reason,
      AuthRejectionReason.walkUpDisabled,
    );
  });

  test(
    'walk-up включён — PIN без имени опознаёт единственного владельца',
    () async {
      await db.thisPosDao.saveAuthSettings(walkUpEnabled: true);
      final id = await addUser(name: 'Айгуль', pin: '1234');
      await addUser(name: 'Другой', pin: '5678');

      final outcome = await auth.login(
        AuthAttempt(pin: '1234', terminalId: cashierTerminalId),
      );

      expect((outcome as AuthSession).userId, id);
    },
  );

  test('два кассира с одним PIN — отказ, а не первый попавшийся', () async {
    // Главный дефект, ради которого этот перебор вообще трогали:
    // `sweepPinCandidates` возвращается на первом совпадении, и деньги смены
    // записались бы не на того человека.
    await db.thisPosDao.saveAuthSettings(walkUpEnabled: true);
    await addUser(name: 'Первая', pin: '1234');
    await addUser(name: 'Вторая', pin: '1234');

    final outcome = await auth.login(
      AuthAttempt(pin: '1234', terminalId: cashierTerminalId),
    );

    expect((outcome as AuthRejection).reason, AuthRejectionReason.ambiguousPin);
  });

  group('задача 7 — замок перестаёт отказывать верному PIN', () {
    // `sleep` подменён на немедленно завершающуюся функцию: тест доказывает
    // поведение (верный PIN проходит), а не тратит секунды прогона набора на
    // настоящие `Future.delayed` растущей задержки.
    LocalAuthRepository fastAuth() => LocalAuthRepository(
      db: db,
      sessions: SessionRegistry(),
      throttle: LoginThrottle(sleep: (_) => Future.value()),
    );

    // Главный тест части. До задачи 7 счётчик неудач превращался в замок,
    // отказывающий и правильному PIN («пятая неудача подряд запирает
    // терминал», прежняя версия этого теста) — то есть узнавший только имя
    // кассира мог держать его запертым сколько угодно, ни разу не угадав
    // PIN. Красное доказательство снято прогоном на HEAD до правки — см.
    // отчёт.
    test('верный PIN проходит даже при исчерпанном счётчике неудач', () async {
      final repo = fastAuth();
      final id = await addUser(name: 'Айгуль', pin: '1234');

      // Куда больше, чем прежний порог замка (5) — счётчик исчерпан
      // многократно, и именно это раньше отказывало любому PIN.
      for (var i = 0; i < 12; i++) {
        final wrong = await repo.login(
          AuthAttempt(pin: '0000', userId: id, terminalId: cashierTerminalId),
        );
        expect((wrong as AuthRejection).reason, AuthRejectionReason.wrongPin);
      }

      final outcome = await repo.login(
        AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
      );

      expect(outcome, isA<AuthSession>());
      expect((outcome as AuthSession).userId, id);
    });

    test(
      'неверный PIN после нескольких неудач стоит заметно дольше первого',
      () async {
        final waited = <Duration>[];
        final repo = LocalAuthRepository(
          db: db,
          sessions: SessionRegistry(),
          throttle: LoginThrottle(
            sleep: (d) {
              waited.add(d);
              return Future.value();
            },
          ),
        );
        final id = await addUser(name: 'Айгуль', pin: '1234');

        for (var i = 0; i < 6; i++) {
          await repo.login(
            AuthAttempt(pin: '0000', userId: id, terminalId: cashierTerminalId),
          );
        }

        // Первые (льготные) неудачи не зовут sleep вовсе; собранные — только
        // задержки сверх льготы, и они строго растут.
        expect(waited, isNotEmpty);
        expect(waited.last, greaterThan(waited.first));
      },
    );

    test(
      'перебор с ротацией terminalId по-прежнему упирается в ключ userId',
      () async {
        // Тот самый сценарий задачи 6: `terminals.register` открыта, значит
        // нападающему новый terminalId ничего не стоит. Задержка обязана
        // расти по userId несмотря на это.
        final waited = <Duration>[];
        final repo = LocalAuthRepository(
          db: db,
          sessions: SessionRegistry(),
          throttle: LoginThrottle(
            sleep: (d) {
              waited.add(d);
              return Future.value();
            },
          ),
        );
        final id = await addUser(name: 'Айгуль', pin: '1234');

        for (var i = 0; i < 6; i++) {
          final terminal = (await LocalTerminalRepository(
            db,
          ).register(name: 'Ротация $i')).terminal;
          await repo.login(
            AuthAttempt(pin: '0000', userId: id, terminalId: terminal.id),
          );
        }

        // Задержка накопилась по userId, а не пропала вместе с каждым новым
        // терминалом — иначе последняя попытка с ещё одним новым terminalId
        // стоила бы так же дёшево, как первая.
        expect(waited, isNotEmpty);
        expect(waited.last, greaterThan(waited.first));
      },
    );

    // Пункт 3 разбора фаз 3/4 закрытия долга (2026-08-21) — тест на
    // свойство, а не на «зелёное»: нападающий, который шлёт N попыток разом,
    // не дожидаясь ответов, всё равно платит — верный ответ среди них не
    // приходит раньше, чем стена по ключу это позволяет. `login_throttle_wall
    // _bench_test.dart` этого не даёт: она вызывает только `penalizeFailure`,
    // никогда `login()`, — моделирует нападающего, который и так уже ждал
    // (докстринг брифа фаз 3/4).
    //
    // `hangingSleep` — тот же приём, что «предел одновременных ожиданий
    // снят» в `login_throttle_test.dart`: не завершается сам, держит попытку
    // реально ожидающей, пока тест не отпустит её вручную. Настоящая PBKDF2
    // (`Isolate.run`, ~206 мс) при этом не подделана — она либо ещё не
    // дошла до сравнения, либо результат неверного PIN некому вернуть, пока
    // `_sleep` висит.
    test(
      'нападающий, слающий попытки не дожидаясь ответов, платит и на верном '
      'PIN',
      () async {
        final pending = <Completer<void>>[];
        var seeding = true;
        // Во время затравки (ниже) `sleep` отвечает мгновенно — затравочные
        // попытки идут одна за другой, честно, без подделки очереди. После
        // затравки та же функция начинает вешать попытку по-настоящему:
        // без этого переключателя пришлось бы заводить второй экземпляр
        // `LoginThrottle`, а счёт неудач обязан быть **один и тот же**,
        // накопленный по одному ключу.
        Future<void> hangingSleep(Duration d) {
          if (seeding) return Future.value();
          final completer = Completer<void>();
          pending.add(completer);
          return completer.future;
        }

        // Отпускает всё, что накопилось в очереди `pending`. Правка 1
        // БЛОКЕРА (2026-08-22, `login_throttle.dart`) сняла цепную очередь
        // ожиданий (`_queueTail`) — все шесть `hangingSleep` независимы, не
        // ждут друг друга, и одного прохода достаточно, чтобы отпустить
        // всех разом. Цикл в несколько попыток с короткой паузой остаётся
        // страховкой не от чужой очереди (её больше нет), а от обычного
        // порядка планирования Dart: шесть `login()` идут через настоящие
        // `await` к базе, прежде чем каждый дойдёт до своего
        // `penalizeFailure`, и без запаса можно освободить `pending` раньше,
        // чем последний из шести туда попал. Не запускается автоматически:
        // до проверки [rightResolved] ниже отпускать пока нечего — сама
        // проверка и есть утверждение, что все шесть к этому моменту уже
        // висят. Зовётся дважды: один раз явно после проверки [rightResolved],
        // и ещё раз в [addTearDown] как страховка — если проверка ниже
        // упадёт, `hangingSleep` не должен остаться висеть до таймаута
        // набора.
        var rightResolved = false;
        Future<void> drainUntilRightResolved() async {
          for (var i = 0; i < 200 && !rightResolved; i++) {
            final toRelease = List<Completer<void>>.of(pending);
            pending.clear();
            for (final c in toRelease) {
              if (!c.isCompleted) c.complete();
            }
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        }

        addTearDown(drainUntilRightResolved);

        final repo = LocalAuthRepository(
          db: db,
          sessions: SessionRegistry(),
          throttle: LoginThrottle(graceFailures: 0, sleep: hangingSleep),
        );
        final id = await addUser(name: 'Айгуль', pin: '1234');

        // Затравка: три честные, последовательно дождавшиеся неудачи выводят
        // счёт этого ключа на 3 **до** того, как начнётся пачка. Так порядок,
        // в котором Dart на самом деле планирует шесть параллельных вызовов
        // ниже (он не гарантирован рассуждением о коде — каждый из них
        // проходит несколько настоящих `await` к базе прежде, чем дойти до
        // `penalizeFailure`), не может случайно подарить верной попытке счёт
        // 0 и льготу: с затравкой у неё счёт не ниже 3, какой бы из шести она
        // ни оказалась синхронно первой.
        for (var i = 0; i < 3; i++) {
          await repo.login(
            AuthAttempt(pin: '0000', userId: id, terminalId: cashierTerminalId),
          );
        }
        seeding = false;

        // Нападающий шлёт пять неверных и один верный разом — ни один
        // `await` между вызовами, «не дожидаясь ответов». Верный не выделен
        // ничем видимым нападающему: он не знает, какой из шести правильный.
        final wrongFutures = [
          for (var i = 0; i < 5; i++)
            repo.login(
              AuthAttempt(
                pin: '0000',
                userId: id,
                terminalId: cashierTerminalId,
              ),
            ),
        ];
        final rightFuture = repo.login(
          AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
        );

        unawaited(rightFuture.then((_) => rightResolved = true));

        // Настоящее время, не микрозадача: на HEAD до правки верный PIN
        // проходит через `_matchAll` (реальный `Isolate.run`, ~206 мс на
        // кандидата, измерено 2026-08-02) и отвечает без единого обращения к
        // замку. 3 секунды — запас на порядок сверх одной PBKDF2 даже под
        // нагрузкой шести конкурентных изолятов: красный прогон на HEAD до
        // этой правки показал `rightResolved == true` уже на нескольких
        // сотнях мс (см. отчёт) — 3 с оставляют нулевые сомнения, не
        // подгоняют временное окно под желаемый результат.
        await Future<void>.delayed(const Duration(seconds: 3));

        expect(
          rightResolved,
          isFalse,
          reason:
              'верный PIN, посланный в общей пачке, обязан ждать очередь '
              'замка по ключу так же, как и неверные — быстрый ответ не '
              'имеет права быть признаком успеха',
        );

        await drainUntilRightResolved();
        final outcome = await rightFuture;
        expect(
          outcome,
          isA<AuthSession>(),
          reason: 'верный PIN не отвергается — он ждёт, но не отказывает',
        );
        for (final wrong in await Future.wait(wrongFutures)) {
          expect((wrong as AuthRejection).reason, AuthRejectionReason.wrongPin);
        }
      },
    );
  });

  test('сеанс несёт права роли, пересечённые с режимом терминала', () async {
    final selfServiceTerminal = (await LocalTerminalRepository(
      db,
    ).register(name: 'КСО')).terminal;
    await setPointMode(selfServiceTerminal.id, 'selfService');
    final id = await addUser(name: 'Директор', pin: '1234', role: 0);

    final outcome = await auth.login(
      AuthAttempt(pin: '1234', userId: id, terminalId: selfServiceTerminal.id),
    );

    final session = outcome as AuthSession;
    // Роль владельца даёт всё; режим самообслуживания отнимает деньги и
    // настройки — и отнимает сильнее, чем роль даёт.
    expect(session.permissions, contains(PermissionKeys.navSale));
    expect(session.permissions, isNot(contains(PermissionKeys.opCashInOut)));
    expect(session.permissions, isNot(contains(PermissionKeys.settingsUsers)));
  });

  test('сбой чтения прав — отказ входа, а не полный доступ', () async {
    // Ровно тот дефект, который жил в `login_controller.dart:446`: catch
    // возвращал allPermissions. Закрытая база — самый дешёвый способ
    // воспроизвести сбой чтения.
    final id = await addUser(name: 'Айгуль', pin: '1234');
    await db.close();

    final outcome = await auth.login(
      AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
    );

    expect((outcome as AuthRejection).reason, AuthRejectionReason.unknown);
  });

  group('легаси PIN', () {
    // 2048-битный RSA — медленный; один ключ на всю группу, как на настоящей
    // установке ровно один `ThisPos.rsaPublicKey`.
    late String legacyKey;

    setUpAll(() => legacyKey = LegacyPinCipher.generatePublicKeyBase64());

    test(
      'вход по легаси-записи переписывает её в новую схему на месте',
      () async {
        // Дефект, который эта задача тихо вносила бы: `PinCheckResult.upgradedStorage`
        // документирован так, что вызывающая сторона обязана его записать —
        // без этого кассир с дореформенной записью входил бы вечно, а в день,
        // когда `ThisPos.rsaPublicKey` сменится или сотрётся, не вошёл бы
        // вовсе, и предупредить его было бы уже нечем.
        final stored = LegacyPinCipher.encryptPin('1234', legacyKey)!;
        final id = await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                name: const Value('Легаси'),
                role: const Value(3),
                status: const Value('active'),
                passwordEnc: Value(stored),
              ),
            );
        await db.thisPosDao.upsert(
          ThisPosEntriesCompanion(rsaPublicKey: Value(legacyKey)),
        );

        final outcome = await auth.login(
          AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
        );

        expect(outcome, isA<AuthSession>());
        final row = await db.userDao.findById(id);
        expect(
          row!.passwordEnc,
          startsWith('pbkdf2\$sha256\$'),
          reason:
              'запись обязана перейти на новую схему сразу после первого '
              'успешного входа, а не остаться в легаси-формате навсегда',
        );
      },
    );

    test(
      'перенос легаси-записи не удался — вход по верному PIN всё равно проходит',
      () async {
        // Находка второго ревью 2026-08-20: запись миграции стояла в общем
        // `try`, и её сбой превращал верный PIN в `AuthRejection.unknown`.
        // Честный способ воспроизвести сбой записи здесь — не подделка DAO
        // (`LocalAuthRepository` принимает `AppDatabase` целиком, отдельного
        // интерфейса для подмены нет), а настоящий отказ самой базы: триггер
        // SQLite, блокирующий UPDATE именно этой строки, — тот же механизм,
        // которым СУБД сама отказала бы при конфликте или блокировке.
        final stored = LegacyPinCipher.encryptPin('1234', legacyKey)!;
        final id = await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                name: const Value('Легаси, запись заблокирована'),
                role: const Value(3),
                status: const Value('active'),
                passwordEnc: Value(stored),
              ),
            );
        await db.thisPosDao.upsert(
          ThisPosEntriesCompanion(rsaPublicKey: Value(legacyKey)),
        );
        await db.customStatement('''
          CREATE TRIGGER block_pin_migration
          BEFORE UPDATE OF password_enc ON users
          WHEN NEW.id = $id
          BEGIN
            SELECT RAISE(ABORT, 'simulated migration write failure');
          END;
        ''');

        final outcome = await auth.login(
          AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
        );

        expect(
          outcome,
          isA<AuthSession>(),
          reason:
              'PIN набран верно и уже проверен — неудача переноса записи не '
              'должна откатывать выданный вход',
        );
        final row = await db.userDao.findById(id);
        expect(
          row!.passwordEnc,
          stored,
          reason:
              'триггер обязан был заблокировать запись целиком — если запись '
              'всё же произошла, тест ничего не проверяет',
        );
      },
    );
  });

  test('испорченная запись PIN — «нечитаема», а не «неверный PIN»', () async {
    // `PinCheckOutcome.unreadable` документирован обратным «неверному»:
    // человек ничего не сделал не так, и повторный набор не поможет —
    // показать это как `wrongPin` отправило бы кассира набирать снова то,
    // что заново не набрать.
    final id = await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            name: const Value('Битая запись'),
            role: const Value(3),
            status: const Value('active'),
            // Схема текущая (префикс совпадает), но частей меньше пяти —
            // `PinCredential._checkCurrent` не может это разобрать.
            passwordEnc: const Value(r'pbkdf2$sha256$bad'),
          ),
        );

    final outcome = await auth.login(
      AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
    );

    expect(
      (outcome as AuthRejection).reason,
      AuthRejectionReason.credentialUnreadable,
    );
  });

  // Пункт 4 разбора фаз 3/4 закрытия долга (2026-08-21): `credentialUnreadable`
  // возвращался до всякого обращения к замку — одна испорченная запись PIN
  // среди кандидатов walk-up делала любой неверный PIN бесплатным для всей
  // попытки, тихо. Правка 1 того же разбора (пункт 3) переместила ожидание
  // на самый верх `login()`, до разбора кандидатов на «читаются/не читаются»
  // — этот путь платит тем же ходом, без отдельной ветки. Тест — на
  // накопление задержки, а не на факт вызова: одного факта мало, важно, что
  // счёт действительно растёт для этого исхода так же, как для wrongPin.
  test(
    'credentialUnreadable больше не бесплатен — задержка растёт так же, как '
    'у wrongPin',
    () async {
      final waited = <Duration>[];
      final repo = LocalAuthRepository(
        db: db,
        sessions: SessionRegistry(),
        throttle: LoginThrottle(
          sleep: (d) {
            waited.add(d);
            return Future.value();
          },
        ),
      );
      final id = await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              name: const Value('Битая запись'),
              role: const Value(3),
              status: const Value('active'),
              passwordEnc: const Value(r'pbkdf2$sha256$bad'),
            ),
          );

      for (var i = 0; i < 6; i++) {
        final outcome = await repo.login(
          AuthAttempt(pin: '1234', userId: id, terminalId: cashierTerminalId),
        );
        expect(
          (outcome as AuthRejection).reason,
          AuthRejectionReason.credentialUnreadable,
          reason: 'исход не должен подмениться на wrongPin вместе с правкой',
        );
      }

      expect(
        waited,
        isNotEmpty,
        reason:
            'на HEAD до правки этот путь не звал sleep вовсе — испорченная '
            'запись была бесплатной калиткой мимо замка',
      );
      expect(waited.last, greaterThan(waited.first));
    },
  );

  test(
    'терминал с неизвестным режимом входит с правами самого узкого режима',
    () async {
      // Ничем не проверенный путь до этого теста: `_issue` откатывается на
      // `PointMode.selfService`, если хранимое имя режима не входит в
      // `PointMode.values` (касса новее терминала). Проверяет, что откат
      // даёт именно урезанные права самого узкого режима — не отказ во
      // входе и не полные права роли.
      final mutantTerminal = (await LocalTerminalRepository(
        db,
      ).register(name: 'Из будущего')).terminal;
      await (db.update(
        db.terminals,
      )..where((t) => t.id.equals(mutantTerminal.id))).write(
        const TerminalsCompanion(pointMode: Value('modeFromTheFuture')),
      );
      final id = await addUser(name: 'Директор', pin: '1234', role: 0);

      final outcome = await auth.login(
        AuthAttempt(pin: '1234', userId: id, terminalId: mutantTerminal.id),
      );

      final session = outcome as AuthSession;
      expect(
        session.permissions,
        PointModePermissions.effective(
          ofRole: PermissionKeys.allPermissions,
          at: PointMode.selfService,
        ),
      );
    },
  );
}
