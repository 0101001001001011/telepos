import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';

/// Кадры входа в аванс и сертификат.
///
/// Утверждения — о полях кадра, а не о том, что «разбор не упал».
void main() {
  Decimal d(String v) => Decimal.parse(v);

  test('остаток аванса едет строкой и возвращается тем же числом', () {
    final json = prepaymentToWireJson(d('700.125'));
    expect(json['amount'], '700.125', reason: 'деньги по проводу — строкой');
  });

  test('ПИН кладётся только набранным, номер — всегда', () {
    final withPin = certificateAskFromWireJson({'number': 'C-1', 'pin': '1234'});
    expect(withPin.number, 'C-1');
    expect(withPin.pin, '1234');

    final withoutPin = certificateAskFromWireJson({'number': 'C-1'});
    expect(withoutPin.pin, isNull);
  });

  test('чужие типы в кадре — пустой номер и нет ПИНа, а не TypeError', () {
    final ask = certificateAskFromWireJson({'number': 42, 'pin': 1234});
    expect(ask.number, '');
    expect(ask.pin, isNull);
  });

  test('хэш ПИНа в ответе об остатке бумажки не едет', () {
    final json = certificateToWireJson(
      GiftCertificate(
        id: 3,
        number: 'C-1',
        nominal: d('5000'),
        balance: d('1200'),
        status: CertificateStatus.active,
        issuedAt: 1000,
        pinHash: 'pbkdf2:секрет',
        liabilityAccountId: 21,
      ),
    );
    expect(json.values, isNot(contains('pbkdf2:секрет')));
    expect(json.containsKey('liabilityAccountId'), isFalse);
    final back = certificateFromWireJson(json);
    expect(back.balance, d('1200'));
    expect(back.pinHash, isNull);
  });

  test('обе операции — вопросы под nav.sale без права по телу', () {
    for (final op in [PayOps.prepayment, PayOps.certificate]) {
      final access = op.access as SessionAccess;
      expect(access.needs, PermissionKeys.navSale, reason: op.name);
      expect(access.alsoNeeds, isNull, reason: op.name);
      expect(PayOps.all, contains(op), reason: op.name);
    }
  });
}
