@Tags(['manual'])
library;

/// Живая проверка оплаты по QR против **отдельного процесса эмулятора**.
///
/// Не проба набора: эмулятор здесь не поднимается внутри теста, а уже
/// работает отдельным процессом, и касса знает его **только адресом из
/// своей базы** (`qr_provider_configs`). Покупатель платит пультом
/// эмулятора по HTTP — снаружи, как настоящий телефон, — а не вызовом
/// метода в той же памяти.
///
/// ```
/// dart run test/emulators/sbp/emulator.dart --port 18890 --control 18900
/// flutter test --tags manual --run-skipped test/manual/qr_live_check.dart
/// curl http://127.0.0.1:18900/_emul/journal
/// curl -X POST http://127.0.0.1:18900/_emul/stop
/// ```
///
/// Адреса переопределяются `QR_LIVE_BASE` и `QR_LIVE_CONTROL`.
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/data/sale/local_payment_service.dart';
import 'package:telepos/data/sale/local_sale_checkout_service.dart';
import 'package:telepos/data/usecases/product/find_by_barcode_use_case_impl.dart';
import 'package:telepos/data/usecases/product/search_product_info_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/deferred_sale_service_impl.dart';
import 'package:telepos/data/usecases/sale/sale_initiation_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_round_option_use_case_impl.dart';
import 'package:telepos/data/usecases/sale/sale_use_case_impl.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import '../helpers/cash_drawer.dart';

const _barcode = '4870001234567';
const _terminal = 7;

void main() {
  final base = Platform.environment['QR_LIVE_BASE'] ?? 'http://127.0.0.1:18890';
  final control =
      Platform.environment['QR_LIVE_CONTROL'] ?? 'http://127.0.0.1:18900';

  Future<Object?> pult(String path, [Map<String, Object?>? body]) async {
    final client = HttpClient();
    try {
      final request = body == null
          ? await client.getUrl(Uri.parse('$control$path'))
          : await client.postUrl(Uri.parse('$control$path'));
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      return jsonDecode(await utf8.decoder.bind(response).join());
    } finally {
      client.close(force: true);
    }
  }

  test('касса ↔ эмулятор отдельным процессом: оплата, отмена, оплата до '
      'отмены', () async {
    await pult('/_emul/reset', const {});
    Decimal d(String v) => Decimal.parse(v);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final logger = Talker();

    await db
        .into(db.thisPosEntries)
        .insert(const ThisPosEntriesCompanion(id: Value(1), accountId: Value(11)));
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: Value(4),
            openTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            name: 'Товар',
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await db
        .into(db.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            ucode: const Value(100),
            barcode: int.parse(_barcode),
            sellingPrice: Value(d('500')),
          ),
        );
    for (final (id, type) in [(11, AccountType.pos), (12, AccountType.customBank)]) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: Value(id),
              type: type,
              name: Value('Счёт $id'),
              value: Value(Decimal.zero),
              visibleToPos: const Value(true),
            ),
          );
    }
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(SystemPaymentKindIds.qr).copyWith(isActive: true),
    );
    // Весь способ подстановки — адрес в базе кассы.
    await db.qrProviderConfigDao.save(
      QrProviderSettings(baseUrl: base, code: 'sbp_live', apiKey: 'live-key'),
      at: DateTime.now(),
    );

    final cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    final payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: const RefusingFiscalService(),
      qr: QrPaymentDesk(db: db, logger: logger),
      drawer: drawerOpens,
    );

    CartCommandMeta mv(CartView v, String k) =>
        CartCommandMeta(key: k, baseVersion: v.version, receiptNo: v.receiptNo);
    var view = await cart.start(
      terminalId: _terminal,
      wholesale: false,
      meta: const CartCommandMeta(key: 'c1', baseVersion: 0, receiptNo: null),
    );
    view = await cart.addByBarcode(_terminal, _barcode, mv(view, 'c2'));
    view = await cart.setQuantity(_terminal, view.lines.single.id, d('2'), mv(view, 'c3'));

    // 1. Отмена кассиром.
    final a1 = await payments.startQr(_terminal, d('1000'), mv(view, 'a1'));
    final c1 = await payments.cancelQr(_terminal, a1.intentKey);
    stdout.writeln('[живьём] отмена: ${a1.phase.name} → ${c1.phase.name}');
    expect(c1.phase.name, 'cashierCancelled');

    // 2. Покупатель платит пультом раньше, чем дошла отмена.
    final a2 = await payments.startQr(_terminal, d('1000'), mv(view, 'a2'));
    await pult('/_emul/pay', {'intentKey': a2.intentKey});
    final c2 = await payments.cancelQr(_terminal, a2.intentKey);
    stdout.writeln('[живьём] оплата до отмены: ${c2.phase.name}');
    expect(c2.phase.name, 'paidAfterGiveUp');

    final outcome = await payments.complete(
      _terminal,
      PaymentRequest(type: PaymentType.cash, qrIntentKey: a2.intentKey),
      mv(view, 'pay'),
    );
    final rows = await db.paymentDao.findBySale(view.receiptNo!, view.posId);
    final qrRow = rows.singleWhere((p) => p.kindId == SystemPaymentKindIds.qr);
    stdout.writeln(
      '[живьём] чек ${outcome.receiptNo}: paid=${outcome.paid} '
      'reference=${qrRow.reference} provider=${qrRow.providerCode} '
      'txn=${qrRow.terminalTransactionId}',
    );
    expect(qrRow.reference, a2.intentKey);

    final state = await pult('/_emul/state') as Map<String, Object?>;
    final journal = await pult('/_emul/journal') as List<Object?>;
    stdout.writeln(
      '[живьём] эмулятор: намерений ${(state['intents'] as List).length}, '
      'записей журнала ${journal.length}',
    );
    for (final entry in journal) {
      stdout.writeln('  $entry');
    }
  });
}
