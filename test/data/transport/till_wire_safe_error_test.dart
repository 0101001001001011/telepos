/// Утечка через провод: хэш PIN не обязан доехать до терминала (задача 2).
///
/// `SqliteException.toString()` печатает `parametersToStatement` как есть для
/// любого текстового параметра — маскирует только `Uint8List`
/// (`package:sqlite3`, `lib/src/exception.dart`). `Users.password_enc` —
/// текстовый столбец, и `UPDATE users SET password_enc = ?` — ровно та
/// статья, которую `AuthService._upgradeStoredPin` шлёт после успешного
/// входа. До этой задачи `till_wire.dart` подставлял пойманное исключение в
/// `ErrorFrame` через `'$error'`, то есть через `toString()`, — и хэш уезжал
/// в кадр отказа, который видит браузер.
///
/// Стенд собран по образцу `test/backend/till_operations_auth_test.dart`:
/// настоящая `AppDatabase` в памяти, настоящий `TillOperations`, и
/// `SetupRepository`, чей `completeSetup` бросает `SqliteException` с таким
/// же по форме параметром. Подделка здесь была бы нечестной: она доказала
/// бы, что стенд умеет собрать `ErrorFrame`, а не то, что настоящий путь
/// исключения — от обработчика через `TillWire._answer` до кадра на проводе —
/// действительно очищен.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';

import '../../fixtures/pin_hash_fixture.dart';
import 'fake_quic_server.dart';
import 'open_guard.dart';
import 'till_operations_stubs.dart';

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

  Future<void> askAndSettle(String message) async {
    server.emitStreamOpened(sessionId: 1, streamId: 4);
    server.emitStreamData(sessionId: 1, streamId: 4, message: message);
    server.emitStreamClosed(sessionId: 1, streamId: 4);
    await Future<void>.delayed(Duration.zero);
  }

  test('setup.complete: SqliteException с хэшем PIN в параметрах — хэш не '
      'доезжает до кадра отказа', () async {
    final operations = TillOperations(
      db: db,
      bootstrap: NoopBootstrap(),
      setup: _LeakingSetup(),
      terminals: EmptyTerminalRepository(),
      deviceBindings: NoopDeviceBindingRepository(),
      auth: _StubAuth(),
    );

    wire = TillWire(server, operations.askHandlers, guard: openGuard)..start();

    await askAndSettle('{"op":"${TillOps.setupComplete.name}","body":{}}');

    final frame = WireFrame.decode(server.sentFrames.single);
    expect(frame, isA<ErrorFrame>());
    final detail = (frame as ErrorFrame).detail;

    expect(
      detail,
      isNot(contains(testPbkdf2PinHash)),
      reason: 'хэш PIN не должен покидать кассу ни в каком виде',
    );
    // Осмысленная часть — `message` — по-прежнему видна: это не «текст
    // пропал вовсе», а «текст без параметров».
    expect(detail, contains('UNIQUE constraint failed: users.password_enc'));
  });
}

class _LeakingSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {
    throw SqliteException(
      2067, // SQLITE_CONSTRAINT_UNIQUE
      'UNIQUE constraint failed: users.password_enc',
      'columns password_enc are not unique',
      'UPDATE users SET password_enc = ? WHERE id = ?',
      [testPbkdf2PinHash, 1],
      'executing a prepared statement',
    );
  }
}

/// Не звана этим тестом ни разу — `setup.complete` не проходит через вход.
class _StubAuth implements AuthRepository {
  @override
  Stream<List<AuthUser>> watchUsers() => throw UnimplementedError();

  @override
  Future<AuthOutcome> login(AuthAttempt attempt) => throw UnimplementedError();

  @override
  Future<void> logout(String token) => throw UnimplementedError();

  @override
  Stream<AuthSession?> watchSession(String token) => throw UnimplementedError();
}
