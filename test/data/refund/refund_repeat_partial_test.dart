/// Повторный частичный возврат одного чека — **замер вместо толкования**.
///
/// # Что утверждала ревизия и что оказалось
///
/// Ревизия 2026-09-19, пункт 17: «раскладка не учитывает прежние возвраты»,
/// следствие — «повторный частичный возврат может выдать больше, чем брали».
///
/// Первая половина **верна** и измерена здесь (группа «раскладка»):
/// `RefundPlan.of` читает строки оплаты чека и ничего не знает о том, что по
/// этому чеку уже возвращали. Вторая половина — **не воспроизводится**, и не
/// по случайности, а по построению: второго возврата одного чека в этом
/// дереве не бывает вовсе.
///
/// Держат это три разных заслона, и здесь измерен каждый:
///
/// 1. **Ключ базы** `Refunds.uniqueKeys = [{saleReceiptNo, salePosId}]` —
///    вторая строка возврата на тот же чек не записывается. Это и есть
///    настоящее основание: два других заслона — код, а этот — структура.
/// 2. `LocalRefundService.start` — названный отказ
///    `receipt_already_refunded` при загрузке чека
///    (`local_refund_service_test.dart`, «по возвращённому чеку второй
///    возврат не заводится»).
/// 3. `LocalRefundService.complete` — тот же отказ **повторно**, уже после
///    сбора черновика: он закрывает окно «черновик начат раньше, чем чужой
///    возврат лёг» (там же, проба с чеком 27).
///
/// # Зачем проба, если дыры нет
///
/// Затем, что её отсутствие держится на одной строке в объявлении таблицы, и
/// эта строка ничем не сторожилась. Снеси ключ — и оба кодовых заслона
/// останутся зелёными (они читают `findBySale`, а не ограничение), а
/// раскладка молча отдала бы ту же строку оплаты второй раз. Замер этого
/// сценария — в тесте «раскладка второго возврата отдала бы те же деньги
/// снова».
///
/// # Чего это НЕ доказывает
///
/// Что возврат нельзя переплатить вообще. Здесь измерен ровно один способ —
/// **повторный возврат по одному чеку**. Не измерены и остаются открытыми:
/// возврат без чека (`saleReceiptNo IS NULL`, ключ на таких строках не
/// работает — в SQLite `NULL` не равен `NULL`), возврат чека, приехавшего
/// обменом с другой кассы, и сумма возврата, превышающая проданное внутри
/// **одного** возврата.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/refund/refund_plan.dart';
import 'package:telepos/data/usecases/refund/refund_product_service_impl.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/refund/refund_allocation.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/usecases/refund/refund_use_case.dart';

const _posId = 1;
const _cashier = 4;
const _receiptNo = 7;

const _posAccount = 11;
const _liabilityAccount = 15;

void main() {
  late AppDatabase db;
  late Talker logger;

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

  /// Чек 1000 — две штуки по 500 — оплаченный **сертификатом на 300 и
  /// наличными на 700**.
  ///
  /// Состав выбран по сути, а не для разнообразия: сертификат отдаёт первым
  /// (`RefundRoute.certificate`, класс 2), наличные — последними (класс 5).
  /// Поэтому частичный возврат на 300 целиком ложится на строку сертификата,
  /// и «отдали ту же строку дважды» видно **бумажкой**: каждый такой возврат
  /// выпускает новый сертификат, и второй было бы не спутать ни с чем.
  Future<void> seedReceipt() async {
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
            payeeAccountId: _liabilityAccount,
            amount: d('300'),
            time: 1700000000,
            receiptNo: const Value(_receiptNo),
            posId: const Value(_posId),
            state: const Value(1),
            kindId: const Value(SystemPaymentKindIds.certificate),
            seq: const Value(0),
            reference: const Value('C-300'),
          ),
        );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: _cashier,
            payeeAccountId: _posAccount,
            amount: d('700'),
            time: 1700000000,
            receiptNo: const Value(_receiptNo),
            posId: const Value(_posId),
            state: const Value(1),
            kindId: const Value(SystemPaymentKindIds.cash),
            seq: const Value(1),
          ),
        );
  }

  /// Завести строку возврата и провести по ней возврат на [amount].
  Future<int> refund(String amount) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: _cashier, time: 2000));
    final refundLocalId = (await db.select(db.refunds).get()).last.localId;
    await RefundUseCaseImpl(
      db: db,
      logger: logger,
      fiscal: const RefusingFiscalService(),
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
    return refundLocalId;
  }

  Future<List<GiftCertificate>> certificates() async {
    final rows = await db.select(db.giftCertificates).get();
    return [for (final row in rows) (await db.certificateDao.byNumber(row.number))!];
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
    await account(_posAccount, AccountType.pos, '5000');
    await account(_liabilityAccount, AccountType.certificateLiability, '0');
    await db.paymentKindDao.put(
      SystemPaymentKinds.byId(
        SystemPaymentKindIds.certificate,
      ).copyWith(isActive: true),
    );
    await db.certificateDao.insertCertificate(
      number: 'C-300',
      nominal: d('300'),
      issuedAt: 1000,
      status: CertificateStatus.redeemed,
      liabilityAccountId: _liabilityAccount,
    );
    await seedReceipt();

    await GetIt.I.reset();
    GetIt.I.registerSingleton<RefundProductService>(
      RefundProductServiceImpl(db: db, logger: logger),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  group('второго возврата одного чека не бывает', () {
    test('вторую строку возврата на тот же чек база не принимает', () async {
      // Заслон, на котором всё держится, — **ограничение таблицы**, а не
      // проверка кодом. Меряется он прямой записью, мимо всех сервисов:
      // иначе зелёный цвет говорил бы о проверке в сервисе, а не о ключе.
      await db
          .into(db.refunds)
          .insert(
            RefundsCompanion.insert(
              userId: _cashier,
              time: 2000,
              state: const Value(1),
              saleReceiptNo: const Value(_receiptNo),
              salePosId: const Value(_posId),
            ),
          );

      await expectLater(
        () => db
            .into(db.refunds)
            .insert(
              RefundsCompanion.insert(
                userId: _cashier,
                time: 2100,
                state: const Value(1),
                saleReceiptNo: const Value(_receiptNo),
                salePosId: const Value(_posId),
              ),
            ),
        throwsA(anything),
        reason:
            'ключ {saleReceiptNo, salePosId} — единственное, что делает '
            '«повторный частичный возврат» невозможным по построению; '
            'снимут его — и раскладка отдаст ту же строку оплаты второй раз',
      );

      expect(
        (await db.select(db.refunds).get())
            .where((r) => r.saleReceiptNo == _receiptNo)
            .length,
        1,
      );
    });

    test('повторный частичный возврат не проводится и денег не выдаёт', () async {
      final first = await refund('300');

      final certificatesAfterFirst = await certificates();
      final liabilityAfterFirst = (await db.accountDao.findById(
        _liabilityAccount,
      ))!.value;
      final drawerAfterFirst = (await db.accountDao.findById(
        _posAccount,
      ))!.value;
      final stockAfterFirst = (await db.productInfoDao.findByUcode(100))!
          .quantity;

      // Первый возврат — тот, что должен был случиться: 300 ушли строкой
      // сертификата, из ящика не вышло ничего, покупателю выпущена новая
      // бумажка.
      expect(certificatesAfterFirst.map((c) => c.number), [
        'C-300',
        'C-300-R$first',
      ]);
      expect(drawerAfterFirst, d('5000'));

      // Второй — тот, которым ревизия объясняла переплату.
      await expectLater(() => refund('300'), throwsA(anything));

      expect(
        (await certificates()).map((c) => c.number),
        certificatesAfterFirst.map((c) => c.number),
        reason:
            'второй бумажки на те же 300 не выпущено — иначе касса отдала '
            'бы за строку оплаты на 300 ровно 600',
      );
      expect(
        (await db.accountDao.findById(_liabilityAccount))!.value,
        liabilityAfterFirst,
      );
      expect((await db.accountDao.findById(_posAccount))!.value, drawerAfterFirst);
      expect(
        (await db.productInfoDao.findByUcode(100))!.quantity,
        stockAfterFirst,
        reason: 'откат транзакции обязан забрать и приход товара на склад',
      );
      expect(
        await db.paymentDao.findByRefund(first + 1),
        isEmpty,
        reason: 'строк сторно у несостоявшегося возврата быть не должно',
      );
    });
  });

  group('раскладка', () {
    test('прежних возвратов не знает — и отдала бы те же деньги снова', () async {
      await refund('300');

      final plan = await RefundPlan.of(
        db,
        amount: d('300'),
        receiptNo: _receiptNo,
        posId: _posId,
      );

      expect(
        [for (final p in plan.parts) (p.route, p.amount)],
        [(RefundRoute.certificate, d('300'))],
        reason:
            'половина утверждения ревизии верна: строка оплаты на 300 '
            'предлагается к возврату целиком во ВТОРОЙ раз. Безопасно это '
            'ровно потому, что до проведения дело не доходит — ключ '
            '{saleReceiptNo, salePosId} не даст записать второй возврат. '
            'Меняешь одно — перечитай другое',
      );
    });
  });
}
