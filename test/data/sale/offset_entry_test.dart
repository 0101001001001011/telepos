/// Вход в аванс и сертификат — **касса**: что она отвечает на вопрос об
/// остатке и чего этот вопрос не делает.
///
/// Экран и провод сторожат свои пробы (`payment_offsets_entry_test`,
/// `wt_payment_service_test`); здесь — ответы `LocalPaymentService` на
/// настоящей базе, утверждения о полях: остаток, отказ кодом, и то, что
/// **вопрос ничего не списал**.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
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
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import '../../helpers/cash_drawer.dart';

import '../../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late LocalPaymentService payments;
  late LocalCertificateIssuer issuer;

  const agentMainAccountId = 14;
  const customerId = 5;

  Decimal d(String v) => Decimal.parse(v);

  Matcher refusedWith(String code) =>
      throwsA(isA<WireRefusal>().having((r) => r.code, 'code', code));

  Future<void> enable(int kindId) => db.paymentKindDao.put(
    SystemPaymentKinds.byId(kindId).copyWith(isActive: true),
  );

  Future<void> seedCustomer({
    String advance = '0',
    bool withAccount = true,
  }) async {
    if (withAccount) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: const Value(agentMainAccountId),
              type: AccountType.agentMain,
              name: const Value('Расчёты с Айгуль'),
              value: Value(d(advance)),
              visibleToPos: const Value(false),
            ),
          );
    }
    await db
        .into(db.agents)
        .insert(
          AgentsCompanion(
            localId: const Value(customerId),
            name: const Value('Айгуль'),
            phone: const Value(77015550000),
            mainAccountId: Value(withAccount ? agentMainAccountId : null),
          ),
        );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = Talker();
    final cart = LocalCartService(
      db: db,
      logger: logger,
      initiation: SaleInitiationUseCaseImpl(db: db, logger: logger),
      deferred: DeferredSaleServiceImpl(db: db, logger: logger),
      rounding: SaleRoundOptionUseCaseImpl(),
      findByBarcode: FindByBarcodeUseCaseImpl(db: db, logger: logger),
      searchProducts: SearchProductInfoUseCaseImpl(db: db, logger: logger),
    );
    payments = LocalPaymentService(
      db: db,
      checkout: LocalSaleCheckoutService(db: db, cart: cart, logger: logger),
      sale: SaleUseCaseImpl(db: db, logger: logger),
      logger: logger,
      fiscal: const RefusingFiscalService(),
      drawer: drawerOpens,
    );
    issuer = LocalCertificateIssuer(db: db, logger: logger);
  });

  tearDown(() async => db.close());

  group('остаток аванса', () {
    test('внесённое — ответом кассы, счёт не тронут', () async {
      await enable(SystemPaymentKindIds.prepayment);
      await seedCustomer(advance: '700.5');

      expect(await payments.prepaymentBalance(customerId), d('700.5'));
      expect(
        (await db.accountDao.findById(agentMainAccountId))!.value,
        d('700.5'),
        reason: 'вопрос об остатке ничего не зачитывает',
      );
    });

    test('минус на расчётном счёте — долг, а не аванс: ноль', () async {
      await enable(SystemPaymentKindIds.prepayment);
      await seedCustomer(advance: '-300');

      expect(await payments.prepaymentBalance(customerId), Decimal.zero);
    });

    test('вид выключен — отказ видом, раньше вопросов о покупателе', () async {
      // Покупателя нет вовсе: будь проверка вида второй, ответом был бы
      // `loyalty_customer_unknown`, и кассир лечил бы не то.
      await expectLater(
        payments.prepaymentBalance(customerId),
        refusedWith(payKindInactiveCode),
      );
    });

    test('покупателя нет — loyalty_customer_unknown', () async {
      await enable(SystemPaymentKindIds.prepayment);
      await expectLater(
        payments.prepaymentBalance(99),
        refusedWith(payCustomerUnknownCode),
      );
    });

    test('расчётного счёта нет — prepayment_account_missing', () async {
      await enable(SystemPaymentKindIds.prepayment);
      await seedCustomer(withAccount: false);
      await expectLater(
        payments.prepaymentBalance(customerId),
        refusedWith(payPrepaymentAccountMissingCode),
      );
    });
  });

  group('остаток сертификата', () {
    test('остаток — ответом кассы, бумажка не погашена', () async {
      await enable(SystemPaymentKindIds.certificate);
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
        pin: '1234',
      );

      final found = await payments.findCertificate('  C-1 ', pin: '1234');

      expect(found.balance, d('5000'));
      final row = await db.certificateDao.byNumber('C-1');
      expect(row!.balance, d('5000'), reason: 'вопрос ничего не гасит');
      expect(row.status, CertificateStatus.active);
    });

    test('без ПИНа у бумажки с ПИНом — отказ, остатка не называют', () async {
      await enable(SystemPaymentKindIds.certificate);
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
        pin: '1234',
      );

      // Без ПИНа — «нужен ПИН» (2026-09-15, `certificatePinRequiredCode`),
      // не тот ПИН — «не подошёл»; остатка не называют ни в одном случае.
      await expectLater(
        payments.findCertificate('C-1'),
        refusedWith(certificatePinRequiredCode),
      );
      await expectLater(
        payments.findCertificate('C-1', pin: '0000'),
        refusedWith(certificatePinWrongCode),
      );
    });

    test('вид выключен — отказ видом, а не «нет такого»', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('100'),
      );
      await expectLater(
        payments.findCertificate('C-1'),
        refusedWith(payKindInactiveCode),
      );
    });

    test('нет такого номера — certificate_unknown', () async {
      await enable(SystemPaymentKindIds.certificate);
      await expectLater(
        payments.findCertificate('C-404'),
        refusedWith(certificateUnknownCode),
      );
    });

    test('истёкший — отказ и отметка expired, записанная сразу', () async {
      await enable(SystemPaymentKindIds.certificate);
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('100'),
        expiresAt: 1000,
      );

      await expectLater(
        payments.findCertificate('C-1'),
        refusedWith(certificateExpiredCode),
      );
      expect(
        (await db.certificateDao.byNumber('C-1'))!.status,
        CertificateStatus.expired,
      );
    });
  });
}
