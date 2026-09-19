/// Намерение QR перестаёт выглядеть оплаченным после возврата — ревизия
/// 2026-09-19, дыра 3, схема v51.
///
/// # Что меряется
///
/// Настоящая база drift, настоящий `RefundUseCaseImpl`, настоящий
/// `PaymentIntentDao`. Подставлен один порт — `RefundTenderGateway`: он
/// разговаривает с провайдером по сети, и его ответ здесь не предмет замера
/// (для него есть `test/emulators/sbp/refund_live_test.dart` с настоящим
/// эмулятором на сокете). Предмет замера — **след, который возврат
/// оставляет в журнале намерений**.
///
/// # Что было до правки
///
/// `paymentIntentDao` не упоминался в `refund_use_case_impl.dart` вовсе.
/// Провайдер отдавал деньги, а строка намерения оставалась `paid` со
/// `settled_at` — то есть читалась как «деньги взяты и лежат в чеке».
/// `QrIntentStatus.reversed` не писал никто.
///
/// # Чего это НЕ доказывает
///
/// Что деньги действительно вернулись: здесь шлюз отвечает согласием по
/// построению. Доказывается ровно одно — касса записывает то, что ей
/// ответили, и записывает **честно**: частичный возврат не выдаётся за
/// полный.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/refund/refund_tender_gateway.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';

const _posId = 1;
const _cashier = 4;
const _receiptNo = 7;

const _posAccount = 11;
const _bankAccount = 12;

/// Шлюз, который всегда соглашается и записывает, о чём его просили.
class _AgreeingGateway implements RefundTenderGateway {
  final qrCalls = <({String intent, Decimal amount, String key})>[];

  @override
  Future<TenderReturn> returnQr({
    required String providerIntentId,
    required Decimal amount,
    required String refundKey,
  }) async {
    qrCalls.add((intent: providerIntentId, amount: amount, key: refundKey));
    return TenderReturn.done(transactionId: providerIntentId);
  }

  @override
  Future<TenderReturn> returnCard({
    required int? terminalId,
    required String transactionId,
    required Decimal amount,
    required String refundKey,
  }) async => TenderReturn.done(transactionId: transactionId);
}

void main() {
  late AppDatabase db;
  late Talker logger;
  late _AgreeingGateway gateway;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> account(int id, int type, String value) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: Value(id),
          type: type,
          name: Value('Счёт $id'),
          value: Value(d(value)),
          visibleToPos: const Value(true),
        ),
      );

  /// Чек 1000: 400 наличными и 600 по QR намерения [providerIntentId].
  ///
  /// Состав выбран так, чтобы **частичный** возврат целиком лёг на QR:
  /// наличные в правиле частичного возврата отдают последними
  /// (`RefundRoute.drawer`, класс 5), QR — раньше (класс 4).
  Future<void> seedReceipt(String providerIntentId) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: _receiptNo,
            posId: _posId,
            userId: _cashier,
            amount: d('1000'),
            time: 1700000000,
            state: const Value(1),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: const Value(_receiptNo),
            posId: const Value(_posId),
            ucode: 100,
            quantity: d('2'),
            price: d('500'),
            priceBefore: d('500'),
          ),
        );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: _cashier,
            payeeAccountId: _bankAccount,
            amount: d('600'),
            time: 1700000000,
            receiptNo: const Value(_receiptNo),
            posId: const Value(_posId),
            state: const Value(1),
            kindId: const Value(SystemPaymentKindIds.qr),
            seq: const Value(0),
            terminalTransactionId: Value(providerIntentId),
            providerCode: const Value('kaspi'),
          ),
        );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: _cashier,
            payeeAccountId: _posAccount,
            amount: d('400'),
            time: 1700000000,
            receiptNo: const Value(_receiptNo),
            posId: const Value(_posId),
            state: const Value(1),
            kindId: const Value(SystemPaymentKindIds.cash),
            seq: const Value(1),
          ),
        );
  }

  /// Намерение, оплаченное и уложенное в чек, — как его оставляет продажа.
  Future<PaymentIntent> seedPaidIntent(String providerIntentId) async {
    final (intent, _) = await db.paymentIntentDao.claim(
      intentKey: 'k-$providerIntentId',
      providerCode: 'kaspi',
      amount: d('600'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      posId: _posId,
      receiptNo: _receiptNo,
    );
    await db.paymentIntentDao.attachProviderIntent(
      id: intent.id,
      providerIntentId: providerIntentId,
      status: QrIntentStatus.pending,
    );
    await db.paymentIntentDao.applyState(
      id: intent.id,
      status: QrIntentStatus.paid,
      paidAmount: d('600'),
      confirmedAt: DateTime.fromMillisecondsSinceEpoch(1700000060000),
    );
    await db.paymentIntentDao.markSettled(
      id: intent.id,
      receiptNo: _receiptNo,
      at: DateTime.fromMillisecondsSinceEpoch(1700000061000),
    );
    return (await db.paymentIntentDao.byId(intent.id))!;
  }

  Future<void> refund(String amount) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: _cashier, time: 2000));
    final refundLocalId = (await db.select(db.refunds).get()).last.localId;
    await RefundUseCaseImpl(
      db: db,
      logger: logger,
      fiscal: const RefusingFiscalService(),
      tenders: gateway,
    ).perform(
      refundLocalId: refundLocalId,
      amount: d(amount),
      userId: _cashier,
      saleReceiptNo: _receiptNo,
      salePosId: _posId,
      products: [
        RefundProductEntry(
          ucode: 100,
          quantity: d('1'),
          price: d('500'),
          inSalePrice: d('500'),
          inSaleQuantity: d('2'),
        ),
      ],
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker();
    gateway = _AgreeingGateway();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(_posId),
            accountId: Value(_posAccount),
          ),
        );
    await db
        .into(db.users)
        .insert(
          const UsersCompanion(id: Value(_cashier), name: Value('Айгуль')),
        );
    await db
        .into(db.shifts)
        .insert(
          const ShiftsCompanion(
            userId: Value(_cashier),
            openTime: Value(1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(100),
            barcode: 4870001234567,
            name: 'Кофе',
            type: 0,
            measure: 0,
            quantity: Value(d('100')),
          ),
        );
    await account(_posAccount, AccountType.pos, '5000');
    await account(_bankAccount, AccountType.customBank, '5000');
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(SystemPaymentKindIds.qr).copyWith(isActive: true),
    );

    await GetIt.I.reset();
    GetIt.I.registerSingleton<RefundProductService>(
      RefundProductServiceImpl(db: db, logger: logger),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  test('возврат всей суммы QR: намерение становится reversed', () async {
    await seedReceipt('p-600');
    final intent = await seedPaidIntent('p-600');
    expect(intent.status, QrIntentStatus.paid);

    await refund('600');

    expect(gateway.qrCalls.single.amount, d('600'));

    final after = (await db.paymentIntentDao.byId(intent.id))!;
    expect(
      after.status,
      QrIntentStatus.reversed,
      reason:
          'деньги у покупателя — намерение больше не имеет права читаться '
          'оплаченным ни разбором при подъёме, ни вкладкой диагностики',
    );
    expect(after.reversedAmount, d('600'));
    expect(after.reversedAt, isNotNull);
    expect(after.moneyLeft, Decimal.zero);
  });

  test('частичный возврат QR: сумма записана, статус остаётся paid', () async {
    await seedReceipt('p-600');
    final intent = await seedPaidIntent('p-600');

    // 300 из 1000: QR отдаёт раньше наличных, поэтому вся доля ложится на
    // него, а на намерении остаётся половина денег.
    await refund('300');

    expect(gateway.qrCalls.single.amount, d('300'));

    final after = (await db.paymentIntentDao.byId(intent.id))!;
    expect(
      after.status,
      QrIntentStatus.paid,
      reason:
          '`reversed` значит «оплата возвращена покупателю»; на намерении '
          'ещё 300 — писать его значило бы соврать в другую сторону',
    );
    expect(after.reversedAmount, d('300'));
    expect(after.moneyLeft, d('300'));
  });

  test('намерения этой кассе не известно — возврат проходит и говорит вслух', () async {
    // Чек приехал обменом с другой кассы: строка оплаты несёт ид намерения,
    // а самого намерения здесь нет. Деньги провайдер вернул — падать нельзя.
    await seedReceipt('p-чужое');

    await refund('600');

    expect(gateway.qrCalls.single.intent, 'p-чужое');
    expect(await db.paymentIntentDao.byProviderIntentId('p-чужое'), isNull);
    expect(
      logger.history
          .map((e) => e.generateTextMessage())
          .where((m) => m.contains('there is no such intent on this till')),
      isNotEmpty,
      reason: 'молчание здесь неотличимо от «записали» — причина названа',
    );
  });
}
