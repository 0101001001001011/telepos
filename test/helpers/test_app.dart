import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Подмостки, поднимающие экран под **темой приложения**.
///
/// Раньше здесь стояла `ThemeData.light(useMaterial3: true)` — чужая тема. Она
/// не несёт ни `AppSemanticColors`, ни типографики, ни настроенных под-тем, и
/// проверка под ней доказывала поведение экрана в приложении, которого нет.
///
/// Это не косметика: под чужой темой любой экран, взявший роль `canvas` или
/// `hairline`, падает на `Null check operator used on a null value` — расширения
/// в теме просто нет. Пока экраны красили фон константами, разницы не было
/// видно, и подмена сходила с рук; ровно поэтому её и не замечали.
class TestApp extends StatelessWidget {
  const TestApp({
    required this.child,
    this.locale = const Locale('ru'),
    this.themeMode = ThemeMode.light,
    super.key,
  });

  final Widget child;

  final Locale locale;

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
        Locale('kk'),
        Locale('ky'),
        Locale('uz'),
      ],
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: child,
    );
  }
}

class TestScaffold extends StatelessWidget {
  const TestScaffold({
    required this.body,
    this.locale = const Locale('ru'),
    super.key,
  });

  final Widget body;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return TestApp(
      locale: locale,
      child: Scaffold(body: body),
    );
  }
}
