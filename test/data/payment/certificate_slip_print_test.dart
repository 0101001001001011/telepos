/// Выпуск сертификата печатает слип — решение заказчика 2026-09-16.
///
/// # Что здесь измерено до правки
///
/// Ничего: печати не было вовсе. `LocalCertificateIssuer.issue` заводила
/// строку и обязательство на счёте, а на руки покупателю не давала ничего —
/// номер бумажки кассир переписывал от руки либо не переписывал.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что бумага вышла из принтера: служба печати здесь подставная, и мерится
/// **состав документа и то, что его вообще собрали**. Байты и ширину ленты
/// меряет `test/unit/hardware/certificate_slip_wire_test.dart` через эмулятор
/// ESC/POS.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/payment/local_certificate_slip_printer.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';

import '../../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late Talker logger;
  late _SlipSpy spy;
  late LocalCertificateSlipPrinter slips;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> boot({bool withPrinter = true}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logger = Talker();
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            cashBoxName: Value('Касса 1'),
            companyName: Value('ТОО Ромашка'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));

    await GetIt.I.reset();
    spy = _SlipSpy();
    if (withPrinter) {
      GetIt.I.registerSingleton<ReceiptPrintService>(spy);
    }
    slips = LocalCertificateSlipPrinter(db: db, logger: logger);
  }

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  test('выпуск отдаёт слип в печать: номер, сумма, кассир', () async {
    await boot();
    final issuer = LocalCertificateIssuer(db: db, logger: logger, slips: slips);

    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('5000'),
      userId: 4,
    );
    // Печать **отправляется, а не ожидается**: даём ей дойти до вызванного,
    // но выпуска это не касается.
    await slips.pending;

    expect(
      spy.slips,
      hasLength(1),
      reason:
          'ЭТО ВСЯ ЗАДАЧА: без слипа покупатель уходит от прилавка с пустыми '
          'руками, имея на кассе годный сертификат',
    );
    final slip = spy.slips.single;
    expect(slip.number, 'C-1');
    expect(slip.amount, d('5000'));
    expect(slip.cashierName, 'Айгуль', reason: 'кассир — из таблицы, не «Cashier»');
    expect(slip.storeName, 'ТОО Ромашка');
    expect(slip.posName, 'Касса 1');
    expect(
      slip.refundLocalId,
      isNull,
      reason: 'обычный выпуск возвратом не рождён — строк про возврат быть не '
          'должно',
    );
  });

  test('ПИН на слип не едет — только факт «задан»', () async {
    await boot();
    final issuer = LocalCertificateIssuer(db: db, logger: logger, slips: slips);

    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-2',
      nominal: d('1000'),
      pin: '4821',
    );
    await slips.pending;

    final slip = spy.slips.single;
    expect(slip.hasPin, isTrue, reason: 'кассир должен знать, что ПИН понадобится');
    // Поля под ПИН у документа нет вовсе — это и есть заслон. Утверждение
    // стоит затем, чтобы поле нельзя было завести молча.
    expect(
      slip.toString(),
      isNot(contains('4821')),
      reason: 'номер и ПИН рядом на бумажке обнуляют весь тираж',
    );
  });

  test('срок бумажки доезжает до слипа', () async {
    await boot();
    final issuer = LocalCertificateIssuer(db: db, logger: logger, slips: slips);

    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-3',
      nominal: d('1000'),
      expiresAt: DateTime.utc(2027, 12, 31).millisecondsSinceEpoch ~/ 1000,
    );
    await slips.pending;

    expect(spy.slips.single.expiresAt, isNotNull);
    expect(spy.slips.single.expiresAt!.year, 2027);
  });

  test('касса без принтера выпускает сертификат так же', () async {
    // Печать не входит в деньги: обязательство берётся и без принтера.
    await boot(withPrinter: false);
    final issuer = LocalCertificateIssuer(db: db, logger: logger, slips: slips);

    final issued = await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-4',
      nominal: d('700'),
    );
    await slips.pending;

    expect(issued.number, 'C-4');
    expect(issued.balance, d('700'));
    expect(spy.slips, isEmpty);
    expect(
      slips.takeTroubles(),
      isEmpty,
      reason:
          'принтера нет вовсе — это настройка кассы, а не беда печати: '
          'жаловаться кассиру не на что',
    );
  });

  test('очередь не приняла слип — выпуск состоялся, беда названа', () async {
    await boot();
    spy.reject = 'В принтере кончилась бумага';
    final issuer = LocalCertificateIssuer(db: db, logger: logger, slips: slips);

    final issued = await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-5',
      nominal: d('300'),
    );
    await slips.pending;

    expect(
      issued.balance,
      d('300'),
      reason: 'отказ принтера не имеет права отменить выпуск',
    );
    final troubles = slips.takeTroubles();
    expect(troubles, hasLength(1));
    expect(troubles.single.number, 'C-5');
    expect(troubles.single.message, 'В принтере кончилась бумага');
    expect(
      slips.takeTroubles(),
      isEmpty,
      reason: 'беда читается один раз и снимается — как у продажи',
    );
  });
}

/// Служба печати, которая запоминает слипы и умеет отказывать.
class _SlipSpy implements ReceiptPrintService {
  final slips = <CertificateSlipData>[];

  /// `null` — очередь приняла; строка — отказала с этой причиной.
  String? reject;

  @override
  Future<PrintSubmitOutcome> printCertificateSlip(CertificateSlipData data) async {
    slips.add(data);
    final why = reject;
    return why == null
        ? PrintSubmitOutcome.accepted('slip-${data.number}')
        : PrintSubmitOutcome.rejected('slip-${data.number}', why);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}
