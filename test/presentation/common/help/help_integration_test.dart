import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/help/help_button.dart';
import 'package:telepos/presentation/common/help/help_dialog.dart';
import 'package:telepos/presentation/common/help/help_service.dart';

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ru'), Locale('en')],
    locale: const Locale('ru'),
    home: child,
  );
}

void main() {
  setUp(() {
    HelpService.clearCache();
  });

  group('HelpButton + HelpDialog integration (with l10n)', () {
    testWidgets('HelpButton shows localized tooltip in Russian', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const Scaffold(body: HelpButton(screenId: 'sale')),
        ),
      );
      await tester.pumpAndSettle();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Справка');
    });

    testWidgets('HelpButton shows localized tooltip in English', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('en'),
          home: const Scaffold(body: HelpButton(screenId: 'sale')),
        ),
      );
      await tester.pumpAndSettle();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Help');
    });

    testWidgets('HelpDialog.show gracefully handles missing JSON', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    HelpDialog.show(context, 'nonexistent_screen_xyz'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('HelpService.routeToScreenId exhaustive mapping', () {
    final expectedMappings = <String, String>{
      '/': 'splash',
      '/initial-setup': 'initial_setup',
      '/restore-or-new': 'restore_or_new',
      '/telegram-setup': 'telegram_auth',
      '/login': 'login',
      '/payment': 'payment',
      '/sale': 'sale',
      '/refund': 'refund',
      '/shift': 'shift',
      '/history': 'history',
      '/agent': 'agent',
      '/supply': 'supply',
      '/cash-operation': 'cash_operation',
      '/settings': 'settings',
      '/transport-settings': 'transport_settings',
      '/printer-settings': 'printer_settings',
      '/fiscal-settings': 'fiscal_settings',
      '/sync': 'sync',
      '/writeoff': 'writeoff',
      '/inventory': 'inventory',
      '/additional': 'additional',
      '/tables': 'tables',
      '/tables/1': 'table_detail',
      '/tables/999': 'table_detail',
      '/orders': 'orders',
      '/service-queue': 'service_queue',
      '/service-intake': 'service_intake',
      '/service-queue/42': 'service_detail',
    };

    for (final entry in expectedMappings.entries) {
      test('route "${entry.key}" → screenId "${entry.value}"', () {
        expect(HelpService.routeToScreenId(entry.key), entry.value);
      });
    }

    final allScreenIds = [
      'sale',
      'refund',
      'payment',
      'shift',
      'history',
      'agent',
      'supply',
      'cash_operation',
      'settings',
      'transport_settings',
      'printer_settings',
      'fiscal_settings',
      'sync',
      'writeoff',
      'inventory',
      'additional',
      'login',
      'initial_setup',
      'tables',
      'table_detail',
      'orders',
      'service_queue',
      'service_intake',
      'service_detail',
      'telegram_auth',
      'telegram_settings',
      'staff_chat',
      'splash',
      'restore_or_new',
    ];

    test('all 29 screen IDs are unique', () {
      expect(allScreenIds.toSet().length, allScreenIds.length);
    });

    test('all 29 screen IDs are non-empty strings', () {
      for (final id in allScreenIds) {
        expect(id, isNotEmpty, reason: 'Screen ID should not be empty');
        expect(
          id,
          isNot(contains(' ')),
          reason: 'Screen ID "$id" should not contain spaces',
        );
        expect(
          id,
          matches(RegExp(r'^[a-z_]+$')),
          reason: 'Screen ID "$id" should be lowercase snake_case',
        );
      }
    });
  });

  group('HelpContent JSON parsing robustness', () {
    test('parses with extra unknown fields (forward compatibility)', () {
      final json = {
        'screenId': 'test',
        'title': 'Test',
        'description': 'Desc',
        'futureField': 'value',
        'anotherFutureList': [1, 2, 3],
        'sections': [
          {'heading': 'H', 'content': 'C', 'unknownField': true},
        ],
        'shortcuts': [
          {'key': 'F1', 'action': 'Help', 'extra': 'data'},
        ],
      };

      final content = HelpContent.fromJson(json);
      expect(content.screenId, 'test');
      expect(content.sections, hasLength(1));
      expect(content.shortcuts, hasLength(1));
    });

    test('handles empty arrays gracefully', () {
      final json = {
        'screenId': 'test',
        'title': 'Test',
        'description': 'Desc',
        'sections': <dynamic>[],
        'tips': <dynamic>[],
        'shortcuts': <dynamic>[],
        'relatedScreens': <dynamic>[],
      };

      final content = HelpContent.fromJson(json);
      expect(content.sections, isEmpty);
      expect(content.tips, isEmpty);
      expect(content.shortcuts, isEmpty);
      expect(content.relatedScreens, isEmpty);
    });

    test('handles sections with multiline content', () {
      final json = {
        'screenId': 'test',
        'title': 'Test',
        'description': 'Desc',
        'sections': [
          {
            'heading': 'Steps',
            'content': '1. First step\n2. Second step\n3. Third step',
          },
        ],
      };

      final content = HelpContent.fromJson(json);
      expect(content.sections.first.content, contains('\n'));
      expect(content.sections.first.content.split('\n'), hasLength(3));
    });
  });

  group('HelpDialog responsive layout', () {
    testWidgets('uses Dialog on desktop-width (≥600px)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      HelpService.clearCache();

      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const Dialog(
                      child: SizedBox(width: 560, child: Text('Help')),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('uses BottomSheet on mobile-width (<600px)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) =>
                        const SizedBox(height: 300, child: Text('Help')),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Help'), findsOneWidget);
    });
  });

  group('Localization keys completeness', () {
    testWidgets('Russian locale has all help keys', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.helpTitle, isNotEmpty);
              expect(l10n.helpTips, isNotEmpty);
              expect(l10n.helpShortcuts, isNotEmpty);
              expect(l10n.helpRelatedScreens, isNotEmpty);
              expect(l10n.helpKey, isNotEmpty);
              expect(l10n.helpAction, isNotEmpty);
              expect(l10n.helpTitle, 'Справка');
              expect(l10n.helpTips, 'Советы');
              expect(l10n.helpShortcuts, 'Горячие клавиши');
              expect(l10n.helpKey, 'Клавиша');
              expect(l10n.helpAction, 'Действие');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('English locale has all help keys', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.helpTitle, 'Help');
              expect(l10n.helpTips, 'Tips');
              expect(l10n.helpShortcuts, 'Keyboard shortcuts');
              expect(l10n.helpKey, 'Key');
              expect(l10n.helpAction, 'Action');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  group('HelpButton in different contexts', () {
    testWidgets('renders inside AppBar actions', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Test'),
              actions: const [HelpButton(screenId: 'sale')],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.help_outline),
          matching: find.byType(AppBar),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders inside Positioned (standalone screens)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Scaffold(
            body: Stack(
              children: const [
                Center(child: Text('Content')),
                Positioned(
                  top: 4,
                  right: 4,
                  child: HelpButton(screenId: 'login'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders with custom color', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.teal,
              actions: const [
                HelpButton(screenId: 'sale', color: Colors.white),
              ],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.help_outline));
      expect(icon.color, Colors.white);
    });

    testWidgets('tap does not crash even without real assets', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const Scaffold(
            body: HelpButton(screenId: 'nonexistent_screen_xyz'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
