import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import 'till_language.dart';
import 'locale_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

final localeServiceProvider = Provider<LocaleService>((ref) {
  return LocaleService(ref.watch(sharedPreferencesProvider));
});

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<AppLocale> {
  static VoidCallback? onLocaleChanged;

  @override
  AppLocale build() {
    final service = ref.watch(localeServiceProvider);
    final systemLocale = PlatformDispatcher.instance.locale;
    final locale = service.getEffectiveLocale(systemLocale);
    // Бумага следует за экраном. До 2026-09-21 чек печатался по-русски
    // независимо от языка кассы, потому что слой печати о языке не знал
    // вовсе — здесь единственное место, где выбор языка уже известен.
    TillLanguage.current = locale;
    return locale;
  }

  LocaleService get _service => ref.read(localeServiceProvider);

  Future<void> setLocale(AppLocale locale) async {
    if (state == locale) return;

    TillLanguage.current = locale;
    await _service.saveLocale(locale);

    state = locale;

    onLocaleChanged?.call();
  }

  Future<void> resetToSystem() async {
    await _service.clearLocale();
    final systemLocale = PlatformDispatcher.instance.locale;
    state = AppLocale.fromSystemLocale(systemLocale);
    onLocaleChanged?.call();
  }

  Locale get flutterLocale => state.toLocale();
}

class AppRestarter extends StatefulWidget {
  const AppRestarter({required this.child, super.key});

  final Widget child;

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestarterState>()?.restart();
  }

  @override
  State<AppRestarter> createState() => _AppRestarterState();
}

class _AppRestarterState extends State<AppRestarter> {
  Key _key = UniqueKey();

  @override
  void initState() {
    super.initState();
    LocaleNotifier.onLocaleChanged = restart;
  }

  @override
  void dispose() {
    LocaleNotifier.onLocaleChanged = null;
    super.dispose();
  }

  void restart() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
