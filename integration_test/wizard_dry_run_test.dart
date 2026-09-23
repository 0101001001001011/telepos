/// Пробный проход мастера настройки — БЕЗ записи.
///
/// # Зачем отдельный прогон
///
/// Правила студии (раздел 10) требуют пробный проход до съёмки. Здесь он и
/// нужен больше всего: память проекта прямо говорит, что первый запуск и
/// настройка в один клик всегда работали плохо, а мастер — двенадцать
/// шагов, и каждый может встретить пустым экраном.
///
/// Прогон ничего не утверждает про красоту. Он проходит мастер до конца и
/// **печатает, что видит на каждом шаге**: заголовок, поля, кнопки. По
/// этому списку и пишется съёмочная дорожка — вслепую её писать значит
/// снимать вслепую.
///
/// # Запуск
///
///     flutter test integration_test/wizard_dry_run_test.dart -d windows
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app_log.installLogger(Talker());
    GetIt.I.allowReassignment = true;
    // База ПУСТАЯ: мастер снимается с чистого листа, иначе он покажет не
    // первый запуск, а повторный — а это другой экран и другой разговор.
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    await configureDependencies(logger: app_log.talker);
  });

  tearDownAll(() async => db.close());

  testWidgets('мастер проходится до конца, и видно чем', (tester) async {
    // Время от начала прогона: по нему из записи достаётся кадр на каждый
    // шаг. Без отметок пришлось бы искать шаги в записи глазами.
    final startedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final router = createRouter();
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
    await tester.pumpAndSettle(const Duration(seconds: 5));

    router.go(AppRoutes.initialSetup);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    /// Что сейчас на экране — словами, которые видит человек.
    void describe(String where) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && d!.trim().isNotEmpty)
          .map((d) => d!.trim())
          .toSet()
          .toList();
      final fields = find.byType(TextField).evaluate().length;
      final at = DateTime.now().difference(startedAt).inMilliseconds / 1000;
      // ignore: avoid_print
      print(
        '[WIZARD] ${at.toStringAsFixed(1)} | $where | полей: $fields | '
        '${texts.join(" · ")}',
      );
    }

    describe('после входа в мастер');

    /// Заполняет поле по его подсказке или подписи.
    ///
    /// По `decoration`, а не по соседнему тексту: в `SettingsFieldTile`
    /// подпись лежит СНАРУЖИ поля, и `find.ancestor` её не связывает — на
    /// этом пробный проход и встал, двенадцать раз нажав «Next» впустую.
    Future<void> fill(String label, String value) async {
      for (final element in find.byType(TextField).evaluate()) {
        final field = element.widget as TextField;
        final d = field.decoration;
        if (d == null) continue;
        if (d.labelText != label && d.hintText != label) continue;
        await tester.enterText(find.byWidget(field), value);
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        return;
      }
    }

    /// Что за поля вообще есть на этом шаге — чтобы не гадать.
    void describeFields() {
      final labels = find.byType(TextField).evaluate().map((e) {
        final d = (e.widget as TextField).decoration;
        return '${d?.labelText ?? '—'}/${d?.hintText ?? '—'}';
      }).toList();
      if (labels.isEmpty) return;
      // ignore: avoid_print
      print('[FIELDS] ${labels.join(" | ")}');
    }

    /// Выбирает страну США — касса в примере американская.
    Future<void> pickUs() async {
      final us = find.text('United States');
      if (us.evaluate().isEmpty) return;
      await tester.tap(us.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    // Двенадцать шагов — потолок обхода; на каждом ищем кнопку «дальше» под
    // любым из её имён и жмём. Остановились — печатаем, на чём.
    for (var i = 0; i < 14; i++) {
      final next = [
        find.text('Next'),
        find.text('Continue'),
        find.text('Start'),
        find.text('Finish'),
        find.text('Done'),
      ].firstWhere(
        (f) => f.evaluate().isNotEmpty,
        orElse: () => find.byType(_Nothing),
      );

      if (next.evaluate().isEmpty) {
        describe('шаг $i: кнопки «дальше» НЕТ');
        break;
      }

      describe('шаг $i');
      describeFields();

      // Заполняем то, что на этом шаге спрашивают. Имена полей берутся с
      // экрана, а не из кода: прогон и заведён затем, чтобы увидеть, что
      // там на самом деле.
      await pickUs();

      // Шаг «Пользователи»: у его полей нет ни подписи, ни подсказки
      // внутри — подписи нарисованы рядом. Заполняем по порядку: имя, PIN,
      // подтверждение.
      if (find.text('Who will be working').evaluate().isNotEmpty) {
        final fields = find.byType(TextField);
        if (fields.evaluate().length >= 3) {
          await tester.enterText(fields.at(0), 'Anna Whitfield');
          await tester.pumpAndSettle(const Duration(milliseconds: 200));
          await tester.enterText(fields.at(1), '1234');
          await tester.pumpAndSettle(const Duration(milliseconds: 200));
          await tester.enterText(fields.at(2), '1234');
          await tester.pumpAndSettle(const Duration(milliseconds: 300));
        }
      }

      // По ПОДСКАЗКЕ: подписи в `SettingsFieldTile` лежат снаружи поля, и
      // в `decoration` их нет вовсе.
      await fill(r'LLC "My Company"', 'Northwind Trading');
      await fill('12-3456789', '841234567');
      await fill(
        '1600 Blake Street, Denver, CO 80202',
        '1600 Blake Street, Denver, CO 80202',
      );
      await fill('POS 1', 'Till-1');
      await fill('POS-1', 'TILL-1');

      await tester.ensureVisible(next.first);
      await tester.pumpAndSettle();
      await tester.tap(next.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    describe('конец обхода');
  });
}

/// Пустой тип для `orElse`: нужен финдер, который заведомо ничего не найдёт.
class _Nothing extends Widget {
  const _Nothing();
  @override
  Element createElement() => throw UnimplementedError();
}
