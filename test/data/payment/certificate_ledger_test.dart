/// Сертификат как **учёт**, а не как строка оплаты: выпуск, остаток,
/// срок, повторное предъявление.
///
/// # Почему утверждения здесь о полях, а не о суммах
///
/// Баланс сумм — слабая проверка, и на сертификате это видно как нигде:
/// «Σ строк оплаты == сумма чека» держится и у кассы, которая списала
/// сертификат дважды, и у кассы, которая не списала его вовсе. Обе
/// оставляют чек в идеальном равновесии и обе раздают товар даром.
/// Поэтому каждый случай здесь утверждает про **сам остаток**: чему он
/// равен, чему равно состояние, и **чему они равны, когда попытка не
/// удалась**.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import '../../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late CertificateIssuer issuer;

  Decimal d(String v) => Decimal.parse(v);

  int inDays(int days) =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + days * 86400;

  Future<GiftCertificate> row(String number) async =>
      (await db.certificateDao.byNumber(number))!;

  Future<Decimal> liabilityBalance() async {
    final accounts = await db.accountDao.findByType(
      AccountType.certificateLiability,
    );
    if (accounts.isEmpty) return Decimal.zero;
    return accounts.first.value ?? Decimal.zero;
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    issuer = LocalCertificateIssuer(db: db, logger: Talker());
  });

  tearDown(() => db.close());

  group('выпуск — это не оплата товара', () {
    test('номинал ложится обязательством кассы, а не выручкой', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );

      // Утверждение о **роде счёта**, а не о числе: число сойдётся и
      // тогда, когда номинал ляжет на счёт кассы, — и это будет удвоенная
      // выручка, а не обязательство.
      final posAccounts = await db.accountDao.findByType(AccountType.pos);
      expect(
        posAccounts,
        isEmpty,
        reason: 'выпуск сертификата не заводит и не двигает счёт выручки',
      );

      expect(await liabilityBalance(), d('5000'));
      expect((await row('C-1')).balance, d('5000'));
      expect((await row('C-1')).nominal, d('5000'));
      expect((await row('C-1')).status, CertificateStatus.active);
    });

    test('ПИН лежит хэшем, а не текстом', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
        pin: '4821',
      );

      final hash = (await row('C-1')).pinHash!;
      expect(
        hash,
        isNot(contains('4821')),
        reason: 'номер и ПИН рядом в открытом виде обнуляют весь тираж',
      );
      expect(hash, startsWith('pbkdf2\$sha256\$'));

      // Слом в обе стороны: хэш обязан **подходить** к своему ПИНу.
      final found = await issuer.lookup(number: 'C-1', pin: '4821');
      expect(found.balance, d('5000'));
    });

    test('второй выпуск под тем же номером отвергается', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );

      await expectLater(
        issuer.issue(
          by: fullDiscountAuthority,
          number: 'C-1',
          nominal: d('100'),
        ),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateDuplicateNumberCode,
          ),
        ),
      );

      // Главное здесь — **не отказ, а остаток**: второй выпуск на 100
      // обнулил бы 5000, внесённые покупателем.
      expect((await row('C-1')).balance, d('5000'));
      expect((await row('C-1')).nominal, d('5000'));
      expect(await liabilityBalance(), d('5000'));
    });

    test('неположительный номинал отвергается до записи', () async {
      for (final bad in ['0', '-100']) {
        await expectLater(
          issuer.issue(
            by: fullDiscountAuthority,
            number: 'C-$bad',
            nominal: d(bad),
          ),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              certificateNominalInvalidCode,
            ),
          ),
        );
        expect(await db.certificateDao.byNumber('C-$bad'), isNull);
      }
      expect(await liabilityBalance(), Decimal.zero);
    });
  });

  group('предъявление', () {
    test('чужой номер — отказ, называющий именно это', () async {
      await expectLater(
        issuer.lookup(number: 'C-НЕТ'),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateUnknownCode,
          ),
        ),
      );
    });

    test('неверный ПИН не выдаёт ни остатка, ни срока', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
        pin: '4821',
        expiresAt: inDays(30),
      );

      Object? caught;
      try {
        await issuer.lookup(number: 'C-1', pin: '0000');
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<WireRefusal>());
      final refusal = caught! as WireRefusal;
      expect(refusal.code, certificatePinWrongCode);
      expect(
        refusal.message,
        isNot(contains('5000')),
        reason: 'тот, кто бумажки не держит, не узнаёт остатка',
      );
    });

    // Пустой ПИН — «нужен ПИН», а не «ПИН не подошёл» (2026-09-15): кассир,
    // не набравший ПИН, читал «не подошёл» и перенабирал номер. Пропуска
    // замок при этом не даёт — код в `certificateGuessCodes`, проба
    // `certificate_throttle_op_test.dart`.
    for (final pin in [null, '', '   ']) {
      test('пустой ПИН к защищённому сертификату — «нужен ПИН» ($pin)',
          () async {
        await issuer.issue(
          by: fullDiscountAuthority,
          number: 'C-1',
          nominal: d('5000'),
          pin: '4821',
        );
        await expectLater(
          issuer.lookup(number: 'C-1', pin: pin),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              'certificate_pin_required',
            ),
          ),
        );
      });
    }

    // Замок перебора засчитывает неудачу заявки только номеру из `subject`
    // (пункт 6 A7) — значит его обязан ставить настоящий `lookup`, а не
    // только подделка пробы замка.
    test('отказы подбора называют номер полем subject', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
        pin: '4821',
      );
      for (final (number, pin, code) in [
        (' C-НЕТ ', '4821', certificateUnknownCode),
        (' C-1 ', '0000', certificatePinWrongCode),
        (' C-1 ', null, certificatePinRequiredCode),
      ]) {
        await expectLater(
          issuer.lookup(number: number, pin: pin),
          throwsA(
            isA<WireRefusal>()
                .having((r) => r.code, 'code', code)
                .having((r) => r.subject, 'subject', number.trim()),
          ),
        );
      }
    });

    test('ПИН к сертификату без ПИНа не спрашивается', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      expect((await issuer.lookup(number: 'C-1')).balance, d('5000'));
    });
  });

  group('срок', () {
    test('просроченный ПОМЕЧАЕТСЯ, а не прячется фильтром', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
        expiresAt: inDays(-1),
      );
      expect((await row('C-1')).status, CertificateStatus.active);

      await expectLater(
        issuer.lookup(number: 'C-1'),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateExpiredCode,
          ),
        ),
      );

      // **Главное утверждение случая.** Отметка обязана пережить отказ:
      // без неё касса на каждой следующей попытке снова считала бы
      // сертификат активным, и «срок вышел» не было бы состоянием — было
      // бы мнением.
      expect((await row('C-1')).status, CertificateStatus.expired);

      // И, помеченный, он не воскресает: повтор отвечает тем же словом.
      await expectLater(
        issuer.lookup(number: 'C-1'),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateExpiredCode,
          ),
        ),
      );
    });

    test('срок, который ещё не вышел, ничего не помечает', () async {
      // Слом в обе стороны: сторож, помечающий всё подряд, погасил бы
      // весь тираж.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
        expiresAt: inDays(1),
      );
      final found = await issuer.lookup(number: 'C-1');
      expect(found.balance, d('5000'));
      expect((await row('C-1')).status, CertificateStatus.active);
    });

    test('бессрочный не истекает никогда', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      expect((await issuer.lookup(number: 'C-1')).balance, d('5000'));
      expect((await row('C-1')).status, CertificateStatus.active);
    });
  });

  group('условное гашение — заслон, а не расчёт', () {
    test('частичное гашение оставляет остаток и годность', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );

      final touched = await db.certificateDao.redeem(
        number: 'C-1',
        amount: d('1200'),
      );

      expect(touched, 1);
      expect((await row('C-1')).balance, d('3800'));
      expect((await row('C-1')).status, CertificateStatus.active);
    });

    test('гашение в ноль переводит состояние ТОЙ ЖЕ записью', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      await db.certificateDao.redeem(number: 'C-1', amount: d('5000'));

      expect((await row('C-1')).balance, Decimal.zero);
      expect(
        (await row('C-1')).status,
        CertificateStatus.redeemed,
        reason: 'между двумя записями сертификат с нулём выглядит активным',
      );
    });

    test('повторное предъявление погашенного не трогает ничего', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      await db.certificateDao.redeem(number: 'C-1', amount: d('5000'));

      final touched = await db.certificateDao.redeem(
        number: 'C-1',
        amount: d('1'),
      );

      expect(touched, 0, reason: 'ноль строк — это отказ, а не «получилось»');
      expect((await row('C-1')).balance, Decimal.zero);
      expect(
        (await row('C-1')).status,
        CertificateStatus.redeemed,
        reason: 'состояние не откатилось в active',
      );

      await expectLater(
        issuer.lookup(number: 'C-1'),
        throwsA(
          isA<WireRefusal>().having(
            (r) => r.code,
            'code',
            certificateExhaustedCode,
          ),
        ),
      );
    });

    test('гашение сверх остатка не списывает НИЧЕГО', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('1000'),
      );

      final touched = await db.certificateDao.redeem(
        number: 'C-1',
        amount: d('1000.001'),
      );

      expect(touched, 0);
      expect(
        (await row('C-1')).balance,
        d('1000'),
        reason: 'частичного списания «сколько было» здесь нет и быть не '
            'может: тогда чек оплачен не полностью, а бумажка пуста',
      );
      expect((await row('C-1')).status, CertificateStatus.active);
    });

    test('отозванный не гасится', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      await issuer.cancel('C-1');

      expect(await db.certificateDao.redeem(number: 'C-1', amount: d('1')), 0);
      expect((await row('C-1')).balance, d('5000'));
    });

    test('просроченный не гасится', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
        expiresAt: inDays(-1),
      );
      await db.certificateDao.markExpired('C-1');

      expect(await db.certificateDao.redeem(number: 'C-1', amount: d('1')), 0);
      expect((await row('C-1')).balance, d('5000'));
    });
  });

  group('копейки не теряются', () {
    /// Ровно тот случай, ради которого остаток лежит целыми тысячными, а
    /// не `double`. В двойной точности `500 − 0.1 − 0.1 − 0.1` даёт
    /// `499.69999999999993`, и `DecimalConverter` честно поднял бы это как
    /// деньги, которых никто не вводил.
    test('тридцать гашений по десять тиынов дают ровно 497', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('500'),
      );
      for (var i = 0; i < 30; i++) {
        expect(
          await db.certificateDao.redeem(number: 'C-1', amount: d('0.1')),
          1,
        );
      }
      expect((await row('C-1')).balance, d('497'));
      expect(
        (await row('C-1')).balance.toString(),
        '497',
        reason: 'ни одного лишнего знака: деньги не «почти равны»',
      );
    });

    test('остаток в тысячных списывается ровно', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('10.005'),
      );
      expect(
        await db.certificateDao.redeem(number: 'C-1', amount: d('10.005')),
        1,
      );
      expect((await row('C-1')).balance, Decimal.zero);
      expect((await row('C-1')).status, CertificateStatus.redeemed);
    });
  });

  group('гашение остатка — возврат чека, которым бумажку продали', () {
    // # Здесь была группа «возврат на сертификат» — снята 2026-09-16
    //
    // Четыре пробы меряли `CertificateDao.restore`: возврат доли **на ту же
    // бумажку**, потолок номинала, повтор и отзыв. Заказчик решение отменил
    // (пункт 2): сертификат не восстанавливается никак, покупатель получает
    // новую бумажку. Метод удалён, и пробы к нему сняты вместе с ним —
    // проба к снятой работе не краснеет, а зеленеет впустую.
    //
    // Что пришло взамен и где это меряется, названо поимённо, чтобы снятие
    // нельзя было спутать с потерей покрытия:
    //
    // - выпуск новой бумажки, наследование срока, журнал связи и заслон от
    //   двойного выпуска — `test/domain/usecases/refund/
    //   refund_certificate_reissue_test.dart`;
    // - гашение проданной бумажки и запрет наличных — там же и в
    //   `refund_certificate_sale_test.dart` (настоящий путь продажи);
    // - сам ключ журнала — `test/data/database/
    //   migration_v48_certificate_refund_links_test.dart`.
    //
    // Ниже — пробы [CertificateDao.redeemRemainder], заменившей `restore` в
    // роли «условная запись, которой возврат трогает бумажку».

    test('гасит весь остаток одной инструкцией', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      await db.certificateDao.redeem(number: 'C-1', amount: d('1200'));
      expect((await row('C-1')).balance, d('3800'));

      expect(await db.certificateDao.redeemRemainder('C-1'), 1);

      expect((await row('C-1')).balance, Decimal.zero);
      expect(
        (await row('C-1')).status,
        CertificateStatus.redeemed,
        reason: 'за бумажку вернули деньги — предъявлять её больше нечем',
      );
    });

    test('просроченную гасит тоже', () async {
      // Срок вышел, но деньги за неё касса возвращает. Оставить её
      // «истёкшей с остатком» значило бы оставить обязательство, которое
      // кто-нибудь однажды восстановит.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      await db.certificateDao.markExpired('C-1');
      expect((await row('C-1')).status, CertificateStatus.expired);

      expect(await db.certificateDao.redeemRemainder('C-1'), 1);
      expect((await row('C-1')).balance, Decimal.zero);
    });

    test('отозванную не трогает: её уже погасил владелец', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );
      await issuer.cancel('C-1');

      expect(await db.certificateDao.redeemRemainder('C-1'), 0);
      expect(
        (await row('C-1')).status,
        CertificateStatus.cancelled,
        reason: 'отзыв владельца не переписывается гашением',
      );
    });

    test('повтор гашения ничего не трогает', () async {
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );

      expect(await db.certificateDao.redeemRemainder('C-1'), 1);
      expect(
        await db.certificateDao.redeemRemainder('C-1'),
        0,
        reason: 'ноль строк — «гасить было нечего», и вызывающий это читает',
      );
      expect((await row('C-1')).balance, Decimal.zero);
    });
  });
}
