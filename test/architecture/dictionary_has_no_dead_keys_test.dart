/// В словаре нет ключей, которых никто не спрашивает.
///
/// # Чем это оплачено
///
/// 2026-09-23 в словаре нашлось **670 мёртвых ключей из 4439** — пятнадцать
/// процентов. Не безобидный излишек: мёртвый ключ опаснее отсутствующего,
/// потому что по словарю кажется, что переведено.
///
/// Так и вышло с родами расхода. Ключи `cashSalary`, `cashUtilities`,
/// `cashOther`, `cashSupplies`, `cashRent` лежали во всех пяти языках и не
/// спрашивались нигде — потому что рядом давно жил ВТОРОЙ набор,
/// `expenseType*`. Два словаря для одного понятия, и разошлись бы они на
/// первой же правке одного из них.
///
/// Сорок два мёртвых ключа вывели на настоящие дефекты: слово было зашито
/// рядом с существующим ключом. Так нашлись квитанция кассовой операции,
/// дисплей покупателя и две подписи в `platform_payment_service.dart`,
/// которые оказались мёртвым кодом.
///
/// # Как считается «спрашивают»
///
/// Собираются ВСЕ опознаватели из `.dart` вне `lib/l10n` — и в `lib`, и в
/// `test`, и в `integration_test`, и в `tools`. Ключ считается живым, если
/// такое слово встретилось хоть где-то.
///
/// Это намеренно щедро: ошибиться можно только в сторону «живой», и ни один
/// используемый ключ сторож не назовёт мёртвым. Проверка стоит на **том, что
/// объявлено и не спрошено**, а не на изяществе обращения.
///
/// # Почему список исключений пуст
///
/// Ключ, который понадобится завтра, добавляют завтра — вместе с тем, кто
/// его спрашивает. Ключ, добавленный заранее, полгода утверждает, что экран
/// переведён.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ключи, законно объявленные без читателя, — поимённо и с доводом.
const _allowed = <String, String>{};

void main() {
  test('каждый ключ словаря кто-то спрашивает', () {
    final arb =
        jsonDecode(File('assets/i18n/intl_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = arb.keys.where((k) => !k.startsWith('@')).toSet();

    final identifier = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
    final used = <String>{};
    for (final dir in const ['lib', 'test', 'integration_test', 'tools']) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final file in root.listSync(recursive: true).whereType<File>()) {
        final path = file.path.replaceAll(r'\', '/');
        if (!path.endsWith('.dart')) continue;
        if (path.endsWith('.g.dart')) continue;
        // ТОЛЬКО порождённый словарь, а не всякий каталог со словом
        // `l10n` в пути. Первая редакция отбрасывала `/l10n/` целиком
        // и вместе с ним `test/l10n/section_keys_test.dart`, где
        // ключи заголовков секций перечислены строками, — и объявила
        // `setupSectionCashback` мёртвым. Уборка его удалила, проба
        // заголовков покраснела на пяти языках.
        if (path.contains('/lib/l10n/') || path.startsWith('lib/l10n/')) {
          continue;
        }
        used.addAll(
          identifier.allMatches(file.readAsStringSync()).map((m) => m.group(0)!),
        );
      }
    }

    final dead = keys.difference(used).difference(_allowed.keys.toSet()).toList()
      ..sort();

    expect(
      dead,
      isEmpty,
      reason:
          'объявлено и не спрошено ${dead.length} ключей. Мёртвый ключ '
          'опаснее отсутствующего: по словарю кажется, что переведено. '
          'Либо его кто-то должен спрашивать, либо его не должно быть.\n'
          '${dead.take(40).join(", ")}',
    );
  });

  test('пять словарей несут один и тот же состав', () {
    // Расхождение состава означает экран, который на одном языке говорит, а
    // на другом молчит — и молчит он ЗАПАСНЫМ значением, то есть
    // по-английски посреди русского.
    Set<String> keysOf(String lang) {
      final arb =
          jsonDecode(File('assets/i18n/intl_$lang.arb').readAsStringSync())
              as Map<String, dynamic>;
      return arb.keys.where((k) => !k.startsWith('@')).toSet();
    }

    final base = keysOf('en');
    for (final lang in const ['ru', 'kk', 'ky', 'uz']) {
      final other = keysOf(lang);
      expect(
        other.difference(base).toList()..sort(),
        isEmpty,
        reason: '$lang несёт ключи, которых нет в en',
      );
      expect(
        base.difference(other).toList()..sort(),
        isEmpty,
        reason: '$lang не несёт ключей, которые есть в en',
      );
    }
  });
}
