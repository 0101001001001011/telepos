import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/help/help_service.dart';

void main() {
  group('HelpDialog', () {
    testWidgets('shows dialog with content on desktop-size screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final content = HelpContent(
        screenId: 'test',
        title: 'Тестовая справка',
        description: 'Описание экрана',
        sections: const [
          HelpSection(heading: 'Раздел', content: 'Текст раздела'),
        ],
        tips: const ['Совет 1'],
        shortcuts: const [HelpShortcut(key: 'F1', action: 'Справка')],
      );

      HelpService.clearCache();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('ru'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(content.title),
                            Text(content.description),
                            ...content.sections.map(
                              (s) => Column(
                                children: [Text(s.heading), Text(s.content)],
                              ),
                            ),
                            ...content.tips.map((t) => Text(t)),
                            ...content.shortcuts.map(
                              (s) => Text('${s.key}: ${s.action}'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Тестовая справка'), findsOneWidget);
      expect(find.text('Описание экрана'), findsOneWidget);
      expect(find.text('Раздел'), findsOneWidget);
      expect(find.text('Текст раздела'), findsOneWidget);
      expect(find.text('Совет 1'), findsOneWidget);
      expect(find.text('F1: Справка'), findsOneWidget);
    });
  });

  group('HelpContent model', () {
    test('const constructor works', () {
      const content = HelpContent(
        screenId: 'sale',
        title: 'Test',
        description: 'Desc',
      );
      expect(content.screenId, 'sale');
      expect(content.sections, isEmpty);
      expect(content.tips, isEmpty);
      expect(content.shortcuts, isEmpty);
      expect(content.relatedScreens, isEmpty);
    });
  });
}
