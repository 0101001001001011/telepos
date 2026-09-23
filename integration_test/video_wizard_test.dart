/// Съёмочная дорожка урока 3 «Мастер настройки» — один непрерывный дубль.
///
/// # Правила, которые здесь выполняются
///
/// `docs/video-production.md`, разделы 6 и 7: один непрерывный дубль без
/// звука, курсор ведётся к цели с паузой полсекунды до и после нажатия,
/// ровное 16:9 (размер задаёт `record_window.ps1`), часы заморожены, в кадре
/// нет личных данных, ничего не выжигается.
///
/// Имена отметок `[VIDEO-MARK]` совпадают с именами `@`-блоков в
/// `docs/internal/video/03-narration.txt` — это вся связь между текстом и
/// картинкой, отдельной таблицы соответствий нет намеренно.
///
/// # База ПУСТАЯ
///
/// Мастер снимается с чистого листа, иначе он покажет не первый запуск, а
/// повторный — а это другой экран и другой разговор.
///
/// # Чему научил пробный проход
///
/// `integration_test/wizard_dry_run_test.dart` прошёл мастер до записи и
/// нашёл пять изъянов, от русского списка стран до вопроса «плательщик ли
/// вы НДС» американскому магазину. Все починены до съёмки; дорожка
/// написана по тому, что проход напечатал, а не по догадкам.
///
/// # Запуск
///
///     flutter test integration_test/video_wizard_test.dart -d windows
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
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
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

import 'support/cursor.dart';

/// Часы, замороженные на демо-значении: правила запрещают часы в кадре, а
/// настоящее время вдобавок делает дубли несравнимыми между собой.
const _frozenClock = '12:30';

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
    // Регистрирует `main.dart`, а не `configureDependencies`, а `main()`
    // здесь не выполняется.
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    await configureDependencies(logger: app_log.talker);
  });

  tearDownAll(() async => db.close());

  testWidgets('урок 3: мастер настройки, один дубль', (tester) async {
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

    Future<void> tapOne(Finder finder, String what, {bool last = false}) async {
      expect(
        finder,
        findsWidgets,
        reason: 'шаг «$what»: в кадре нет того, на что надо нажать',
      );
      final target = last ? finder.last : finder.first;

      // Прокрутка доводится до конца, а не продвигается на кадр: после
      // одного `pump()` цель ещё едет, и курсор приезжает туда, где она
      // БУДЕТ. На записи урока 8 это выглядело как нажатие невидимой
      // кнопки — заметил заказчик.
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await hold(const Duration(milliseconds: 700));

      if (cursor != null) {
        await cursor.moveTo(tester, tester.getCenter(target));
        await hold(const Duration(milliseconds: 500));
      }

      final hit = tester.hitTestOnBinding(tester.getCenter(target));
      expect(
        hit.path.length,
        greaterThan(2),
        reason:
            'шаг «$what»: в точке нажатия нет виджета — цель за краем экрана '
            'или закрыта чем-то сверху',
      );

      await tester.tap(target);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      if (cursor != null) await hold(const Duration(milliseconds: 500));
    }

    /// Заполняет поле по его подсказке.
    ///
    /// По `decoration`, а не по соседнему тексту: подпись в
    /// `SettingsFieldTile` лежит СНАРУЖИ поля, и `find.ancestor` её не
    /// связывает. Пробный проход встал на этом, двенадцать раз нажав
    /// «Next» впустую.
    Future<void> fillByHint(String hint, String value) async {
      for (final element in find.byType(TextField).evaluate()) {
        final field = element.widget as TextField;
        if (field.decoration?.hintText != hint) continue;
        final finder = find.byWidget(field);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        if (cursor != null) {
          await cursor.moveTo(tester, tester.getCenter(finder));
          await hold(const Duration(milliseconds: 400));
        }
        await tester.enterText(finder, value);
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
        return;
      }
      fail('поля с подсказкой «$hint» в кадре нет');
    }

    Future<void> next(String what) => tapOne(find.text('Next'), what);

    // ── подготовка ──────────────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentTimeProvider.overrideWithValue(_frozenClock),
        ],
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
    await tester.pumpAndSettle(const Duration(seconds: 5));

    router.go(AppRoutes.initialSetup);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── intro ───────────────────────────────────────────────────────────────
    mark('intro');
    expect(
      find.text('Step 1 of 11'),
      findsOneWidget,
      reason: 'в кадре не первый шаг мастера — дубль начался не с того экрана',
    );
    // Двадцать восемь: на пробном проходе вступление не укладывалось в
    // двадцать пять на секунду, а голос лёг бы поверх следующей сцены.
    await hold(const Duration(seconds: 28));

    // ── country ─────────────────────────────────────────────────────────────
    mark('country');
    await hold(const Duration(seconds: 12));
    await tapOne(find.text('United States'), 'выбор страны');
    await hold(const Duration(seconds: 7));
    await next('переход к организации');

    // ── company ─────────────────────────────────────────────────────────────
    mark('company');
    await hold(const Duration(seconds: 4));
    await fillByHint(r'LLC "My Company"', 'Northwind Trading');
    await hold(const Duration(seconds: 3));
    await fillByHint('12-3456789', '841234567');
    await hold(const Duration(seconds: 3));
    await fillByHint(
      '1600 Blake Street, Denver, CO 80202',
      '1600 Blake Street, Denver, CO 80202',
    );
    await hold(const Duration(seconds: 7));
    await next('переход к налогу');

    // ── tax ─────────────────────────────────────────────────────────────────
    mark('tax');
    expect(
      find.text('Sales tax'),
      findsWidgets,
      reason:
          'на кассе США шаг обязан говорить про налог с продаж, а не про '
          'НДС — этого понятия в стране нет',
    );
    await hold(const Duration(seconds: 30));
    await tapOne(find.text('I collect sales tax'), 'выбор сбора налога');
    await hold(const Duration(seconds: 4));
    await next('переход к людям');

    // ── users ───────────────────────────────────────────────────────────────
    mark('users');
    await hold(const Duration(seconds: 6));
    final userFields = find.byType(TextField);
    await tester.enterText(userFields.at(0), 'Anna Whitfield');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await hold(const Duration(seconds: 4));
    await tester.enterText(userFields.at(1), '1234');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.enterText(userFields.at(2), '1234');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await hold(const Duration(seconds: 12));
    await next('переход к роду дела');

    // ── mode ────────────────────────────────────────────────────────────────
    mark('mode');
    await hold(const Duration(seconds: 18));
    await next('переход к кассе');

    // ── till ────────────────────────────────────────────────────────────────
    mark('till');
    await hold(const Duration(seconds: 4));
    await fillByHint('POS 1', 'Till-1');
    await hold(const Duration(seconds: 3));
    await fillByHint('POS-1', 'TILL-1');
    await hold(const Duration(seconds: 15));
    await next('переход к фискализации');

    // ── skip ────────────────────────────────────────────────────────────────
    mark('skip');
    expect(
      find.text('Fiscalization is not required for your country'),
      findsOneWidget,
      reason:
          'экран обязан СКАЗАТЬ, что фискализации в стране нет, а не '
          'спрашивать про неё',
    );
    await hold(const Duration(seconds: 8));
    await next('переход к оборудованию');
    await hold(const Duration(seconds: 6));
    await next('переход к терминалам');
    await hold(const Duration(seconds: 6));
    await next('переход к правилам');

    // ── rules ───────────────────────────────────────────────────────────────
    mark('rules');
    await hold(const Duration(seconds: 17));
    await next('переход к сводке');

    // ── review ──────────────────────────────────────────────────────────────
    mark('review');
    expect(
      find.text('84-1234567'),
      findsOneWidget,
      reason:
          'номер налогоплательщика обязан стоять с разделителями страны: '
          'девять голых цифр на американской сводке читаются как чужой номер',
    );
    await hold(const Duration(seconds: 26));

    // ── done ────────────────────────────────────────────────────────────────
    mark('done');
    await tapOne(find.text('Done'), 'завершение мастера', last: true);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await hold(const Duration(seconds: 14));

    // ── help ────────────────────────────────────────────────────────────────
    mark('help');
    await hold(const Duration(seconds: 30));
  });
}
