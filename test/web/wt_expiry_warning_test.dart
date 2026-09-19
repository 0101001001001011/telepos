/// Предупреждение о просроченной партии с браузерного терминала — пункт 11
/// ревизии 2026-09-19.
///
/// # Почему пробы ходят по проводу
///
/// Тем же доводом, что `sale_permissions_test.dart`: «договор объявлен» и
/// «кассир за планшетом получит ответ» — разные утверждения, и между ними в
/// этом проекте уже пропадало целое требование. Здесь кадр проходит
/// настоящий `wireGuardForTill`, собранный тем же выражением
/// `{for (final op in TillOps.all) op.name: op.access}`, каким его собирает
/// `ApiServer`, а отвечает настоящая `LocalExpiryWarning` поверх настоящих
/// `BatchTrackingUseCaseImpl` и `WmsConfigUseCaseImpl` над настоящей базой в
/// памяти. Ни один обработчик здесь не зовётся напрямую.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что кассир увидит снекбар: за это отвечает `SaleNotifier._warnIfExpired`
/// и пробы экрана продажи. И что товар спишется именно этой партией —
/// `suggestBatchForPicking` ничего не резервирует.
library;

import 'package:decimal/decimal.dart';
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
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/repositories/batch_repository_impl.dart';
import 'package:telepos/data/repositories/wms_config_repository_impl.dart';
import 'package:telepos/data/sale/local_expiry_warning.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/data/usecases/wms/batch_tracking_use_case_impl.dart';
import 'package:telepos/data/usecases/wms/wms_config_use_case_impl.dart';
import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_expiry_warning.dart';

import '../data/transport/till_operations_stubs.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';

/// Час проб. Закреплён, а не `DateTime.now()`: «просрочено» — утверждение
/// про сейчас, и проба, закрепившая только даты партий, через год мерила бы
/// календарь, а не код.
final _now = DateTime.utc(2026, 9, 19, 12);

int _secondsOf(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

/// Товар с партиями. `ucode` — то же, что `productId` в чеке.
const _fresh = 10;
const _rotten = 20;
const _noBatches = 30;

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late SessionRegistry sessions;
  late PairingInvites invites;
  late LocalExpiryWarning localWarning;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> seedBatch({
    required int ucode,
    required String number,
    required DateTime expiry,
    String quantity = '5',
    bool active = true,
    bool quarantined = false,
  }) async {
    await db
        .into(db.batches)
        .insert(
          BatchesCompanion.insert(
            ucode: ucode,
            batchNumber: number,
            expiryDate: Value(_secondsOf(expiry)),
            initialQuantity: d(quantity),
            currentQuantity: d(quantity),
            reservedQuantity: Value(Decimal.zero),
            isActive: Value(active),
            isQuarantined: Value(quarantined),
          ),
        );
  }

  Future<WtDispatcher> browser(Set<String> permissions) async {
    final session = sessions.mint(
      userId: 4,
      name: 'Айгуль',
      role: 'cashier',
      permissions: permissions,
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 1,
    );
    final dispatcher = WtDispatcher(loop, tokens: FakeTokens(session.token));
    await dispatcher.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    return dispatcher;
  }

  Future<TillWire> start({ExpiryWarningReader? expiryWarning}) async {
    final operations = TillOperations(
      db: db,
      bootstrap: NoopBootstrap(),
      setup: NoopSetupRepository(),
      terminals: LocalTerminalRepository(db),
      invites: invites,
      deviceBindings: NoopDeviceBindingRepository(),
      auth: LocalAuthRepository(
        db: db,
        sessions: sessions,
        throttle: LoginThrottle(),
      ),
      expiryWarning: expiryWarning,
    );
    return TillWire(
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
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-петля'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));

    // Годный товар и просроченный. Третий — вовсе без партий: у розницы
    // партионный учёт включён далеко не на всём, и «партий нет» обязано
    // читаться как «предупреждать не о чем», а не как просрочка.
    await seedBatch(
      ucode: _fresh,
      number: 'F-1',
      expiry: _now.add(const Duration(days: 30)),
    );
    await seedBatch(
      ucode: _rotten,
      number: 'R-1',
      expiry: _now.subtract(const Duration(days: 1)),
    );

    sessions = SessionRegistry();
    invites = PairingInvites();
    localWarning = LocalExpiryWarning(
      batches: BatchTrackingUseCaseImpl(BatchRepositoryImpl(db)),
      wmsConfig: WmsConfigUseCaseImpl(WmsConfigRepositoryImpl(db)),
      now: () => _now,
    );
    wire = await start(expiryWarning: localWarning);
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
  });

  test('просроченная партия называется и в браузере', () async {
    final reader = WtExpiryWarning(await browser({PermissionKeys.navSale}));

    expect(await reader.isPickedBatchExpired(_rotten), isTrue);
    // Управляющая проба, без которой «починка», отвечающая `true` всегда,
    // прошла бы первую.
    expect(await reader.isPickedBatchExpired(_fresh), isFalse);
    expect(
      await reader.isPickedBatchExpired(_noBatches),
      isFalse,
      reason: 'товар без партий — не просрочка, предупреждать не о чем',
    );
  });

  test('ответ терминала — тот же, что у кассы', () async {
    // Две реализации одного договора сверяются напрямую: расхождение между
    // «что показывает планшет» и «что знает касса» — это и есть дефект,
    // который пункт 11 закрывает.
    final reader = WtExpiryWarning(await browser({PermissionKeys.navSale}));

    for (final ucode in [_fresh, _rotten, _noBatches]) {
      expect(
        await reader.isPickedBatchExpired(ucode),
        await localWarning.isPickedBatchExpired(ucode),
        reason: 'товар $ucode',
      );
    }
  });

  test('карантин и снятая партия из ответа выпадают', () async {
    // Просроченная партия, которую отбор не отдаст: она в карантине.
    // Предупреждать о ней значило бы пугать кассира товаром, который
    // продаётся из другой партии.
    await seedBatch(
      ucode: _fresh,
      number: 'F-Q',
      expiry: _now.subtract(const Duration(days: 10)),
      quarantined: true,
    );
    await seedBatch(
      ucode: _fresh,
      number: 'F-OFF',
      expiry: _now.subtract(const Duration(days: 20)),
      active: false,
    );
    final reader = WtExpiryWarning(await browser({PermissionKeys.navSale}));

    expect(await reader.isPickedBatchExpired(_fresh), isFalse);
  });

  test('пустая партия не отбирается — отбор берёт следующую', () async {
    // Просроченная партия с нулевым остатком: отдать её нечем, и отбор
    // уходит на годную. Нулевой остаток — та самая граница, на которой
    // «сортируем по сроку» и «сортируем среди доступных» расходятся.
    await seedBatch(
      ucode: _fresh,
      number: 'F-EMPTY',
      expiry: _now.subtract(const Duration(days: 5)),
      quantity: '0',
    );
    final reader = WtExpiryWarning(await browser({PermissionKeys.navSale}));

    expect(await reader.isPickedBatchExpired(_fresh), isFalse);
  });

  test('без nav.sale — forbidden, а не «не просрочено»', () async {
    // Молчаливое `false` было бы худшим из возможных ответов: кассир без
    // права продажи не увидел бы разницы между «годен» и «спросить не
    // дали».
    final reader = WtExpiryWarning(await browser(const {}));

    await expectLater(
      reader.isPickedBatchExpired(_rotten),
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', 'forbidden')),
    );
  });

  test('касса без склада отказывает названной причиной, а не «годен»', () async {
    // Голый процесс без продажи. Выдуманное «не просрочено» учило бы
    // кассира верить отсутствию снекбара.
    await wire.stop();
    wire = await start();
    final reader = WtExpiryWarning(await browser({PermissionKeys.navSale}));

    await expectLater(
      reader.isPickedBatchExpired(_rotten),
      throwsA(
        isA<WireRefusal>().having((r) => r.code, 'code', 'no_sale_module'),
      ),
    );
  });
}
