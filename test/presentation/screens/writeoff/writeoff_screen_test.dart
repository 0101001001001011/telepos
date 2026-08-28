import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/writeoff/writeoff_controller.dart';
import 'package:telepos/presentation/screens/writeoff/writeoff_screen.dart';
import 'package:telepos/domain/usecases/writeoff/create_writeoff_use_case.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';

void main() {
  Widget createTestWidget({
    required WriteoffState state,
    double width = 400,
    double height = 800,
  }) {
    return ProviderScope(
      overrides: [
        writeoffControllerProvider.overrideWith(
          () => MockWriteoffNotifier(state),
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
          home: Material(child: WriteoffScreen()),
        ),
      ),
    );
  }

  group('WriteoffScreen', () {
    group('Mobile Layout (<1200px)', () {
      testWidgets('renders Scaffold with AppBar', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: const WriteoffState(), width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Списание'), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('shows "Сохранить" button in AppBar', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.withProducts, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Сохранить'), findsOneWidget);
      });

      testWidgets('shows barcode input field', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: const WriteoffState(), width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsWidgets);
        expect(find.text('Сканируйте штрихкод'), findsOneWidget);
      });

      testWidgets('shows reason dropdown', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: const WriteoffState(), width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Причина'), findsOneWidget);
        expect(
          find.byType(DropdownButtonFormField<WriteoffReason>),
          findsOneWidget,
        );
      });

      testWidgets('shows products as cards', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.withProducts, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Молоко 1л'), findsOneWidget);
        expect(find.text('Хлеб белый'), findsOneWidget);
        expect(find.byType(Card), findsWidgets);
      });

      testWidgets('shows total bar with product count', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.withProducts, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Товаров: 2'), findsOneWidget);
        expect(find.textContaining('Итого:'), findsOneWidget);
      });

      testWidgets('shows error message', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.withError, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Товар не найден: 999'), findsOneWidget);
      });

      testWidgets('shows comment field', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: const WriteoffState(), width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Комментарий'), findsOneWidget);
        expect(find.text('Необязательно'), findsOneWidget);
      });

      testWidgets('shows saving spinner', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.saving, width: 400),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Desktop Layout (>=1200px)', () {
      testWidgets('renders desktop header with title', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: const WriteoffState(), width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Списание'), findsOneWidget);
        expect(find.byIcon(TeleposIcons.delete), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows "Сохранить" ElevatedButton', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.withProducts, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(
          find.ancestor(
            of: find.text('Сохранить'),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
          findsOneWidget,
        );

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows DataTable for products', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.withProducts, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DataTable), findsOneWidget);
        expect(find.text('Молоко 1л'), findsOneWidget);
        expect(find.text('Хлеб белый'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows total row', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.withProducts, width: 1400),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Товаров: 2'), findsOneWidget);
        expect(find.textContaining('Итого:'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('State Rendering', () {
      testWidgets('empty state shows barcode hint', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: const WriteoffState(), width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Сканируйте штрихкод'), findsOneWidget);
      });

      testWidgets('displays correct reason label', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: TestWriteoffStates.expired, width: 400),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(DropdownButtonFormField<WriteoffReason>),
          findsOneWidget,
        );
      });

      testWidgets('canSave is false when no products', (tester) async {
        await tester.pumpWidget(
          createTestWidget(state: const WriteoffState(), width: 400),
        );
        await tester.pumpAndSettle();

        final textWidget = tester.widget<Text>(find.text('Сохранить'));
        final style = textWidget.style;
        expect(style?.color, equals(Colors.white54));
      });
    });
  });
}
