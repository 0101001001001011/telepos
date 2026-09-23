/// Подписи мастера: без крика капсом и без двойников.
///
/// # Что измерено 2026-09-21
///
/// Заказчик, глядя на экран мастера: «там текст вышел за пределы блока или
/// не раскрашен». Смотрели кадром — нашлось два разных изъяна, и ни один не
/// был переполнением, о котором Flutter сообщает сам.
///
/// 1. **«Store address» на экране дважды.** Я завёл поле адреса в разделе
///    «Компания», не заметив такого же в разделе «Адреса». Хуже вида: оба
///    писали в одно значение `actualAddress` разными контроллерами —
///    несинхронно, и побеждало то, которое тронули последним.
/// 2. **`"setupSellerLabel": "SELLER"`** — единственное слово капсом среди
///    подписей в обычном регистре. Крик был зашит прямо в словарь, во всех
///    пяти языках.
///
/// # Почему сторож на словарь, а не на экран
///
/// Экранная проба увидела бы только тот экран, до которого дошла. Обе беды
/// живут в словаре, и там их видно все сразу — включая языки, на которых
/// никто не запускал.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Двойники, которые НЕ мешают, — поимённо и с доводом.
///
/// Не «список исключений на всякий случай»: каждая пара названа, и рядом
/// сказано, почему её читают верно. Молчаливое исключение превратило бы
/// сторожа в украшение.
final _allowedSameScreen = <Set<String>>[
  // «COM-порт» у весов и у дисплея покупателя. Каждое поле стоит внутри
  // своего раздела — «Весы» и «Дисплей покупателя», — и заголовок раздела
  // отвечает на вопрос «чей порт». У адреса торговой точки так не вышло:
  // там оба поля назывались одним и тем же существительным, и раздел
  // ничего не различал.
  {'setupScalePortLabel', 'setupDisplayPortLabel'},
];

void main() {
  const locales = ['ru', 'en', 'kk', 'ky', 'uz'];

  Map<String, String> labelsOf(String locale) {
    final json =
        jsonDecode(File('assets/i18n/intl_$locale.arb').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final e in json.entries)
        if (!e.key.startsWith('@') &&
            e.key.startsWith('setup') &&
            e.key.endsWith('Label') &&
            e.value is String)
          e.key: e.value as String,
    };
  }

  test('ни одна подпись мастера не кричит капсом', () {
    final offenders = <String>[];

    for (final locale in locales) {
      labelsOf(locale).forEach((key, value) {
        // Смотрим ПОСЛОВНО, а не на подпись целиком.
        //
        // «API URL» и «URL ОФД» целиком состоят из заглавных, и мерка по
        // всей подписи красила бы их — а это аббревиатуры, а не крик.
        // Первая редакция сторожа так и сделала и дала четыре ложных.
        //
        // Порог — пять букв в ОДНОМ слове: «URL», «API», «POS», «ОФД»,
        // «ИИН» короче, «SELLER» и «ADMINISTRATOR» длиннее.
        for (final word in value.split(RegExp(r'[^\p{L}]+', unicode: true))) {
          if (word.length < 5) continue;
          if (word == word.toUpperCase() && word != word.toLowerCase()) {
            offenders.add('$locale/$key = «$value»');
            break;
          }
        }
      });
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'подпись капсом среди подписей в обычном регистре выглядит '
          'ошибкой вёрстки, а не выделением:\n${offenders.join('\n')}',
    );
  });

  test('на одном экране мастера нет двух полей с одной подписью', () {
    // Двойники ищутся не по словарю целиком, а ПО ЭКРАНУ.
    //
    // Первая редакция сторожа сравнивала весь словарь и дала два ложных:
    // «ID кассы» стоит и у кассы, и в настройке ОФД, «COM-порт» — у весов
    // и у дисплея покупателя. Это разные экраны и разные вопросы, и
    // одинаковая подпись там не мешает.
    //
    // Мешает она на ОДНОМ экране: человек читает повтор и не знает, в
    // какое поле писать. Так и было с адресом торговой точки.
    final steps = Directory('lib/presentation/screens/setup/steps')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    expect(steps, isNotEmpty, reason: 'шагов мастера не найдено вовсе');

    final labels = labelsOf('ru');
    final offenders = <String>[];

    for (final step in steps) {
      final source = step.readAsStringSync();
      final used = labels.keys
          .where((k) => source.contains('l10n.$k'))
          .toList();

      final byText = <String, List<String>>{};
      for (final key in used) {
        (byText[labels[key]!.trim().toLowerCase()] ??= []).add(key);
      }

      for (final entry in byText.entries) {
        if (entry.value.length < 2) continue;
        // Сравнение по СОДЕРЖИМОМУ: `contains` у списка множеств
        // сравнивает по ссылке и молчал бы всегда.
        final pair = entry.value.toSet();
        if (_allowedSameScreen.any(
          (allowed) =>
              allowed.length == pair.length && allowed.containsAll(pair),
        )) {
          continue;
        }
        offenders.add(
          '${step.path.split(RegExp(r"[\/]")).last}: «${entry.key}» — '
          '${entry.value.join(", ")}',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'два поля с одной подписью на одном экране. Человек читает это '
          'как повтор и не знает, в какое писать; у нас они вдобавок '
          'писали в одно значение разными контроллерами:\n'
          '${offenders.join('\n')}',
    );
  });
}
