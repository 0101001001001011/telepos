/// Обработчики возврата на кассе — задача 19 плана «Продажа с браузерного
/// терминала».
///
/// Проверяется три вещи, которых нет ни в каталоге, ни в контракте:
///
/// 1. **имя рабочего места берётся из сеанса**, а кадр, в котором оно
///    названо, отвергается названным отказом (требование безопасности,
///    докстринг `RefundService`, правило 1);
/// 2. **тела разбираются и собираются парами кодеков** — то есть довод,
///    доехавший до контракта, тот же самый, что положил терминал, и снимок,
///    вернувшийся терминалу, тот же самый, что отдала касса;
/// 3. **отказ реализации доезжает своим кодом**, а не общим
///    `handler_failed`, — иначе терминал отличал бы «чек уже вернули» от
///    «касса не настроена» по подстроке в тексте.
///
/// Обработчики зовутся **прямо из карт**, без транспорта: сторож проверен
/// сквозным путём в `refund_permissions_test.dart`, и заводить второй такой
/// же путь здесь значило бы мерить одно дважды, а не мерить второе.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble, CompletionTroubleKind;
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/wire/refund_codec.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

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

const _meta = CartCommandMeta(key: 'k7', baseVersion: 3, receiptNo: 12);

void main() {
  late AppDatabase db;
  late RecordingRefund refund;
  late PairingInvites invites;

  TillOperations build({RefundService? service}) => TillOperations(
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
    refund: service,
  );

  /// Заводит сессии 1 её терминал ровно тем путём, которым это делает
  /// вкладка браузера, — `terminals.register` с одноразовым кодом привязки.
  /// Обработчику возврата взять имя места больше неоткуда: он читает
  /// `_sessionTerminals`, а её пишет только регистрация.
  Future<int> registerTerminal(TillOperations operations, int sessionId) async {
    final body = await operations.askHandlers[TillOps.terminalRegister.name]!({
      'name': 'Терминал вкладки $sessionId',
      'code': invites.mint().code,
    }, sessionId);
    return (body['terminal']! as Map)['id']! as int;
  }

  /// Касса, у которой сессия 1 уже завела себе терминал. Возвращает пару
  /// «операции, имя заведённого места».
  Future<(TillOperations, int)> tillWithSession() async {
    final operations = build(service: refund);
    return (operations, await registerTerminal(operations, 1));
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    refund = RecordingRefund();
    invites = PairingInvites();
  });
  tearDown(() => db.close());

  test('каждая операция возврата имеет обработчик', () {
    // Та же сверка, что и общая в `till_operations_test.dart`, но названная
    // поимённо: операция каталога без обработчика отвечает `unknown_op`, и
    // заметить это можно было бы только открыв терминал.
    final operations = build(service: refund);
    final declared = {
      ...operations.askHandlers.keys,
      ...operations.watchHandlers.keys,
    };

    for (final op in RefundOps.all) {
      expect(declared, contains(op.name), reason: op.name);
    }
    expect(operations.watchHandlers, contains(RefundOps.view.name));
  });

  group('имя рабочего места — из сеанса, а не из тела', () {
    test(
      'обработчик берёт терминал, заведённый этой же QUIC-сессией',
      () async {
        final (operations, terminalId) = await tillWithSession();

        await operations.askHandlers[RefundOps.startWithoutReceipt.name]!(
          refundCommandMetaToWireJson(_meta),
          1,
        );

        expect(refund.lastTerminalId, terminalId);
      },
    );

    test(
      'кадр, назвавший терминал, отвергается — и реализация не тронута',
      () async {
        // Измеренное решение, а не осторожность: холодный вызов с чужим именем
        // отдавал бы чужой черновик, потому что черновик возврата лежит на
        // кассе под ключом `terminalId`. Молча игнорировать поле нельзя — это
        // прятало бы и ошибку клиента, и попытку.
        final (operations, terminalId) = await tillWithSession();
        final body = {
          ...refundCommandMetaToWireJson(_meta),
          'terminalId': terminalId + 100,
        };

        await expectLater(
          () => operations.askHandlers[RefundOps.startWithoutReceipt.name]!(
            body,
            1,
          ),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'terminal_in_body',
            ),
          ),
        );
        expect(refund.calls, isEmpty);
      },
    );

    test('своё же имя в теле тоже отвергается, а не пропускается', () async {
      // Иначе проверка означала бы «нельзя назвать ЧУЖОЙ терминал», то есть
      // сверку, которой здесь нет вовсе: тело сверять не с чем, его целиком
      // пишет вызывающий.
      final (operations, terminalId) = await tillWithSession();

      await expectLater(
        () => operations.askHandlers[RefundOps.startWithoutReceipt.name]!({
          ...refundCommandMetaToWireJson(_meta),
          'terminalId': terminalId,
        }, 1),
        throwsA(isA<WireRefusal>()),
      );
      expect(refund.calls, isEmpty);
    });

    test('сессия без заведённого терминала — unknown_terminal', () async {
      // Тот же код, что у `auth.login` в том же положении: сессия, ничего не
      // зарегистрировавшая, не имеет рабочего места, от имени которого
      // возвращать деньги.
      final operations = build(service: refund);

      await expectLater(
        () => operations.askHandlers[RefundOps.complete.name]!(
          refundCommandMetaToWireJson(_meta),
          99,
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'unknown_terminal'),
        ),
      );
      expect(refund.calls, isEmpty);
    });

    test('подписка на черновик — тем же правилом', () async {
      // Первая подписка провода, которой нельзя брать имя места из тела, —
      // ради неё `WireWatchHandler` и получил второй довод. Отказ обязан
      // прийти **до** подписки: поток без событий выглядел бы как пустой
      // черновик.
      final (operations, terminalId) = await tillWithSession();
      final watch = operations.watchHandlers[RefundOps.view.name]!;

      final snapshot = await watch(const {}, 1).first;
      expect(refund.lastTerminalId, terminalId);
      expect(refundViewFromWireJson(snapshot), refund.view);

      expect(
        () => watch({'terminalId': terminalId}, 1),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'terminal_in_body'),
        ),
      );
      expect(
        () => watch(const {}, 77),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'unknown_terminal'),
        ),
      );
    });
  });

  group('тела разбираются и собираются парами', () {
    test('запрос чека доезжает до контракта целиком', () async {
      final (operations, _) = await tillWithSession();
      const request = ReceiptKey(receiptNo: 501, posId: 7, meta: _meta);

      await operations.askHandlers[RefundOps.loadReceipt.name]!(
        receiptKeyToWireJson(request),
        1,
      );

      expect(refund.calls, ['loadReceipt']);
      expect(refund.lastArguments, {'receiptNo': 501, 'posId': 7});
      expect(
        refund.lastMeta,
        _meta,
        reason:
            'номер черновика из метки не должен быть подменён номером чека '
            'продажи — они едут под разными именами именно поэтому',
      );
    });

    test(
      'количество товара доезжает Decimal-ом, а не потерянным double',
      () async {
        final (operations, _) = await tillWithSession();

        await operations.askHandlers[RefundOps.addProduct.name]!(
          refundLineRequestToWireJson(
            RefundLineRequest(
              productId: 3,
              quantity: Decimal.parse('2.125'),
              meta: _meta,
            ),
          ),
          1,
        );

        expect(refund.lastArguments['productId'], 3);
        expect(refund.lastArguments['quantity'], Decimal.parse('2.125'));
      },
    );

    test('ноль в количестве строки доезжает нулём, а не пропуском', () async {
      // Ноль здесь — «сними выделение с этой строки», единственный способ
      // передать кассе итог выделения. Прочитай его касса как «поля нет» —
      // и вернула бы весь чек независимо от того, что выбрал кассир.
      final (operations, _) = await tillWithSession();

      await operations.askHandlers[RefundOps.setLine.name]!(
        refundLineQuantityToWireJson(
          RefundLineQuantity(lineId: '17', quantity: Decimal.zero, meta: _meta),
        ),
        1,
      );

      expect(refund.calls, ['setLineQuantity']);
      expect(refund.lastArguments, {'lineId': '17', 'quantity': Decimal.zero});
    });

    test('снимок возвращается терминалу тем же, что отдала касса', () async {
      final (operations, _) = await tillWithSession();
      refund.view = RefundView(
        posId: 1,
        terminalId: 7,
        version: 4,
        draftNo: 12,
        saleReceiptNo: 501,
        salePosId: 1,
        lines: [
          RefundLine(
            id: '17',
            productId: 3,
            name: 'Молоко 3.2%',
            quantity: Decimal.parse('2.5'),
            price: Decimal.parse('97.125'),
            maxQuantity: Decimal.parse('4'),
            barcode: '4870001234567',
          ),
        ],
      );

      final body = await operations.askHandlers[RefundOps.loadReceipt.name]!(
        receiptKeyToWireJson(
          const ReceiptKey(receiptNo: 501, posId: 1, meta: _meta),
        ),
        1,
      );

      // Через `decode` самой операции — тем путём, которым читает терминал,
      // а не разбором тела руками.
      expect(RefundOps.loadReceipt.decode(body), refund.view);
    });

    test(
      'беды ящика спрашиваются местом из сеанса и доезжают целиком',
      () async {
        // Приёмка 2026-09-17: возврат с наличной частью ящика не открывал. Беда
        // ящика теперь отдаётся тому месту, которое возвращало, — значит имя
        // места обязано прийти из сеанса, а номер возврата — из тела, и беда
        // обязана вернуться терминалу тем же видом, каким её назвала касса.
        final (operations, terminalId) = await tillWithSession();
        refund.troubles = const [
          CompletionTrouble(
            kind: CompletionTroubleKind.drawer,
            receiptNo: 9,
            message: 'денежный ящик не открылся',
          ),
        ];

        final body = await operations.askHandlers[RefundOps.troubles.name]!(
          RefundOps.troubles.encode(9),
          1,
        );

        expect(refund.calls, ['hardwareTroubles']);
        expect(refund.lastTerminalId, terminalId);
        expect(refund.lastArguments, {'refundLocalId': 9});
        expect(RefundOps.troubles.decode(body), refund.troubles);
      },
    );

    test('исход завершения возвращается терминалу целиком', () async {
      final (operations, _) = await tillWithSession();

      final body = await operations.askHandlers[RefundOps.complete.name]!(
        refundCommandMetaToWireJson(_meta),
        1,
      );

      expect(RefundOps.complete.decode(body), refund.outcome);
      expect(refund.lastMeta, _meta);
    });
  });

  group('отказ приходит значением, с названным кодом', () {
    test('отказ реализации доезжает своим кодом, не handler_failed', () async {
      final (operations, _) = await tillWithSession();
      refund.refuseWith = const WireRefusal(
        refundAlreadyRefundedCode,
        'по этому чеку возврат уже сделан',
      );

      await expectLater(
        () => operations.askHandlers[RefundOps.loadReceipt.name]!(
          receiptKeyToWireJson(
            const ReceiptKey(receiptNo: 501, posId: 1, meta: _meta),
          ),
          1,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            refundAlreadyRefundedCode,
          ),
        ),
      );
    });

    test('касса без собранного возврата отказывает названной причиной, а не '
        'отвечает пустым черновиком', () async {
      // `null` — голый процесс Dart (`bin/telepos_backend.dart`), у
      // которого нет контейнера зависимостей. Пустой снимок был бы
      // законным ответом «черновика нет», то есть рабочим состоянием, и
      // терминал показал бы его кассиру как готовность возвращать.
      final operations = build();
      await registerTerminal(operations, 1);

      await expectLater(
        () => operations.askHandlers[RefundOps.complete.name]!(
          refundCommandMetaToWireJson(_meta),
          1,
        ),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'no_refund_service'),
        ),
      );
      expect(
        () => operations.watchHandlers[RefundOps.view.name]!(const {}, 1),
        throwsA(isA<WireRefusal>()),
      );
    });
  });
}
