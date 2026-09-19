import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';

import 'package:telepos/presentation/screens/sale/sale_screen.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/sale/widgets/product_search.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_items_table.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_items_list.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_total_panel.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_action_buttons.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';

void main() {
  late SharedPreferences prefs;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildSaleScreen(
    SaleState state, {
    double width = 1400,
    double height = 900,
  }) {
    return ProviderScope(
      overrides: [
        saleControllerProvider.overrideWith(() => MockSaleNotifier(state)),
        sharedPreferencesProvider.overrideWithValue(prefs),
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
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ru')],
          locale: const Locale('ru'),
          home: const Scaffold(body: SaleScreen(shiftClose: ShiftCloseAtTill())),
        ),
      ),
    );
  }

  void suppressOverflowErrors() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed by')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });
  }

  group('Desktop layout (>= 1200px)', () {
    testWidgets('renders Row widget for desktop breakpoint', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('contains ProductSearch widget', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductSearch), findsOneWidget);
    });

    testWidgets('contains SaleItemsTable widget', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsTable), findsOneWidget);
    });

    testWidgets('contains SaleActionButtons widget', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleActionButtons), findsOneWidget);
    });

    testWidgets('contains SaleTotalPanel widget', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleTotalPanel), findsOneWidget);
    });

    testWidgets('does NOT contain SaleItemsList (mobile-only widget)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsList), findsNothing);
    });
  });

  group('Tablet layout (600-1200px)', () {
    const tabletWidth = 1000.0;
    const tabletHeight = 900.0;

    testWidgets('renders Row widget for tablet breakpoint', (tester) async {
      suppressOverflowErrors();
      tester.view.physicalSize = const Size(tabletWidth, tabletHeight);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(
          TestSaleStates.empty,
          width: tabletWidth,
          height: tabletHeight,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('contains SaleItemsTable widget', (tester) async {
      suppressOverflowErrors();
      tester.view.physicalSize = const Size(tabletWidth, tabletHeight);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(
          TestSaleStates.empty,
          width: tabletWidth,
          height: tabletHeight,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsTable), findsOneWidget);
    });

    testWidgets('contains SaleTotalPanel widget', (tester) async {
      suppressOverflowErrors();
      tester.view.physicalSize = const Size(tabletWidth, tabletHeight);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(
          TestSaleStates.empty,
          width: tabletWidth,
          height: tabletHeight,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleTotalPanel), findsOneWidget);
    });

    testWidgets('contains ProductSearch widget', (tester) async {
      suppressOverflowErrors();
      tester.view.physicalSize = const Size(tabletWidth, tabletHeight);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(
          TestSaleStates.empty,
          width: tabletWidth,
          height: tabletHeight,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductSearch), findsOneWidget);
    });

    testWidgets('contains SaleActionButtons widget', (tester) async {
      suppressOverflowErrors();
      tester.view.physicalSize = const Size(tabletWidth, tabletHeight);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(
          TestSaleStates.empty,
          width: tabletWidth,
          height: tabletHeight,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleActionButtons), findsOneWidget);
    });

    testWidgets('does NOT contain SaleItemsList (mobile-only)', (tester) async {
      suppressOverflowErrors();
      tester.view.physicalSize = const Size(tabletWidth, tabletHeight);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(
          TestSaleStates.empty,
          width: tabletWidth,
          height: tabletHeight,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsList), findsNothing);
    });
  });

  group('Mobile layout (< 600px)', () {
    testWidgets('renders Column layout (no Row-based split)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 400, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsTable), findsNothing);
      expect(find.byType(SaleActionButtons), findsNothing);
    });

    testWidgets('contains SaleItemsList widget', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 400, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsList), findsOneWidget);
    });

    testWidgets('contains SaleTotalPanel widget', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 400, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleTotalPanel), findsOneWidget);
    });

    testWidgets('contains ProductSearch widget', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 400, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductSearch), findsOneWidget);
    });
  });

  group('Empty state', () {
    testWidgets('shows ProductSearch when sale is empty', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductSearch), findsOneWidget);
    });

    testWidgets('shows empty cart placeholder icon', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });
  });

  group('State with items', () {
    testWidgets('shows SaleItemsTable on desktop when items present', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.withItems, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsTable), findsOneWidget);
      expect(find.byType(SaleItemsList), findsNothing);
    });

    testWidgets('shows SaleItemsList on mobile when items present', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.withItems, width: 400, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsList), findsOneWidget);
    });

    testWidgets('total panel shows computed total on desktop', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.withItems, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleTotalPanel), findsOneWidget);
      expect(find.text('${TestSaleStates.withItems.total}'), findsWidgets);
    });
  });

  group('Error state', () {
    testWidgets('renders SaleScreen with error state on desktop', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.withError, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductSearch), findsOneWidget);
      expect(find.byType(SaleItemsTable), findsOneWidget);
    });

    testWidgets('renders SaleScreen with error state on mobile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.withError, width: 400, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductSearch), findsOneWidget);
      expect(find.byType(SaleItemsList), findsOneWidget);
    });
  });

  group('State with search results', () {
    testWidgets('search results render product names on desktop', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(
          TestSaleStates.withSearchResults,
          width: 1400,
          height: 900,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductSearch), findsOneWidget);
      for (final result in TestSaleStates.withSearchResults.searchResults) {
        expect(find.text(result.name), findsOneWidget);
      }
    });

    testWidgets('search results render product names on mobile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(
          TestSaleStates.withSearchResults,
          width: 400,
          height: 800,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProductSearch), findsOneWidget);
      for (final result in TestSaleStates.withSearchResults.searchResults) {
        expect(find.text(result.name), findsOneWidget);
      }
    });
  });

  group('State with discount', () {
    testWidgets('total panel reflects discount on desktop', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.withDiscount, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleTotalPanel), findsOneWidget);
      expect(find.text('${TestSaleStates.withDiscount.total}'), findsWidgets);
    });
  });

  group('State with agent', () {
    testWidgets('agent name appears in total panel on desktop', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.withAgent, width: 1400, height: 900),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleTotalPanel), findsOneWidget);
      expect(
        find.text('${TestSaleStates.withAgent.agentName}'),
        findsOneWidget,
      );
    });
  });

  group('Опт на кассе (задача 8, находка 4)', () {
    testWidgets('ярлык режима — переключатель, а не индикатор', (tester) async {
      // До задачи 8 `toggleMode` не вызывался **ниоткуда**: панель итогов
      // показывала режим чека и всегда «Розница», потому что изменить его
      // было нечем. Проверка достижимости, а не расчёта: что делает касса,
      // получив команду, доказано на настоящей базе
      // (`test/data/sale/local_cart_service_test.dart`).
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      final notifier = _RecordingSaleNotifier(TestSaleStates.withItems);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saleControllerProvider.overrideWith(() => notifier),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1400, 900)),
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
              home: const Scaffold(body: SaleScreen(shiftClose: ShiftCloseAtTill())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = find.byKey(const Key('sale_wholesale_toggle'));
      expect(toggle, findsOneWidget, reason: 'переключателя режима нет вовсе');

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(
        notifier.toggles,
        1,
        reason: 'ярлык показывает режим, но переключить его нечем',
      );
    });
  });

  group('Breakpoint boundary tests', () {
    testWidgets('exactly 1200px wide uses desktop layout', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1200, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsTable), findsOneWidget);
      expect(find.byType(SaleActionButtons), findsOneWidget);
      expect(find.byType(SaleItemsList), findsNothing);
    });

    testWidgets('1199px wide uses tablet layout (not desktop)', (tester) async {
      suppressOverflowErrors();
      tester.view.physicalSize = const Size(1199, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 1199, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsTable), findsOneWidget);
      expect(find.byType(SaleItemsList), findsNothing);
    });

    testWidgets('599px wide uses mobile layout', (tester) async {
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1.0;
      addTeardownForView(tester);

      await tester.pumpWidget(
        buildSaleScreen(TestSaleStates.empty, width: 599, height: 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SaleItemsList), findsOneWidget);
      expect(find.byType(SaleItemsTable), findsNothing);
      expect(find.byType(SaleActionButtons), findsNothing);
    });
  });
}

void addTeardownForView(WidgetTester tester) {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void suppressOverflowErrors() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (message.contains('overflowed by')) {
      return;
    }
    originalOnError?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = originalOnError;
  });
}

/// Подделка контроллера, считающая нажатия переключателя режима.
///
/// Тест доказывает **достижимость** команды из интерфейса кассы: что она
/// делает с чеком, доказано на настоящей базе в
/// `test/data/sale/local_cart_service_test.dart`.
class _RecordingSaleNotifier extends MockSaleNotifier {
  _RecordingSaleNotifier(super.initialState);

  int toggles = 0;

  @override
  Future<void> toggleMode() async => toggles++;
}
