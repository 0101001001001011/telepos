import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_data.dart';
import 'package:telepos/presentation/screens/customer_display/customer_display_screen.dart';

/// Язык окна покупателя.
///
/// # Почему не `localeProvider`
///
/// Окно живёт в ОТДЕЛЬНОМ движке (`desktop_multi_window`), и `ProviderContainer`
/// здесь свой, без подмен. `localeProvider` тянет `sharedPreferencesProvider`,
/// а тот объявлен бросающим, пока его не подменят в `ProviderScope`. То есть
/// обращение к нему уронило бы окно покупателя на первом же кадре — и проба,
/// рисующая экран напрямую, этого бы не увидела: она рисует ЭКРАН, а не ОКНО.
///
/// Язык приезжает от кассы доводом окна, как и имя магазина.
Locale _localeFrom(String code) {
  if (code.isEmpty) {
    return AppLocale.fromSystemLocale(
      PlatformDispatcher.instance.locale,
    ).toLocale();
  }
  final known = AppLocale.supportedLocales.where((l) => l.languageCode == code);
  return known.isEmpty
      ? AppLocale.fromSystemLocale(
          PlatformDispatcher.instance.locale,
        ).toLocale()
      : known.first;
}

Future<void> runCustomerDisplayWindow(WindowController controller) async {
  Map<String, dynamic> args = const {};
  try {
    args = jsonDecode(controller.arguments) as Map<String, dynamic>;
  } catch (_) {}

  final storeName = args['storeName'] as String? ?? 'TelePOS';

  // Язык и валюта приходят от кассы — и нужны ДО первой корзины: пустое окно
  // здоровается с покупателем, и делать это на чужом языке незачем.
  final container = ProviderContainer();
  container
      .read(customerDisplayDataProvider.notifier)
      .set(
        CustomerDisplayData(
          currencySymbol: args['currencySymbol'] as String? ?? '',
          languageCode: args['languageCode'] as String? ?? '',
        ),
      );

  try {
    await windowManager.ensureInitialized();
    final x = (args['x'] as num?)?.toDouble();
    final y = (args['y'] as num?)?.toDouble();
    final w = (args['w'] as num?)?.toDouble();
    final h = (args['h'] as num?)?.toDouble();
    await windowManager.setTitle(
      lookupAppLocalizations(
        _localeFrom(args['languageCode'] as String? ?? ''),
      ).displayWindowTitle,
    );
    if (x != null && y != null && w != null && h != null) {
      await windowManager.setBounds(Rect.fromLTWH(x, y, w, h));
    }
    await windowManager.show();
    await windowManager.focus();
  } catch (_) {}

  controller.setWindowMethodHandler((call) async {
    if (call.method == 'cart') {
      try {
        final json =
            jsonDecode(call.arguments as String) as Map<String, dynamic>;
        container
            .read(customerDisplayDataProvider.notifier)
            .set(CustomerDisplayData.fromJson(json));
      } catch (_) {}
    }
    return null;
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _CustomerDisplayApp(storeName: storeName),
    ),
  );
}

class _CustomerDisplayApp extends StatelessWidget {
  const _CustomerDisplayApp({required this.storeName});
  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // Окно покупателя — отдельное, и словари ему нужны СВОИ.
        //
        // До 2026-09-22 этот `MaterialApp` не нёс ни делегатов, ни языка, и
        // `AppLocalizations.of(context)` здесь был `null`. То есть экран,
        // который видит ПОКУПАТЕЛЬ, локализовать было нельзя вовсе — это
        // вскрылось, когда на нём завели первое же слово из словаря.
        //
        // Язык берётся тот же, что у кассы: покупатель стоит по ту сторону
        // одного прилавка, и говорить с ним на другом языке незачем. Едет он
        // вместе с корзиной, поэтому смена языка на кассе доходит сюда сама.
        final data = ref.watch(customerDisplayDataProvider);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: _localeFrom(data.languageCode),
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: CustomerDisplayView(data: data, storeName: storeName),
        );
      },
    );
  }
}
