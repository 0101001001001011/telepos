import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/additional/additional_screen.dart';

void main() {
  setUp(() {
    final getIt = GetIt.I;
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget createTestWidget() {
    return ProviderScope(
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
        supportedLocales: const [Locale('ru'), Locale('en')],
        locale: const Locale('ru'),
        home: const AdditionalScreen(),
        onGenerateRoute: (settings) =>
            MaterialPageRoute(builder: (_) => const AdditionalScreen()),
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

  void setMobileSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
  }

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
  }

  void setTabletSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetSize(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('AdditionalScreen', () {
    group('Mobile Layout (<900px)', () {
      testWidgets('renders Scaffold with AppBar', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Дополнительно'), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);

        resetSize(tester);
      });

      testWidgets('shows GridView with action cards', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GridView), findsOneWidget);
        expect(find.byType(Card), findsWidgets);

        resetSize(tester);
      });

      testWidgets('shows key action labels', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Выход'), findsOneWidget);
        expect(find.text('Блокировка'), findsOneWidget);
        expect(find.text('Принтер'), findsOneWidget);
        expect(find.text('Синхронизация'), findsOneWidget);

        resetSize(tester);
      });

      testWidgets('shows action icons', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.logout), findsOneWidget);
        expect(find.byIcon(Icons.lock), findsOneWidget);
        expect(find.byIcon(Icons.print), findsOneWidget);
        expect(find.byIcon(Icons.sync), findsOneWidget);

        resetSize(tester);
      });

      testWidgets('hides desktop-only actions on mobile', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Свернуть'), findsNothing);

        resetSize(tester);
      });

      testWidgets('uses 2-column grid on mobile', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final gridView = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(2));

        resetSize(tester);
      });

      testWidgets('shows supply action', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Приёмка'), findsOneWidget);
        expect(find.byIcon(Icons.inventory_2), findsOneWidget);

        resetSize(tester);
      });

      testWidgets('shows language action', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Язык'), findsOneWidget);
        expect(find.byIcon(Icons.language), findsOneWidget);

        resetSize(tester);
      });

      testWidgets('shows Kaspi POS action', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Kaspi POS'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Kaspi POS'), findsOneWidget);
        expect(find.byIcon(Icons.credit_card), findsOneWidget);

        resetSize(tester);
      });

      testWidgets('shows customers action', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Покупатели'), findsOneWidget);
        expect(find.byIcon(Icons.people), findsOneWidget);

        resetSize(tester);
      });
    });

    group('Desktop Layout (>=900px)', () {
      testWidgets('shows title without AppBar', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Дополнительно'), findsOneWidget);

        resetSize(tester);
      });

      testWidgets('uses 3-column grid on desktop', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final gridView = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(3));

        resetSize(tester);
      });

      testWidgets('shows desktop-only actions', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Свернуть'), findsOneWidget);
        expect(find.byIcon(Icons.minimize), findsOneWidget);

        resetSize(tester);
      });

      testWidgets('shows all 13 actions on desktop', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byType(Card),
          findsNWidgets(AdditionalAction.values.length),
        );

        resetSize(tester);
      });
    });

    group('Tablet Layout (600-900px)', () {
      testWidgets('uses 2-column grid on tablet', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final gridView = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(2));

        resetSize(tester);
      });

      testWidgets('shows AppBar on tablet', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Дополнительно'), findsOneWidget);

        resetSize(tester);
      });
    });

    group('Interactions', () {
      testWidgets('tapping logout shows confirmation dialog', (tester) async {
        suppressOverflowErrors();
        setMobileSize(tester);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Выход'));
        await tester.pumpAndSettle();

        expect(find.text('Выход'), findsNWidgets(4));
        expect(find.text('Отмена'), findsOneWidget);

        resetSize(tester);
      });
    });
  });
}
