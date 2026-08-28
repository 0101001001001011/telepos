import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/core/settings/terminal_service_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/terminal_service_settings_screen.dart';

/// Половина решения, которую нельзя доказать ни одним сокетом: **где оператор
/// его принимает**.
///
/// Настройка, которую негде включить, — это флаг сборки под другим именем, а
/// именно флагом сборки браузерный терминал и не работал ни у кого. Поэтому
/// проверяется не отрисовка, а то, что щелчок по переключателю доходит до той
/// самой величины, которую при следующем запуске читает `lib/main.dart`.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Widget host(Widget child) => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru')],
      home: child,
    ),
  );

  testWidgets('щелчок оператора открывает порт при следующем запуске', (
    tester,
  ) async {
    await tester.pumpWidget(host(const TerminalServiceSettingsScreen()));
    await tester.pumpAndSettle();

    // Из коробки закрыто, и экран это показывает, а не молчит.
    expect(TerminalServiceChoice.read(prefs).scope, ListenScope.loopback);
    expect(
      find.byKey(const ValueKey('terminal-service-restart-note')),
      findsNothing,
      reason: 'напоминание о перезапуске тому, кто ничего не менял, — шум',
    );

    await tester.tap(find.byKey(const ValueKey('terminal-service-enable')));
    await tester.pumpAndSettle();

    // Та же величина, которую при следующем запуске читает `lib/main.dart`.
    expect(
      TerminalServiceChoice.read(prefs).scope,
      ListenScope.everywhere,
      reason: 'щелчок никуда не доехал — оператору негде включить обслуживание',
    );

    // Адрес появляется только у включённой кассы: показывать его выключенной
    // значило бы диктовать оператору адрес, по которому никто не ответит.
    expect(
      find.byKey(const ValueKey('terminal-service-address')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('terminal-service-restart-note')),
      findsOneWidget,
      reason:
          'без него человек щёлкает, идёт к планшету и видит отказ соединения '
          'по причине, о которой ему не сказали',
    );
  });

  testWidgets('обратный щелчок закрывает порт', (tester) async {
    await TerminalServiceChoice.write(prefs, enabled: true);

    await tester.pumpWidget(host(const TerminalServiceSettingsScreen()));
    await tester.pumpAndSettle();

    // Экран открылся на сохранённом значении, а не на умолчании: иначе он
    // показывал бы «выключено» кассе, которая слушает всю сеть.
    expect(
      find.byKey(const ValueKey('terminal-service-address')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('terminal-service-enable')));
    await tester.pumpAndSettle();

    expect(TerminalServiceChoice.read(prefs).scope, ListenScope.loopback);
  });
}
