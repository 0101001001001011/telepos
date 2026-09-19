/// Раскладка возврата по видам — чистый домен, задача 26.
///
/// Каждое утверждение — о **числе на строке**, а не о сумме: раскладка,
/// сводящая итог и путающая получателей, зелена по любой проверке итога.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/refund/refund_allocation.dart';

Decimal d(String v) => Decimal.parse(v);

RefundSource src(int seq, RefundRoute route, String paid) =>
    RefundSource(seq: seq, route: route, paid: d(paid));

Map<RefundRoute, Decimal> byRoute(List<RefundPart> parts) => {
  for (final p in parts) p.route: p.amount,
};

void main() {
  group('правило частичного возврата', () {
    test('полный возврат — каждая строка отдаёт всё, что принесла', () {
      final parts = RefundAllocation.allocate(
        amount: d('1000'),
        sources: [
          src(0, RefundRoute.drawer, '200'),
          src(1, RefundRoute.card, '300'),
          src(2, RefundRoute.certificate, '400'),
          src(3, RefundRoute.debt, '100'),
        ],
      );
      expect(byRoute(parts), {
        RefundRoute.debt: d('100'),
        RefundRoute.certificate: d('400'),
        RefundRoute.card: d('300'),
        RefundRoute.drawer: d('200'),
      });
    });

    test('порядок: долг → бонус → сертификат → аванс → безнал → наличные', () {
      final sources = [
        src(0, RefundRoute.drawer, '100'),
        src(1, RefundRoute.card, '100'),
        src(2, RefundRoute.advance, '100'),
        src(3, RefundRoute.certificate, '100'),
        src(4, RefundRoute.bonus, '100'),
        src(5, RefundRoute.debt, '100'),
      ];
      // Возвращаем по сотне больше — каждая следующая доля открывает ровно
      // одного следующего получателя.
      final expected = [
        RefundRoute.debt,
        RefundRoute.bonus,
        RefundRoute.certificate,
        RefundRoute.advance,
        RefundRoute.card,
        RefundRoute.drawer,
      ];
      for (var n = 1; n <= expected.length; n++) {
        final parts = RefundAllocation.allocate(
          amount: d('${n * 100}'),
          sources: sources,
        );
        expect(
          [for (final p in parts) p.route],
          expected.sublist(0, n),
          reason: 'возврат ${n * 100}',
        );
      }
    });

    test('частичная доля ложится на последнего открытого получателя', () {
      final parts = RefundAllocation.allocate(
        amount: d('650.5'),
        sources: [
          src(0, RefundRoute.drawer, '500'),
          src(1, RefundRoute.certificate, '500'),
        ],
      );
      expect(byRoute(parts), {
        RefundRoute.certificate: d('500'),
        RefundRoute.drawer: d('150.5'),
      });
    });

    test('внутри одного класса — порядок чека', () {
      final parts = RefundAllocation.allocate(
        amount: d('150'),
        sources: [
          src(1, RefundRoute.card, '100'),
          src(0, RefundRoute.provider, '100'),
        ],
      );
      expect([for (final p in parts) (p.source!.seq, p.amount)], [
        (0, d('100')),
        (1, d('50')),
      ]);
    });

    test('остаток сверх строк — из ящика, названной строкой', () {
      final parts = RefundAllocation.allocate(
        amount: d('1000.01'),
        sources: [src(0, RefundRoute.card, '1000')],
      );
      expect(parts, hasLength(2));
      expect(parts.last.unmatched, isTrue);
      expect(parts.last.route, RefundRoute.drawer);
      expect(parts.last.amount, d('0.01'));
    });

    test('без строк оплаты весь возврат — из ящика', () {
      final parts = RefundAllocation.allocate(amount: d('70'), sources: []);
      expect(parts.single.unmatched, isTrue);
      expect(parts.single.amount, d('70'));
    });

    test('нулевой возврат не порождает строк', () {
      expect(
        RefundAllocation.allocate(
          amount: Decimal.zero,
          sources: [src(0, RefundRoute.drawer, '10')],
        ),
        isEmpty,
      );
    });
  });

  group('куда возвращается строка этого вида', () {
    RefundRoute route(int kindId, {bool bonus = false, String? txn}) =>
        RefundAllocation.routeOf(
          kind: SystemPaymentKinds.byId(kindId),
          bonusAccount: bonus,
          transactionId: txn,
        );

    test('системные виды', () {
      expect(route(SystemPaymentKindIds.cash), RefundRoute.drawer);
      expect(route(SystemPaymentKindIds.card, txn: 'KP1'), RefundRoute.card);
      expect(route(SystemPaymentKindIds.card), RefundRoute.manual);
      expect(route(SystemPaymentKindIds.qr), RefundRoute.provider);
      expect(route(SystemPaymentKindIds.certificate), RefundRoute.certificate);
      expect(route(SystemPaymentKindIds.prepayment), RefundRoute.advance);
      expect(route(SystemPaymentKindIds.debt), RefundRoute.debt);
      expect(route(SystemPaymentKindIds.installment), RefundRoute.debt);
      expect(
        route(SystemPaymentKindIds.bonus, bonus: true),
        RefundRoute.bonus,
      );
    });

    test('строка без вида (до v41) — из ящика, как до задачи 26', () {
      expect(
        RefundAllocation.routeOf(kind: null, bonusAccount: false),
        RefundRoute.drawer,
      );
    });

    test('вид оператора со своим безналичным счётом — вне кассы', () {
      final transfer = SystemPaymentKinds.byId(
        SystemPaymentKindIds.cash,
      ).copyWith(code: 'transfer', payeeAccountType: 1, givesChange: false);
      expect(
        RefundAllocation.routeOf(kind: transfer, bonusAccount: false),
        RefundRoute.manual,
      );
    });

    test('у каждого получателя свой код, и он читается обратно', () {
      for (final r in RefundRoute.values) {
        expect(RefundRoute.byCode(r.code), r);
      }
      expect(RefundRoute.byCode('cash'), isNull);
    });
  });
}
