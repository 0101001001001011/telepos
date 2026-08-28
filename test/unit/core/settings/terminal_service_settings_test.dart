import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/core/settings/terminal_service_settings.dart';

/// Решение «обслуживает ли эта касса браузерные терминалы» — единственное, что
/// отделяет кассу, слушающую петлю, от кассы, открывшей порт в сеть магазина.
/// Проверяется здесь, а не в `main.dart`: там окно, граф DI и настоящие сокеты,
/// и под тестом он не запускается.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Пустая настройка — состояние свежей установки, а не выдуманное удобство:
    // именно его видит первая же касса заказчика.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('новая установка порт не открывает', () async {
    final prefs = await SharedPreferences.getInstance();
    final choice = TerminalServiceChoice.read(prefs);

    expect(choice.enabled, isFalse);
    expect(
      choice.scope,
      ListenScope.loopback,
      reason:
          'раздел 16 архитектуры: новая установка не открывает наружу ничего, '
          'каждая открытая возможность — сознательное включение владельцем',
    );
  });

  test('включение оператором открывает оба семейства адресов', () async {
    final prefs = await SharedPreferences.getInstance();
    await TerminalServiceChoice.write(prefs, enabled: true);

    final choice = TerminalServiceChoice.read(prefs);
    expect(choice.enabled, isTrue);
    expect(choice.scope, ListenScope.everywhere);
  });

  test('выключение обратно возвращает кассу на петлю', () async {
    final prefs = await SharedPreferences.getInstance();
    await TerminalServiceChoice.write(prefs, enabled: true);
    await TerminalServiceChoice.write(prefs, enabled: false);

    expect(TerminalServiceChoice.read(prefs).scope, ListenScope.loopback);
  });

  test('прочитанное — то же, что записал экран, а не второй разбор', () async {
    // Ключ проверяется поимённо: читатель (`lib/main.dart`) и писатель (экран
    // настройки) обязаны говорить об одной величине. Разъехавшись, они
    // разошлись бы молча — переключатель стоял бы «включено», а касса
    // поднималась бы на петле.
    final prefs = await SharedPreferences.getInstance();
    await TerminalServiceChoice.write(prefs, enabled: true);

    expect(prefs.getBool(kTerminalServicePrefsKey), isTrue);
  });

  test('касса без окна обслуживает терминалы, не спрашивая настройку', () async {
    // У процесса без окна интерфейс не здесь: рисовать нечего и некому.
    // Оставить его на петле значило бы поставить кассу, до которой не дойдёт
    // ни один терминал, — и включить её было бы негде, экрана настройки у неё
    // не существует.
    final prefs = await SharedPreferences.getInstance();

    expect(
      TerminalServiceChoice.resolve(prefs, headless: true).scope,
      ListenScope.everywhere,
    );
    expect(prefs.getBool(kTerminalServicePrefsKey), isNull);
  });

  test('касса с окном обслуживает терминалы только по настройке', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(
      TerminalServiceChoice.resolve(prefs, headless: false).scope,
      ListenScope.loopback,
    );

    await TerminalServiceChoice.write(prefs, enabled: true);
    expect(
      TerminalServiceChoice.resolve(prefs, headless: false).scope,
      ListenScope.everywhere,
    );
  });

  test('чужой тип под ключом не открывает порт', () async {
    // Под ключом строка — например, от другой версии программы. Испорченная
    // настройка не имеет права расширить слушателя: молчаливое расширение
    // здесь хуже, чем неудобство (см. `ListenScope`).
    SharedPreferences.setMockInitialValues(<String, Object>{
      kTerminalServicePrefsKey: 'yes',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(TerminalServiceChoice.read(prefs).scope, ListenScope.loopback);
  });
}
