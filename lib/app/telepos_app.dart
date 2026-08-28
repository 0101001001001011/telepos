import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/theme/theme_mode_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// The application root, shared by every binding.
///
/// Deliberately free of platform and infrastructure: no `dart:io`, no hardware,
/// no database. A native entry point and a browser entry point run this same
/// widget with the same screens — the only difference between them is which
/// implementations they bound to the domain contracts before starting it.
///
/// Anything platform-specific that needs to hang off the app lifecycle belongs
/// in the entry point that owns it, not here. See docs/ARCHITECTURE.md.
class TelePosApp extends ConsumerWidget {
  const TelePosApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TelePOS',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      // Тёмная тема была написана целиком — со своими семантическими цветами —
      // и не подключена ничем: здесь стояла одна строка `theme: AppTheme.light`.
      // Замечено 2026-08-04; до того она существовала только в исходнике.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      supportedLocales: AppLocale.supportedLocales,
      locale: currentLocale.toLocale(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Drag with anything, including a stylus.
///
/// Flutter's default excludes stylus and touch from scroll drags on desktop,
/// which is wrong for a till: the screens this runs on are touched, not
/// clicked.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}
