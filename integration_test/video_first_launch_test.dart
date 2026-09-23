/// Съёмочный дубль урока 2 — первый запуск.
///
/// Правила студии соблюдены теми же средствами, что в уроках 3, 5 и 7: без
/// звука, курсор ведётся к цели с паузой полсекунды до и после нажатия,
/// ровное 16:9 (размер задаёт `record_window.ps1`), часы заморожены, в кадре
/// нет личных данных.
///
/// Имена отметок `[VIDEO-MARK]` совпадают с именами `@`-блоков в
/// `docs/internal/video/02-narration.txt` — это вся связь между текстом и
/// картинкой, отдельной таблицы соответствий нет намеренно.
///
/// # Чего здесь НЕТ: установщика
///
/// Решение заказчика 2026-09-23: «установщик стандартный, там не надо
/// съёмку делать, после установки то что происходит важно». Четыре
/// стандартных окна Windows и человек, жмущий «Далее», не учат никого.
/// Урок начинается с того, чем установка кончилась.
///
/// Попутно это снимает препятствие, которое иначе было бы непреодолимым:
/// запрос прав UAC идёт на защищённом рабочем столе — его нельзя ни
/// записать, ни нажать программно, а после повышения окно установщика
/// недоступно для ввода из непривилегированного процесса (UIPI).
///
/// # База ПУСТАЯ
///
/// Иначе это будет не первый запуск, а повторный — другой экран и другой
/// разговор. Дубль НИКУДА НЕ ХОДИТ сам: смысл урока в том, куда касса
/// придёт без подсказки.
///
/// # Запуск
///
///     powershell -File tools/record_window.ps1 -Out docs/internal/video/out/lesson-02-take1.mp4
///     flutter test integration_test/video_first_launch_test.dart -d windows
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/di/service_locator.dart' show configureDependencies;
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/l10n/app_localizations.dart';

import 'support/cursor.dart';

/// Сколько секунд держится каждый блок.
///
/// # Числа не на глаз
///
/// Это длина НАЧИТКИ, посчитанная по словам: `docs/internal/video/
/// 02-narration.txt`, 199 слов на блок в среднем сто пятьдесят слов в
/// минуту — темп, которым читает синтез. Первая редакция дубля держала
/// кадр 80 секунд под 199 секунд голоса: видео кончилось бы на середине
/// фразы, и заметили бы это на монтаже, а не здесь.
///
/// Сторож `video_take_covers_narration_test` сличает отметки снятого дубля
/// с длиной начитки и краснеет, если картинки меньше, чем слов.
const _blockSeconds = <String, int>{
  'intro': 28,
  'launch': 32,
  'wizard': 25,
  'country': 31,
  'language': 28,
  'alpha': 30,
  'next': 26,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app_log.installLogger(Talker());
    GetIt.I.allowReassignment = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    await configureDependencies(logger: app_log.talker);
  });

  tearDownAll(() async => db.close());

  testWidgets('урок 2: первый запуск, один дубль', (tester) async {
    final filmingStartedAt = DateTime.now();
    final cursor = CursorDriver.attach('TelePOS');

    void mark(String block) {
      final at = DateTime.now().difference(filmingStartedAt).inMilliseconds;
      // ignore: avoid_print
      print('[VIDEO-MARK] $block ${(at / 1000).toStringAsFixed(3)}');
    }

    Future<void> hold(Duration duration) async {
      final end = DateTime.now().add(duration);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();

    // ── @intro ────────────────────────────────────────────────────────
    // Касса ещё не поднята: в кадре пустое окно ровно столько, сколько
    // нужно голосу, чтобы сказать «оно установлено».
    mark('intro');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          title: 'TelePOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
          supportedLocales: AppLocale.supportedLocales,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 16));
    await hold(Duration(seconds: _blockSeconds['intro']!));

    // ── @launch ───────────────────────────────────────────────────────
    // Ни одного `router.go`: куда касса придёт, туда и придёт. Это и есть
    // предмет урока.
    mark('launch');
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await hold(Duration(seconds: _blockSeconds['launch']!));

    // ── @wizard ───────────────────────────────────────────────────────
    mark('wizard');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      contains(AppRoutes.initialSetup),
      reason:
          'урок обещает, что касса сама приводит к настройке. Если она не '
          'там, снимать нечего — и это дефект, а не неудачный дубль',
    );
    expect(
      find.textContaining('Step 1 of 11'),
      findsWidgets,
      reason: 'счёт шагов назван в начитке числом — он обязан совпадать',
    );
    await hold(Duration(seconds: _blockSeconds['wizard']!));

    // ── @country ──────────────────────────────────────────────────────
    // Курсор ведётся по четырём странам из разных денежных укладов.
    // Ничего не нажимается: выбор страны — предмет урока 3, здесь только
    // показывается, что он первый и что от него зависит остальное.
    mark('country');
    const shown = ['Kazakhstan', 'United States', 'Germany', 'Japan'];
    final perCountry = _blockSeconds['country']! ~/ shown.length;
    for (final country in shown) {
      final target = find.text(country);
      if (target.evaluate().isEmpty) continue;
      await tester.ensureVisible(target.first);
      await tester.pumpAndSettle();
      if (cursor != null) {
        await cursor.moveTo(tester, tester.getCenter(target.first));
      }
      await hold(Duration(seconds: perCountry));
    }

    // ── @language ─────────────────────────────────────────────────────
    // Переключатель языка — на этом же экране, и голос говорит, что он
    // отдельно от страны.
    mark('language');
    final language = find.text('EN');
    expect(
      language,
      findsWidgets,
      reason:
          'начитка утверждает, что язык интерфейса выбирается на этом же '
          'экране. Нет переключателя — утверждение ложно',
    );
    if (cursor != null) {
      await cursor.moveTo(tester, tester.getCenter(language.first));
    }
    await hold(Duration(seconds: _blockSeconds['language']!));

    // ── @alpha ────────────────────────────────────────────────────────
    // Честность про альфу — голосом поверх неподвижного экрана: правила
    // требуют сказать это в первые пятнадцать секунд И отдельным местом.
    mark('alpha');
    await hold(Duration(seconds: _blockSeconds['alpha']!));

    // ── @next ─────────────────────────────────────────────────────────
    mark('next');
    await hold(Duration(seconds: _blockSeconds['next']!));
  });
}
