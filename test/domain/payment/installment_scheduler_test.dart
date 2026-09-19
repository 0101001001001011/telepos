/// График рассрочки — **арифметика подписанного договора**.
///
/// # Почему неделящийся остаток обязателен в каждой пробе
///
/// Проба на круглом теле (10 000 на 4 месяца) **ничего не доказывает**:
/// она зелена и у планировщика, который выбрасывает остаток, потому что
/// остатка нет. Взято `10000.001` — тысячная, которая не делится ни на 3,
/// ни на 6, ни на 12, ни на 24, и потому обязана где-то лежать.
///
/// Проверено диверсией: последняя строка получает `base` вместо
/// `total − base × (N−1)` — то есть остаток выбрасывается. На круглом теле
/// набор остаётся **зелёным**, на `10000.001` краснеют 12 сочетаний из 12.
///
/// # Почему утверждений три, а не одно
///
/// «Сумма сошлась» — слабая проверка того же класса, что «Σ строк оплаты
/// == сумма чека»: она зелена и у планировщика, который свалил всё в один
/// платёж, и у того, который раздал отрицательные суммы. Поэтому рядом
/// стоят утверждения **о самих полях**: число строк, монотонность
/// номеров, положительность каждого платежа и раздельное схождение тела и
/// надбавки.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  final firstDue = DateTime(2026, 10, 15);

  group('Σ графика равна подписанному', () {
    test('Σ totalDue == principal + feeTotal на всех 12 сочетаниях', () {
      for (final scheme in InstallmentScheme.values) {
        for (final term in InstallmentScheduler.allowedTerms) {
          final lines = InstallmentScheduler.build(
            principal: d('10000.001'),
            feeTotal: Decimal.zero,
            termMonths: term,
            firstDueDate: firstDue,
            scheme: scheme,
          );
          expect(
            lines.fold(Decimal.zero, (Decimal s, l) => s + l.totalDue),
            d('10000.001'),
            reason: '${scheme.code}/$term',
          );
        }
      }
    });

    test(
      'тело и надбавка сходятся ПОРОЗНЬ — на всех 12 сочетаниях',
      () {
        // Раздельное утверждение ловит то, чего не ловит общая сумма:
        // планировщик, переложивший тысячную из тела в надбавку, даёт ту
        // же сумму и **другой договор** — в нём покупатель должен другую
        // сумму основного долга, а это разные деньги при досрочном
        // погашении.
        for (final scheme in InstallmentScheme.values) {
          for (final term in InstallmentScheduler.allowedTerms) {
            final lines = InstallmentScheduler.build(
              principal: d('10000.001'),
              feeTotal: d('1500.007'),
              termMonths: term,
              firstDueDate: firstDue,
              scheme: scheme,
            );
            expect(
              lines.fold(Decimal.zero, (Decimal s, l) => s + l.principalDue),
              d('10000.001'),
              reason: 'тело ${scheme.code}/$term',
            );
            expect(
              lines.fold(Decimal.zero, (Decimal s, l) => s + l.feeDue),
              d('1500.007'),
              reason: 'надбавка ${scheme.code}/$term',
            );
          }
        }
      },
    );

    test('остаток ложится в ПОСЛЕДНИЙ платёж, а не растворяется', () {
      // 10000.001 на 3 месяца: 10000001 тысячных ÷ 3 = 3333333 и одна
      // тысячная в остатке. Правило одно на все схемы — усечь вниз,
      // последнему отдать всё нероспределённое.
      final lines = InstallmentScheduler.build(
        principal: d('10000.001'),
        feeTotal: Decimal.zero,
        termMonths: 3,
        firstDueDate: firstDue,
        scheme: InstallmentScheme.equalInstalments,
      );
      expect(lines[0].principalDue, d('3333.333'));
      expect(lines[1].principalDue, d('3333.333'));
      expect(lines[2].principalDue, d('3333.335'));
    });
  });

  group('поля графика, а не только сумма', () {
    test('строк ровно столько, сколько месяцев, и seq идёт от нуля', () {
      for (final term in InstallmentScheduler.allowedTerms) {
        final lines = InstallmentScheduler.build(
          principal: d('10000.001'),
          feeTotal: d('7'),
          termMonths: term,
          firstDueDate: firstDue,
          scheme: InstallmentScheme.differentiated,
        );
        expect(lines.length, term);
        expect([for (final l in lines) l.seq], [for (var i = 0; i < term; i++) i]);
      }
    });

    test('ни один платёж не отрицателен и ни один не пуст', () {
      for (final scheme in InstallmentScheme.values) {
        for (final term in InstallmentScheduler.allowedTerms) {
          final lines = InstallmentScheduler.build(
            principal: d('10000.001'),
            feeTotal: d('1500.007'),
            termMonths: term,
            firstDueDate: firstDue,
            scheme: scheme,
          );
          for (final l in lines) {
            expect(
              l.totalDue > Decimal.zero,
              isTrue,
              reason: '${scheme.code}/$term строка ${l.seq}: ${l.totalDue}',
            );
            expect(l.feeDue >= Decimal.zero, isTrue, reason: '${scheme.code}');
          }
        }
      }
    });

    test('схемы РАЗНЫЕ: одна и та же сумма ложится по-разному', () {
      // Без этого утверждения три схемы могли бы оказаться одной под
      // тремя именами — и выбор кассира ничего бы не значил, а договор
      // печатался бы с чужим названием схемы.
      List<Decimal> totals(InstallmentScheme scheme) => [
        for (final l in InstallmentScheduler.build(
          principal: d('12000'),
          feeTotal: d('1200'),
          termMonths: 6,
          firstDueDate: firstDue,
          scheme: scheme,
        ))
          l.totalDue,
      ];

      final equal = totals(InstallmentScheme.equalInstalments);
      final diff = totals(InstallmentScheme.differentiated);
      final upfront = totals(InstallmentScheme.feeUpfront);

      // Равные — все одинаковые.
      expect(equal.toSet().length, 1, reason: 'равными платежами');
      // Убывающие — первый строго больше последнего.
      expect(diff.first > diff.last, isTrue, reason: 'убывающими');
      // Надбавка первым платежом — первый больше остальных, остальные
      // равны между собой.
      expect(upfront.first > upfront[1], isTrue);
      expect(upfront.skip(1).toSet().length, 1);
    });
  });

  group('даты', () {
    test('срок платежа — каждый месяц, первый в названную дату', () {
      final lines = InstallmentScheduler.build(
        principal: d('1200'),
        feeTotal: Decimal.zero,
        termMonths: 3,
        firstDueDate: DateTime(2026, 10, 15),
        scheme: InstallmentScheme.equalInstalments,
      );
      DateTime at(int i) =>
          DateTime.fromMillisecondsSinceEpoch(lines[i].dueDate * 1000);
      expect(at(0), DateTime(2026, 10, 15));
      expect(at(1), DateTime(2026, 11, 15));
      expect(at(2), DateTime(2026, 12, 15));
    });

    test('31 января + месяц это 28 февраля, а НЕ 3 марта', () {
      // `DateTime(y, m + 1, 31)` в Dart переполняется в следующий месяц.
      // Договор, подписанный 31 января на год, получил бы график, в
      // котором февраля нет вовсе, а март встречается дважды.
      final lines = InstallmentScheduler.build(
        principal: d('1200'),
        feeTotal: Decimal.zero,
        termMonths: 3,
        firstDueDate: DateTime(2026, 1, 31),
        scheme: InstallmentScheme.equalInstalments,
      );
      DateTime at(int i) =>
          DateTime.fromMillisecondsSinceEpoch(lines[i].dueDate * 1000);
      expect(at(0), DateTime(2026, 1, 31));
      expect(at(1), DateTime(2026, 2, 28), reason: '2026 — не високосный');
      expect(at(2), DateTime(2026, 3, 31), reason: 'день возвращается');
    });

    test('високосный год: 31 января + месяц это 29 февраля', () {
      final lines = InstallmentScheduler.build(
        principal: d('1200'),
        feeTotal: Decimal.zero,
        termMonths: 3,
        firstDueDate: DateTime(2028, 1, 31),
        scheme: InstallmentScheme.equalInstalments,
      );
      expect(
        DateTime.fromMillisecondsSinceEpoch(lines[1].dueDate * 1000),
        DateTime(2028, 2, 29),
      );
    });

    test('перевал через год: декабрь + месяц это январь следующего', () {
      final lines = InstallmentScheduler.build(
        principal: d('1200'),
        feeTotal: Decimal.zero,
        termMonths: 3,
        firstDueDate: DateTime(2026, 12, 10),
        scheme: InstallmentScheme.equalInstalments,
      );
      expect(
        DateTime.fromMillisecondsSinceEpoch(lines[1].dueDate * 1000),
        DateTime(2027, 1, 10),
      );
    });
  });

  group('отказы приходят значением', () {
    test('срок вне списка — credit_term_invalid', () {
      expect(
        () => InstallmentScheduler.build(
          principal: d('1000'),
          feeTotal: Decimal.zero,
          termMonths: 5,
          firstDueDate: firstDue,
          scheme: InstallmentScheme.equalInstalments,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            creditTermInvalidCode,
          ),
        ),
      );
    });

    test('тело не положительно — credit_principal_invalid', () {
      expect(
        () => InstallmentScheduler.build(
          principal: Decimal.zero,
          feeTotal: Decimal.zero,
          termMonths: 3,
          firstDueDate: firstDue,
          scheme: InstallmentScheme.equalInstalments,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            creditPrincipalInvalidCode,
          ),
        ),
      );
    });

    test('надбавка отрицательна — credit_fee_invalid', () {
      expect(
        () => InstallmentScheduler.build(
          principal: d('1000'),
          feeTotal: d('-1'),
          termMonths: 3,
          firstDueDate: firstDue,
          scheme: InstallmentScheme.equalInstalments,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            creditFeeInvalidCode,
          ),
        ),
      );
    });
  });

  group('код схемы — стабильная строка, а не индекс члена', () {
    test('byCode находит каждую схему по её же коду', () {
      for (final scheme in InstallmentScheme.values) {
        expect(InstallmentScheme.byCode(scheme.code), scheme);
      }
    });

    test('незнакомый код — null, а не первая схема', () {
      expect(InstallmentScheme.byCode('annuity_v2'), isNull);
      expect(InstallmentScheme.byCode(null), isNull);
    });
  });
}
