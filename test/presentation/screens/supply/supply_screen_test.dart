import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/supply/supply_controller.dart';
import 'package:telepos/presentation/screens/supply/supply_screen.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';

void main() {
  Widget createTestWidget({
    required SupplyState state,
    double width = 400,
    double height = 800,
  }) {
    return ProviderScope(
      overrides: [
        supplyControllerProvider.overrideWith(() => MockSupplyNotifier(state)),
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
          home: SupplyMobileScreen(),
        ),
      ),
    );
  }

  group('SupplyScreen (Mobile)', () {
    testWidgets('renders Scaffold with AppBar', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: const SupplyState(), width: 400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Приёмка товара'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows "Сохранить" button in AppBar', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: TestSupplyStates.withProducts, width: 400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Сохранить'), findsWidgets);
    });

    testWidgets('shows back button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: const SupplyState(), width: 400),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows SupplyForm', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: const SupplyState(), width: 400),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('shows error banner when error exists', (tester) async {
      final stateWithError = SupplyState(error: 'Товар не найден');

      await tester.pumpWidget(
        createTestWidget(state: stateWithError, width: 400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Товар не найден'), findsOneWidget);
      expect(find.byIcon(TeleposIcons.error), findsOneWidget);
    });

    testWidgets('shows total bar when products exist', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: TestSupplyStates.withProducts, width: 400),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Товаров: 2'), findsOneWidget);
      expect(find.textContaining('Итого:'), findsOneWidget);
    });

    testWidgets('hides total bar when no products', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: const SupplyState(), width: 400),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Товаров:'), findsNothing);
    });

    testWidgets('shows saving spinner', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: TestSupplyStates.saving, width: 400),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      const loadingState = SupplyState(isLoading: true);

      await tester.pumpWidget(
        createTestWidget(state: loadingState, width: 400),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('save button disabled when no products', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: const SupplyState(), width: 400),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Сохранить'));
      expect(textWidget.style?.color, equals(Colors.white54));
    });

    testWidgets('save button enabled with products', (tester) async {
      await tester.pumpWidget(
        createTestWidget(state: TestSupplyStates.withProducts, width: 400),
      );
      await tester.pumpAndSettle();

      final saveTexts = find.text('Сохранить');
      expect(saveTexts, findsWidgets);
    });
  });
}
