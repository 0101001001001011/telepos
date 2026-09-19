/// Фискальный узел возврата — **довод конструктора, а не поиск в `GetIt`**.
///
/// # Что нашла приёмка 2026-09-17
///
/// Возврат доставал узел сам, `GetIt.I<FiscalService>()`, **внутри того же
/// `try`**, который ловит беды самой фискализации. Бросок «службы нет в
/// контейнере» приходил в тот же `catch`, что и отказ оператора, и уходил
/// строкой предупреждения в журнал. Стенд живой приёмки полгода проводил
/// возвраты **без фискального документа** и выглядел при этом исправным:
/// деньги возвращались, чек печатался, отказа никто не видел.
///
/// Заметили это глазами. Ни сборка, ни набор из пяти тысяч проб не сказали
/// ни слова — сказать им было нечем: дефект был в **молчании**, а молчание
/// нельзя утверждать, не назвав, кто обязан был говорить.
///
/// # Почему обе пробы здесь ничего не регистрируют в `GetIt`
///
/// Это и есть их несущая часть, а не оформление. `FiscalService` в
/// контейнере **нарочно отсутствует** — ровно как на стенде до правки. При
/// прежнем устройстве возврата обе пробы покраснели бы одинаково: узел,
/// названный доводом, не был бы спрошен ни разу, потому что возврат
/// спрашивал бы контейнер и проглатывал бросок.
///
/// Это и есть диверсия, ради которой файл написан: вернуть поиск в `GetIt`
/// — и `asked` в обеих пробах остаётся нулём.
///
/// `RefundProductService` в контейнере остаётся: возврат по-прежнему
/// достаёт **его** оттуда, и это второй скрытый поиск того же рода —
/// названный в отчёте, но не чинённый здесь (он, в отличие от
/// фискализации, бросает наружу и валит возврат целиком, то есть молчанием
/// не является).
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
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';

const _posId = 1;
const _cashier = 4;
const _posAccount = 11;

/// Настроенный оператор, записывающий доводы `fiscalizeRefund` **по имени**.
///
/// `noSuchMethod` — чтобы проба не переписывалась от того, что в подпись
/// `fiscalizeRefund` добавили ведро; подписи у конверта одиннадцать доводов,
/// и повторять их здесь значило бы завести второе мнение о том, как она
/// выглядит.
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

/// Касса **без фискального узла** — настоящий [RefusingFiscalService] со
/// счётчиком обращений.
///
/// Наследование, а не подделка: отвечает ровно то же, что ответит собранная
/// без оператора касса (`FiscalResult.notConfigured()`), и добавляет
/// единственное — счёт того, **спросили ли его вообще**. Заглушка,
/// отвечающая успехом, здесь была бы хуже отсутствия пробы: она утверждала
/// бы, что документ ушёл с кассы, где его не с чем выписать.
class _CountingRefusal extends RefusingFiscalService {
  _CountingRefusal();

  int asked = 0;

  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    required Decimal mobileAmount,
    required Decimal bonusAmount,
    required Decimal creditAmount,
    required Decimal offsetAmount,
    required OffsetFiscalLayout offsetLayout,
    required bool excludeCertificatePositions,
  }) {
    asked++;
    return super.fiscalizeRefund(
      refundLocalId: refundLocalId,
      originalSaleReceiptNo: originalSaleReceiptNo,
      amount: amount,
      cashAmount: cashAmount,
      cardAmount: cardAmount,
      mobileAmount: mobileAmount,
      bonusAmount: bonusAmount,
      creditAmount: creditAmount,
      offsetAmount: offsetAmount,
      offsetLayout: offsetLayout,
      excludeCertificatePositions: excludeCertificatePositions,
    );
  }
}

void main() {
  late AppDatabase db;
  late Talker logger;

  Decimal d(String v) => Decimal.parse(v);

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))?.value ?? Decimal.zero;

  /// Чек на 1000 наличными: две штуки по 500.
  ///
  /// [isOfd] — **признак того, что продажа получила фискальный документ**.
  /// Возврат смотрит именно на него: возвращать по документу нечего там,
  /// где документа не выписывали.
  Future<void> receipt(int receiptNo, {required bool isOfd}) async {
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
            isOfd: Value(isOfd),
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
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: _cashier,
            payeeAccountId: _posAccount,
            amount: d('1000'),
            time: 1700000000,
            receiptNo: Value(receiptNo),
            posId: const Value(_posId),
            state: const Value(1),
            kindId: const Value(SystemPaymentKindIds.cash),
            seq: const Value(0),
          ),
        );
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

    await GetIt.I.reset();
    // Нарочно **только** он: фискального узла в контейнере нет, и это
    // несущая часть обеих проб (разбор — в докстринге файла).
    GetIt.I.registerSingleton<RefundProductService>(
      RefundProductServiceImpl(db: db, logger: logger),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  test('возврат фискализованного чека уходит оператору фискальным '
      'возвратом', () async {
    final fiscal = _RecordingFiscalService();
    await receipt(7, isOfd: true);

    await refundWhole(7, fiscal);

    // **Несущее утверждение работы.** До правки здесь был ноль: узел
    // доставался из `GetIt`, где его нет, бросок ловился тем же `catch`,
    // что и беды оператора, и возврат молча обходился без документа.
    expect(
      fiscal.refunds.length,
      1,
      reason:
          'оператор обязан получить фискальный возврат по чеку, который '
          'сам же и фискализовал',
    );

    final args = fiscal.refunds.single;
    expect(
      args[#originalSaleReceiptNo],
      7,
      reason: 'документ ссылается на чек',
    );
    expect(args[#amount], d('1000'));
    expect(
      args[#cashAmount],
      d('1000'),
      reason: 'вернулись живые наличные — ими же и в документе',
    );
    expect(args[#offsetAmount], Decimal.zero);
    expect(args[#creditAmount], Decimal.zero);
  });

  test('касса без фискального оператора возвращает деньги и обходится без '
      'документа — не падая', () async {
    final fiscal = _CountingRefusal();
    await receipt(8, isOfd: true);

    final refundId = await refundWhole(8, fiscal);

    // Узел **спрошен**: касса без оператора не «пропускает фискализацию»,
    // а получает от названного ею узла отказ. Ноль здесь означал бы, что
    // возврат снова решает это сам, мимо довода.
    expect(
      fiscal.asked,
      1,
      reason: 'узел, названный доводом, обязан быть спрошен',
    );

    // Деньги вернулись целиком, и отказ фискализации их не откатил: чек
    // возврата к этой строке уже свершился.
    expect(
      await balanceOf(_posAccount),
      d('4000'),
      reason: 'из ящика ушла ровно тысяча',
    );
    final rows = await db.paymentDao.findByRefund(refundId);
    expect(rows.map((p) => p.amount).toList(), [d('-1000')]);
    expect(
      (await db.productInfoDao.findByUcode(100))!.quantity,
      d('102'),
      reason: 'товар лёг обратно на остаток',
    );
  });

  test('чек без фискального документа оператора не беспокоит', () async {
    // Обратный полюс: узел назван и настроен, но продажа документа не
    // получала (`isOfd == false`) — возвращать по документу нечего.
    // Без этой пробы первое утверждение прошло бы и у кода, который зовёт
    // оператора на каждом возврате подряд.
    final fiscal = _RecordingFiscalService();
    await receipt(9, isOfd: false);

    await refundWhole(9, fiscal);

    expect(fiscal.refunds, isEmpty);
    expect(await balanceOf(_posAccount), d('4000'));
  });
}
