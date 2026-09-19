/// Сборка отчёта смены доносит числа сертификатов **из базы**, а не из нуля.
///
/// # Зачем отдельная проба между журналом и бумагой
///
/// Потому что звеньев три, и разорвать можно любое: запрос к базе, сборка
/// `ShiftReceipt` и печать. Байты на ленте меряет
/// `test/unit/hardware/certificate_shift_line_wire_test.dart`, источник и
/// сходимость со счётом обязательства —
/// `test/data/payment/certificate_shift_totals_test.dart`, а здесь среднее
/// звено: что сборка спрашивает базу **тем же окном и тем же кассиром**,
/// какими считает выручку, и кладёт ответ в отчёт, а не забывает поле.
///
/// Забытое поле — не выдумка: оба числа имеют умолчание `Decimal.zero` в
/// конструкторе `ShiftReceipt` (иначе каждый вызывающий отчёта смены
/// перестал бы собираться), и сборка, не передавшая их, дала бы честный с
/// виду ноль.
///
/// # Чего эта проба НЕ доказывает
///
/// Не доказывает, что числа верные по учёту: сходимость со счётом
/// обязательства проверяется отдельно и на настоящем пути кассы.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/usecases/shift/assemble_shift_receipt_use_case_impl.dart';
import 'package:telepos/data/usecases/shift/custom_bank_payments_sum_use_case_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/usecases/shift/assemble_shift_receipt_use_case.dart';

import '../../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late AssembleShiftReceiptUseCase assemble;
  late CertificateIssuer issuer;

  const cashierId = 4;
  const otherCashierId = 5;
  const posAccountId = 11;
  late int shiftOpen;
  late int shiftId;

  Decimal d(String v) => Decimal.parse(v);

  /// Строка гашения — **записью в журнал оплат**, а не продажей: здесь
  /// проверяется сборка отчёта, и настоящий путь кассы участвует в
  /// `certificate_shift_totals_test.dart`.
  Future<void> redemptionRow({
    required Decimal amount,
    required int at,
    int userId = cashierId,
  }) async {
    final accounts = await db.accountDao.findByType(
      AccountType.certificateLiability,
    );
    await db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            userId: userId,
            payeeAccountId: accounts.first.id,
            amount: amount,
            time: at,
            receiptNo: const Value(1),
            posId: const Value(1),
            kindId: const Value(SystemPaymentKindIds.certificate),
            seq: Value(at),
          ),
        );
  }

  setUp(() async {
    shiftOpen = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            cashBoxName: Value('Касса 1'),
            companyName: Value('ТОО ТестПОС'),
          ),
        );
    await db
        .into(db.users)
        .insert(
          const UsersCompanion(id: Value(cashierId), name: Value('Айгуль')),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value(posAccountId),
            type: AccountType.pos,
            name: const Value('Касса'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
          ),
        );
    shiftId = await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion(
            userId: const Value(cashierId),
            openTime: Value(shiftOpen),
            isOpened: const Value(true),
            isSynced: const Value(false),
          ),
        );

    final logger = Talker();
    assemble = AssembleShiftReceiptUseCaseImpl(
      db: db,
      paymentsSumUseCase: CustomBankPaymentsSumUseCaseImpl(
        db: db,
        logger: logger,
      ),
      logger: logger,
    );
    issuer = LocalCertificateIssuer(db: db, logger: logger);
  });

  tearDown(() => db.close());

  test('выпущенное и погашенное доезжают до отчёта смены', () async {
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('5000'),
    );
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-2',
      nominal: d('2000'),
    );
    await redemptionRow(amount: d('1200.50'), at: shiftOpen + 600);

    final receipt = (await assemble.assemble(shiftId, d('1250')))!;

    expect(receipt.certificatesIssued, d('7000'));
    expect(receipt.certificatesRedeemed, d('1200.50'));
  });

  test('без сертификатов оба числа — ноль, а не null', () async {
    final receipt = (await assemble.assemble(shiftId, d('1250')))!;

    expect(receipt.certificatesIssued, Decimal.zero);
    expect(receipt.certificatesRedeemed, Decimal.zero);
  });

  test('окно смены — то же, каким считается выручка', () async {
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-OLD',
      nominal: d('9000'),
    );
    await (db.update(db.giftCertificates)
          ..where((c) => c.number.equals('C-OLD')))
        .write(GiftCertificatesCompanion(issuedAt: Value(shiftOpen - 7200)));
    await redemptionRow(amount: d('333'), at: shiftOpen - 7200);

    final receipt = (await assemble.assemble(shiftId, d('1250')))!;

    expect(
      receipt.certificatesIssued,
      Decimal.zero,
      reason: 'бумажка прошлой смены попала в эту — отчёт врёт про обе',
    );
    expect(receipt.certificatesRedeemed, Decimal.zero);
  });

  test('гашение чужой смены в отчёт не попадает', () async {
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-1',
      nominal: d('5000'),
    );
    await redemptionRow(
      amount: d('444'),
      at: shiftOpen + 600,
      userId: otherCashierId,
    );

    final receipt = (await assemble.assemble(shiftId, d('1250')))!;

    expect(
      receipt.certificatesRedeemed,
      Decimal.zero,
      reason: 'сборка отбирает оплаты по кассиру смены — как и выручку',
    );
    // Слом в обратную сторону: своё гашение считается.
    await redemptionRow(amount: d('100'), at: shiftOpen + 700);
    final again = (await assemble.assemble(shiftId, d('1250')))!;
    expect(again.certificatesRedeemed, d('100'));
  });

  // ── выпуск и кассир: хвост, закрытый 2026-09-19 ───────────────────────
  //
  // У гашения проба на чужую смену была с самого начала (выше), у выпуска
  // — нет, и не случайно: отбирать было нечего. Провод
  // (`pay.certificateIssue`) не передавал `userId` вовсе, поле
  // `issued_by_user_id` было пусто у **каждой** бумажки с планшета, и
  // строгая половина запроса не срабатывала ни разу. Докстринг
  // `CertificateDao.issuedNominalBetween` это называл и просил проверить
  // отбор, когда провод начнёт передавать кассира. Начал — вот проверка.
  //
  // # Чего эти две пробы НЕ доказывают
  //
  // Не доказывают, что провод передаёт кассира: это меряется на кадре
  // провода (`test/backend/certificate_issue_op_test.dart`). Здесь
  // проверяется **следствие** — что при заполненном поле отбор режет, а
  // при пустом по-прежнему пропускает.
  test('выпуск чужой смены в отчёт не попадает', () async {
    await issuer.issue(
      by: fullDiscountAuthority,
      number: 'C-ЧУЖ',
      nominal: d('5000'),
      userId: otherCashierId,
    );

    final receipt = (await assemble.assemble(shiftId, d('1250')))!;

    expect(
      receipt.certificatesIssued,
      Decimal.zero,
      reason: 'бумажка чужого кассира в строке этой смены — отчёт врёт '
          'про обязательство обеих',
    );

    // Слом в обратную сторону: свой выпуск считается. Без него проба
    // зеленела бы и от запроса, который не считает вовсе ничего.
    await issuer.issue(by: fullDiscountAuthority, number: 'C-СВОЙ', nominal: d('700'), userId: cashierId);
    final again = (await assemble.assemble(shiftId, d('1250')))!;
    expect(again.certificatesIssued, d('700'));
  });

  test('бумажка без кассира остаётся за этой сменой', () async {
    // Строки, выпущенные **до** правки провода: поле пусто навсегда, и
    // задним числом требовать от них совпадения значило бы вычесть их из
    // уже напечатанных отчётов. Мягкость снята не будет — эта проба и
    // есть то, что покраснеет, если её всё-таки снимут.
    await issuer.issue(by: fullDiscountAuthority, number: 'C-СТАР', nominal: d('3000'));

    final receipt = (await assemble.assemble(shiftId, d('1250')))!;

    expect(receipt.certificatesIssued, d('3000'));
  });
}
