import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/screens/shift/shift_screen.dart';
import 'package:telepos/presentation/screens/shift/widgets/bills_tab.dart';
import 'package:telepos/presentation/screens/shift/widgets/shift_info_panel.dart';
import 'package:telepos/presentation/screens/shift/widgets/shift_actions.dart';
import 'package:telepos/app/theme/app_colors.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';
import 'package:telepos/app/theme/app_theme.dart';

void main() {
  Widget createTestWidget({required ShiftState state}) {
    return ProviderScope(
      overrides: [
        shiftControllerProvider.overrideWith(() => MockShiftNotifier(state)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ru'), Locale('en')],
        locale: Locale('ru'),
        home: ShiftScreen(),
      ),
    );
  }

  const mobileSize = Size(580, 1000);
  const tabletSize = Size(750, 1024);
  const desktopSize = Size(1200, 800);

  group('ShiftScreen', () {
    group('Loading state', () {
      testWidgets('shows CircularProgressIndicator when loading', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.loading),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
      });
    });

    group('Desktop layout (>=900px)', () {
      testWidgets('shows TabBar with 3 desktop tabs', (tester) async {
        tester.view.physicalSize = desktopSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TabBar), findsOneWidget);
        expect(find.text('Купюры'), findsOneWidget);
        expect(find.text('Общая сумма'), findsOneWidget);
        expect(find.text('Операции'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows ShiftInfoPanel in right panel', (tester) async {
        tester.view.physicalSize = desktopSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ShiftInfoPanel), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows ShiftActions in right panel', (tester) async {
        tester.view.physicalSize = desktopSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ShiftActions), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows BillsTab in TabBarView', (tester) async {
        tester.view.physicalSize = desktopSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BillsTab), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows VerticalDivider between panels', (tester) async {
        tester.view.physicalSize = desktopSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VerticalDivider), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Tablet layout (600-900px)', () {
      testWidgets('shows TabBar with 3 compact tabs', (tester) async {
        tester.view.physicalSize = tabletSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.byType(TabBar), findsOneWidget);
        expect(find.text('Купюры'), findsOneWidget);
        expect(find.text('Сумма'), findsOneWidget);
        expect(find.text('Операции'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows compact info at the bottom', (tester) async {
        tester.view.physicalSize = tabletSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.text('Смена открыта'), findsOneWidget);
        expect(find.byType(ShiftActions), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('does not show ShiftInfoPanel (desktop only)', (
        tester,
      ) async {
        tester.view.physicalSize = tabletSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.byType(ShiftInfoPanel), findsNothing);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Mobile layout (<600px)', () {
      testWidgets('shows AppBar with title', (tester) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('Закрытие смены'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows ExpansionTile sections when shift is open', (
        tester,
      ) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile), findsNWidgets(3));
        expect(find.text('Пересчёт по купюрам'), findsOneWidget);
        expect(find.text('Ручной ввод суммы'), findsOneWidget);
        expect(find.text('Кассовые операции'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('does not show TabBar (mobile uses ExpansionTile)', (
        tester,
      ) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.byType(TabBar), findsNothing);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Shift closed', () {
      testWidgets('mobile shows "Открытие смены" in AppBar', (tester) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.text('Открытие смены'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows lock icon when shift is closed', (tester) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('does not show ExpansionTile sections when closed', (
        tester,
      ) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile), findsNothing);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('tablet shows "Смена закрыта" text and lock icon', (
        tester,
      ) async {
        tester.view.physicalSize = tabletSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.closed),
        );
        await tester.pumpAndSettle();

        expect(find.text('Смена закрыта'), findsOneWidget);
        expect(find.byIcon(Icons.lock), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Shift open', () {
      testWidgets('mobile shows "Закрытие смены" in AppBar', (tester) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.text('Закрытие смены'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows lock_open icon when shift is open', (tester) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock_open), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows cashier name on mobile status card', (tester) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(state: TestShiftStates.open));
        await tester.pumpAndSettle();

        expect(find.text('Кассир Тест'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Shift with positive difference', () {
      testWidgets('mobile shows green text for positive difference', (
        tester,
      ) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.withPositiveDifference),
        );
        await tester.pumpAndSettle();

        final positiveDiffFinder = find.text('+2000.00');
        expect(positiveDiffFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(positiveDiffFinder);
        expect(textWidget.style?.color, equals(AppColors.success));

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('tablet shows green difference text', (tester) async {
        tester.view.physicalSize = tabletSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.withPositiveDifference),
        );
        await tester.pumpAndSettle();

        expect(find.text('Разница: '), findsOneWidget);
        final positiveDiffFinder = find.text('+2000.00');
        expect(positiveDiffFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(positiveDiffFinder);
        expect(textWidget.style?.color, equals(AppColors.success));

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Shift with negative difference', () {
      testWidgets('mobile shows red text for negative difference', (
        tester,
      ) async {
        tester.view.physicalSize = mobileSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.withNegativeDifference),
        );
        await tester.pumpAndSettle();

        final negativeDiffFinder = find.text('-2000.00');
        expect(negativeDiffFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(negativeDiffFinder);
        expect(textWidget.style?.color, equals(AppColors.error));

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('tablet shows red difference text', (tester) async {
        tester.view.physicalSize = tabletSize;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestShiftStates.withNegativeDifference),
        );
        await tester.pumpAndSettle();

        expect(find.text('Разница: '), findsOneWidget);
        final negativeDiffFinder = find.text('-2000.00');
        expect(negativeDiffFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(negativeDiffFinder);
        expect(textWidget.style?.color, equals(AppColors.error));

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
