/// Сплеш стоит по центру окна, а не прижат к левому краю.
///
/// # Что измерено 2026-09-21
///
/// Заказчик, глядя на запись: «на сплеш странице съехал логотип». На кадре
/// из дубля знак, название и полоса действительно стоят в левой трети
/// широкого окна.
///
/// # Почему проба меряет, а не смотрит
///
/// У кадра есть вторая правдоподобная причина: запись подгоняет клиентскую
/// область окна под 1280×720 уже после запуска, и сплеш мог нарисоваться в
/// прежнем, меньшем размере — тогда справа осталась бы незакрашенная
/// область, а не дефект вёрстки. Отличить одно от другого глазами нельзя, и
/// «у замера тоже бывает зелёный цвет» — про такие случаи.
///
/// Здесь окно задано числом, и ответ однозначен.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/boot_stage.dart';
import 'package:telepos/presentation/screens/splash/splash_screen.dart';

/// Загрузка, которая никогда не кончается.
///
/// Нужна, чтобы сплеш СТРОИЛСЯ, а не подменялся виджетом ошибки: первая
/// редакция пробы этого не сделала, `AppBootstrap` не нашёлся, и мерилось
/// дерево с заглушкой — то есть не то, о чём проба. Не кончается намеренно:
/// уйти с экрана посреди замера ему незачем.
class _NeverFinishes implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) {
    onProgress(0.4, BootStage.loadingConfig);
    return Completer<AppInitStatus>().future;
  }
}

void main() {
  setUp(() {
    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<AppBootstrap>(_NeverFinishes());
  });

  tearDown(() => GetIt.I.reset());

  testWidgets('знак приложения стоит по центру широкого окна', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale("en"),
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final title = find.text('TelePOS');
    expect(title, findsOneWidget, reason: 'сплеш не нарисовался вовсе');

    final centre = tester.getCenter(title);
    expect(
      centre.dx,
      closeTo(640, 2),
      reason:
          'название стоит на ${centre.dx.toStringAsFixed(0)} вместо 640 — '
          'содержимое сплеша прижато к краю, а не стоит по центру окна',
    );
  });

  testWidgets('на узком окне тоже по центру', (tester) async {
    // Обратная сторона: правка не имеет права починить широкое окно ценой
    // узкого. Телефон — первый экран, который увидит большинство.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale("en"),
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final centre = tester.getCenter(find.text('TelePOS'));
    expect(centre.dx, closeTo(210, 2));
  });
}
