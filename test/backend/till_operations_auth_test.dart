/// Обработчики входа на кассе (задача 9).
///
/// `till_operations_test.dart:46-71` уже сверяет каталог операций с картами
/// обработчиков в обе стороны — этот файл не дублирует ту сверку, а называет
/// отказ поимённо для четырёх операций входа: если один из них исчезнет,
/// падает именно этот тест, а не общая сверка множеств.
///
/// Второй тест проверяет то самое правило задачи: обработчик не содержит ни
/// одной строки логики входа, он только переводит кадр в довод и исход в
/// кадр — а проверяет PIN настоящий `LocalAuthRepository` поверх базы в
/// памяти. Подделка здесь была бы нечестной: она доказала бы, что обработчик
/// умеет звать метод, а не то, что настоящий отказ `LocalAuthRepository`
/// доезжает до терминала кадром-значением, а не падением обмена.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

void main() {
  late AppDatabase db;
  // Задача 6 плана «знакомство терминала с кассой» (шаг 3 спеки):
  // `terminals.register` требует код привязки — этот набор про вход, не про
  // сам гейт, поэтому здесь один общий `PairingInvites`, и каждый вызов
  // `terminals.register` ниже мятит себе свежий код (`invites.mint().code`).
  late PairingInvites invites;

  TillOperations build() => TillOperations(
    db: db,
    bootstrap: _StubBootstrap(),
    setup: _StubSetup(),
    terminals: _StubTerminals(),
    deviceBindings: _StubBindings(),
    auth: LocalAuthRepository(
      db: db,
      sessions: SessionRegistry(),
      throttle: LoginThrottle(),
    ),
    invites: invites,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    invites = PairingInvites();
  });
  tearDown(() => db.close());

  test('у каждой операции входа есть обработчик', () {
    // Существующий тест `till_operations_test.dart:46-71` сверяет множества в
    // обе стороны и поймает это сам; здесь — поимённо, чтобы отказ назывался.
    final operations = build();

    expect(operations.watchHandlers, contains(TillOps.authUsers.name));
    expect(operations.askHandlers, contains(TillOps.authLogin.name));
    expect(operations.askHandlers, contains(TillOps.authLogout.name));
    expect(operations.watchHandlers, contains(TillOps.authSession.name));
  });

  test('вход отвечает кадром-значением даже при отказе', () async {
    final operations = build();
    // Пункт 2 фазы 3/4 закрытия долга: `auth.login` больше не берёт
    // `terminalId` из тела — только из того, что эта же сессия сама завела
    // через `terminals.register`. Здесь и ниже сессия сперва регистрируется
    // напрямую тем же обработчиком, каким это делает настоящий провод.
    const sessionId = 42;
    await operations.askHandlers[TillOps.terminalRegister.name]!({
      'name': 'Терминал вкладки',
      'code': invites.mint().code,
    }, sessionId);

    // Свежая база в памяти: ни `ThisPos`, ни пользователей. `walkUpEnabled`
    // по умолчанию `false` (`ThisPosDao.authSettings`), и без выбранного
    // `userId` касса отказывает раньше, чем дойдёт до проверки PIN, — этого
    // достаточно, чтобы отказ был настоящим, а не подстроенным для теста.
    final body = await operations.askHandlers[TillOps.authLogin.name]!({
      'pin': '0000',
      'userId': null,
    }, sessionId);

    // Отказ — это `ok: false` внутри ответа, а не ErrorFrame: неверный PIN не
    // является поломкой обмена.
    //
    // Конкретная причина, а не `isNotNull`: та проходила бы и на случайно
    // подставленном значении — `null.toString()` тоже не `null`. Свежая база
    // без `ThisPos` даёт `walkUpEnabled == false` (умолчание
    // `ThisPosDao.authSettings`), и без выбранного `userId` касса отказывает
    // этой причиной раньше, чем дойдёт до проверки PIN.
    expect(body['ok'], isFalse);
    expect(body['reason'], 'walkUpDisabled');
  });

  test(
    'сессия, не заведшая терминал, — отказ названной причиной, а не молчит',
    () async {
      // Регрессия, которую точно тот же код закрывал раньше по `terminalId`
      // из тела: пункт 2 фазы 3/4 закрытия долга убрал доверие телу и завёл
      // источник доверия в сессии — здесь проверяется, что отсутствие записи
      // тоже отказывает названно, а не роняет обмен и не пропускает вход.
      final operations = build();

      // Задача 2б: причина едет как `WireRefusal` со своим кодом
      // (`unknown_terminal`), а не как `ArgumentError` — провод больше не
      // несёт текст произвольного исключения. Тот же код, которым раньше
      // отвечал несуществующий `terminalId` в теле — терминал не обязан
      // отличать по тексту «сессия ничего не зарегистрировала» от «указанный
      // id не существует», обе причины сводятся к «входить как этот
      // терминал нельзя».
      await expectLater(
        operations.askHandlers[TillOps.authLogin.name]!({
          'pin': '0000',
          'userId': null,
        }, 99),
        throwsA(
          isA<WireRefusal>().having(
            (refusal) => refusal.code,
            'code',
            'unknown_terminal',
          ),
        ),
      );
    },
  );

  test(
    'sessionId в теле не подделать — чужой terminalId в теле игнорируется',
    () async {
      // Пункт 2 фазы 3/4 закрытия долга — сама дыра: до правки кассир мог
      // назвать любой terminalId в теле и получить сеанс на него. Сессия
      // здесь зарегистрировала терминал #1 (первый в свежей базе), тело
      // называет заведомо другой (999) — обработчик обязан использовать
      // терминал сессии, а не тело.
      final operations = build();
      const sessionId = 7;
      final registered = await operations.askHandlers[TillOps
              .terminalRegister
              .name]!({
            'name': 'Терминал сессии',
            'code': invites.mint().code,
          }, sessionId);
      final terminal = registered['terminal']! as Map<String, Object?>;

      await expectLater(
        operations.askHandlers[TillOps.authLogin.name]!({
          'pin': '0000',
          'terminalId': 999,
          'userId': null,
        }, sessionId),
        // Не бросает `unknown_terminal` — терминал сессии существует (тот,
        // что вернул `register` выше), значит доходит до `LocalAuthRepository`
        // и отказывает `walkUpDisabled` тем же путём, что первый тест.
        completion(
          predicate<Map<String, Object?>>(
            (body) => body['ok'] == false && body['reason'] == 'walkUpDisabled',
          ),
        ),
      );
      expect(terminal['id'], isNotNull);
    },
  );

  test(
    'незаведённый terminalId в теле сам по себе больше ни на что не влияет',
    () async {
      // `LoginThrottle` больше не ключуется телом напрямую — терминал берётся
      // из сессии. Тело с несуществующим `terminalId`, но БЕЗ регистрации
      // сессии — тот же `unknown_terminal`, что и полное отсутствие тела:
      // тело давно не источник истины для этого поля.
      final operations = build();

      await expectLater(
        operations.askHandlers[TillOps.authLogin.name]!({
          'pin': '0000',
          'terminalId': 999,
          'userId': null,
        }, 100),
        throwsA(
          isA<WireRefusal>().having(
            (refusal) => refusal.code,
            'code',
            'unknown_terminal',
          ),
        ),
      );
    },
  );
}

class _StubBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _StubSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _StubTerminals implements TerminalRepository {
  // Терминал #1 — тот самый id, которым пользуются тесты ниже. Пустой список
  // означал бы, что вообще любая попытка входа отказывает как «терминала не
  // существует» ещё до того, как дело дойдёт до `LocalAuthRepository`.
  @override
  Future<List<domain.Terminal>> list() async => const [
    domain.Terminal(id: 1, name: 'Касса-1', pointMode: domain.PointMode.cashier),
  ];

  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield const [];
    await Completer<void>().future;
  }

  // Пункт 2 фазы 3/4 закрытия долга: `auth.login` теперь требует, чтобы эта
  // же сессия сама зарегистрировала терминал перед входом — тесты файла
  // зовут `terminals.register` напрямую тем же обработчиком. Отдаёт терминал
  // #1 всегда, тот же, что и статичный [list] ниже: `authLogin`
  // перепроверяет существование через `list()` — если бы `register` отдавал
  // id, которого там нет, любой такой тест отказывал бы `unknown_terminal`
  // независимо от того, что на самом деле проверяет.
  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async => (
    terminal: const domain.Terminal(
      id: 1,
      name: 'Касса-1',
      pointMode: domain.PointMode.cashier,
    ),
    secret: 'fake-secret-not-a-real-terminal-secret',
  );

  @override
  Future<domain.Terminal> resume({
    required int terminalId,
    required String secret,
  }) async => throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) async {}

  @override
  Future<void> delete(int terminalId) async {}

  @override
  Future<domain.Terminal> self() => throw UnimplementedError();

  @override
  Stream<domain.Terminal?> watchSelf() async* {
    yield null;
    await Completer<void>().future;
  }
}

class _StubBindings implements DeviceBindingRepository {
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
