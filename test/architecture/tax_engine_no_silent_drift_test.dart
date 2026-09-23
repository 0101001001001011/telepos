/// Чек и фискальный документ считают налог одинаково.
///
/// # Что эта проба нашла
///
/// Написана ДО правки налогового движка (план
/// `2026-09-21-us-tax-engine.md`) — и немедленно нашла дефект, к США
/// отношения не имеющий.
///
/// Фискальный документ везёт налог **по каждой позиции**
/// (`FiscalPositionBuilder.buildTax` → `vatFromGross(lineTotal, rate)`).
/// Чек до 2026-09-21 считал его **один раз от суммы чека**
/// (`sale_receipt_composer.dart` → `vatFromGross(sale.amount)`).
///
/// Это не одно и то же: округление по строкам накапливается. На чеке из
/// шести позиций при казахстанских 16% выходило 615.24 против 615.23.
/// Копейка — но бумага у покупателя и документ у налоговой расходились, и
/// расходились молча, годами, без единой красной пробы.
///
/// # Почему проба написана раньше правки
///
/// Написанная после, она закрепила бы новое поведение как правильное, каким
/// бы оно ни оказалось. В этом проекте такое уже случалось: две пробы
/// пришлось переворачивать, потому что они удерживали дефект как норму.
///
/// # Что считается главным
///
/// Построчный способ. Его видит налоговая, и чек обязан совпадать с
/// документом, а не наоборот.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/data/print/receipt_requisites.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_position_builder.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';

void main() {
  /// Чек из нескольких строк.
  ///
  /// Суммы намеренно «некруглые»: на них способы округления расходятся, а на
  /// 100.00 и 200.00 не расходится ничего, и проба была бы зелёной при любой
  /// поломке.
  const lines = <String>[
    '450.00',
    '3200.00',
    '620.00',
    '149.99',
    '33.33',
    '7.07',
  ];

  Decimal d(String v) => Decimal.parse(v);

  /// Как считает фискальный документ и как теперь считает чек.
  Decimal perLine(Decimal rate) => lines
      .map((l) => FiscalPositionBuilder.vatFromGross(d(l), rate))
      .fold<Decimal>(Decimal.zero, (a, b) => a + b);

  /// Как чек считал до правки — от суммы всего чека.
  Decimal wholeReceipt(Decimal rate) {
    final total = lines.map(d).reduce((a, b) => a + b);
    return FiscalPositionBuilder.vatFromGross(total, rate);
  }

  test('два способа НЕ равны — ради этого проба и написана', () {
    // Утверждение о самой арифметике, а не о продукте: округление по
    // строкам накапливается. Если однажды они совпадут на этих числах,
    // значит изменилось округление, и остальные пробы этого файла проверяют
    // уже не то, что проверяли.
    expect(
      perLine(d('16')),
      isNot(wholeReceipt(d('16'))),
      reason:
          'на этих суммах способы обязаны расходиться. Совпали — значит '
          'сменилось округление, и проба ослепла',
    );
  });

  group('чек считает так же, как фискальный документ', () {
    for (final rate in const [12, 16, 20, 22]) {
      test('ставка $rate%', () {
        // Слева — то, что кладётся В ЧЕК. Справа — как считает фискальный
        // документ. Это разные куски кода, и в том и ценность: сравнение
        // величины с собой ничего бы не доказало.
        final requisites = ReceiptRequisites(
          seller: const ReceiptSellerInfo(binIin: '123456789012'),
          fiscal: null,
          isVatPayer: true,
          vatRatePercent: Decimal.fromInt(rate),
          currencySymbol: '₸',
          taxTreatment: TaxTreatment.inclusive,
          currencyBeforeAmount: false,
          hasFiscalisation: true,
        );

        expect(
          requisites.vatFromLines(lines.map(d)),
          perLine(Decimal.fromInt(rate)),
          reason:
              'налог на бумаге разошёлся с налогом в фискальном документе. '
              'Именно это и было сломано до 2026-09-21: чек считал от суммы '
              'чека, документ — по позициям',
        );
      });
    }
  });

  test('старый способ действительно давал другое число', () {
    // Доказательство, что правка что-то изменила, а не переставила строки.
    final requisites = ReceiptRequisites(
      seller: const ReceiptSellerInfo(binIin: '123456789012'),
      fiscal: null,
      isVatPayer: true,
      vatRatePercent: Decimal.fromInt(16),
      currencySymbol: '₸',
      taxTreatment: TaxTreatment.inclusive,
      currencyBeforeAmount: false,
      hasFiscalisation: true,
    );
    final total = lines.map(d).reduce((a, b) => a + b);

    expect(
      requisites.vatFromLines(lines.map(d)),
      isNot(requisites.vatFromGross(total)),
      reason:
          'если построчный и «от итога» способы дают одно и то же, эта '
          'правка ничего не исправила, и дефект остался где-то ещё',
    );
  });

  test('нулевая ставка не даёт налога', () {
    expect(perLine(Decimal.zero), Decimal.zero);
    expect(wholeReceipt(Decimal.zero), Decimal.zero);
  });

  test('дробная ставка считается, а не отбрасывается', () {
    // Сама формула дробную ставку уже принимает — значит, дыра этапа 1 не в
    // ней, а в типах вокруг (`int vatRatePercent`). Проба закрепляет то, что
    // уже верно, чтобы правка типов это не сдвинула.
    final eightQuarter = FiscalPositionBuilder.vatFromGross(
      d('108.25'),
      d('8.25'),
    );
    expect(eightQuarter > Decimal.zero, isTrue);
    expect(
      eightQuarter,
      isNot(FiscalPositionBuilder.vatFromGross(d('108.25'), d('8'))),
      reason:
          'если 8,25% и 8% дают одно и то же, дробная часть отбрасывается — '
          'ровно та дыра, ради которой затеян этап 1',
    );
  });
}
