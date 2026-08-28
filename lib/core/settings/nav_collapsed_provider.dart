import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/core/locale/locale_provider.dart';

/// Свёрнута ли левая колонка назначений.
///
/// Заведено 2026-08-27 по требованию заказчика: развёрнутая колонка занимает
/// [AppTokens.navColumnWidth] = 260 точек постоянно, и на кассовом экране
/// 1024×768 это четверть ширины под список, в который смотрят раз в смену.
/// Свёрнутая оставляет иконки — попасть в пункт по-прежнему можно, а место
/// возвращается содержимому.
///
/// Хранится, а не живёт в памяти: выбор, слетающий при перезапуске, кассир
/// сочтёт несработавшим нажатием и будет жать снова — тот же довод, каким
/// заведено хранение темы и языка.
///
/// Устроено по образцу [themeModeProvider] и [localeProvider]: тот же ключ в
/// [SharedPreferences], та же нечувствительность к мусору в хранилище. Отказ
/// приходит значением (И144): касса, не открывшая смену из-за строки в
/// настройках, — цена, несоизмеримая с поводом.
///
/// Умолчание — **свёрнута** (решение заказчика, 2026-08-27). Довод против —
/// «человек не увидит, куда попадёт» — снят подсказкой: свёрнутая строка
/// показывает подпись при наведении (`Tooltip` в `TgNavRow`), а развернуть
/// колонку можно одним нажатием, и выбор запомнится.
const _key = 'nav_collapsed';

final navCollapsedProvider = NotifierProvider<NavCollapsedNotifier, bool>(
  NavCollapsedNotifier.new,
);

class NavCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // `getBool` сам вернёт `null`, если под ключом лежит строка или число от
    // прежней версии, — читать через `get` и разбирать тип незачем.
    return prefs.getBool(_key) ?? true;
  }

  Future<void> toggle() => setCollapsed(!state);

  Future<void> setCollapsed(bool collapsed) async {
    if (state == collapsed) return;
    await ref.read(sharedPreferencesProvider).setBool(_key, collapsed);
    state = collapsed;
  }
}
