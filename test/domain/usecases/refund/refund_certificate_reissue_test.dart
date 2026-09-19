/// Сертификаты при возврате — решения заказчика 2026-09-16.
///
/// Здесь меряются четыре из шести решений, и каждое своей пробой:
///
/// 1. **Проданный сертификат при возврате гасится сразу** (решение 1).
/// 2. **Восстановления не бывает — выпускается новая бумажка** (решение 2),
///    со сроком, унаследованным от исходной и урезанным тремя годами от
///    первичной продажи.
/// 3. **Наличными за сертификат не возвращают** (решения 3 и 5).
/// 4. **Журнал связи обязателен**, и повторный возврат по тому же чеку
///    второй бумажки не выпускает.
///
/// # Что здесь настоящее
///
/// Настоящая база drift, настоящий `RefundUseCaseImpl`, настоящий
/// `CertificateDao`, настоящая раскладка `RefundAllocation`. Чек и его
/// строки оплаты посеяны прямо в таблицы — с видом (`kindId`) и документом
/// (`reference`), ровно так, как их пишет `LocalPaymentService`: раскладка
/// возврата читает **строки**, а не то, как они появились. Тот же приём и
/// тот же довод, что у соседа `test/data/refund/refund_by_payment_kind_test.dart`.
///
/// # Почему карта здесь без номера операции
///
/// Строка карты **без** `terminalTransactionId` раскладывается в
/// `RefundRoute.manual` (`RefundAllocation.routeOf`): карту провели на
/// отдельном терминале, и касса возвращает её записью, а деньги кассир
/// отдаёт там же. Это единственный безналичный путь, которому не нужен
/// эквайринговый шлюз, — и потому единственный, которым проба может
/// измерить «вернули не наличными», не поднимая банк.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/certificate_refund_tables.dart';
import 'package:telepos/data/usecases/refund/refund_use_case_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_service.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/usecases/refund/refund_product_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

const _posId = 1;
const _cashier = 4;

const _posAccount = 11;
const _bankAccount = 12;
const _liabilityAccount = 15;

/// Возврат строк товара этим пробам не нужен: они меряют деньги и бумажки.
/// Служба обязана быть зарегистрирована — `RefundUseCaseImpl` достаёт её из
/// `GetIt` внутри транзакции независимо от того, пуст ли список строк.
class _NoRefundProducts implements RefundProductService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

void main() {
  late AppDatabase db;
  late Talker logger;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> account(int id, int type, [String value = '0']) => db
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

  /// Чек на [total] и одна строка оплаты.
  Future<void> receipt(
    int receiptNo, {
    required String total,
    required int kindId,
    required int accountId,
    String? reference,
  }) async {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: receiptNo,
            posId: _posId,
            userId: _cashier,
            amount: d(total),
            time: 1700000000,
            state: const Value(1),
          ),
        );
    await db
        .into(db.saleProducts)
        .insert(
          SaleProductsCompanion.insert(
            receiptNo: Value(receiptNo),
            posId: const Value(_posId),
            ucode: 100,
            quantity: d('1'),
            price: d(total),
            priceBefore: d(total),
          ),
        );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: _cashier,
            payeeAccountId: accountId,
            amount: d(total),
            time: 1700000000,
            receiptNo: Value(receiptNo),
            posId: const Value(_posId),
            state: const Value(1),
            kindId: Value(kindId),
            seq: const Value(0),
            reference: Value(reference),
          ),
        );
  }

  Future<int> refund(int receiptNo, String amount) async {
    await db
        .into(db.refunds)
        .insert(RefundsCompanion.insert(userId: _cashier, time: 2000));
    final refundId = (await db.select(db.refunds).get()).last.localId;
    await RefundUseCaseImpl(
      db: db,
      logger: logger,
      fiscal: const RefusingFiscalService(),
    ).perform(
      refundLocalId: refundId,
      amount: d(amount),
      userId: _cashier,
      saleReceiptNo: receiptNo,
      salePosId: _posId,
      products: const [],
    );
    return refundId;
  }

  Future<GiftCertificate> cert(String number) async =>
      (await db.certificateDao.byNumber(number))!;

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))?.value ?? Decimal.zero;

  setUp(() async {
    GetIt.I.registerSingleton<RefundProductService>(_NoRefundProducts());
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
    await account(_bankAccount, AccountType.customBank, '5000');
    // Обязательство под одну непогашенную бумажку на 5000 — то состояние,
    // в котором касса находится после её продажи.
    await account(_liabilityAccount, AccountType.certificateLiability, '5000');
  });

  tearDown(() async {
    await GetIt.I.unregister<RefundProductService>();
    await db.close();
  });

  group('возврат товара, оплаченного сертификатом', () {
    /// Бумажка, которой заплатили за товар: выпущена и потрачена целиком.
    Future<void> spentCertificate({
      required String nominal,
      int? expiresAt,
      int issuedAt = 1600000000,
    }) async {
      await db.certificateDao.insertCertificate(
        number: 'C-1',
        nominal: d(nominal),
        issuedAt: issuedAt,
        status: CertificateStatus.active,
        expiresAt: expiresAt,
        liabilityAccountId: _liabilityAccount,
      );
      await db.certificateDao.redeem(number: 'C-1', amount: d(nominal));
    }

    test('выпускается НОВАЯ бумажка, старая остаётся погашенной', () async {
      await spentCertificate(nominal: '1000');
      await receipt(
        5001,
        total: '1000',
        kindId: SystemPaymentKindIds.certificate,
        accountId: _liabilityAccount,
        reference: 'C-1',
      );

      final refundId = await refund(5001, '1000');

      // Старая — **погашена навсегда**. Ожившая бумажка неотличима от
      // непогашенной, и её предъявляют второй раз.
      expect((await cert('C-1')).balance, Decimal.zero);
      expect((await cert('C-1')).status, CertificateStatus.redeemed);

      final issued = await cert('C-1-R$refundId');
      expect(issued.balance, d('1000'));
      expect(issued.nominal, d('1000'));
      expect(issued.status, CertificateStatus.active);
      expect(
        issued.issuedReceiptNo,
        isNull,
        reason:
            'бумажка рождена возвратом, а не продажей: чек выпуска здесь '
            'соврал бы, и byIssuedReceipt погасила бы её при следующем '
            'возврате того же чека',
      );

      // Из ящика не вышло ни тенге — тот же довод, что был у восстановления.
      expect(await balanceOf(_posAccount), d('5000'));
    });

    test('журнал связи записан: новая ← возврат ← исходная', () async {
      await spentCertificate(nominal: '1000');
      await receipt(
        5001,
        total: '1000',
        kindId: SystemPaymentKindIds.certificate,
        accountId: _liabilityAccount,
        reference: 'C-1',
      );

      final refundId = await refund(5001, '1000');

      final links = await db.certificateDao.linksByRefund(refundId);
      expect(links, hasLength(1));
      expect(links.single.sourceNumber, 'C-1');
      expect(links.single.issuedNumber, 'C-1-R$refundId');
      expect(links.single.amountMillis, 1000000);
      expect(links.single.reason, CertificateRefundReason.issued.code);
    });

    test('срок наследуется от исходной бумажки', () async {
      // Исходная выпущена 2020-09-13 (1600000000) и истекает через год.
      // Год меньше трёхлетнего потолка — значит наследуется как есть.
      const issuedAt = 1600000000;
      const expires = issuedAt + 365 * 24 * 60 * 60;
      await spentCertificate(nominal: '1000', expiresAt: expires);
      await receipt(
        5001,
        total: '1000',
        kindId: SystemPaymentKindIds.certificate,
        accountId: _liabilityAccount,
        reference: 'C-1',
      );

      final refundId = await refund(5001, '1000');

      expect(
        (await cert('C-1-R$refundId')).expiresAt,
        expires,
        reason: 'новый срок не может быть щедрее исходного',
      );
    });

    test('срок урезан тремя годами от первичной продажи', () async {
      // Исходная бессрочная. Наследовать бессрочность значило бы оставить
      // обязательство кассы без срока давности вовсе.
      const issuedAt = 1600000000; // 2020-09-13 12:26:40 UTC
      await spentCertificate(nominal: '1000', issuedAt: issuedAt);
      await receipt(
        5001,
        total: '1000',
        kindId: SystemPaymentKindIds.certificate,
        accountId: _liabilityAccount,
        reference: 'C-1',
      );

      final refundId = await refund(5001, '1000');

      final issued = DateTime.fromMillisecondsSinceEpoch(
        issuedAt * 1000,
        isUtc: true,
      );
      final cap =
          DateTime.utc(
            issued.year + 3,
            issued.month,
            issued.day,
            issued.hour,
            issued.minute,
            issued.second,
          ).millisecondsSinceEpoch ~/
          1000;

      expect(
        (await cert('C-1-R$refundId')).expiresAt,
        cap,
        reason:
            'иначе возврат стал бы способом бесплатно продлевать бумажку: '
            'верни раз в год — и срок не кончится никогда',
      );
    });

    test('на отозванную исходную бумажку новую не выпускают', () async {
      // **Бумажка на 2000, потрачено 1000** — она остаётся годной, и потому
      // её можно отозвать. Первая редакция пробы отзывала погашенную
      // целиком и была зелена по недоразумению: `CertificateDao.cancel`
      // берёт только `active` и `expired`, то есть не делал ничего, и
      // проба мерила не отзыв, а его отсутствие. Отсюда утверждение о
      // состоянии **до** возврата: без него проба вырождается молча.
      await db.certificateDao.insertCertificate(
        number: 'C-1',
        nominal: d('2000'),
        issuedAt: 1600000000,
        status: CertificateStatus.active,
        liabilityAccountId: _liabilityAccount,
      );
      await db.certificateDao.redeem(number: 'C-1', amount: d('1000'));
      await db.certificateDao.cancel('C-1');
      expect(
        (await cert('C-1')).status,
        CertificateStatus.cancelled,
        reason: 'отзыв обязан состояться, иначе мерить нечего',
      );
      await receipt(
        5001,
        total: '1000',
        kindId: SystemPaymentKindIds.certificate,
        accountId: _liabilityAccount,
        reference: 'C-1',
      );

      await expectLater(
        refund(5001, '1000'),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateExhaustedCode,
          ),
        ),
      );
    });
  });

  group('возврат чека, которым сертификат продан', () {
    /// Непотраченная бумажка, проданная чеком [receiptNo].
    Future<void> soldCertificate(
      int receiptNo, {
      String nominal = '5000',
      String? spend,
    }) async {
      await db.certificateDao.insertCertificate(
        number: 'C-9',
        nominal: d(nominal),
        issuedAt: 1600000000,
        status: CertificateStatus.active,
        issuedReceiptNo: receiptNo,
        liabilityAccountId: _liabilityAccount,
      );
      if (spend != null) {
        await db.certificateDao.redeem(number: 'C-9', amount: d(spend));
      }
    }

    test('бумажка гасится, деньги уходят безналично', () async {
      // Карта без номера операции — `RefundRoute.manual`: банк не нужен.
      await receipt(
        7001,
        total: '5000',
        kindId: SystemPaymentKindIds.card,
        accountId: _bankAccount,
      );
      await soldCertificate(7001);

      final refundId = await refund(7001, '5000');

      expect(
        (await cert('C-9')).balance,
        Decimal.zero,
        reason: 'за бумажку вернули деньги — остатка на ней быть не должно',
      );
      expect((await cert('C-9')).status, CertificateStatus.redeemed);

      // Обязательство кассы закрыто: товара она больше не должна.
      expect(await balanceOf(_liabilityAccount), Decimal.zero);

      // Журнал назвал гашение, а не выпуск: новой бумажки здесь не бывает.
      final links = await db.certificateDao.linksByRefund(refundId);
      expect(links, hasLength(1));
      expect(links.single.sourceNumber, 'C-9');
      expect(links.single.issuedNumber, isNull);
      expect(links.single.reason, CertificateRefundReason.redeemed.code);
    });

    test('потраченное деньгами не возвращается', () async {
      // Бумажка на 5000, отоварено 1200. Вернуть 5000 значит отдать эти
      // 1200 дважды: один раз товаром, второй деньгами.
      await receipt(
        7001,
        total: '5000',
        kindId: SystemPaymentKindIds.card,
        accountId: _bankAccount,
      );
      await soldCertificate(7001, spend: '1200');

      await refund(7001, '5000');

      expect(
        await balanceOf(_bankAccount),
        d('1200'),
        reason: 'с банковского счёта ушло 3800 — остаток, а не цена бумажки',
      );
      expect((await cert('C-9')).balance, Decimal.zero);
      expect((await cert('C-9')).status, CertificateStatus.redeemed);
    });

    test('наличными за сертификат — названный отказ, а не выдача', () async {
      await receipt(
        7001,
        total: '5000',
        kindId: SystemPaymentKindIds.cash,
        accountId: _posAccount,
      );
      await soldCertificate(7001);

      await expectLater(
        refund(7001, '5000'),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateCashRefundRefusedCode,
          ),
        ),
      );

      // **Откат целиком**: ни денег из ящика, ни погашенной бумажки.
      expect(await balanceOf(_posAccount), d('5000'));
      expect((await cert('C-9')).balance, d('5000'));
      expect((await cert('C-9')).status, CertificateStatus.active);
      expect(await balanceOf(_liabilityAccount), d('5000'));
    });
  });
}
