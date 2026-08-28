import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/screens/agent/agent_screen.dart';
import 'package:telepos/presentation/screens/agent/widgets/agent_search_bar.dart';
import 'package:telepos/presentation/screens/agent/widgets/agent_table.dart';

import '../../../helpers/mock_providers.dart';
import '../../../fixtures/test_states.dart';
import 'package:telepos/app/theme/app_theme.dart';

void main() {
  Widget createTestWidget({
    required AgentSearchState agentSearchState,
    AddCustomerState? addCustomerState,
    double width = 400,
    double height = 800,
  }) {
    return ProviderScope(
      overrides: [
        agentSearchProvider.overrideWith(
          () => MockAgentSearchNotifier(agentSearchState),
        ),
        addCustomerProvider.overrideWith(
          () => MockAddCustomerNotifier(addCustomerState),
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
          home: AgentScreen(),
        ),
      ),
    );
  }

  group('AgentScreen', () {
    group('Desktop Layout (>=900px)', () {
      testWidgets('shows AgentSearchBar', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.empty,
            width: 1200,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AgentSearchBar), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows header row with agent type title', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.empty,
            width: 1200,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Клиенты'), findsWidgets);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows "Добавить" ElevatedButton', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.empty,
            width: 1200,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Добавить'), findsOneWidget);
        expect(find.byIcon(Icons.person_add), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows AgentTable when items present', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.withAgents,
            width: 1200,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AgentTable), findsOneWidget);
        expect(find.byType(DataTable), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('shows "Найдено" count when items present', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.withAgents,
            width: 1200,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Найдено: 3'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    group('Mobile Layout (<600px)', () {
      testWidgets('shows AppBar with "Клиенты"', (tester) async {
        await tester.pumpWidget(
          createTestWidget(agentSearchState: TestAgentStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Клиенты'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('shows search TextField', (tester) async {
        await tester.pumpWidget(
          createTestWidget(agentSearchState: TestAgentStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Поиск по имени или телефону...'), findsWidgets);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('shows FAB with person_add icon', (tester) async {
        await tester.pumpWidget(
          createTestWidget(agentSearchState: TestAgentStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.person_add), findsOneWidget);
      });

      testWidgets('shows debt filter toggle icon in AppBar', (tester) async {
        await tester.pumpWidget(
          createTestWidget(agentSearchState: TestAgentStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.money_off_outlined), findsOneWidget);
        expect(find.byTooltip('Только с долгом'), findsOneWidget);
      });

      testWidgets('shows agent cards when items present', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.withAgents,
            width: 400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Покупатель Тест'), findsOneWidget);
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('debt filter icon changes when active', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: const AgentSearchState(showOnlyWithDebt: true),
            width: 400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.money_off), findsOneWidget);
      });
    });

    group('Tablet Layout (600-900px)', () {
      testWidgets('shows compact AgentSearchBar', (tester) async {
        await tester.pumpWidget(
          createTestWidget(agentSearchState: TestAgentStates.empty, width: 750),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AgentSearchBar), findsOneWidget);
      });

      testWidgets('shows FAB instead of inline button', (tester) async {
        await tester.pumpWidget(
          createTestWidget(agentSearchState: TestAgentStates.empty, width: 750),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.person_add), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('desktop shows empty icon and hint text', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.empty,
            width: 1200,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);
        expect(find.text('Поиск по имени или телефону...'), findsWidgets);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('mobile shows empty icon and hint text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(agentSearchState: TestAgentStates.empty, width: 400),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);
        expect(find.text('Поиск по имени или телефону...'), findsWidgets);
      });

      testWidgets(
        'desktop shows "Клиенты не найдены" when search has no results',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 900);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            createTestWidget(
              agentSearchState: const AgentSearchState(
                searchQuery: 'несуществующий',
                items: [],
              ),
              width: 1200,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Клиенты не найдены'), findsOneWidget);

          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        },
      );

      testWidgets('tablet shows empty hint text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(agentSearchState: TestAgentStates.empty, width: 750),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);
        expect(find.text('Поиск клиентов'), findsOneWidget);
      });
    });

    group('With Agents', () {
      testWidgets('desktop shows agent names in table', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.withAgents,
            width: 1200,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Покупатель Тест'), findsOneWidget);
        expect(find.text('ТОО "Поставщик"'), findsOneWidget);
        expect(find.text('Клиент без долга'), findsOneWidget);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('mobile shows agent names in cards', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.withAgents,
            width: 400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Покупатель Тест'), findsOneWidget);
        expect(find.text('ТОО "Поставщик"'), findsOneWidget);
        expect(find.text('Клиент без долга'), findsOneWidget);
      });

      testWidgets('mobile shows CircleAvatar initials', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.withAgents,
            width: 400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('П'), findsOneWidget);
        expect(find.text('Т'), findsOneWidget);
        expect(find.text('К'), findsOneWidget);
      });

      testWidgets('shows balance values', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.withAgents,
            width: 400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('-5000.00'), findsOneWidget);
        expect(find.text('100000.00'), findsOneWidget);
        expect(find.text('0.00'), findsOneWidget);
      });

      testWidgets('shows chevron_right icon on mobile cards', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.withAgents,
            width: 400,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
      });
    });

    group('Loading State', () {
      testWidgets('mobile shows CircularProgressIndicator', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.loading,
            width: 400,
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Supplier Mode', () {
      testWidgets('desktop header shows "Поставщики" for supplier type', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          createTestWidget(
            agentSearchState: TestAgentStates.suppliers,
            width: 1200,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Поставщики'), findsWidgets);

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
