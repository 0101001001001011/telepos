/// Довесок фазы 3/4 закрытия долга, часть Б: ленивая уборка неиспользуемых
/// строк `terminals`.
///
/// Отчёт волны (`.superpowers/sdd/2026-08-21-security-debt-closure/
/// phase34-fix-report.md`, пункт 2) назвал цену пункта 2 явно: каждая новая
/// QUIC-сессия браузера — честная новая строка `terminals`, не восстановление
/// старой (дедупликация по имени снята пунктом 6 — дырой была она, не
/// решение). Кассир, обновивший вкладку (F5) двести раз за смену, упирался бы
/// в потолок `LocalTerminalRepository.maxTerminals` (200) на пустом месте —
/// каждая старая строка оставалась в базе неиспользуемой навсегда.
///
/// `TillOperations._pruneUnusedTerminals` чистит такие строки на каждом
/// `terminals.register` — тем же приёмом, что `SessionRegistry._forget()`/
/// `LoginThrottle._forget()`: без будильника, на обращении. Настоящий
/// клиентский путь целиком — `FakeQuicServer` + `TillWire` + `TillOperations`
/// — тем же приёмом, что `terminal_login_session_binding_test.dart`.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import '../data/transport/fake_quic_server.dart';

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

void main() {
  late AppDatabase db;
  late FakeQuicServer server;
  late TillWire wire;
  late TillOperations operations;
  late SessionRegistry sessions;
  late int cashierId;
  // Задача 6 плана «знакомство терминала с кассой»: каждый `terminals
  // .register` ниже мятит себе свежий код — этот набор про уборку строк, не
  // про сам гейт код/секрет.
  late PairingInvites invites;

  // Часы — только у [TillOperations]: [SessionRegistry] по-прежнему меряет
  // срок настоящим `DateTime.now()` — она не про то, что проверяют тесты
  // ниже (её собственный `idleTimeout`, 30 минут по умолчанию, не истекает
  // ни в одном из них за настоящее время прогона).
  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 8, 22, 9);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeQuicServer();
    sessions = SessionRegistry();
    invites = PairingInvites();

    await db.thisPosDao.insertInitialConfig(
      companyName: 'ЖШС «Тест»',
      iinbin: null,
      cashBoxName: 'Касса-1',
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
    cashierId = await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            name: const Value('Айгуль'),
            role: const Value(3),
            status: const Value('active'),
            passwordEnc: Value(PinCredential.create('1234')),
          ),
        );

    operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      // Порт, который уборка спрашивает про живой сеанс, — тот же реестр,
      // что выписывает сеансы через `auth.login` выше: без общего реестра
      // тест 2 не проверял бы ничего настоящего.
      sessions: sessions,
      invites: invites,
      terminalIdleGrace: const Duration(minutes: 5),
      clock: () => now,
    );
    wire = TillWire(
      server,
      operations.askHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
      onSessionClosed: operations.forgetSession,
    )..start();
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await db.close();
  });

  /// Один обмен на своём потоке — так же, как настоящий клиент открывает
  /// новый поток на каждый вопрос. Ждёт настоящее (не виртуальное) время —
  /// тот же приём и тот же довод, что у `terminal_login_session_binding_test
  /// .dart`'s `ask()`.
  Future<WireFrame> ask(
    int sessionId,
    int streamId,
    String op,
    Map<String, Object?> body,
  ) async {
    final before = server.sentFrames.length;
    server.emitStreamOpened(sessionId: sessionId, streamId: streamId);
    server.emitStreamData(
      sessionId: sessionId,
      streamId: streamId,
      message: jsonEncode({'op': op, 'body': body}),
    );
    server.emitStreamClosed(sessionId: sessionId, streamId: streamId);
    for (var i = 0; i < 50 && server.sentFrames.length == before; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return WireFrame.decode(server.sentFrames.last);
  }

  /// Закрывает QUIC-сессию [sessionId] — тот же путь, которым уходит
  /// вкладка, закрытая или перезагруженная по-настоящему (F5): `TillWire`
  /// слышит `SessionClosed` и зовёт `operations.forgetSession`.
  Future<void> closeSession(int sessionId) async {
    server.emitSessionClosed(sessionId: sessionId);
    // `_events` — широковещательный `StreamController`; событие доходит до
    // `TillWire._onEvent` не обязательно синхронно с `add()`.
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  Future<int> registeredTerminalId(int sessionId, String name) async {
    final frame = await ask(sessionId, 1, TillOps.terminalRegister.name, {
      'name': name,
      'code': invites.mint().code,
    });
    return ((frame as OkFrame).body['terminal']! as Map)['id'] as int;
  }

  /// То же, что [registeredTerminalId], но отдаёт и секрет — задел для
  /// сценариев, которые предъявляют его обратно через `terminals.resume`.
  Future<({int id, String secret})> registerTerminal(
    int sessionId,
    String name,
  ) async {
    final frame = await ask(sessionId, 1, TillOps.terminalRegister.name, {
      'name': name,
      'code': invites.mint().code,
    });
    final body = (frame as OkFrame).body;
    return (
      id: (body['terminal']! as Map)['id'] as int,
      secret: body['secret'] as String,
    );
  }

  test('двести перезагрузок вкладки подряд, предъявляя сохранённый секрет через '
      'resume, не заводят ни одной лишней строки', () async {
    // БЛОКЕР пункта 1 финальной волны — до задачи 5 F5 заводил новую
    // строку `terminals` на каждую перезагрузку, и уборка (`_pruneUnusedTerminals`)
    // была единственным, что не давало счёту дойти до потолка. С задачи 5
    // честный клиент (`_resolveTerminalId`, `login_controller.dart`)
    // больше не зовёт `register` на F5 вовсе — он предъявляет сохранённый
    // секрет через `resume` на новой QUIC-сессии и получает ТОТ ЖЕ
    // terminalId обратно. Мусора больше нет структурно, а не только
    // потому, что его подчищает уборка — этот тест это и проверяет:
    // 210 «перезагрузок» не создают ни одной новой строки.
    final enrolled = await registerTerminal(0, 'Вкладка Айгуль');
    const cycles = 210;
    for (var i = 1; i <= cycles; i++) {
      final frame = await ask(i, 1, TillOps.terminalResume.name, {
        'terminalId': enrolled.id,
        'secret': enrolled.secret,
      });
      expect(
        frame,
        isA<OkFrame>(),
        reason:
            'попытка $i из $cycles обязана вернуть тот же терминал по '
            'сохранённому секрету',
      );
      expect(
        ((frame as OkFrame).body['terminal']! as Map)['id'],
        enrolled.id,
        reason: 'resume обязан отдавать тот же terminalId, не заводить новый',
      );

      await closeSession(i);
      now = now.add(const Duration(minutes: 6));
    }

    // Ещё одна честная регистрация — она и звала бы уборку, будь что
    // убирать.
    final otherId = await registeredTerminalId(1000, 'Другая вкладка');

    final rows = await db.select(db.terminals).get();
    expect(
      rows.map((r) => r.id).toSet(),
      {enrolled.id, otherId},
      reason:
          'после $cycles «перезагрузок» через resume и одной новой честной '
          'регистрации в базе обязаны быть ровно две строки — та, что '
          'пережила все перезагрузки по секрету, и новая; ни одной лишней '
          'строки от F5 быть не должно вовсе',
    );
  });

  test('терминал с живым сеансом кассира не убирается, даже если его '
      'QUIC-сессия давно закрыта', () async {
    // Сессия 1: вкладка регистрируется и входит по-настоящему.
    final terminalId = await registeredTerminalId(1, 'Рабочая вкладка');
    final login = await ask(1, 2, TillOps.authLogin.name, {
      'pin': '1234',
      'userId': cashierId,
    });
    expect(login, isA<OkFrame>(), reason: 'предпосылка — вход настоящий');

    // Вкладка пережила F5: QUIC-сессия закрылась (уборка увидела бы её
    // осиротевшей), но токен в `SessionTokenStorage` браузера пережил
    // перезагрузку и восстановил тот же сеанс — ровно то, что
    // `_restoreSession()` (`login_controller.dart`) делает по-настоящему.
    // Сеанс остаётся живым в `SessionRegistry` независимо от того, что
    // случилось с транспортом, который его выписал.
    await closeSession(1);
    now = now.add(const Duration(minutes: 6));

    // Другая сессия регистрируется — это и запускает уборку
    // (`_pruneUnusedTerminals` зовётся первой строкой `terminals
    // .register`).
    await registeredTerminalId(2, 'Другая вкладка');

    final rows = await db.select(db.terminals).get();
    expect(
      rows.map((r) => r.id),
      contains(terminalId),
      reason:
          'терминал с живым сеансом обязан пережить уборку — иначе она '
          'вышибает терминал из-под кассира посреди смены, ровно то, что '
          'бриф запрещает первым делом',
    );
  });

  test(
    'терминал с привязкой устройства не убирается, даже без живого сеанса',
    () async {
      final terminalId = await registeredTerminalId(1, 'Касса с принтером');

      // Привязка устройства заводится напрямую через тот же репозиторий,
      // которым пользуется настоящий обработчик `deviceBindingSave` — без
      // входа: у настоящей настройки оборудования сеанса может уже не быть
      // (кассу настроили и выключили), а привязка остаётся.
      await LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ).save(
        terminalId,
        const DeviceBinding(
          deviceClass: DeviceClass.receiptPrinter,
          profileId: 'printer.escpos.usb',
        ),
      );

      await closeSession(1);
      now = now.add(const Duration(minutes: 6));

      await registeredTerminalId(2, 'Другая вкладка');

      final rows = await db.select(db.terminals).get();
      expect(
        rows.map((r) => r.id),
        contains(terminalId),
        reason:
            'терминал с настроенным устройством — чья-то настоящая рабочая '
            'станция, а не мусор от F5, даже когда за ней сейчас никто не '
            'сидит; уборка обязана его не тронуть',
      );
    },
  );

  test('терминал, осиротевший недавно, не убирается раньше зазора '
      'terminalIdleGrace', () async {
    final terminalId = await registeredTerminalId(1, 'Вкладка только что');

    await closeSession(1);
    // Зазор НЕ прошёл — на минуту меньше настроенных пяти.
    now = now.add(const Duration(minutes: 4));

    await registeredTerminalId(2, 'Другая вкладка');

    final rows = await db.select(db.terminals).get();
    expect(
      rows.map((r) => r.id),
      contains(terminalId),
      reason:
          'короткая сетевая заминка не обязана стоить терминала — зазор '
          'существует именно ради этого запаса осторожности',
    );
  });

  // Пункт 1 БЛОКЕР финальной волны — `.superpowers/sdd/2026-08-23
  // -terminal-enrolment/final-fix-report.md`: до этой правки уборка не
  // различала терминал, прошедший привязку по одноразовому коду (задача 5),
  // от честного мусора F5, и убирала оба на общих основаниях. Пара тестов
  // ниже нарочно НЕ даёт терминалу ни живой сессии ([hasLiveSession] всегда
  // ложно — никто не логинился), ни привязки устройства — обе защиты,
  // которые проверяют тесты выше, здесь выключены нарочно, чтобы граница
  // держалась ровно на `secretFingerprint`, а не на одной из них.
  test(
    'терминал с секретом переживает уборку дольше terminalIdleGrace даже без '
    'единой другой защиты (ни сеанса, ни привязки устройства)',
    () async {
      // `register()` (задача 4) сам заводит секрет каждой новой строке —
      // так что обычная регистрация уже даёт ровно тот случай, который
      // защищает правка.
      final terminalId = await registeredTerminalId(1, 'Планшет у входа');

      await closeSession(1);
      // Дольше, чем ночь до задачи 5 стоила бы терминалу привязки — зазор
      // взят с большим запасом намеренно: правка обязана держать терминал
      // вечно, не только чуть дольше пяти минут.
      now = now.add(const Duration(hours: 10));

      // Другая вкладка регистрируется — это и запускает уборку.
      await registeredTerminalId(2, 'Другая вкладка');

      final rows = await db.select(db.terminals).get();
      expect(
        rows.map((r) => r.id),
        contains(terminalId),
        reason:
            'терминал с непустым secretFingerprint обязан пережить уборку '
            'независимо от простоя — удаление строки уничтожает личность '
            'устройства, которую задача 5 обещала пронести через '
            'перезагрузку',
      );
    },
  );

  test('терминал без секрета убирается по-прежнему — правка сузила исключение, '
      'а не сняла уборку целиком', () async {
    // `register()` с задачи 4 всегда пишет secretFingerprint — строки без
    // него больше не заводятся честным путём. Единственный источник
    // такой строки сегодня — база, поднятая раньше миграции v35→v36
    // (докстринг `Terminals.secretFingerprint`, `app_database.dart`):
    // `secretFingerprint` у неё остаётся `NULL` навсегда, и ровно это
    // симулирует прямая запись в колонку ниже — не через `register()`,
    // которому спорить с фингерпринтом больше нечем.
    final terminalId = await registeredTerminalId(1, 'Легаси-терминал');
    await (db.update(db.terminals)..where((t) => t.id.equals(terminalId)))
        .write(const TerminalsCompanion(secretFingerprint: Value(null)));

    await closeSession(1);
    now = now.add(const Duration(minutes: 6));

    await registeredTerminalId(2, 'Другая вкладка');

    final rows = await db.select(db.terminals).get();
    expect(
      rows.map((r) => r.id),
      isNot(contains(terminalId)),
      reason:
          'без secretFingerprint терминал остаётся тем самым мусором от '
          'F5, ради которого уборка вообще писалась — исключение из '
          'кандидатов не должно превращаться в отключение уборки целиком',
    );
  });
}
