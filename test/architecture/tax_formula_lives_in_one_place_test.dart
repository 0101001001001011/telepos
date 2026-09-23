/// Формула налога объявлена ровно в одном файле.
///
/// # Зачем сторож, если функция и так общая
///
/// Потому что общей она стала не сразу. Корзине понадобился налог, формула
/// была внутри печати чека, и первым побуждением было её скопировать —
/// копия и появилась, с другим округлением (`scaleOnInfinitePrecision: 2`
/// вместо `.round(scale: 2)`). На двух позициях расхождение составило
/// полцента.
///
/// Копии расходятся не в момент копирования. Они расходятся тогда, когда
/// кто-то поправит одну — и не найдёт вторую. В этом проекте это уже
/// случалось: печатаемый чек и фискальный документ считали налог
/// по-разному, и бумага у покупателя расходилась с документом у налоговой
/// на копейку.
///
/// # Что именно ищется
///
/// Деление на сто и на «сто плюс ставка» — два узнаваемых следа обеих
/// формул. Сторож ловит след, а не имя функции: скопируют её под другим
/// именем, и проверка по имени промолчала бы.
///
/// # У этого способа нашлась слепота, и она стоила двух копий
///
/// 2026-09-22 в продукте оказались ЕЩЁ ДВЕ записи той же формулы, и ни одну
/// из них сторож не видел:
///
/// * `FiscalPositionBuilder.vatFromGross` — та же арифметика, набранная
///   другими словами: `denominator` вместо `hundred + ratePercent`;
/// * `VatCalculator.extractVatFromGross` — та же формула, СВЁРНУТАЯ под
///   ставку 16 % в числа `4/29` и `116/100`. Ни ставки, ни деления на сто
///   в тексте нет вовсе, зато она работала на боевом пути печати чека: чек
///   мог объявить ставку 12 % и показать налог, посчитанный по 16 %.
///
/// Поэтому к следу добавлено ИМЯ: второй тест ниже. Проверка по имени
/// слабее — но она ловит ровно то, что пропускает первая, и наоборот.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Единственный дом формулы.
  const home = 'lib/domain/tax/tax_amounts.dart';

  /// Следы: `/ Decimal.fromInt(100)` и `/ (hundred + ratePercent)`.
  final traces = [
    RegExp(r'/\s*Decimal\.fromInt\(100\)'),
    RegExp(r'/\s*\(hundred\s*\+\s*ratePercent\)'),
  ];

  test('дом формулы на месте — сторож смотрит не в пустоту', () {
    final file = File(home);
    expect(file.existsSync(), isTrue, reason: '$home исчез');
    final text = file.readAsStringSync();
    for (final trace in traces) {
      expect(
        trace.hasMatch(text),
        isTrue,
        reason:
            'в $home нет следа «$trace» — формула переписана, и сторож '
            'ловит теперь не то, что думает',
      );
    }
  });

  test('никто больше не делит на сто ради налога', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith(home)) continue;
      // Сгенерированное не в счёт: его не пишут руками.
      if (path.endsWith('.g.dart')) continue;

      final text = entity.readAsStringSync();
      // Смотрим только там, где рядом говорят про налог: деление на сто
      // встречается и в скидках, и в наценке, и запрещать его целиком
      // значило бы запретить проценты вообще.
      if (!RegExp(
        r'ratePercent|taxRate|taxOnNet|taxFromGross',
      ).hasMatch(text)) {
        continue;
      }
      for (final trace in traces) {
        if (trace.hasMatch(text)) {
          offenders.add(path);
          break;
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'формула налога скопирована в ${offenders.join(", ")}. Копии '
          'расходятся тогда, когда кто-то поправит одну и не найдёт '
          'вторую; зовите `taxOnNet`/`taxFromGross` из $home',
    );
  });

  test('никто больше не ОБЪЯВЛЯЕТ функцию, считающую налог', () {
    // Слепота следа, измеренная 2026-09-22: формулу можно свернуть под
    // одну ставку (`4/29` вместо `ratePercent / (100 + ratePercent)`), и
    // тогда следа не остаётся вовсе. Имя остаётся.
    //
    // Делегирование не считается: `vatFromGross` у фискального построителя
    // объявлен стрелкой в общий дом, и запрещать такое значило бы требовать
    // переписать все вызовы разом.
    final declaration = RegExp(
      r'(?:static\s+)?Decimal\??\s+(vatFrom|taxFrom|vatOn|taxOn|extractVat)'
      r'[A-Za-z]*\s*\(',
    );
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith(home)) continue;
      if (path.endsWith('.g.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!declaration.hasMatch(lines[i])) continue;
        // Пересылка в общий дом — не вторая формула. Признак пересылки:
        // тело зовёт домашнюю функцию (напрямую или через уже проверенный
        // `FiscalPositionBuilder.vatFromGross`) и САМО НИЧЕГО НЕ ДЕЛИТ.
        // Делитель в теле — это и есть та арифметика, ради которой сторож.
        // Комментарии из окна вырезаются: `///` — это тоже делитель, и
        // докстрока следующей функции объявляла бы пересылку арифметикой.
        final body = lines
            .sublist(i, (i + 5).clamp(0, lines.length))
            .where((l) => !l.trimLeft().startsWith('//'))
            .join(' ');
        final forwards = RegExp(
          r'tax(From|On)[A-Za-z]*\(|FiscalPositionBuilder\.vatFromGross\(',
        ).hasMatch(body);
        if (forwards && !body.contains('/')) continue;
        offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'это вторая формула налога, даже если она свёрнута под одну '
          'ставку и следа деления не оставляет. Делегируйте в $home:'
          '\n${offenders.join('\n')}',
    );
  });
}
