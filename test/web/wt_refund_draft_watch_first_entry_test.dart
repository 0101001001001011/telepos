/// Первый заход на возврат поднимает **одну** подписку на черновик, а не две.
///
/// # Находка живой приёмки 2026-09-17
///
/// Браузерный терминал, первый заход на «Возврат» после входа: в консоли
/// `Refund: draft watch error: WireRefusal(stream_ended: подписка оборвалась
/// — состояние больше не приходит)`, на экране «Связь с кассой потеряна» при
/// живом проводе; через 2 с переподписка проходит, на повторных заходах
/// отказа нет. То же 2026-09-07 после F5 — тоже первый подъём провайдера.
///
/// # Причина — измерена, а не прочитана
///
/// Цепочка из двух звеньев:
///
/// 1. **Повод, здесь.** `RefundNotifier.build()` звал `_listenToDraft`
///    микрозадачей, экран — через `ensureWatching` из `initState`. Оба ждали
///    имя места, и проверка «подписка уже есть» в `ensureWatching` в этом окне
///    видела `null`. Вторая подписка отменяла первую, чей поток провода уже
///    открывался: на каждый первый заход касса получала поток, брошенный в
///    момент рождения, и отвечала в него отказом — запись получала `peerGone`.
///    Эта проба мерит повод: открытий потока на первом заходе ровно одно.
///    До починки их **два** (второе — брошенное).
/// 2. **Причина, в `rk_quic` до 0.2.2.** `QuicServer` раздавал ответы
///    командного изолята по порядку прихода, а не по вызову: две записи в
///    полёте получали **обе** первый ответ. `peerGone` брошенного потока
///    доставался первой записи снимка в живую подписку, и
///    `TillSubscriptions.deliver` честно закрывал живой поток — терминал видел
///    `stream_ended`. Проба причины — `packages/rk_quic/test/
///    concurrent_commands_test.dart`, на настоящей нативной библиотеке:
///    здесь, на петле, ответы транспорта верны по построению, и воспроизвести
///    подмену петля не может.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/auth/local_auth_repository.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_refund_service.dart';

import '../backend/support/recording_refund.dart';
import '../presentation/auth/support/fakes.dart';
import 'support/fake_dispatcher.dart';
import 'support/loopback.dart';

void main() {
  late AppDatabase db;
  late Loopback loop;
  late TillWire wire;
  late List<String> warnings;
  late _Slow streams;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    loop = Loopback();
    warnings = [];
    app_log.installLogger(
      Talker(
        observer: _Collect(warnings),
        settings: TalkerSettings(useConsoleLogs: false),
      ),
    );
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса-1'),
          ),
        );
  });

  tearDown(() async {
    await wire.stop();
    await loop.dispose();
    await db.close();
    await GetIt.instance.reset();
  });

  Future<WtDispatcher> boot() async {
    final sessions = SessionRegistry();
    final invites = PairingInvites();
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
      refund: RecordingRefund(),
    );
    final session = sessions.mint(
      userId: 4,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {PermissionKeys.opRefund},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
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
    streams = _Slow(loop);
    final browser = WtDispatcher(streams, tokens: FakeTokens(session.token));
    await browser.ask<TerminalRegisterRequest, TerminalEnrollment>(
      TillOps.terminalRegister,
      (name: 'Вкладка', code: invites.mint().code),
    );
    return browser;
  }

  test('первый заход поднимает один поток провода, и он живой', () async {
    final browser = await boot();
    GetIt.instance
      ..registerSingleton<RefundService>(WtRefundService(browser))
      ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity());
    final opensBefore = streams.opened;

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Порядок экрана: `ref.watch` в build строит провайдер (микрозадача
    // `_listenToDraft`), затем `addPostFrameCallback` зовёт `ensureWatching`
    // — синхронно, раньше микрозадачи.
    final sub = container.listen(refundControllerProvider, (_, _) {});
    addTearDown(sub.close);
    unawaited(
      container.read(refundControllerProvider.notifier).ensureWatching(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));
    await settleLoopback();

    expect(
      streams.opened - opensBefore,
      1,
      reason:
          'КРАСНОЕ БЕЗ ПРАВКИ: build() и ensureWatching поднимали по подписке, '
          'вторая бросала поток первой в момент рождения — касса отвечала в '
          'брошенный поток, и этот peerGone rk_quic до 0.2.2 отдавал живой '
          'подписке рядом',
    );
    expect(wire.liveSubscriptions, 1);
    expect(container.read(refundControllerProvider).connectionLost, isFalse);
    expect(warnings, isEmpty);
  });
}

/// Опора, которая открывает поток не мгновенно, как вкладка
/// (`createBidirectionalStream` — обещание JS), и считает открытия.
///
/// Без паузы петля открывает поток раньше, чем вторая подписка успевает
/// отменить первую, и брошенный поток не заводится вовсе.
class _Slow implements WtStreams {
  _Slow(this._inner);
  final Loopback _inner;
  int opened = 0;
  @override
  Future<WtStream> openStream() async {
    opened++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return _inner.openStream();
  }

  @override
  Future<void> get closed => _inner.closed;
  @override
  Future<void> close() => _inner.close();
}

class _Collect extends TalkerObserver {
  _Collect(this.into);
  final List<String> into;
  @override
  void onLog(TalkerData log) => into.add('${log.message}');
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
