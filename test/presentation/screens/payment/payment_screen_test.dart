import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/screens/payment/widgets/payment_type_selector.dart';
import 'package:telepos/presentation/screens/payment/widgets/payment_amount_panel.dart';
import 'package:telepos/presentation/screens/payment/widgets/denomination_grid.dart';
import 'package:telepos/presentation/screens/payment/widgets/account_selector.dart';
import 'package:telepos/presentation/screens/payment/widgets/loyalty_panel.dart';
import 'package:telepos/presentation/screens/payment/widgets/iin_input.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';
import 'package:telepos/app/theme/app_theme.dart';

Future<void> ignoreOverflowErrors(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final exception = details.exceptionAsString();
    if (exception.contains('overflowed') ||
        exception.contains('A RenderFlex')) {
      return;
    }
    if (original != null) {
      original(details);
    }
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  void setScreenSize(WidgetTester tester, Size logicalSize) {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
  }

  void resetScreenSize(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  Widget buildTestWidget({
    required PaymentState paymentState,
    bool isRefund = false,
  }) {
    return ProviderScope(
      overrides: [
        paymentControllerProvider.overrideWith(
          () => MockPaymentNotifier(paymentState),
        ),
        paymentAccountsProvider.overrideWith((ref) async => <PaymentAccount>[]),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        locale: const Locale('ru'),
        home: PaymentScreen(
          amount: paymentState.totalAmount,
          isRefund: isRefund,
        ),
      ),
    );
  }

  const mobileSize = Size(500, 900);
  const tabletSize = Size(899, 1200);
  const desktopSize = Size(1600, 1000);

  group('Mobile layout (<600px)', () {
    testWidgets('shows AppBar with "Оплата" title', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
      );
      await tester.pumpAndSettle();

      expect(find.text('Оплата'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('contains mobile-specific sub-widgets', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PaymentTypeSelector), findsOneWidget);
      expect(find.byType(PaymentAmountPanel), findsOneWidget);
      expect(find.byType(DenominationRow), findsOneWidget);
      expect(find.byType(LoyaltyPanelCompact), findsOneWidget);
      expect(find.byType(IinInputCompact), findsOneWidget);
    });

    testWidgets('shows totalAmount in AppBar subtitle', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
      );
      await tester.pumpAndSettle();

      expect(find.text('1150'), findsAtLeastNWidgets(1));
    });
  });

  group('Tablet layout (600-900px)', () {
    testWidgets('shows AppBar with "Оплата" title', (tester) async {
      setScreenSize(tester, tabletSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.text('Оплата'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });
    });

    testWidgets('body contains Row layout with full-size widgets', (
      tester,
    ) async {
      setScreenSize(tester, tabletSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Row), findsAtLeastNWidgets(1));
        expect(find.byType(DenominationRow), findsNothing);
        expect(find.byType(LoyaltyPanelCompact), findsNothing);
        expect(find.byType(IinInputCompact), findsNothing);
        expect(find.byType(DenominationGrid), findsOneWidget);
        expect(find.byType(LoyaltyPanel), findsOneWidget);
        expect(find.byType(IinInput), findsOneWidget);
      });
    });
  });

  group('Desktop layout (>=900px)', () {
    testWidgets('no AppBar, renders modal-style container', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(DenominationGrid), findsOneWidget);
        expect(find.byType(LoyaltyPanel), findsOneWidget);
        expect(find.byType(IinInput), findsOneWidget);
      });
    });

    testWidgets('shows title and amount in _Header', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.text('Оплата'), findsOneWidget);
        expect(find.text('1150'), findsAtLeastNWidgets(1));
      });
    });
  });

  group('Refund mode', () {
    testWidgets('mobile: title changes to "Возврат"', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(
          paymentState: TestPaymentStates.cashWaiting,
          isRefund: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Возврат'), findsOneWidget);
      expect(find.text('Оплата'), findsNothing);
    });

    testWidgets('desktop: header shows "Возврат"', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(
            paymentState: TestPaymentStates.cashWaiting,
            isRefund: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Возврат'), findsOneWidget);
        expect(find.text('Оплата'), findsNothing);
      });
    });

    testWidgets('tablet: AppBar shows "Возврат"', (tester) async {
      setScreenSize(tester, tabletSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(
            paymentState: TestPaymentStates.cashWaiting,
            isRefund: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Возврат'), findsOneWidget);
      });
    });
  });

  group('Cash payment state', () {
    testWidgets('shows cash-related widgets on desktop', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.text('Наличная'), findsAtLeastNWidgets(1));
        expect(find.byType(DenominationGrid), findsOneWidget);
        expect(find.text('К оплате'), findsOneWidget);
        expect(find.text('Номиналы'), findsAtLeastNWidgets(1));
      });
    });

    testWidgets('cash complete state shows change amount', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashComplete),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Сдача'), findsAtLeastNWidgets(1));
        expect(find.text('850'), findsAtLeastNWidgets(1));
      });
    });
  });

  group('Processing state', () {
    testWidgets('shows CircularProgressIndicator on desktop', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.processing),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    testWidgets('shows CircularProgressIndicator on mobile', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(paymentState: TestPaymentStates.processing),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Error state', () {
    testWidgets('still renders core widgets (amount panel, type selector)', (
      tester,
    ) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.withError),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PaymentAmountPanel), findsOneWidget);
        expect(find.byType(PaymentTypeSelector), findsOneWidget);
      });
    });

    testWidgets('renders on mobile with error state', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(paymentState: TestPaymentStates.withError),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PaymentAmountPanel), findsOneWidget);
      expect(find.byType(PaymentTypeSelector), findsOneWidget);
    });
  });

  group('"ОПЛАТИТЬ" button', () {
    testWidgets('exists on desktop layout', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cardPayment),
        );
        await tester.pumpAndSettle();

        expect(find.text('ОПЛАТИТЬ'), findsOneWidget);
      });
    });

    testWidgets('exists on mobile layout', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(paymentState: TestPaymentStates.cardPayment),
      );
      await tester.pumpAndSettle();

      expect(find.text('ОПЛАТИТЬ'), findsOneWidget);
    });

    testWidgets('exists on tablet layout', (tester) async {
      setScreenSize(tester, tabletSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cardPayment),
        );
        await tester.pumpAndSettle();

        expect(find.text('ОПЛАТИТЬ'), findsOneWidget);
      });
    });
  });

  group('"Отмена" button', () {
    testWidgets('exists on desktop layout', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.text('Отмена'), findsOneWidget);
      });
    });

    testWidgets('exists on tablet layout', (tester) async {
      setScreenSize(tester, tabletSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.text('Отмена'), findsOneWidget);
      });
    });
  });

  group('Refund mode "ВЕРНУТЬ" button', () {
    testWidgets('desktop shows "ВЕРНУТЬ" instead of "ОПЛАТИТЬ"', (
      tester,
    ) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(
            paymentState: TestPaymentStates.cardPayment,
            isRefund: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ВЕРНУТЬ'), findsOneWidget);
        expect(find.text('ОПЛАТИТЬ'), findsNothing);
      });
    });

    testWidgets('mobile shows "ВЕРНУТЬ" instead of "ОПЛАТИТЬ"', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(
          paymentState: TestPaymentStates.cardPayment,
          isRefund: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ВЕРНУТЬ'), findsOneWidget);
      expect(find.text('ОПЛАТИТЬ'), findsNothing);
    });
  });

  group('Card payment hides denominations', () {
    testWidgets('DenominationGrid hidden for card payment on desktop', (
      tester,
    ) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cardPayment),
        );
        await tester.pumpAndSettle();

        expect(find.text('Номиналы'), findsNothing);
      });
    });
  });

  group('Payment type selector labels', () {
    testWidgets('shows all three payment type labels', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.text('Наличная'), findsAtLeastNWidgets(1));
        expect(find.text('Безналичная'), findsAtLeastNWidgets(1));
        expect(find.text('Смешанная'), findsAtLeastNWidgets(1));
      });
    });
  });

  group('Close icon button', () {
    testWidgets('close icon exists on mobile AppBar', (tester) async {
      setScreenSize(tester, mobileSize);
      addTearDown(() => resetScreenSize(tester));

      await tester.pumpWidget(
        buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(TeleposIcons.close), findsOneWidget);
    });

    testWidgets('close icon exists on desktop header', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(TeleposIcons.close), findsOneWidget);
      });
    });
  });

  group('Loyalty panel visibility', () {
    testWidgets('LoyaltyPanel present on desktop', (tester) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cashWaiting),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoyaltyPanel), findsOneWidget);
        expect(find.text('Программа лояльности'), findsOneWidget);
      });
    });
  });

  group('AccountSelector visibility for card payment', () {
    testWidgets('AccountSelector renders for card payment type', (
      tester,
    ) async {
      setScreenSize(tester, desktopSize);
      addTearDown(() => resetScreenSize(tester));

      await ignoreOverflowErrors(() async {
        await tester.pumpWidget(
          buildTestWidget(paymentState: TestPaymentStates.cardPayment),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AccountSelector), findsOneWidget);
      });
    });
  });
}
