import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_mode_selector.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_items_table.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_items_list.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_total_panel.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_action_buttons.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';

void main() {
  Widget createTestWidget({
    required RefundState state,
    double width = 400,
    double height = 800,
  }) {
    return ProviderScope(
      overrides: [
        refundControllerProvider.overrideWith(() => MockRefundNotifier(state)),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: MaterialApp(
          // Тема приложения, а не умолчание Material: экран берёт цвета
          // ролями (`context.semantic`, `colorScheme`), и под голым
          // `MaterialApp` расширение `AppSemanticColors` не
          // зарегистрировано — обращение к нему падает. Это и есть та
          // причина, по которой такой тест проверял не тот продукт,
          // что уезжает заказчику.
          theme: AppTheme.light,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ru'), Locale('en')],
          locale: Locale('ru'),
          home: Scaffold(body: RefundScreen()),
        ),
      ),
    );
  }

  group('RefundScreen', () {
    group('Desktop Layout (>=1200px)', () {
      testWidgets('renders Row layout with two Expanded panels', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Row), findsWidgets);
        expect(find.byType(Expanded), findsWidgets);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows RefundModeSelector', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundModeSelector), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows RefundItemsTable', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundItemsTable), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows RefundActionButtons', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundActionButtons), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows RefundTotalPanel', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundTotalPanel), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Mobile Layout (<600px)', () {
      testWidgets('renders Column layout', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundModeSelector), findsOneWidget);
        expect(find.byType(RefundItemsList), findsOneWidget);
        expect(find.byType(RefundTotalPanel), findsOneWidget);
      });

      testWidgets('shows RefundModeSelector', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundModeSelector), findsOneWidget);
      });

      testWidgets('shows RefundItemsList instead of RefundItemsTable', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundItemsList), findsOneWidget);
        expect(find.byType(RefundItemsTable), findsNothing);
      });

      testWidgets('shows RefundTotalPanel', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundTotalPanel), findsOneWidget);
      });
    });

    group('By Receipt Mode', () {
      testWidgets('shows "Загрузить чек" button on mobile', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            state: const RefundState(mode: RefundMode.byReceipt),
            width: 400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Загрузить чек'), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long), findsWidgets);
      });

      testWidgets('shows "Загрузить чек" action button on desktop', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            state: const RefundState(mode: RefundMode.byReceipt),
            width: 1400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Загрузить чек'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Without Receipt Mode', () {
      testWidgets('shows search field on mobile', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            state: const RefundState(mode: RefundMode.withoutReceipt),
            width: 400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Поиск товара для возврата'), findsOneWidget);
      });

      testWidgets('shows search field on desktop', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            state: const RefundState(mode: RefundMode.withoutReceipt),
            width: 1400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Поиск товара для возврата'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('State with Items', () {
      testWidgets('shows product names on desktop', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Молоко 1л'), findsOneWidget);
        expect(find.text('Хлеб белый'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows product names on mobile', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.byReceipt, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Молоко 1л'), findsOneWidget);
        expect(find.text('Хлеб белый'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state message on desktop', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.empty, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Нет товаров для возврата'), findsOneWidget);
        expect(find.text('Молоко 1л'), findsNothing);
        expect(find.text('Хлеб белый'), findsNothing);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows empty state message on mobile', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Нет товаров'), findsOneWidget);
        expect(find.text('Молоко 1л'), findsNothing);
      });
    });

    group('Loading State', () {
      testWidgets('renders without error when isLoading is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.loading, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundModeSelector), findsOneWidget);
        expect(find.byType(RefundTotalPanel), findsOneWidget);
      });

      testWidgets(
        'shows CircularProgressIndicator when searching in withoutReceipt mode',
        (tester) async {
          await tester.pumpWidget(
            createTestWidget(
              state: const RefundState(
                mode: RefundMode.withoutReceipt,
                searchQuery: 'молоко',
                isSearching: true,
              ),
              width: 400,
            ),
          );
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );
    });

    group('Error State', () {
      testWidgets('renders without crashing when error is set', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestRefundStates.withError, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RefundModeSelector), findsOneWidget);
        expect(find.byType(RefundTotalPanel), findsOneWidget);
      });
    });
  });
}
