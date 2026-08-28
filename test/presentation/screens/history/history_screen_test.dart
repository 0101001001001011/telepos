import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/screens/history/history_screen.dart';
import 'package:telepos/presentation/screens/history/widgets/history_filters.dart';
import 'package:telepos/presentation/screens/history/widgets/history_pagination.dart';
import 'package:telepos/presentation/screens/history/widgets/history_table.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';
import 'package:telepos/app/theme/app_theme.dart';

void main() {
  Widget createTestWidget({
    required HistoryState state,
    double width = 400,
    double height = 800,
  }) {
    return ProviderScope(
      overrides: [
        historyControllerProvider.overrideWith(
          () => MockHistoryNotifier(state),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
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
          home: HistoryScreen(),
        ),
      ),
    );
  }

  group('HistoryScreen', () {
    group('Loading State', () {
      testWidgets(
        'shows CircularProgressIndicator when loading with no items',
        (tester) async {
          await tester.pumpWidget(
            createTestWidget(state: TestHistoryStates.loading, width: 400),
          );

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(HistoryFilters), findsNothing);
          expect(find.byType(HistoryPagination), findsNothing);
        },
      );
    });

    group('Desktop Layout (>=900px)', () {
      testWidgets('shows HistoryFilters widget', (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HistoryFilters), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows HistoryPagination widget', (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.withItems, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HistoryPagination), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows table header text', (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.text('История операций'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows refresh button', (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byTooltip('Обновить'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows "Сбросить фильтры" when filters active', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.withFilters, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.text('Сбросить фильтры'), findsOneWidget);
        expect(find.byIcon(TeleposIcons.close), findsAtLeastNWidgets(1));

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('does not show "Сбросить фильтры" when no filters active', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.text('Сбросить фильтры'), findsNothing);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Mobile Layout (<600px)', () {
      testWidgets('shows AppBar with title', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('История'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('shows filter_list icon in AppBar actions', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.filter_list), findsOneWidget);
        expect(find.byTooltip('Фильтры'), findsOneWidget);
      });

      testWidgets('shows filter badge when filters are active', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.withFilters, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Badge), findsOneWidget);
        expect(find.byIcon(Icons.filter_alt_off), findsOneWidget);
        expect(find.byTooltip('Сбросить фильтры'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state on desktop', (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.text('Нет записей'), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
        expect(find.text('История операций пуста'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows empty state on mobile', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Нет записей'), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      });

      testWidgets('shows filter hint when empty with active filters', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.withFilters, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.text('Нет записей'), findsOneWidget);
        expect(find.text('Попробуйте изменить фильтры'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows empty state on tablet', (tester) async {
        tester.view.physicalSize = const Size(700, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.empty, width: 700),
        );
        await tester.pumpAndSettle();

        expect(find.text('Нет записей'), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('With Items', () {
      testWidgets('shows HistoryTable on desktop', (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.withItems, width: 1600),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HistoryTable), findsOneWidget);
        expect(find.byType(DataTable), findsOneWidget);
        expect(find.text('#42'), findsAtLeastNWidgets(1));
        expect(find.text('#43'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows history cards on mobile', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.withItems, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('#42'), findsAtLeastNWidgets(1));
        expect(find.text('#43'), findsOneWidget);
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('shows amounts with type prefix on mobile', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.withItems, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('+1150.00'), findsOneWidget);
        expect(find.text('+500.00'), findsOneWidget);
        expect(find.text('-500.00'), findsOneWidget);
      });

      testWidgets('shows compact HistoryTable on tablet', (tester) async {
        tester.view.physicalSize = const Size(700, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestHistoryStates.withItems, width: 700),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HistoryTable), findsOneWidget);
        expect(find.byType(HistoryFilters), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
