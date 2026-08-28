import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/theme/theme_mode_provider.dart';

/// Выбор темы: светлая, тёмная или как в системе.
///
/// Заведено 2026-08-04, когда выяснилось, что `AppTheme.dark` написана целиком
/// — со своими семантическими цветами — и **не подключена ничем**:
/// `telepos_app.dart` жёстко ставил `theme: AppTheme.light`, а `darkTheme` и
/// `themeMode` отсутствовали. Тёмная тема была мёртвым кодом, выглядящим живым,
/// и это третий такой случай за день.
void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> container() async {
    prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  test('по умолчанию — светлая, а не как в системе', () async {
    // Изменено 2026-08-27. Прежде здесь стояла системная, и это было шире
    // того, ради чего провайдер заводили: согласованная спека называется
    // «Светлая тема в стиле Telegram», по ней рисовали экраны и мерили
    // контрасты. Тёмную по спеке не рисовал никто, а на машине с тёмной ОС
    // продукт открывался именно ею — измерено на собранной кассе: имя
    // выбранного кассира давало 1.12:1, названия плиток настроек 1.35:1.
    SharedPreferences.setMockInitialValues({});
    final c = await container();
    addTearDown(c.dispose);

    expect(c.read(themeModeProvider), ThemeMode.light);
  });

  test('выбор переживает перезапуск', () async {
    // Тема, слетающая при перезапуске, хуже отсутствия выбора: кассир решит,
    // что нажатие не сработало, и будет жать снова.
    SharedPreferences.setMockInitialValues({});
    final first = await container();
    await first.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    first.dispose();

    final second = await container();
    addTearDown(second.dispose);

    expect(second.read(themeModeProvider), ThemeMode.dark);
  });

  test('испорченное значение не роняет запуск', () async {
    // В хранилище может лежать что угодно — от прошлой версии, от чужой руки.
    // Отказ приходит значением: неизвестное имя означает умолчание продукта,
    // то есть светлую. Мусор не имеет права дать вид, которого не рисовали.
    SharedPreferences.setMockInitialValues({'theme_mode': 'фиолетовая'});
    final c = await container();
    addTearDown(c.dispose);

    expect(c.read(themeModeProvider), ThemeMode.light);
  });

  test('системная записывается именем, а не отсутствием записи', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await container();
    addTearDown(c.dispose);

    await c.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    expect(c.read(themeModeProvider), ThemeMode.light);

    await c.read(themeModeProvider.notifier).setMode(ThemeMode.system);
    expect(c.read(themeModeProvider), ThemeMode.system);
    expect(
      prefs.getString('theme_mode'),
      'system',
      reason:
          'отсутствие записи теперь означает светлую (умолчание продукта), '
          'поэтому «выбрал системную» обязано быть записано именем — иначе '
          'этот выбор неотличим от «не выбирал» и молча станет светлой',
    );
  });
}
