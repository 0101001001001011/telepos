/// В контейнере зависимостей нет договоров, которых никто не спрашивает.
///
/// # Что измерено 2026-09-22
///
/// `service_locator.dart` регистрировал 199 договоров. **Тридцать три** из них
/// не спрашивал никто: ни экран, ни другой договор, ни проба — 4376 строк в
/// 65 файлах, где были и объявление, и полная реализация.
///
/// Это не «лишний код»: он выглядит живым. Так `SaleValidationService`
/// создавал впечатление, что цена товара проверяется. Проверка там была —
/// `validateSale(hasZeroPriceProduct:)`, — и не выполнялась ни разу, а
/// корзина тем временем клала товар без цены в чек по нулю и продавала его
/// даром.
///
/// # Как сторож считает
///
/// Он не ищет `GetIt.I<T>()`: договор можно спросить и через довод
/// конструктора. Он ищет ЛЮБОЕ упоминание имени договора в дереве, кроме
/// файла, который его объявляет, файла реализации и самого контейнера.
///
/// # Ловушка, стоившая правки
///
/// Первая редакция удаляла файл целиком. Два файла держали не только
/// договор, но и ТИПЫ, которыми пользуется живой код (`ProductWithPrice`,
/// `SupplyHistoryItem`). Файл и договор — разные вещи, и сторож меряет
/// договор.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final registration = RegExp(
    r'register(?:LazySingleton|Singleton|Factory)<([A-Za-z0-9_]+)>',
  );

  /// Договоры, зарегистрированные впрок, — поимённо и с доводом.
  ///
  /// Пусто намеренно: «зарегистрируем, пригодится» — это и есть то, из чего
  /// вырастают 4376 строк мёртвого кода. Запись сюда обязана называть, кто
  /// и когда начнёт спрашивать.
  const expected = <String, String>{};

  test('сторож смотрит не в пустоту: контейнер на месте', () {
    final file = File('lib/app/di/service_locator.dart');
    expect(file.existsSync(), isTrue);
    final names = registration
        .allMatches(file.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    expect(
      names.length,
      greaterThan(100),
      reason: 'договоров почти нет — сторож читает не тот файл',
    );
  });

  test('каждый зарегистрированный договор кто-то спрашивает', () {
    final container = File('lib/app/di/service_locator.dart');
    final names = registration
        .allMatches(container.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();

    final sources = <String, String>{};
    for (final dir in ['lib', 'test', 'integration_test']) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.endsWith('service_locator.dart')) continue;
        if (path.endsWith('.g.dart')) continue;
        sources[path] = entity.readAsStringSync();
      }
    }

    final orphans = <String>[];
    for (final name in names) {
      if (expected.containsKey(name)) continue;
      final snake = name
          .replaceAllMapped(RegExp('(?<!^)([A-Z])'), (m) => '_${m.group(1)}')
          .toLowerCase();
      // Собирается из СЫРЫХ кусков: `'\b$name\b'` в обычной строке Dart —
      // это символ забоя, а не граница слова, и такой сторож молчал бы
      // всегда. Поймано первым же прогоном: орфанами оказались все 166
      // договоров, включая `AppDatabase`.
      final word = RegExp(r'\b' + name + r'\b');

      var asked = false;
      for (final entry in sources.entries) {
        final base = entry.key.split('/').last.replaceAll('.dart', '');
        // Объявление и реализация — не спрашивающие.
        if (base == snake || base == '${snake}_impl') continue;
        if (word.hasMatch(entry.value)) {
          asked = true;
          break;
        }
      }
      if (!asked) orphans.add(name);
    }

    expect(
      orphans,
      isEmpty,
      reason:
          'эти договоры зарегистрированы и не спрошены ни разу. Такой код '
          'выглядит живым и потому опаснее отсутствующего: он говорит, что '
          'проверка есть. Снимите его или назовите здесь, кто начнёт его '
          'спрашивать:\n${orphans.join('\n')}',
    );
  });
}
