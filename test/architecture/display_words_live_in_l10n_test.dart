/// Слово, которое увидит человек, не живёт вне словаря.
///
/// # Зачем сторож, когда их уже трое
///
/// `presentation_has_no_russian_literals_test` читает исходник всего
/// `lib/presentation`, и это хорошо — но ровно настолько, насколько слово
/// лежит в `lib/presentation`.
///
/// 2026-09-22 выяснилось, чего он не видит. `ExpenseType.displayName`
/// возвращал «Зарплата», «Инкассация», «Закуп мелочей» — и жил в
/// `lib/domain`, куда сторож не смотрит.
///
/// **Замер поправил первую догадку, и поправку стоит записать.** На экране
/// эти слова НЕ показывались: рядом давно жило расширение
/// `ExpenseTypeLocalization.localizedName` на ключах `expenseType*`, и
/// выпадающий список был английским. Опасна была вторая дорога того же
/// геттера: касса склеивала его с комментарием человека и писала строку в
/// `cash_operations.note`. Слово для человека, **записанное в историю**, —
/// его уже не перевести, и подпись под каждым расходом на английской кассе
/// оставалась русской.
///
/// Роль сотрудника в чате — тот же геттер и тот же дефект, но без
/// прикрытия: `StaffRole.displayName` уходил прямо на экран.
///
/// И третье, найденное попутно: ключи `cashSalary`, `cashUtilities`,
/// `cashOther`, `cashSupplies`, `cashRent` лежали во всех пяти словарях и
/// не спрашивались нигде — ВТОРОЙ набор для одного понятия, оставшийся от
/// времени до расширения. Снят. Тот же узор, что 36 зарегистрированных и
/// не спрошенных договоров: объявленное принимают за сделанное. Таких
/// ключей в словаре **685 из 4423** (замер 2026-09-22) — это отдельная
/// работа, здесь снят только разошедшийся набор.
///
/// # Правило
///
/// Член класса, названный `displayName` или `description` — то есть прямо
/// объявляющий себя словом для человека, — **не возвращает литерал** нигде,
/// кроме `lib/presentation` и `lib/l10n`. Слово выбирается по устойчивому
/// признаку на языке интерфейса; так уже сделан каталог оборудования
/// (`lib/presentation/common/utils/device_profile_label.dart`), и это
/// образец, а не исключение.
///
/// Правило про ИМЯ члена, а не про кириллицу, и это выбор. Литерал
/// `'Salary'` в `lib/domain` — тот же дефект, просто он молчит на русской
/// кассе вместо английской, а найдётся на полгода позже.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/cash_operation_label.dart';

/// Места, где слово для человека законно лежит вне словаря, — поимённо.
///
/// Пусто, и пусть таким остаётся: каждое исключение здесь означает экран,
/// который на чужом языке покажет чужие слова. Если строка сюда просится —
/// рядом обязан стоять довод, почему её не переводят, а не «пока так».
const _allowed = <String, String>{};

void main() {
  test('displayName и description не возвращают литерал вне словаря', () {
    final offenders = <String>[];

    final member = RegExp(
      r'String\s+get\s+(displayName|description)\b',
    );
    // Любой литерал в теле, а не только `return '…'`. Первая редакция
    // искала `return` и пропустила `UserRole.displayName`: он написан
    // выражением-`switch` со стрелками, и ни одного `return` в нём нет.
    // Слепое пятно нашлось РУЧНЫМ замером, не самим сторожем, — и это
    // ровно то, чем сторож опасен, когда его не проверяют порчей.
    final literal = RegExp("'[^']*[A-Za-zА-яЁё][^']*'");

    for (final dir in const ['lib/domain', 'lib/data', 'lib/telegram',
      'lib/core', 'lib/backend', 'lib/hardware']) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final file in root.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        // Порождённое не читается: там `@pragma('vm:prefer-inline')`
        // рядом с `description` даёт ложное срабатывание, а править
        // там всё равно нечего.
        if (file.path.endsWith('.g.dart')) continue;
        if (file.path.endsWith('.freezed.dart')) continue;
        final rel = file.path.replaceAll(r'\', '/');
        if (_allowed.containsKey(rel)) continue;

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!member.hasMatch(lines[i])) continue;
          // Тело члена — до ближайшей строки, начинающейся с закрывающей
          // скобки того же уровня. Достаточно заглянуть на два десятка
          // строк: длиннее такие геттеры не бывают, а перебрать лишнее
          // безопаснее, чем недосмотреть.
          final end = (i + 24 < lines.length) ? i + 24 : lines.length;
          for (var j = i + 1; j < end; j++) {
            if (RegExp(r'^\s{0,2}\}').hasMatch(lines[j])) break;
            final line = lines[j];
            if (line.trimLeft().startsWith('//')) continue;
            if (line.trimLeft().startsWith('///')) continue;
            if (literal.hasMatch(line)) {
              offenders.add('$rel:${j + 1}  ${line.trim()}');
            }
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'слово для человека лежит вне словаря — на чужом языке экран '
          'покажет чужие слова. Образец, как делать: '
          'lib/presentation/common/utils/device_profile_label.dart — '
          'устойчивый признак хранится, слово выбирается при показе.\n'
          '${offenders.join('\n')}',
    );
  });

  test('род расхода подписан словарём на всех шести значениях', () async {
    // Проверка про ПОВЕДЕНИЕ, а не про имена ключей, и это выбор. Имена
    // сторожить бессмысленно: ключи `cashSalary`, `cashUtilities`,
    // `cashOther`, `cashSupplies`, `cashRent` лежали во всех пяти словарях
    // и не спрашивались нигде, потому что рядом давно жил ВТОРОЙ, живой
    // набор `expenseType*`. Мёртвый набор снят; сторожить надо то, что
    // увидит человек.
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));

    for (final type in ExpenseType.values) {
      final english = type.localizedName(en);
      final russian = type.localizedName(ru);

      expect(english, isNotEmpty, reason: 'род $type без слова по-английски');
      expect(
        english,
        isNot(matches(RegExp('[А-Яа-яЁё]'))),
        reason: 'на английской кассе род расхода $type показан кириллицей: '
            '«$english». Именно так и было: `ExpenseType.displayName` вёз '
            '«Зарплату» и «Инкассацию» из `lib/domain`',
      );
      expect(
        russian,
        isNot(equals(english)),
        reason: 'русское и английское слово совпали у $type — скорее всего '
            'ключ есть в одном словаре и подставился запасным',
      );
    }
  });
}
