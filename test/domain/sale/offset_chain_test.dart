import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/sale/offset_chain.dart';

/// Цепочка зачётов — одна функция на кассу и экран.
///
/// Утверждения здесь **о том, кто урезан**, а не о сумме: сумма сходится
/// при любом порядке потолков (разбор — `certificate_with_neighbours_test`).
/// Поэтому каждое число названо по своему зачёту.
void main() {
  Decimal d(String v) => Decimal.parse(v);

  test('порядок: бонус → QR → сертификат → аванс, урезан последний', () {
    final split = OffsetChain.split(
      amount: d('1000'),
      bonus: d('100'),
      qr: d('300'),
      certificateBalances: [d('400')],
      prepayment: d('600'),
    );

    expect(split.bonus, d('100'));
    expect(split.qr, d('300'));
    expect(split.certificates, [d('400')]);
    expect(split.prepayment, d('200'), reason: 'аванс берёт только остаток');
    expect(split.toPay, d('0'));
  });

  test('бумажка урезана остатком чека, а не своим номиналом', () {
    final split = OffsetChain.split(
      amount: d('1200'),
      certificateBalances: [d('5000')],
    );
    expect(split.certificates, [d('1200')]);
    expect(split.toPay, d('0'));
  });

  test('вторая бумажка после покрытого чека получает ноль, а не минус', () {
    final split = OffsetChain.split(
      amount: d('500'),
      certificateBalances: [d('600'), d('300')],
    );
    expect(split.certificates, [d('500'), d('0')]);
    expect(split.certificate, d('500'));
  });

  test('две бумажки делят чек по порядку предъявления', () {
    final split = OffsetChain.split(
      amount: d('1000'),
      certificateBalances: [d('300'), d('500')],
      prepayment: d('1000'),
    );
    expect(split.certificates, [d('300'), d('500')]);
    expect(split.prepayment, d('200'));
    expect(split.toPay, d('0'));
  });

  test('отрицательное и нулевое — «зачёта нет»', () {
    final split = OffsetChain.split(
      amount: d('1000'),
      bonus: d('-50'),
      prepayment: d('-300'),
    );
    expect(split.bonus, d('0'));
    expect(split.prepayment, d('0'));
    expect(split.toPay, d('1000'));
  });

  test('бонус больше чека урезан чеком, и остальным ничего не остаётся', () {
    final split = OffsetChain.split(
      amount: d('400'),
      bonus: d('900'),
      certificateBalances: [d('100')],
      prepayment: d('100'),
    );
    expect(split.bonus, d('400'));
    expect(split.certificates, [d('0')]);
    expect(split.prepayment, d('0'));
    expect(split.toPay, d('0'));
  });

  test('тысячные не теряются', () {
    final split = OffsetChain.split(
      amount: d('1000.005'),
      certificateBalances: [d('0.003')],
      prepayment: d('999.999'),
    );
    expect(split.certificates, [d('0.003')]);
    expect(split.prepayment, d('999.999'));
    expect(split.toPay, d('0.003'));
  });
}
