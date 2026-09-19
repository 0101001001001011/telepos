/// **Строка оплаты, вид которой касса назвать не может** — ревизия
/// 2026-09-19, дыра 2.
///
/// # Что было измерено до этих проб
///
/// `RefundUseCaseImpl._refundFiscalBuckets` выбрасывал такую строку из
/// цикла (`if (kind == null) continue`), а её сумму добирал **остатком** в
/// наличную часть конверта (`rest > 0 → cash += rest`). Два следствия, и
/// оба денежные:
///
/// * чек до v41 с бонусной строкой: деньги вернулись на бонусный счёт, а
///   оператор получал «выдано наличными» ровно на бонус — ящик и ОФД
///   расходились;
/// * чек с видом чужой кассы: раскладка отправляла его из ящика, конверт
///   называл это наличными, и **кассир не видел ничего** — ни причины, ни
///   следа.
///
/// # Что закреплено здесь
///
/// 1. Вид **записан**, а справочника на него нет → отказ с названной
///    причиной [refundKindUnknownCode], и отказ **до денег**: ящик не
///    тронут, строк сторно нет, оператор не спрошен.
/// 2. Строка **до v41** (вида не записано вовсе) → возврат идёт как шёл, и
///    конверт называет её тем маршрутом, которым деньги ушли на самом
///    деле: из ящика — наличными, на бонусный счёт — бонусом.
///
/// Второе — это и есть проверка «не сломал ли отказ работающие возвраты»:
/// старые чеки обязаны возвращаться, и отказ их не касается.
///
/// # Чего эти пробы НЕ доказывают
///
/// Ничего о том, **что именно** оператор сделает с полученным конвертом:
/// сведение позиций с оплатами живёт в `fiscal_envelope_balance_test`.
/// И ничего о маршруте самих денег — раскладку сторожит
/// `refund_by_payment_kind_test`.
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
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

const _posId = 1;
const _cashier = 4;
const _posAccount = 11;
const _bonusAccount = 12;

/// Оператор, записывающий доводы `fiscalizeRefund` **по имени**.
///
/// `noSuchMethod` — тот же приём, что у соседа
/// (`refund_fiscal_document_test`): у конверта одиннадцать доводов, и
/// повторять их подпись здесь значило бы завести второе мнение о ней.
class _RecordingFiscalService implements FiscalService {
  final refunds = <Map<Symbol, Object?>>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #fiscalizeRefund) {
      refunds.add(Map.of(invocation.namedArguments));
      return Future<FiscalResult>.value(FiscalResult.queued());
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late AppDatabase db;
  late Talker logger;

  Decimal d(String v) => Decimal.parse(v);

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))?.value ?? Decimal.zero;

  /// Чек на 1000: две штуки по 500, оплата — строками [lines].
  Future<void> receipt(
    int receiptNo,
    List<({int accountId, int? kindId, String amount})> lines,
  ) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: _posId,
            userId: _cashier,
            amount: d('1000'),
            time: 1700000000,
            state: const Value(1),
            isOfd: const Value(true),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: const Value(_posId),
            ucode: 100,
            quantity: d('2'),
            price: d('500'),
            priceBefore: d('500'),
          ),
        );
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              userId: _cashier,
              payeeAccountId: line.accountId,
              amount: d(line.amount),
              time: 1700000000,
              receiptNo: Value(receiptNo),
              posId: const Value(_posId),
              state: const Value(1),
              kindId: Value(line.kindId),
              seq: Value(i),
            ),
          );
    }
  }

  Future<int> refundWhole(int receiptNo, FiscalService fiscal) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: _cashier, time: 2000));
    final refundId = (await db.select(db.refunds).get()).last.localId;
    await RefundUseCaseImpl(db: db, logger: logger, fiscal: fiscal).perform(
      refundLocalId: refundId,
      amount: d('1000'),
      userId: _cashier,
      saleReceiptNo: receiptNo,
      salePosId: _posId,
      products: [
        RefundProductEntry(
          ucode: 100,
          quantity: d('2'),
          price: d('500'),
          inSalePrice: d('500'),
          inSaleQuantity: d('2'),
          inSalePriceBefore: d('500'),
        ),
      ],
    );
    return refundId;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker();
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
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(_posAccount),
            type: AccountType.pos,
            name: const Value('Ящик'),
            value: Value(d('5000')),
            visibleToPos: const Value(true),
          ),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(_bonusAccount),
            type: AccountType.cashback,
            name: const Value('Бонусы покупателя'),
            value: Value(d('300')),
            visibleToPos: const Value(true),
          ),
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

  test('вид чужой кассы — отказ названной причиной, и раньше денег', () async {
    final fiscal = _RecordingFiscalService();
    // 777 — вид, заведённый оператором на соседней кассе. Ид записан,
    // строки справочника нет: чем платили, эта касса не знает.
    await receipt(7, [(accountId: _posAccount, kindId: 777, amount: '1000')]);

    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: _cashier, time: 2000));
    final refundId = (await db.select(db.refunds).get()).last.localId;

    await expectLater(
      RefundUseCaseImpl(db: db, logger: logger, fiscal: fiscal).perform(
        refundLocalId: refundId,
        amount: d('1000'),
        userId: _cashier,
        saleReceiptNo: 7,
        salePosId: _posId,
        products: [
          RefundProductEntry(
            ucode: 100,
            quantity: d('2'),
            price: d('500'),
            inSalePrice: d('500'),
            inSaleQuantity: d('2'),
            inSalePriceBefore: d('500'),
          ),
        ],
      ),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          refundKindUnknownCode,
        ),
      ),
      reason:
          'кассир обязан узнать причину. Прежний исход — выдача наличных '
          'за вид, о котором касса не знает ничего',
    );

    // **Раньше денег** — три утверждения, а не одно: отказ, пришедший
    // после раскладки, был бы виден так же, а ящик уже опустел бы.
    expect(
      await balanceOf(_posAccount),
      d('5000'),
      reason: 'из ящика не ушло ничего',
    );
    expect(
      await db.paymentDao.findByRefund(refundId),
      isEmpty,
      reason: 'строк сторно не появилось',
    );
    expect(
      fiscal.refunds,
      isEmpty,
      reason: 'оператору нечего рассказывать о несостоявшемся возврате',
    );
    expect(
      (await db.productInfoDao.findByUcode(100))!.quantity,
      d('100'),
      reason: 'товар не вернулся на остаток',
    );
  });

  test('строка до v41 из ящика остаётся наличными — возврат идёт', () async {
    final fiscal = _RecordingFiscalService();
    // Вида не записано вовсе: чек продан до v41. Решение задачи 26 —
    // деньги из ящика; отказ выше его не касается.
    await receipt(8, [(accountId: _posAccount, kindId: null, amount: '1000')]);

    await refundWhole(8, fiscal);

    expect(
      await balanceOf(_posAccount),
      d('4000'),
      reason: 'старый чек обязан возвращаться, а не отказывать',
    );
    final args = fiscal.refunds.single;
    expect(
      args[#cashAmount],
      d('1000'),
      reason: 'деньги ушли из ящика — наличными и в документе',
    );
    expect(args[#bonusAmount], Decimal.zero);
  });

  test('бонусная строка до v41 едет бонусом, а не наличными', () async {
    final fiscal = _RecordingFiscalService();
    // Чек до v41: 700 наличными и 300 бонусами. Вида нет ни у одной
    // строки — обе классифицируются маршрутом.
    await receipt(9, [
      (accountId: _posAccount, kindId: null, amount: '700'),
      (accountId: _bonusAccount, kindId: null, amount: '300'),
    ]);

    await refundWhole(9, fiscal);

    final args = fiscal.refunds.single;
    expect(
      args[#cashAmount],
      d('700'),
      reason:
          'из ящика ушло семьсот — столько же обязан увидеть оператор. '
          'Тысяча здесь означала бы расхождение ящика с ОФД ровно на бонус',
    );
    expect(
      args[#bonusAmount],
      d('300'),
      reason: 'бонус вернулся на бонусный счёт — он и в конверте бонус',
    );
    expect(args[#amount], d('1000'));

    // Слом в обе стороны: деньги и правда разошлись по двум местам.
    expect(await balanceOf(_posAccount), d('4300'));
    expect(
      await balanceOf(_bonusAccount),
      d('600'),
      reason: 'бонус лёг обратно на счёт покупателя',
    );
  });
}
