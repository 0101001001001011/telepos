/// `pay.certificateSlip` — повтор печати слипа **из продукта**, а не из
/// пробы: решение заказчика 2026-09-18 «в браузере должно работать то же, что
/// в приложении».
///
/// # Что здесь чинилось, а что нет
///
/// Слип при **выпуске** с планшета печатался и до этой операции: выпуск
/// исполняет касса (`pay.certificateIssue` → `LocalCertificateIssuer`), а она
/// печатает слип внутри выпуска. Комментарий браузерной таблицы маршрутов
/// утверждал обратное («печати слипа у вкладки не будет вовсе»), и это было
/// неверно уже в день, когда он написан.
///
/// Недостижим с планшета был **повтор** — то, ради чего кассир и приходит:
/// бумажка не вышла, покупатель стоит у прилавка с оплаченным чеком.
///
/// # Чего эта проба НЕ доказывает
///
/// - **Что бумажка вышла из принтера.** Печать отправляется и не ожидается
///   (правило дерева «деньги не ждут железа»); здесь мерится, что слип дошёл
///   до порта печати, а не до бумаги.
/// - **Что право охраняет операцию достижимо.** Это мерит
///   `pay_ops_access_test.dart` настоящим сторожем; обработчик здесь зовётся
///   напрямую, сторож не участвует.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/data/payment/local_certificate_slip_reprinter.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/shift/shift_status.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/bare_till_deps.dart';
import 'support/noop_auth.dart';
import '../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late CertificateIssuer issuer;
  late _SpySlips slips;
  late TillOperations ops;

  Decimal d(String v) => Decimal.parse(v);

  /// Сеанс кассира — **источник имени**: кадр его не называет и назвать не
  /// может.
  AuthSession session(int userId) => AuthSession(
    token: 'tok',
    userId: userId,
    name: 'Айгуль',
    role: 'cashier',
    permissions: const {},
    operatingMode: 0,
    pointMode: 'cashier',
    shift: ShiftStatus.open,
    issuedAt: DateTime(2026, 9, 18),
    expiresAt: DateTime(2026, 9, 19),
    terminalId: 7,
  );

  Future<Map<String, Object?>> reprint(
    Map<String, Object?> body, {
    AuthSession? who,
  }) async {
    final result = await ops.askHandlers[PayOps.certificateSlip.name]!(
      body,
      1,
      who,
    );
    return result! as Map<String, Object?>;
  }

  void bootWith({CertificateSlipReprinter? reprinter}) {
    ops = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
      certificates: issuer,
      certificateSlips: reprinter,
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    issuer = LocalCertificateIssuer(db: db, logger: Talker());
    slips = _SpySlips();
    bootWith(
      reprinter: LocalCertificateSlipReprinter(
        certificates: issuer,
        slips: slips,
      ),
    );
    // Бумажка заводится **выпуском**, а не вставкой в таблицу: слип печатают
    // с того, что касса действительно выпустила.
    await issuer.issue(by: fullDiscountAuthority, number: 'C-1', nominal: d('5000'), pin: '4821');
    await issuer.issue(by: fullDiscountAuthority, number: 'C-2', nominal: d('1200.500'));
    // Слип выпуска печатается самим выпуском, и это отдельная запись. Её
    // здесь снимают, чтобы пробы ниже мерили **повтор**, а не её.
    slips.printed.clear();
  });

  tearDown(() => db.close());

  test('кадр провода доводит повтор до очереди печати', () async {
    final answer = await reprint({
      'number': 'C-2',
    }, who: session(4));

    // Ответ — тот, который увидит вкладка: ей есть что показать кассиру.
    expect(answer['number'], 'C-2');
    expect(answer['balance'], '1200.5');
    expect(
      answer.containsKey('pinHash'),
      isFalse,
      reason: 'хэш ПИНа не едет во вкладку ни одной веткой',
    );

    // Несущая часть: слип дошёл до порта печати, и **с полями кассы**, а не
    // кадра — вкладка в кадре не называла ни номинала, ни остатка.
    expect(slips.printed, hasLength(1));
    expect(slips.printed.single.certificate.number, 'C-2');
    expect(slips.printed.single.certificate.nominal, d('1200.5'));
  });

  test('кассир берётся из сеанса, а не из тела кадра', () async {
    // Кадр называет чужое имя. Оно обязано быть выброшено: слип уходит в
    // очередь с именем того, кто его заказал, и назвать вместо себя другого
    // кадр права не имеет — то же правило, по которому он не смеет называть
    // рабочее место.
    await reprint({'number': 'C-2', 'userId': 999}, who: session(4));

    expect(slips.printed.single.userId, 4);
  });

  test('без сеанса слип печатается без имени, а не с выдуманным', () async {
    // Петлевой вызов кассы (`till_operations_loopback_session_test`) сеанса
    // не несёт. Ноль или единица на этом месте были бы именем живого
    // пользователя, которого никто не спрашивал.
    await reprint({'number': 'C-2'});

    expect(slips.printed.single.userId, isNull);
  });

  test('бумажка с ПИНом без ПИНа не печатается', () async {
    // Слип несёт номер и остаток. Напечатать его тому, кто бумажки в руках
    // не держит, значит выдать чужой сертификат по одному подобранному
    // номеру — ровно от этого `lookup` и спрашивает ПИН.
    await expectLater(
      reprint({'number': 'C-1'}, who: session(4)),
      throwsA(isA<WireRefusal>()),
    );

    expect(
      slips.printed,
      isEmpty,
      reason: 'печать обязана не состояться, а не «состояться с отказом»',
    );
  });

  test('не тот ПИН — названный отказ, и ни одного слипа', () async {
    await expectLater(
      reprint({'number': 'C-1', 'pin': '0000'}, who: session(4)),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          certificatePinWrongCode,
        ),
      ),
    );

    expect(slips.printed, isEmpty);
  });

  test('тот ПИН — слип уходит', () async {
    // Страховка от вырождения: запрет, не пропускающий никого, выглядит так
    // же зелено, как запрет, не останавливающий никого.
    await reprint({'number': 'C-1', 'pin': '4821'}, who: session(4));

    expect(slips.printed, hasLength(1));
    expect(slips.printed.single.certificate.number, 'C-1');
  });

  test('нет такого номера — названный отказ, и ни одного слипа', () async {
    await expectLater(
      reprint({'number': 'C-нет'}, who: session(4)),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          certificateUnknownCode,
        ),
      ),
    );

    expect(slips.printed, isEmpty);
  });

  test('касса без печати слипов отказывает названной причиной', () async {
    // Голый процесс `bin/telepos_backend.dart` очереди печати не поднимает.
    // Отвечать «отправлено» в пустоту здесь хуже всего: покупатель стоит у
    // прилавка и ждёт бумажку, которой никто не печатал.
    bootWith();

    await expectLater(
      reprint({'number': 'C-2'}, who: session(4)),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          'certificates_unavailable',
        ),
      ),
    );
  });
}

/// Порт печати, который **записывает** отправленное.
///
/// Подделка, а не очередь: эта проба про путь кадра до порта, а не про
/// ESC/POS. Запись — затем, чтобы «слип отправлен» и «слипа не было»
/// различались величиной, а не верой.
class _SpySlips implements CertificateSlipPrinter {
  final List<({GiftCertificate certificate, int? userId})> printed = [];

  @override
  Future<void> printIssued({
    required GiftCertificate certificate,
    int? userId,
    int? refundLocalId,
    String? sourceNumber,
  }) async {
    printed.add((certificate: certificate, userId: userId));
  }

  @override
  List<CertificateSlipTrouble> takeTroubles() => const [];

  @override
  Future<void> get pending => Future<void>.value();
}
