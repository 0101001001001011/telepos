/// **Проверка цели всей работы.** Без неё остальное — смена транспорта без
/// выгоды.
///
/// Здесь обе половины провода соединены торцами: настоящая база drift,
/// настоящие `TillOperations`, настоящий `TillWire` — и настоящие браузерные
/// репозитории поверх настоящего `WtDispatcher`. Подставлено ровно одно: сам
/// QUIC, потому что нативной библиотеки под `flutter test` нет вовсе (см.
/// `fake_quic_server.dart`). Кадры при этом настоящие: они кодируются,
/// пересекают петлю строкой и разбираются тем же `WireFrame.decode`.
///
/// Доказательство состоит из двух половин, и обе обязательны:
///
/// 1. подписчик получил второе значение **после изменения на кассе**;
/// 2. между первым и вторым значением он не отправил ни одного кадра.
///
/// Без второй половины тест не отличал бы подписку от опроса, а именно ради
/// этого различия транспорт и менялся.
library;

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
// `Terminal` есть и здесь (строка drift), и в домене. Прячем строку: тест
// смотрит на доменное значение — на то, что доехало до браузера.
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/terminal.dart' show Terminal;
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/web/wt_device_binding_repository.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_startup_state_repository.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late WtDispatcher browser;
  late SessionRegistry sessions;
  // Задача 6 плана «знакомство терминала с кассой»: `terminals.register`
  // требует код привязки — этот стенд про порядок «касса говорит первой»,
  // не про сам гейт код/секрет.
  late PairingInvites invites;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    sessions = SessionRegistry();
    invites = PairingInvites();
    final operations = TillOperations(
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
      invites: invites,
    );
    // `terminals.list` требует сеанса (`SessionAccess()` без права) — новый
    // договор проверки не делает исключения для стенда, который проверяет
    // саму цель переезда на провод. `terminals.deviceBindings` с правки 2
    // волны закрытия долга безопасности (2026-08-22) требует ещё и
    // `settings.hardware` — она была единственной в своей группе без
    // `needs`, и этот стенд её проверяет (`привязка, сохранённая на кассе,
    // доезжает до браузера без вопроса`), значит сеанс обязан нести право,
    // как несла бы настоящая вкладка настроек оборудования. Сеанс настоящий,
    // минтится тем же реестром, что отдан `TillWire.guard`, и предъявляется
    // браузером через `SessionTokenStorage`, как это делает настоящая
    // вкладка после входа (задача 6).
    final session = sessions.mint(
      userId: 1,
      name: 'Кассир',
      role: 'cashier',
      permissions: const {PermissionKeys.settingsHardware},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 1,
    );
    wire = TillWire(
      loop,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      runHandlers: operations.runHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
    )..start();
    browser = WtDispatcher(loop, tokens: FakeTokens(session.token));
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  test(
    'терминал, заведённый на кассе, доезжает до браузера без вопроса',
    () async {
      final seen = <List<Terminal>>[];
      final errors = <Object>[];
      final subscription = WtTerminalRepository(
        browser,
      ).watchAll().listen(seen.add, onError: errors.add);
      await settleLoopback();

      expect(errors, isEmpty, reason: 'подписка обязана завестись');
      expect(seen, hasLength(1), reason: 'первый кадр — текущее значение');
      expect(seen.single, isEmpty);

      final askedSoFar = loop.framesFromBrowser.length;
      expect(askedSoFar, 1, reason: 'подписка стоит ровно одного вопроса');

      // ИЗМЕНЕНИЕ НА КАССЕ. Браузер в этот момент ничего не делает.
      await db
          .into(db.terminals)
          .insert(
            TerminalsCompanion.insert(name: 'Касса у входа', createdAt: 0),
          );
      await settleLoopback();

      expect(
        seen,
        hasLength(2),
        reason:
            'касса обязана заговорить первой — ради этого менялся транспорт',
      );
      expect(seen.last.single.name, 'Касса у входа');
      expect(
        loop.framesFromBrowser.length,
        askedSoFar,
        reason:
            'подписчик не задал ни одного нового вопроса — иначе это опрос, '
            'а не подписка, и вся смена транспорта была напрасной',
      );

      await subscription.cancel();
    },
  );

  test('заведённый на кассе кассир доезжает до браузера без вопроса', () async {
    await _configure(db);

    final seen = <SetupState>[];
    final subscription = WtStartupStateRepository(
      browser,
    ).watch().listen(seen.add);
    await settleLoopback();

    expect(seen, hasLength(1));
    expect(seen.single.configured, isTrue);
    expect(seen.single.hasUsers, isFalse);
    final askedSoFar = loop.framesFromBrowser.length;

    // Ровно тот дефект, который назван в `setup_state.dart`: пользователь,
    // заведённый на кассе, доезжал до терминала при следующем вопросе — и
    // до тех пор терминал отправлял оператора в мастер настройки поверх
    // работающей кассы.
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: const Value(1),
            name: const Value('Кассир'),
            status: const Value('active'),
          ),
        );
    await settleLoopback();

    expect(seen.length, greaterThanOrEqualTo(2));
    expect(seen.last.hasUsers, isTrue);
    expect(loop.framesFromBrowser.length, askedSoFar);

    await subscription.cancel();
  });

  test(
    'привязка, сохранённая на кассе, доезжает до браузера без вопроса',
    () async {
      final terminalId = await db
          .into(db.terminals)
          .insert(TerminalsCompanion.insert(name: 'Касса-1', createdAt: 0));

      final seen = <List<DeviceBinding>>[];
      final subscription = WtDeviceBindingRepository(
        browser,
      ).watchForTerminal(terminalId).listen(seen.add);
      await settleLoopback();

      expect(seen, hasLength(1));
      expect(seen.single, isEmpty);
      final askedSoFar = loop.framesFromBrowser.length;

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
      await settleLoopback();

      expect(seen.length, greaterThanOrEqualTo(2));
      expect(seen.last.single.deviceClass, DeviceClass.receiptPrinter);
      expect(loop.framesFromBrowser.length, askedSoFar);

      await subscription.cancel();
    },
  );

  test('отписка закрывает поток, и касса перестаёт слать', () async {
    // Иначе подписки копятся молча и живут дольше экранов, которые их завели:
    // касса продолжает читать базу ради вкладки, которой больше нет.
    final subscription = WtTerminalRepository(
      browser,
    ).watchAll().listen((_) {});
    await settleLoopback();
    expect(wire.liveSubscriptions, 1);

    await subscription.cancel();
    await settleLoopback();

    // Сама отписка кассе не видна — событий отписки в этом транспорте не
    // существует (см. доку `TillSubscriptions`). Она узнаёт об уходе по
    // отказу записи: следующее обновление писать некуда.
    await db
        .into(db.terminals)
        .insert(TerminalsCompanion.insert(name: 'Ещё одна', createdAt: 0));
    await settleLoopback();

    expect(
      wire.liveSubscriptions,
      0,
      reason: 'подписка снимается по первой же записи в закрытый поток',
    );
  });

  test('вопрос по тому же проводу отвечается и закрывает свой поток', () async {
    // Подписка и вопрос делят одну сессию и не мешают друг другу: у каждого
    // обмена свой поток, и это единственный механизм соответствия.
    final subscription = WtTerminalRepository(
      browser,
    ).watchAll().listen((_) {});
    await settleLoopback();

    final enrolled = await WtTerminalRepository(
      browser,
    ).register(name: 'Новая', code: invites.mint().code);
    expect(enrolled.terminal.name, 'Новая');
    expect(
      enrolled.secret,
      isNotEmpty,
      reason: 'заведение обязано отдать секрет, а не только терминал',
    );

    await settleLoopback();
    expect(
      wire.liveSubscriptions,
      1,
      reason: 'одноразовый вопрос не снимает и не заводит подписок',
    );

    await subscription.cancel();
  });
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

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}
