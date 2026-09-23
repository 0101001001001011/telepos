/// Пробный проход главы 5 «Эмуляторы» — БЕЗ записи.
///
/// # Зачем
///
/// Правила студии требуют пробный проход до съёмки, и на мастере он окупился
/// пятью находками. Здесь показывают главное обещание продукта — «продай и
/// напечатай, ничего не купив», — и если оно где-то не держится, узнать об
/// этом надо до камеры, а не при ней.
///
/// Проход ничего не утверждает про красоту. Он идёт по экрану эмуляторов и
/// **печатает, что видит**: какие приборы предлагаются, что написано под
/// каждым, какие кнопки есть. По этому списку и пишется дорожка.
///
/// # Запуск
///
///     flutter test integration_test/emulators_dry_run_test.dart -d windows
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

import 'package:telepos/app/di/hardware_module.dart'
    show registerHardwareServices;
import 'package:telepos/app/di/service_locator.dart' show configureDependencies;
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
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
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<Talker>(app_log.talker);
    GetIt.I.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
    await configureDependencies(logger: app_log.talker);

    // Настроенная касса: глава 5 идёт ПОСЛЕ мастера, и показывать мастер
    // заново незачем.
    final posAccId = await db.accountDao.createPosAccount(name: 'Cash');
    final bankAccId = await db.accountDao.createAcquiringAccount(
      name: 'Card',
      acquirerId: 1,
    );
    await db.thisPosDao.insertInitialConfig(
      companyName: 'Northwind Trading',
      iinbin: '841234567',
      cashBoxName: 'Till-1',
      countryCode: 4,
      currencyCode: 4,
      currencySymbol: r'$',
      currencyNameShort: 'USD',
      paperWidth: 48,
      printerHeader: null,
      printerFooter: null,
      accountId: posAccId,
      acquiringAccountId: bankAccId,
      rsaPublicKey: null,
      sendToOfd: false,
      cashInOut: true,
    );
    final cashierId = await db.userDao.createCashier(
      name: 'Anna Whitfield',
      passwordEnc: null,
    );
    await db.userPermissionDao.setPermissions(cashierId, {
      for (final key in PermissionKeys.allPermissions) key: true,
    });
    await registerHardwareServices(GetIt.I, logger: app_log.talker);
  });

  tearDownAll(() async => db.close());

  testWidgets('экран эмуляторов: что на нём есть', (tester) async {
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

    void describe(String where) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && d!.trim().isNotEmpty)
          .map((d) => d!.trim())
          .toSet()
          .toList();
      final switches = find.byType(Switch).evaluate().length;
      // ignore: avoid_print
      print('[EMU] $where | выключателей: $switches | ${texts.join(" · ")}');
    }

    router.go(AppRoutes.emulatorSettings);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    describe('экран эмуляторов, до включения');

    // Включаем всё по очереди и смотрим, что меняется: это и есть содержание
    // урока — приборы, которых нет, начинают отвечать.
    // Обход по ИМЕНИ прибора, а не по номеру выключателя.
    //
    // По номеру не выходит: включённый прибор раскрывает свои строки, и
    // список выключателей меняется прямо во время обхода — их стало пять,
    // потом четыре, потом три, и `at(i)` уехал за край. Это моя ошибка
    // оснастки, а не продукта.
    for (final name in const [
      'Receipt printer and cash drawer',
      'Scales',
      'Display',
      'Fiscal operator (OFD)',
      'QR payment provider',
    ]) {
      final row = find.ancestor(
        of: find.text(name),
        matching: find.byType(SwitchListTile),
      );
      if (row.evaluate().isEmpty) {
        // ignore: avoid_print
        print('[EMU] прибора «$name» на экране НЕТ');
        continue;
      }
      await tester.ensureVisible(row.first);
      await tester.pumpAndSettle();
      await tester.tap(row.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      describe('после включения «$name»');
    }
  });
}
