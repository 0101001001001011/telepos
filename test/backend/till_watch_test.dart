/// Кассовая половина подписок: касса говорит первой.
///
/// Это проверка **цели всей работы**, а не украшение. Транспорт менялся ради
/// одного: чтобы упавшая печать, появившееся устройство и заведённый кассир
/// доезжали до терминала в момент события, а не при следующем вопросе. Пока у
/// кассы нет источника изменений, подписка отдала бы одно значение и
/// закрылась — вопрос в одежде подписки, — и вся смена транспорта осталась бы
/// без выгоды.
///
/// Поэтому здесь после первого кадра **никто ничего не спрашивает**: тест
/// меняет базу и ждёт, что кадр придёт сам. Счёт входящих запросов в
/// `FakeQuicServer` не растёт — это и есть доказательство.
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
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

import '../data/transport/fake_quic_server.dart';

void main() {
  late AppDatabase db;
  late FakeQuicServer server;
  late SessionRegistry sessions;
  late WireGuard guard;
  // Задача 6 плана «знакомство терминала с кассой»: `terminals.register`
  // требует код привязки — здесь только один тест несёт настоящее имя
  // («заведение терминала возвращает заведённый терминал») и мятит себе код.
  late PairingInvites invites;

  TillOperations build({DeviceDiscovery? discovery, DeviceCheck? check}) =>
      TillOperations(
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
        deviceDiscovery: discovery,
        deviceCheck: check,
        invites: invites,
      );

  /// Настоящий сеанс через тот же реестр, что проверяет [guard]. `needs` —
  /// как в договоре: `deviceDiscovery`/`deviceCheck`/`deviceBindings`
  /// требуют `settings.hardware`, `terminalsList` — только сам факт сеанса.
  ///
  /// Правка 2 волны закрытия долга безопасности (2026-08-22):
  /// `deviceBindings` до неё была здесь названа неверно — единственная в
  /// своей группе `ownTerminal.same` без `needs`, и этот докстринг подавал
  /// дыру как решение. Тесты ниже, заводившие сеанс `deviceBindings` без
  /// `settingsHardware`, правились вместе с этой строкой.
  ///
  /// `terminalId` по умолчанию — 1, тот же терминал, что уже используют
  /// вызовы этого файла без явного довода. С задачи 10 закрытия долга
  /// `deviceBindings`, `deviceBindingSave`, `terminalRename` и `deviceCheck`
  /// сверяют `terminalId` тела с `session.terminalId` сами (сторож,
  /// `SessionAccess.ownTerminal`) — вызовы на терминал, отличный от 1,
  /// обязаны передать сюда тот же id, иначе получат `forbidden` вместо
  /// проверяемого исхода.
  String sessionToken({
    Set<String> permissions = const {},
    int terminalId = 1,
  }) => sessions
      .mint(
        userId: 1,
        name: 'Кассир',
        role: 'cashier',
        permissions: permissions,
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: terminalId,
      )
      .token;

  /// Задаёт один вопрос и отдаёт разобранный ответный кадр.
  Future<WireFrame> ask(
    TillOperations operations,
    String op, [
    Map<String, Object?> body = const {},
    String? token,
  ]) async {
    final wire = TillWire(server, operations.askHandlers, guard: guard)
      ..start();
    server.emitStreamOpened(sessionId: 1, streamId: 8);
    server.emitStreamData(
      sessionId: 1,
      streamId: 8,
      message: jsonEncode({
        'op': op,
        'body': body,
        if (token != null) 'token': token,
      }),
    );
    await _settle();
    await wire.stop();
    return WireFrame.decode(server.sentFrames.single);
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeQuicServer();
    sessions = SessionRegistry();
    invites = PairingInvites();
    guard = wireGuardForTill(
      db: db,
      access: {for (final op in TillOps.all) op.name: op.access},
      sessions: sessions,
    );
  });
  tearDown(() async {
    await server.dispose();
    await db.close();
  });

  /// Заводит подписку и отдаёт провод. Один запрос — и больше ни одного за
  /// весь тест: в этом весь смысл.
  Future<TillWire> subscribe(
    TillOperations operations,
    String op, {
    Map<String, Object?> body = const {},
    int streamId = 4,
    String? token,
  }) async {
    final wire = TillWire(
      server,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      guard: guard,
    )..start();
    server.emitStreamOpened(sessionId: 1, streamId: streamId);
    server.emitStreamData(
      sessionId: 1,
      streamId: streamId,
      message: jsonEncode({
        'op': op,
        'body': body,
        if (token != null) 'token': token,
      }),
    );
    // Закрытие приходит сразу за запросом — так устроен приём, и подписку оно
    // не снимает (см. доку `TillSubscriptions`).
    server.emitStreamClosed(sessionId: 1, streamId: streamId);
    await _settle();
    return wire;
  }

  test('семь подписок объявлены на кассе', () {
    // Пока их нет, провод отвечает `unknown_op`, и терминал не может узнать
    // об изменении иначе как вопросом. `auth.users`/`auth.session` — задача
    // 9; `auth.sessions` — задача 19 закрытия долга безопасности (экран
    // списка сеансов).
    final names = build().watchHandlers.keys.toSet();

    expect(names, {
      TillOps.setupState.name,
      TillOps.terminalsList.name,
      TillOps.terminalSelf.name,
      TillOps.deviceBindings.name,
      TillOps.authUsers.name,
      TillOps.authSession.name,
      TillOps.authSessions.name,
    });
  });

  test('список терминалов: новый терминал доезжает без вопроса', () async {
    final operations = build();
    final wire = await subscribe(
      operations,
      TillOps.terminalsList.name,
      token: sessionToken(),
    );

    expect(
      server.sentFrames.length,
      1,
      reason: 'первый кадр — текущее значение',
    );
    expect(_bodyOf(server.sentFrames.first)['terminals'], isEmpty);

    // Изменение НА КАССЕ. Терминал в этот момент молчит.
    await db
        .into(db.terminals)
        .insert(
          TerminalsCompanion.insert(
            name: 'Касса-2',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
    await _settle();

    expect(
      server.sentFrames.length,
      2,
      reason: 'касса обязана заговорить первой — ради этого менялся транспорт',
    );
    final update = WireFrame.decode(server.sentFrames.last);
    expect(update, isA<UpdateFrame>());
    final terminals = (update as UpdateFrame).body['terminals']! as List;
    expect((terminals.single as Map)['name'], 'Касса-2');

    await wire.stop();
  });

  test('свой терминал: переименование доезжает без вопроса', () async {
    await _configure(db);
    final id = await db
        .into(db.terminals)
        .insert(
          TerminalsCompanion.insert(
            name: 'Касса-1',
            isSelf: const Value(true),
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

    final operations = build();
    final wire = await subscribe(operations, TillOps.terminalSelf.name);
    expect(server.sentFrames.length, 1);

    await db.terminalDao.rename(id, 'Касса у входа');
    await _settle();

    expect(server.sentFrames.length, 2);
    final body = _bodyOf(server.sentFrames.last);
    expect((body['terminal']! as Map)['name'], 'Касса у входа');

    await wire.stop();
  });

  test('своего терминала ещё нет — это значение, а не отказ', () async {
    // Свежая установка: мастер не проходил, `self()` отказывается выдумывать
    // имя. Подписка обязана сказать «его нет» кадром, а не оборваться — иначе
    // экран мастера настройки не откроется вовсе.
    final operations = build();
    final wire = await subscribe(operations, TillOps.terminalSelf.name);

    expect(WireFrame.decode(server.sentFrames.single), isA<UpdateFrame>());
    expect(_bodyOf(server.sentFrames.single)['terminal'], isNull);

    await wire.stop();
  });

  test('состояние установки: заведённый кассир доезжает без вопроса', () async {
    await _configure(db);
    final operations = build();
    final wire = await subscribe(operations, TillOps.setupState.name);

    expect(server.sentFrames.length, 1);
    expect(_bodyOf(server.sentFrames.first)['hasUsers'], isFalse);
    expect(_bodyOf(server.sentFrames.first)['configured'], isTrue);

    // Ровно тот случай, который назван в `setup_state.dart`: пользователь,
    // заведённый на кассе, доезжал до терминала при следующем вопросе.
    await _addUser(db);
    await _settle();

    expect(server.sentFrames.length, greaterThanOrEqualTo(2));
    expect(_bodyOf(server.sentFrames.last)['hasUsers'], isTrue);

    await wire.stop();
  });

  test(
    'привязки устройств: появившееся устройство доезжает без вопроса',
    () async {
      final terminalId = await db
          .into(db.terminals)
          .insert(
            TerminalsCompanion.insert(
              name: 'Касса-1',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          );

      final operations = build();
      final wire = await subscribe(
        operations,
        TillOps.deviceBindings.name,
        body: {'terminalId': terminalId},
        // Явно тот же терминал, что в теле — задача 10 закрытия долга:
        // сторож сверяет их сам, и не полагаться на то, что автоинкремент
        // случайно даст сеансу и терминалу один и тот же id.
        //
        // `settingsHardware` — правка 2 волны закрытия долга безопасности
        // (2026-08-22): без права `deviceBindings` теперь отвечает
        // `forbidden`, не первым кадром подписки.
        token: sessionToken(
          terminalId: terminalId,
          permissions: {PermissionKeys.settingsHardware},
        ),
      );
      expect(server.sentFrames.length, 1);
      expect(_bodyOf(server.sentFrames.first)['bindings'], isEmpty);

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
      await _settle();

      expect(server.sentFrames.length, greaterThanOrEqualTo(2));
      final bindings = _bodyOf(server.sentFrames.last)['bindings']! as List;
      expect(bindings, hasLength(1));

      await wire.stop();
    },
  );

  test('чужой терминал не получает чужих обновлений', () async {
    // Подписка на терминал №1 обязана молчать, когда меняется терминал №2:
    // иначе экран настроек одной кассы перерисовывался бы от чужого принтера.
    final one = await db
        .into(db.terminals)
        .insert(
          TerminalsCompanion.insert(
            name: 'Один',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
    final two = await db
        .into(db.terminals)
        .insert(
          TerminalsCompanion.insert(
            name: 'Два',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

    final operations = build();
    final wire = await subscribe(
      operations,
      TillOps.deviceBindings.name,
      body: {'terminalId': one},
      token: sessionToken(
        terminalId: one,
        permissions: {PermissionKeys.settingsHardware},
      ),
    );
    final afterFirst = server.sentFrames.length;

    await LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog()).save(
      two,
      const DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'printer.escpos.usb',
      ),
    );
    await _settle();

    final delivered = server.sentFrames.skip(afterFirst).map(WireFrame.decode);
    for (final frame in delivered) {
      // drift будит запрос на любое изменение таблицы; кадр допустим только
      // если значение действительно другое. Чужая привязка своего списка не
      // меняет — значит и списка в кадре быть не должно.
      expect((frame as UpdateFrame).body['bindings'], isEmpty);
    }

    await wire.stop();
  });

  group('вопросы, добавленные ради полноты договоров', () {
    // Договор, у которого на проводе нет одного метода, — это биндинг,
    // отказывающий в одном месте из четырёх, и узнать об этом можно только
    // нажав кнопку. Здесь проверено, что каждый из добавленных отвечает по
    // существу, а не просто объявлен.

    test('заведение терминала возвращает заведённый терминал', () async {
      final frame = await ask(build(), TillOps.terminalRegister.name, {
        'name': '  Касса у входа  ',
        'code': invites.mint().code,
      });

      expect(frame, isA<OkFrame>());
      final enrollment = TillOps.terminalRegister.decode(
        (frame as OkFrame).body,
      );
      expect(
        enrollment.terminal.name,
        'Касса у входа',
        reason: 'имя хранится обрезанным — правило договора, а не оформление',
      );
      expect(
        enrollment.secret,
        isNotEmpty,
        reason: 'заведение обязано отдать секрет, а не только терминал',
      );
      expect(await db.terminalDao.all(), hasLength(1));
    });

    test('заведение без имени отказывает названной причиной', () async {
      final frame = await ask(build(), TillOps.terminalRegister.name, {
        'name': '   ',
      });

      // Код называет причину точно — `bad_request`, а не общий
      // `handler_failed`: `WireRefusal` (задача 2б) отвечает своим кодом,
      // потому что причина в теле запроса, а не в поломке обработчика.
      expect((frame as ErrorFrame).code, 'bad_request');
      expect(frame.detail, contains('имя обязательно'));
      expect(
        await db.terminalDao.all(),
        isEmpty,
        reason: 'отклонённый запрос не оставляет строки',
      );
    });

    test('свой терминал заводится, если его ещё нет', () async {
      // Тем же делом занимался `GET /api/terminals/self` до провода: он звал
      // `self()`, который создаёт строку при первом обращении. Наблюдающая
      // `terminals.self` этого не делает и не должна.
      await _configure(db);

      final frame = await ask(build(), TillOps.terminalSelfEnsure.name);

      expect(
        TillOps.terminalSelfEnsure.decode((frame as OkFrame).body),
        isNotNull,
      );
      expect(await db.terminalDao.self(), isNotNull);
    });

    test('своего терминала нет до мастера — значение, а не отказ', () async {
      final frame = await ask(build(), TillOps.terminalSelfEnsure.name);

      expect(
        frame,
        isA<OkFrame>(),
        reason: 'свежая установка — состояние, а не поломка',
      );
      expect(
        TillOps.terminalSelfEnsure.decode((frame as OkFrame).body),
        isNull,
      );
      expect(
        await db.terminalDao.self(),
        isNull,
        reason: 'ненастроенная касса не заводит терминала с выдуманным именем',
      );
    });

    test('поиск устройств отдаёт то, что нашла касса', () async {
      final frame = await ask(
        build(discovery: _ScriptedDiscovery()),
        TillOps.deviceDiscovery.name,
        {'deviceClass': DeviceClass.receiptPrinter.name},
        sessionToken(permissions: {PermissionKeys.settingsHardware}),
      );

      final result = TillOps.deviceDiscovery.decode((frame as OkFrame).body);
      expect(result.candidates.single.title, 'Принтер на COM3');
      expect(
        result.failedSources,
        {DeviceDiscoverySource.usb},
        reason: '«не смогли спросить» обязано доехать отдельно от «не нашлось»',
      );
    });

    test('касса без драйверов отказывает названной причиной', () async {
      // «Искать было нечем» и «ничего не нашлось» для оператора разные вещи.
      final frame = await ask(
        build(),
        TillOps.deviceDiscovery.name,
        {'deviceClass': DeviceClass.receiptPrinter.name},
        sessionToken(permissions: {PermissionKeys.settingsHardware}),
      );

      // `no_drivers`, а не общий `handler_failed`: касса, а не тело запроса,
      // не умеет искать устройства — «искать было нечем», код обязан
      // называть это отдельно от «ничего не нашлось».
      expect((frame as ErrorFrame).code, 'no_drivers');
      expect(frame.detail, contains('нет драйверов'));
    });

    test('неизвестный класс устройств не угадывается', () async {
      // Угаданный класс отправил бы кассу искать не то железо и рапортовать
      // о нём как о запрошенном.
      final frame = await ask(
        build(discovery: _ScriptedDiscovery()),
        TillOps.deviceDiscovery.name,
        {'deviceClass': 'quantumScanner'},
        sessionToken(permissions: {PermissionKeys.settingsHardware}),
      );

      // `bad_request`: причина в теле запроса (класс устройства, которого
      // касса не знает), а не в поломке обработчика.
      expect((frame as ErrorFrame).code, 'bad_request');
      expect(frame.detail, contains('quantumScanner'));
    });

    test('проверка устройства отдаёт исход кассы как есть', () async {
      final frame = await ask(
        build(check: _ScriptedCheck()),
        TillOps.deviceCheck.name,
        {'terminalId': 3, 'deviceClass': DeviceClass.cashDrawer.name},
        sessionToken(
          permissions: {PermissionKeys.settingsHardware},
          terminalId: 3,
        ),
      );

      final outcome = TillOps.deviceCheck.decode((frame as OkFrame).body);
      expect(outcome.reason, DeviceCheckReason.notConfigured);
      expect(
        outcome.message,
        'Ящик не привязан',
        reason: 'текст считает касса; провод его не пересочиняет',
      );
    });

    test(
      'касса без драйверов отказывает проверке устройства названной причиной',
      () async {
        // Тот же случай, что у поиска устройств чуть выше, и той же
        // причиной: «искать было нечем» и «ничего не нашлось» разные вещи
        // и для `deviceCheck`, не только для `deviceDiscovery`.
        final frame = await ask(
          build(),
          TillOps.deviceCheck.name,
          {'terminalId': 3, 'deviceClass': DeviceClass.cashDrawer.name},
          sessionToken(
            permissions: {PermissionKeys.settingsHardware},
            terminalId: 3,
          ),
        );

        expect((frame as ErrorFrame).code, 'no_drivers');
        expect(frame.detail, contains('нет драйверов'));
      },
    );
  });

  test('подписка снимается, когда писать больше некуда', () async {
    // Подписки, живущие дольше экранов, которые их завели, — тот отказ,
    // которого иначе не видно: касса продолжает читать базу ради вкладки,
    // которой нет.
    final operations = build();
    final wire = TillWire(
      server,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      guard: guard,
    )..start();
    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(
      sessionId: 1,
      streamId: 4,
      message: jsonEncode({
        'op': TillOps.terminalsList.name,
        'body': const {},
        'token': sessionToken(),
      }),
    );
    await _settle();
    expect(wire.liveSubscriptions, 1);

    server.emitSessionClosed(sessionId: 1);
    await _settle();

    expect(wire.liveSubscriptions, 0);
    await wire.stop();
  });
}

/// Даёт отработать и потокам drift, и записи в поток провода.
///
/// Микрозадачи одного оборота не хватает: обновление проходит через
/// `StreamQueryStore` drift, через `map`, и только потом через `sendOn`, между
/// которыми есть настоящие `await`.
Future<void> _settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Map<String, Object?> _bodyOf(String frame) {
  final decoded = WireFrame.decode(frame);
  return switch (decoded) {
    UpdateFrame(:final body) => body,
    _ => throw StateError('ожидался кадр изменения, пришёл $decoded'),
  };
}

Future<void> _configure(AppDatabase db) => db.thisPosDao.insertInitialConfig(
  companyName: 'ТОО Ромашка',
  iinbin: null,
  cashBoxName: 'Касса-1',
  countryCode: 0,
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

Future<void> _addUser(AppDatabase db) => db
    .into(db.users)
    .insert(
      UsersCompanion.insert(
        id: const Value(1),
        name: const Value('Кассир'),
        status: const Value('active'),
      ),
    );

class _ScriptedDiscovery implements DeviceDiscovery {
  @override
  Future<DeviceDiscoveryResult> find(DeviceClass deviceClass) async =>
      const DeviceDiscoveryResult(
        candidates: [
          DeviceCandidate(
            source: DeviceDiscoverySource.serialPort,
            title: 'Принтер на COM3',
            parameters: {'comPort': 'COM3'},
          ),
        ],
        // «Спросить не удалось» едет отдельным полем — ради этого различия
        // `failedSources` в контракте и появился.
        failedSources: {DeviceDiscoverySource.usb},
      );
}

class _ScriptedCheck implements DeviceCheck {
  @override
  Future<DeviceCheckOutcome> check({
    required int terminalId,
    required DeviceClass deviceClass,
  }) async => DeviceCheckOutcome.wire(
    reason: DeviceCheckReason.notConfigured,
    message: 'Ящик не привязан',
  );
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}
