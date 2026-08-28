/// Удаление терминала — задача 8 закрытия долга («замок кассы»).
///
/// До этой задачи `TerminalDao` не имел ни `delete`, ни `remove` — метода
/// удаления не было вовсе. Задача 7 (`terminal_register_test.dart`) завела
/// потолок в 200 заведённых терминалов и прямо назвала недостающий выход:
/// настоящий магазин, упёршийся в потолок, не имел штатного пути освободить
/// место.
///
/// Четыре вещи проверяются через настоящий провод (`FakeQuicServer` +
/// `TillWire` + `WireGuard`, собранный тем же `wireGuardForTill`, что и
/// настоящая касса), а не прямым вызовом обработчика — иначе тест доказал бы,
/// что обработчик умеет звать репозиторий, а не то, что сторож действительно
/// отказывает без права и различает `forbidden` от `unauthorized`:
///
/// 1. без права `settings.hardware` — отказ `forbidden`, обработчик не
///    вызывается, строка жива;
/// 2. с правом — терминал уходит из базы;
/// 3. терминал, которым касса пользуется сама (`isSelf`), не удаляется
///    даже с правом — `cannot_delete_self`, не `bad_request` и не молчание.
/// 4. терминал, под которым сидит сама вызывающая вкладка (обычный,
///    зарегистрированный, не `isSelf`) — тоже не удаляется, а терминал
///    любой другой вкладки той же вкладкой удаляется. Это задача 9
///    закрытия долга: запрет «не удаляй себя» до неё был истолкован как
///    «терминал самой кассы» за неимением `AuthSession.terminalId`
///    (см. историю на `TerminalRepository.delete`,
///    `lib/domain/terminal/terminal_repository.dart`) — здесь он проверен в
///    настоящем, тонком смысле.
///
/// Отдельно — данные: привязки устройств удалённого терминала проверяются
/// прямым запросом к таблице `TerminalDeviceBindings`, а не через
/// `deviceBindingsFor` (который заодно и есть код, который тестируется бы
/// дважды одним и тем же путём) — это доказывает, что строки **удалены**, а
/// не просто не возвращаются читающим методом.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import '../data/transport/fake_quic_server.dart';
import 'support/noop_auth.dart';

/// Два известных токена — с правом на оборудование и без него. Тот же приём,
/// что `_OneSession` в `test/data/transport/till_wire_guard_test.dart`, но на
/// два сеанса сразу: этому файлу нужны оба пути в одном наборе.
class _TwoSessions implements SessionLookup {
  const _TwoSessions(this._sessions);
  final Map<String, AuthSession> _sessions;

  @override
  AuthSession? sessionFor(String token) => _sessions[token];
}

// `terminalId` по умолчанию — заведомо не терминал ни одного теста этого
// файла (строки в `terminals` начинаются с id=1): существующие пять тестов
// не проверяют владение терминалом и не обязаны случайно задеть новую
// проверку «не удаляй терминал вкладки» только потому, что счётчик id
// совпал.
AuthSession _session({
  required bool withHardware,
  int terminalId = -1,
}) => AuthSession(
  token: withHardware ? 'with-hw' : 'without-hw',
  userId: 1,
  name: 'Айгуль',
  role: 'admin',
  permissions: withHardware
      ? const {PermissionKeys.settingsHardware}
      : const <String>{},
  operatingMode: 0,
  pointMode: 'cashier',
  shiftOpen: false,
  issuedAt: DateTime.utc(2026, 8, 21, 10),
  expiresAt: DateTime.utc(2026, 8, 21, 10, 30),
  terminalId: terminalId,
);

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

/// Устройства этого набора не касаются — `TerminalDeviceBindings` заполняется
/// в тесте про привязки прямой вставкой в таблицу, минуя этот контракт: тест
/// доказывает, что уходит **строка**, а не что репозиторий умеет её читать.
class _NoopBindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) =>
      const Stream.empty();

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}

void main() {
  late AppDatabase db;
  late FakeQuicServer server;
  late TillWire wire;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeQuicServer();
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await db.close();
  });

  TillWire buildWire({Map<String, AuthSession> extraSessions = const {}}) {
    final operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: _NoopBindings(),
      auth: NoopAuth(),
    );
    return TillWire(
      server,
      operations.askHandlers,
      guard: wireGuardForTill(
        db: db,
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: _TwoSessions({
          'with-hw': _session(withHardware: true),
          'without-hw': _session(withHardware: false),
          ...extraSessions,
        }),
      ),
    )..start();
  }

  Future<void> askAndSettle(String message) async {
    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(sessionId: 1, streamId: 4, message: message);
    server.emitStreamClosed(sessionId: 1, streamId: 4);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'без права settings.hardware — отказ forbidden, строка остаётся',
    () async {
      final repo = LocalTerminalRepository(db);
      final terminal = (await repo.register(name: 'Касса у окна')).terminal;
      wire = buildWire();

      await askAndSettle(
        '{"op":"${TillOps.terminalDelete.name}",'
        '"body":{"terminalId":${terminal.id}},"token":"without-hw"}',
      );

      final frame = WireFrame.decode(server.sentFrames.single);
      expect(frame, isA<ErrorFrame>());
      // `forbidden`, а не `unauthorized`: сеанс живой, просто не хватает
      // права — терминал не обязан гнать оператора на экран входа за то, что
      // он не решает новым сеансом той же учётки.
      expect((frame as ErrorFrame).code, 'forbidden');
      expect(
        await db.terminalDao.findById(terminal.id),
        isNotNull,
        reason: 'отказ по праву не имеет права тронуть строку',
      );
    },
  );

  test('с правом settings.hardware — удаляет', () async {
    final repo = LocalTerminalRepository(db);
    final terminal = (await repo.register(name: 'Касса у окна')).terminal;
    wire = buildWire();

    await askAndSettle(
      '{"op":"${TillOps.terminalDelete.name}",'
      '"body":{"terminalId":${terminal.id}},"token":"with-hw"}',
    );

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<OkFrame>());
    expect((frame as OkFrame).body, {'ok': true});
    expect(await db.terminalDao.findById(terminal.id), isNull);
  });

  test(
    'терминал, которым касса пользуется сама (isSelf), удалить нельзя',
    () async {
      final selfTerminal = await db.terminalDao.ensureSelf(
        fallbackName: 'Касса-1',
      );
      wire = buildWire();

      await askAndSettle(
        '{"op":"${TillOps.terminalDelete.name}",'
        '"body":{"terminalId":${selfTerminal.id}},"token":"with-hw"}',
      );

      final frame = WireFrame.decode(server.sentFrames.single);
      expect(frame, isA<ErrorFrame>());
      // Названный код, не `bad_request` общего вида: терминал обязан уметь
      // сказать оператору именно «это касса, а не завести обычный отказ».
      expect((frame as ErrorFrame).code, 'cannot_delete_self');
      expect(await db.terminalDao.findById(selfTerminal.id), isNotNull);
    },
  );

  test(
    'вкладка не удаляет терминал, под которым сидит сама, а чужой '
    '(с правом) — удаляет',
    () async {
      final repo = LocalTerminalRepository(db);
      // Ни один из двух — не isSelf: это обычные, зарегистрированные
      // терминалы, ровно то, что репозиторный `isSelf`-запрет не ловит
      // (доказано тестом выше).
      final own = (await repo.register(name: 'Терминал вкладки')).terminal;
      final other =
          (await repo.register(name: 'Терминал соседней вкладки')).terminal;

      // Сеанс несёт `terminalId: own.id` — это и есть «терминал, под
      // которым сидит вкладка», задача 9 закрытия долга.
      wire = buildWire(
        extraSessions: {
          'tab': _session(withHardware: true, terminalId: own.id),
        },
      );

      await askAndSettle(
        '{"op":"${TillOps.terminalDelete.name}",'
        '"body":{"terminalId":${own.id}},"token":"tab"}',
      );
      final ownFrame = WireFrame.decode(server.sentFrames[0]);
      expect(ownFrame, isA<ErrorFrame>());
      // Тот же код, что и у `isSelf`-отказа: это тот же самый запрет «не
      // удаляй себя», приведённый к настоящему смыслу, а не второй в
      // придачу к первому.
      expect((ownFrame as ErrorFrame).code, 'cannot_delete_self');
      expect(
        await db.terminalDao.findById(own.id),
        isNotNull,
        reason: 'вкладка не может отрезать себя',
      );

      await askAndSettle(
        '{"op":"${TillOps.terminalDelete.name}",'
        '"body":{"terminalId":${other.id}},"token":"tab"}',
      );
      final otherFrame = WireFrame.decode(server.sentFrames[1]);
      expect(otherFrame, isA<OkFrame>());
      expect(
        await db.terminalDao.findById(other.id),
        isNull,
        reason:
            'право settings.hardware разрешает удалить чужой терминал — '
            'запрет только про терминал самой вкладки',
      );
    },
  );

  test('несуществующий terminalId — отказ unknown_terminal', () async {
    wire = buildWire();

    await askAndSettle(
      '{"op":"${TillOps.terminalDelete.name}",'
      '"body":{"terminalId":999},"token":"with-hw"}',
    );

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, 'unknown_terminal');
  });

  test(
    'привязки устройств удалённого терминала уходят вместе с ним, не '
    'осиротевают',
    () async {
      final repo = LocalTerminalRepository(db);
      final terminal = (await repo.register(name: 'Касса у принтера')).terminal;
      await db
          .into(db.terminalDeviceBindings)
          .insert(
            TerminalDeviceBindingsCompanion.insert(
              terminalId: terminal.id,
              deviceClass: 'printer',
              profileId: 'some_profile',
              bindingKey: 'printer',
            ),
          );
      expect(await db.terminalDao.deviceBindingsFor(terminal.id), hasLength(1));

      wire = buildWire();
      await askAndSettle(
        '{"op":"${TillOps.terminalDelete.name}",'
        '"body":{"terminalId":${terminal.id}},"token":"with-hw"}',
      );

      final frame = WireFrame.decode(server.sentFrames.single);
      expect(frame, isA<OkFrame>());

      // Прямой запрос к таблице, а не `deviceBindingsFor`: доказывает, что
      // строки в `TerminalDeviceBindings` больше нет, а не только что
      // читающий метод перестал её отдавать.
      final orphaned = await (db.select(
        db.terminalDeviceBindings,
      )..where((b) => b.terminalId.equals(terminal.id))).get();
      expect(
        orphaned,
        isEmpty,
        reason:
            'привязки удалённого терминала не должны осиротеть на '
            'несуществующий terminalId',
      );
    },
  );
}
