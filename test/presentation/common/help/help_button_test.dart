import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/help/help_button.dart';
import 'package:telepos/app/theme/app_theme.dart';

void main() {
  group('HelpButton', () {
    testWidgets('renders with help_outline icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ru'), Locale('en')],
          locale: Locale('ru'),
          home: Scaffold(body: HelpButton(screenId: 'sale')),
        ),
      );

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('uses custom color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ru'), Locale('en')],
          locale: Locale('ru'),
          home: Scaffold(
            body: HelpButton(screenId: 'sale', color: Colors.red),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.help_outline));
      expect(icon.color, Colors.red);
    });

    testWidgets('uses custom icon size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ru'), Locale('en')],
          locale: Locale('ru'),
          home: Scaffold(body: HelpButton(screenId: 'sale', iconSize: 32)),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.help_outline));
      expect(icon.size, 32);
    });

    testWidgets('is tappable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ru'), Locale('en')],
          locale: Locale('ru'),
          home: Scaffold(body: HelpButton(screenId: 'sale')),
        ),
      );

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();
    });
  });
}
