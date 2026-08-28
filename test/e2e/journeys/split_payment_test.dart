library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/restaurant/dialogs/split_payment_dialog.dart';

Decimal _d(String v) => Decimal.parse(v);

void main() {
  group('Split payment aggregation (money-exact)', () {
    final guests = [1, 2, 3];
    Decimal share(int g) => _d('950');
    final total = _d('2850');

    test('all cash -> card portion is zero, cash == total', () {
      final r = SplitPaymentDialog.aggregate(guests, share, {
        1: false,
        2: false,
        3: false,
      }, total);
      expect(r.cash, _d('2850'));
      expect(r.card, Decimal.zero);
      expect(r.cash + r.card, total);
    });

    test('all card -> cash portion is zero, card == total', () {
      final r = SplitPaymentDialog.aggregate(guests, share, {
        1: true,
        2: true,
        3: true,
      }, total);
      expect(r.cash, Decimal.zero);
      expect(r.card, _d('2850'));
      expect(r.cash + r.card, total);
    });

    test('mixed (1 cash, 2 card) -> exact split summing to total', () {
      final r = SplitPaymentDialog.aggregate(guests, share, {
        1: false,
        2: true,
        3: true,
      }, total);
      expect(r.cash, _d('950'));
      expect(r.card, _d('1900'));
      expect(r.cash + r.card, total);
    });

    test(
      'uneven shares with rounding remainder still sum to total exactly',
      () {
        final t = _d('1000');
        Decimal s(int g) => _d('333.333');
        final r = SplitPaymentDialog.aggregate(
          [1, 2, 3],
          s,
          {1: false, 2: true, 3: true},
          t,
        );
        expect(r.cash, _d('333.333'));
        expect(r.card, t - _d('333.333'));
        expect(r.cash + r.card, t);
      },
    );
  });

  group('Split payment dialog UI', () {
    Future<Map<int, bool>?> openDialog(WidgetTester tester) async {
      Map<int, bool>? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await SplitPaymentDialog.show(
                      context,
                      guests: [1, 2, 3],
                      amountForGuest: (_) => _d('950'),
                      total: _d('2850'),
                    );
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('renders a method toggle per guest plus cancel/proceed', (
      tester,
    ) async {
      await openDialog(tester);
      expect(find.byKey(const Key('split.guest.1.method')), findsOneWidget);
      expect(find.byKey(const Key('split.guest.2.method')), findsOneWidget);
      expect(find.byKey(const Key('split.guest.3.method')), findsOneWidget);
      expect(find.byKey(const Key('split.payment.proceed')), findsOneWidget);
    });

    testWidgets(
      'proceeding closes the dialog (settles via the payment screen)',
      (tester) async {
        await openDialog(tester);
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('split.guest.2.method')),
            matching: find.text('Карта'),
          ),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('split.payment.proceed')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('split.payment.proceed')), findsNothing);
      },
    );
  });
}
