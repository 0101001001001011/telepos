/// Задача 7 плана «знакомство терминала с кассой», разбор блокера
/// (`.superpowers/sdd/2026-08-23-terminal-enrolment/enrolment-entry-report.md`).
///
/// # Почему настоящий провод, а не подделки
///
/// Ровно этот класс дефекта — «набор зелёный, вход сломан» — родился из
/// того, что путь проверяли подделки (`FakeTerminalRepository.register`),
/// которые довод `code` не смотрели вовсе: `test/presentation/auth/
/// login_controller_test.dart` был зелёным на сломанной реализации. Этот
/// файл соединяет обе половины провода торцами — настоящую базу drift,
/// настоящие `TillOperations`, настоящий `TillWire`, настоящий
/// `PairingInvites`, настоящий `LocalAuthRepository` — и ведёт настоящий
/// `LoginNotifier` через настоящие `WtTerminalRepository`/`WtAuthRepository`
/// поверх настоящего `WtDispatcher`. Подставлено ровно то же, что и в
/// `wt_till_speaks_first_test.dart`: сам QUIC (`Loopback`,
/// `test/web/support/loopback.dart`) — нативной библиотеки под `flutter
/// test` нет. Подделаны намеренно только `TerminalIdentity` (десктопное
/// понятие, браузерная ветка `_resolveTerminalId` его не читает — только
/// звонит `.forget()` в ветке, которую эти сценарии не проходят) и
/// `TerminalSecretStorage` (`localStorage`, не часть провода).
///
/// # Три случая брифа задачи 7 — по одному тесту на каждый
///
/// 1. «Новое устройство»: `terminals.register` без кода отказывает
///    `pairing_code_invalid`, гейт остаётся; настоящий код от
///    `PairingInvites.mint()` заводит настоящую строку в базе кассы и
///    впускает настоящего кассира.
/// 2. «Старое устройство без секрета»: сохранённый секрет называет
///    несуществующий терминал — настоящий `terminals.resume` отвечает
///    `terminal_secret_invalid`, а не молчанием; после этого новый код
///    заводит терминал заново.
/// 3. Десктоп (доказательство «не задет» тем же приёмом, что и
///    `terminal_register_gate_test.dart`): `ensureSelf()`/`self()` не
///    видят код привязки вовсе — тест зовёт их напрямую, без единого
///    `PairingInvites` в кадре.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret_storage.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/web/wt_auth_repository.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_terminal_repository.dart';

import '../presentation/auth/support/fakes.dart';
import 'support/loopback.dart';

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late WtDispatcher browser;
  late PairingInvites invites;
  late int cashierId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Настоящий кассир с настоящим PIN — то же самое, чем «свежая
    // установка» проверена в `terminal_register_gate_test.dart`: без
    // `thisPosDao.insertInitialConfig` `LocalAuthRepository.login` не имеет
    // ни одной строки, на которую можно опереться.
    await db.thisPosDao.insertInitialConfig(
      companyName: 'ТОО Ромашка',
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
            role: const Value(1),
            status: const Value('active'),
            passwordEnc: Value(PinCredential.create('4321')),
          ),
        );

    invites = PairingInvites();
    final sessions = SessionRegistry();
    final operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: _NoopBindings(),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      invites: invites,
    );

    loop = Loopback();
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
    browser = WtDispatcher(loop);

    final getIt = GetIt.instance;
    getIt
      ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
      ..registerSingleton<HostCapabilities>(HostCapabilities.browser)
      ..registerSingleton<TerminalRepository>(WtTerminalRepository(browser))
      ..registerSingleton<AuthRepository>(WtAuthRepository(browser))
      ..registerSingleton<SessionTokenStorage>(FakeSessionTokenStorage());
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
    await GetIt.instance.reset();
  });

  Future<void> loginWithPin(LoginNotifier notifier, String pin) async {
    for (final digit in pin.split('')) {
      notifier.addDigit(digit);
    }
    await notifier.pendingVerification;
  }

  test(
    'новое устройство: register() без кода отказывает по-настоящему, гейт '
    'держит, действительный код от PairingInvites.mint() заводит строку и '
    'впускает кассира',
    () async {
      GetIt.instance.registerSingleton<TerminalSecretStorage>(
        FakeTerminalSecretStorage(),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      // Шаг 1: первая попытка входа этой вкладки — секрета нет, кода тоже
      // нет. КРАСНОЕ БЕЗ ПРАВКИ КОНТРОЛЛЕРА: до неё этот путь звал
      // `register(code: '')` вслепую, настоящая касса отвечала
      // `pairing_code_invalid`, и `_resolveTerminalId` тонул в общем
      // `catch (_)` — `error` стало бы `error.auth_unknown`, а не гейтом.
      await loginWithPin(notifier, '4321');

      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isTrue,
        reason: 'без кода касса не имеет права завести терминал',
      );
      expect(
        await db.terminalDao.all(),
        isEmpty,
        reason: 'отклонённая (не отправленная) попытка не заводит строку',
      );

      // Шаг 2: выдуманный код — настоящая касса отвечает `pairing_code_invalid`
      // по-настоящему (не подделка), причина обязана называться поимённо.
      notifier.updateEnrolmentCode('этот-код-никто-не-мятил');
      await notifier.submitEnrolmentCode();

      expect(
        container.read(loginControllerProvider).error,
        'error.pairing_code_invalid',
      );
      expect(container.read(loginControllerProvider).needsEnrolmentCode, isTrue);
      expect(await db.terminalDao.all(), isEmpty);

      // Шаг 3: настоящий код от настоящего PairingInvites той же кассы —
      // тем же экземпляром, каким пользуется `TerminalPairingScreen`.
      final code = invites.mint().code;
      notifier.updateEnrolmentCode(code);
      await notifier.submitEnrolmentCode();

      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isFalse,
        reason: 'действительный код обязан снять гейт',
      );
      final terminals = await db.terminalDao.all();
      expect(
        terminals,
        hasLength(1),
        reason: 'настоящая строка терминала обязана появиться в базе кассы',
      );
      expect(notifier.browserTerminalId, terminals.single.id);

      // Шаг 4: вход настоящим кассиром, настоящим PIN, по настоящему проводу.
      await loginWithPin(notifier, '4321');

      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isTrue,
        reason:
            'ДОСТИЖИМОСТЬ: терминал, заведённый настоящим кодом, обязан '
            'провести настоящий вход, а не только появиться в базе',
      );
    },
  );

  test(
    'старое устройство без секрета: настоящий resume() отвечает '
    'terminal_secret_invalid, гейт называет причину, новый код заводит '
    'терминал заново',
    () async {
      // Секрет, оставшийся от терминала, которого на этой (свежей) базе
      // никогда не было — тот же случай, что называет пункт 7 брифа задачи
      // 7: обновление кассы, восстановление из копии, или просто удалённый
      // на кассе терминал.
      final secretStore = FakeTerminalSecretStorage()
        ..write(9999, 'секрет-от-удалённого-или-чужого-терминала');
      GetIt.instance.registerSingleton<TerminalSecretStorage>(secretStore);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      await loginWithPin(notifier, '4321');

      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isTrue,
      );
      expect(
        container.read(loginControllerProvider).error,
        'error.terminal_secret_invalid',
        reason:
            'ГЛАВНАЯ ПРОВЕРКА ПУНКТА 7 БРИФА: старое устройство без '
            'действующего секрета обязано увидеть названную причину, а не '
            'общее «попробуйте ещё раз»',
      );
      expect(
        secretStore.read(),
        isNull,
        reason: 'касса доказала, что секрет плохой — он обязан быть забыт',
      );
      expect(await db.terminalDao.all(), isEmpty);

      // Новый код от настоящего PairingInvites заводит терминал заново.
      final code = invites.mint().code;
      notifier.updateEnrolmentCode(code);
      await notifier.submitEnrolmentCode();

      expect(container.read(loginControllerProvider).needsEnrolmentCode, isFalse);
      final terminals = await db.terminalDao.all();
      expect(terminals, hasLength(1));
      expect(
        secretStore.read()?.terminalId,
        terminals.single.id,
        reason: 'новый секрет новой заводки обязан быть сохранён',
      );

      await loginWithPin(notifier, '4321');
      expect(container.read(loginControllerProvider).isAuthenticated, isTrue);
    },
  );

  // Пункт «не запри десктоп» брифа задачи 7 — на этом же настоящем проводе:
  // десктопная касса берёт свой терминал через `self()`/`ensureSelf()`, а
  // не через `register()`, и код привязки ей спрашивать негде и не за чем.
  // Тот же довод, что и «свежая установка» в `terminal_register_gate_test
  // .dart`, только здесь — доказательство поверх настоящего провода целиком,
  // а не только обработчика.
  test(
    'десктоп: self()/ensureSelf() заводят терминал без единого кода '
    'привязки, PairingInvites этому пути не нужен вовсе',
    () async {
      final localTerminals = LocalTerminalRepository(db);
      final terminal = await localTerminals.self();

      expect(terminal.name, 'Касса-1');
      expect(await db.terminalDao.all(), hasLength(1));

      final auth = LocalAuthRepository(
        db: db,
        sessions: SessionRegistry(),
        throttle: LoginThrottle(),
      );
      final outcome = await auth.login(
        AuthAttempt(pin: '4321', terminalId: terminal.id, userId: cashierId),
      );

      expect(
        outcome,
        isA<AuthSession>(),
        reason: 'десктопный путь не задет гейтом задачи 6 — вход проходит '
            'без единого PairingInvites в кадре',
      );
    },
  );
}
