import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';

class _GoldenApp extends StatelessWidget {
  const _GoldenApp({required this.child, required this.brightness});

  final Widget child;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
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
      // Тема приложения, а не материальная по умолчанию.
      //
      // Здесь стояла ThemeData.light, то есть все эталоны снимались палитрой,
      // которой в кассе нет: голден "подтверждал" оформление, никогда не
      // существовавшее на экране. Та же ошибка, что была со шрифтом Arial.
      //
      // Тема выбирается снаружи, а не прибита к светлой. `AppTheme.dark`
      // подключена 2026-08-04, до того она была мёртвым кодом; эталон,
      // снимаемый только в светлой, оставил бы её мёртвой и дальше — уже
      // «проверенной».
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: child,
    );
  }
}

class TestBreakpoints {
  TestBreakpoints._();

  static const mobile = Size(360, 640);
  static const tablet = Size(800, 1024);
  static const desktop = Size(1280, 800);
}

class GoldenTestHelpers {
  GoldenTestHelpers._();

  static const mobileTag = 'mobile';
  static const tabletTag = 'tablet';
  static const desktopTag = 'desktop';

  /// Тёмный снимок получает суффикс, светлый — нет.
  ///
  /// Так 86 уже снятых эталонов остаются на своих именах: переименование ради
  /// симметрии превратило бы «добавили тёмную» в «переснимали всё», и разницу
  /// между этими двумя изменениями в истории уже никто бы не увидел.
  static String _suffix(Brightness brightness) =>
      brightness == Brightness.dark ? '_dark' : '';

  static Future<void> matchGoldenMobile(
    WidgetTester tester,
    Widget widget,
    String name, {
    Brightness brightness = Brightness.light,
  }) async {
    await _matchGoldenAtSize(
      tester,
      widget,
      name,
      TestBreakpoints.mobile,
      mobileTag,
      brightness,
    );
  }

  static Future<void> matchGoldenTablet(
    WidgetTester tester,
    Widget widget,
    String name, {
    Brightness brightness = Brightness.light,
  }) async {
    await _matchGoldenAtSize(
      tester,
      widget,
      name,
      TestBreakpoints.tablet,
      tabletTag,
      brightness,
    );
  }

  static Future<void> matchGoldenDesktop(
    WidgetTester tester,
    Widget widget,
    String name, {
    Brightness brightness = Brightness.light,
  }) async {
    await _matchGoldenAtSize(
      tester,
      widget,
      name,
      TestBreakpoints.desktop,
      desktopTag,
      brightness,
    );
  }

  static Future<void> matchGoldenAllBreakpoints(
    WidgetTester tester,
    Widget widget,
    String name, {
    Brightness brightness = Brightness.light,
  }) async {
    await matchGoldenMobile(tester, widget, name, brightness: brightness);
    await matchGoldenTablet(tester, widget, name, brightness: brightness);
    await matchGoldenDesktop(tester, widget, name, brightness: brightness);
  }

  static Future<void> _matchGoldenAtSize(
    WidgetTester tester,
    Widget widget,
    String name,
    Size size,
    String tag,
    Brightness brightness,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      _GoldenApp(brightness: brightness, child: widget),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/${name}_$tag${_suffix(brightness)}.png'),
    );

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}
