/// Два ключа `op.*`, у которых не было читателя — задача 19 плана «Продажа с
/// браузерного терминала».
///
/// `op.refund` и `op.refundWithoutReceipt` объявлены в `PermissionKeys`,
/// показаны в форме прав и розданы ролям — и до этой задачи не читались ни
/// одной строкой `lib/` (`point_mode_permissions.dart` их **вычитает** у роли
/// по режиму точки, то есть сужает выдаваемое сеансу, а не проверяет
/// требуемое). Здесь они впервые проверяются, и проверяются **сквозным
/// путём**: настоящий `WireGuard` с настоящим словарём доступа, настоящий
/// `TillWire` над `FakeQuicServer`, настоящий `SessionRegistry`.
///
/// Проверяется не «сторож объявлен», а **что обработчик не был вызван**:
/// право, проверенное после работы, — это не право. Тот же приём, что у
/// пробы `sale.ping` без сеанса (`till_operations_test.dart`), и та же
/// причина.
library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/backend/till_wire_guard.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/data/transport/till_wire.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

import '../data/transport/fake_quic_server.dart';
import 'support/noop_auth.dart';
import 'support/recording_refund.dart';

class _NoopSetup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _NoopBootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

/// Тела пяти вопросов и одной подписки — в той форме, в какой их пишет
/// терминал: через `encode` самой операции, а не набранные здесь руками.
/// Иначе проба проверяла бы форму, которую сама и выдумала.
final _bodies = <String, Map<String, Object?>>{
  RefundOps.view.name: RefundOps.view.encode(null),
  RefundOps.loadReceipt.name: RefundOps.loadReceipt.encode(
    const ReceiptKey(receiptNo: 501, posId: 1, meta: _meta),
  ),
  RefundOps.startWithoutReceipt.name: RefundOps.startWithoutReceipt.encode(
    _meta,
  ),
  RefundOps.addProduct.name: RefundOps.addProduct.encode(
    RefundLineRequest(productId: 3, quantity: Decimal.one, meta: _meta),
  ),
  RefundOps.setLine.name: RefundOps.setLine.encode(
    RefundLineQuantity(lineId: '17', quantity: Decimal.zero, meta: _meta),
  ),
  RefundOps.complete.name: RefundOps.complete.encode(_meta),
  RefundOps.troubles.name: RefundOps.troubles.encode(9),
};

const _meta = CartCommandMeta(key: 'k1', baseVersion: 0, receiptNo: null);

void main() {
  late AppDatabase db;
  late FakeQuicServer server;
  late SessionRegistry sessions;
  late RecordingRefund refund;
  late PairingInvites invites;
  late TillOperations operations;
  late TillWire wire;
  var streamId = 4;

  /// Кассир с названными правами, вошедший на терминале, который **эта же
  /// QUIC-сессия** сама завела через `terminals.register` — ровно тот путь,
  /// которым в браузер входит настоящая вкладка (`login_controller.dart`).
  Future<String> loginWith(Set<String> permissions) async {
    final code = invites.mint().code;
    server.emitStreamOpened(sessionId: 1, streamId: ++streamId);
    server.emitStreamData(
      sessionId: 1,
      streamId: streamId,
      message: jsonEncode({
        'op': TillOps.terminalRegister.name,
        'body': {'name': 'Терминал вкладки', 'code': code},
      }),
    );
    await Future<void>.delayed(Duration.zero);
    final registered = WireFrame.decode(server.sentFrames.last);
    expect(
      registered,
      isA<OkFrame>(),
      reason: 'без заведённого терминала сессия не дошла бы и до входа',
    );
    final terminalId =
        ((registered as OkFrame).body['terminal']! as Map)['id']! as int;

    return sessions
        .mint(
          userId: 1,
          name: 'Айгуль',
          role: 'cashier',
          permissions: permissions,
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: true,
          terminalId: terminalId,
        )
        .token;
  }

  Future<WireFrame> call(
    String op, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    server.emitStreamOpened(sessionId: 1, streamId: ++streamId);
    server.emitStreamData(
      sessionId: 1,
      streamId: streamId,
      message: jsonEncode({
        'op': op,
        'body': body ?? _bodies[op]!,
        if (token != null) 'token': token,
      }),
    );
    server.emitStreamClosed(sessionId: 1, streamId: streamId);
    await Future<void>.delayed(Duration.zero);
    return WireFrame.decode(server.sentFrames.last);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakeQuicServer();
    sessions = SessionRegistry();
    refund = RecordingRefund();
    invites = PairingInvites();
    streamId = 4;

    operations = TillOperations(
      db: db,
      bootstrap: _NoopBootstrap(),
      setup: _NoopSetup(),
      terminals: LocalTerminalRepository(db),
      deviceBindings: LocalDeviceBindingRepository(
        db,
        BuiltinDeviceProfileCatalog(),
      ),
      auth: NoopAuth(),
      invites: invites,
      refund: refund,
    );

    wire = TillWire(
      server,
      operations.askHandlers,
      watchHandlers: operations.watchHandlers,
      guard: wireGuardForTill(
        db: db,
        // Настоящий словарь кассы, собранный из того же `TillOps.all`, из
        // которого его строит `ApiServer.access`, — а не «всё открыто».
        access: {for (final op in TillOps.all) op.name: op.access},
        sessions: sessions,
      ),
    )..start();
  });

  tearDown(() async {
    await wire.stop();
    await server.dispose();
    await db.close();
  });

  test('возврат без чека без своего права отвергается кассой', () async {
    // Проба брифа задачи 19. Кассир с `op.refund` — то есть возврат ему
    // открыт — но **без** `op.refundWithoutReceipt`.
    final token = await loginWith(const {PermissionKeys.opRefund});

    final frame = await call(RefundOps.startWithoutReceipt.name, token: token);

    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, WireDenied.forbidden);
    expect(
      frame.detail,
      contains(PermissionKeys.opRefundWithoutReceipt),
      reason: 'отказ обязан назвать недостающее право, а не «нельзя»',
    );
    expect(
      refund.calls,
      isEmpty,
      reason:
          'право проверяется ДО обработчика — реализация, тронутая до отказа, '
          'доказывала бы обратное тому, что заявлено',
    );
  });

  test('возврат без чека со своим правом доходит до кассы', () async {
    // Обратная половина: без неё первая проба доказывала бы, что операция
    // отказывает всем, а не что право проверяется.
    final token = await loginWith(const {
      PermissionKeys.opRefund,
      PermissionKeys.opRefundWithoutReceipt,
    });

    final frame = await call(RefundOps.startWithoutReceipt.name, token: token);

    expect(frame, isA<OkFrame>());
    expect(refund.calls, ['startWithoutReceipt']);
  });

  test(
    'своего права мало для остальных — они требуют op.refund',
    () async {
      // Право на возврат без чека не открывает возврат вообще: кассир,
      // которому доверили только его, не получает ни чужого чека, ни
      // завершения. Иначе `op.refund` перестал бы что-либо значить у того,
      // у кого есть второй ключ.
      final token = await loginWith(const {
        PermissionKeys.opRefundWithoutReceipt,
      });

      for (final name in const [
        'refund.view',
        'refund.loadReceipt',
        'refund.addProduct',
        'refund.setLine',
        'refund.complete',
        'refund.troubles',
      ]) {
        final frame = await call(name, token: token);

        expect(frame, isA<ErrorFrame>(), reason: name);
        expect((frame as ErrorFrame).code, WireDenied.forbidden, reason: name);
        expect(frame.detail, contains(PermissionKeys.opRefund), reason: name);
      }

      expect(refund.calls, isEmpty);
    },
  );

  test('подписка на черновик без права не заводится вовсе', () async {
    // Отказ подписке приходит на **открытии потока**, а не пустым потоком:
    // экран без права обязан не увидеть чужой черновик ни в каком виде.
    final token = await loginWith(const {
      PermissionKeys.opRefundWithoutReceipt,
    });

    final frame = await call(RefundOps.view.name, token: token);

    expect(frame, isA<ErrorFrame>());
    expect((frame as ErrorFrame).code, WireDenied.forbidden);
    expect(wire.liveSubscriptions, 0);
    expect(refund.calls, isEmpty);
  });

  test('подписка на черновик с правом заводится и отдаёт снимок', () async {
    final token = await loginWith(const {PermissionKeys.opRefund});

    final frame = await call(RefundOps.view.name, token: token);

    expect(frame, isA<UpdateFrame>());
    expect(refund.calls, ['watch']);
    expect(wire.liveSubscriptions, 1);
  });

  test('без сеанса вовсе — unauthorized у всех операций возврата', () async {
    // Отдельный код от `forbidden`, и это не мелочь: только `unauthorized`
    // ведёт браузер на экран входа (`WtDispatcher`), а вошедшему без права
    // повторный вход не даёт ничего.
    for (final op in RefundOps.all) {
      final frame = await call(op.name);

      expect(frame, isA<ErrorFrame>(), reason: op.name);
      expect(
        (frame as ErrorFrame).code,
        WireDenied.unauthorized,
        reason: op.name,
      );
    }

    expect(refund.calls, isEmpty);
  });
}
