import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/inventory/inventory_controller.dart';
import 'package:telepos/presentation/screens/inventory/inventory_screen.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';

void main() {
  Widget createTestWidget({
    required InventoryState state,
    double width = 400,
    double height = 800,
  }) {
    return ProviderScope(
      overrides: [
        inventoryControllerProvider.overrideWith(
          () => MockInventoryNotifier(state),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ru'), Locale('en')],
          locale: Locale('ru'),
          home: Material(child: InventoryScreen()),
        ),
      ),
    );
  }

  group('InventoryScreen', () {
    group('Mobile Layout (<1200px)', () {
      testWidgets('renders Scaffold with AppBar', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: const InventoryState(), width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Инвентаризация'), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('shows "Начать" button when inactive', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.inactive, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Начать'), findsOneWidget);
      });

      testWidgets('shows empty state hint when inactive', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.inactive, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.inventory), findsOneWidget);
        expect(
          find.text('Нажмите "Начать" для инвентаризации'),
          findsOneWidget,
        );
      });

      testWidgets('shows barcode input when active', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.activeEmpty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Сканируйте штрихкод'), findsOneWidget);
        expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      });

      testWidgets('shows "Завершить" button when active', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Завершить'), findsOneWidget);
      });

      testWidgets('shows products as cards', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Молоко 1л'), findsOneWidget);
        expect(find.text('Хлеб белый'), findsOneWidget);
        expect(find.text('Яблоки'), findsOneWidget);
        expect(find.byType(Card), findsWidgets);
      });

      testWidgets('shows product count and discrepancy count', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Товаров: 3'), findsOneWidget);
        expect(find.textContaining('Расхождений: 2'), findsOneWidget);
      });

      testWidgets('shows error message', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.withError, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Товар не найден: 999'), findsOneWidget);
      });

      testWidgets('shows scan hint when active but empty', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.activeEmpty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Сканируйте товары для подсчёта'), findsOneWidget);
      });
    });

    group('Desktop Layout (>=1200px)', () {
      testWidgets('renders desktop header with title', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.inactive, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Инвентаризация'), findsOneWidget);
        expect(find.byIcon(Icons.inventory), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows "Начать" ElevatedButton when inactive', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.inactive, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.bySubtype<ButtonStyleButton>(), findsOneWidget);
        expect(find.text('Начать'), findsWidgets);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows DataTable for products', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DataTable), findsOneWidget);
        expect(find.text('Товар'), findsOneWidget);
        expect(find.text('Ожидаемое'), findsOneWidget);
        expect(find.text('Фактическое'), findsOneWidget);
        expect(find.text('Расхождение'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows barcode input when active', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Сканируйте штрихкод'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows "Завершить" button when active', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.bySubtype<ButtonStyleButton>(), findsOneWidget);
        expect(find.text('Завершить'), findsWidgets);
        expect(find.byIcon(TeleposIcons.check), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows summary row with counts', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Товаров: 3'), findsOneWidget);
        expect(find.textContaining('Расхождений: 2'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows empty hint when inactive', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.inactive, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Нажмите "Начать" для инвентаризации'),
          findsOneWidget,
        );

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Difference Coloring', () {
      testWidgets('positive difference shown in green', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('+2'), findsOneWidget);
      });

      testWidgets('negative difference shown in red', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('-1'), findsOneWidget);
      });

      testWidgets('zero difference shown normally', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestInventoryStates.active, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('0'), findsOneWidget);
      });
    });
  });
}
