@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/fiscal/fiscal_state_codes.dart';
import 'package:telepos/domain/sale/payment_service.dart';

/// Сторож числа, которым состояние фискализации ляжет в базу.
///
/// # Мина, ради которой этот файл заведён
///
/// Задача 14 заводит колонку `Sales.fiscalState`. Задача 5 вставляет в
/// перечисление [FiscalState] **два новых члена в середину** —
/// `operatorAbsent` и `fiscalModuleAbsent`. Провод такую вставку переживает:
/// `pay_ops.dart` перебирает `FiscalState.values` и сверяет по **имени**
/// (`state.name == name`) — измерено, не предположено. База — не переживает:
/// если бы колонка хранила `index`, каждая уже записанная строка после
/// релиза молча сменила бы смысл — `done` стало бы `operatorAbsent`,
/// `failed` стало бы `queued`. Деньги остались бы теми же, а отчёт о них
/// соврал бы.
///
/// Отсюда [FiscalStateCodes]: число объявлено **отдельно от порядка
/// членов**, картой. Перестановка членов кода не двигает — в этом весь
/// смысл.
///
/// # Почему сторожей четыре, а не один
///
/// Каждый краснеет от своей диверсии, и ни один не краснеет от чужой:
///
/// 1. **Числа закреплены** — краснеет, если кто-то поправит число в карте.
///    От перестановки членов не краснеет, и это правильно: ровно это
///    свойство и требуется доказать.
/// 2. **Порядок закреплён** — краснеет от перестановки и от вставки члена.
///    Перестановка не запрещена, но обязана быть осознанной: тот, кто её
///    делает, обязан заново ответить на вопрос «а никто ли не начал хранить
///    `index`?» — и сторож 4 отвечает на него измерением, а не памятью.
/// 3. **Карта полна и взаимно однозначна** — краснеет, если член добавили,
///    а кода ему не дали, или дали чужой.
/// 4. **`index` в дереве не хранится** — обход исходников. Самый ценный:
///    он краснеет не от правки перечисления, а от правки того, кто его
///    записывает. Сегодня в дереве `index` над [FiscalState] нет ни одного
///    вхождения — измерено; сторож нужен затем, чтобы первое же вхождение
///    было замечено, а не найдено в отчёте через полгода.
void main() {
  group('FiscalStateCodes', () {
    test('код состояния не зависит от порядка членов', () {
      // Колонка `Sales.fiscalState` (задача 14) хранит ЭТО число.
      // Перестановка членов перечисления не имеет права его сдвинуть.
      expect(FiscalStateCodes.of(FiscalState.notRequired), 1);
      expect(FiscalStateCodes.of(FiscalState.operatorAbsent), 2);
      expect(FiscalStateCodes.of(FiscalState.fiscalModuleAbsent), 3);
      expect(FiscalStateCodes.of(FiscalState.done), 4);
      expect(FiscalStateCodes.of(FiscalState.queued), 5);
      expect(FiscalStateCodes.of(FiscalState.failed), 6);
      expect(FiscalStateCodes.of(FiscalState.unchanged), 7);
      expect(
        FiscalStateCodes.unknown,
        0,
        reason: '«не спрашивали» — отдельное значение, и это НЕ notRequired',
      );
      for (final s in FiscalState.values) {
        expect(FiscalStateCodes.of(s), isNot(0), reason: s.name);
      }
    });

    test('нулём сегодня не является ни одно живое состояние', () {
      // Платёжный черновик ошибался ровно здесь: `0` значил `notRequired`,
      // потому что `notRequired` стоит первым в перечислении. Прочитанный
      // из базы ноль означает «поле не заполняли», а не «документ не был
      // нужен» — это разные утверждения, и путать их нельзя.
      expect(FiscalStateCodes.fromCode(FiscalStateCodes.unknown), isNull);
      for (final s in FiscalState.values) {
        expect(
          FiscalStateCodes.of(s),
          isNot(FiscalStateCodes.unknown),
          reason: '${s.name} не имеет права занять код «не спрашивали»',
        );
      }
    });

    test('код и состояние ходят туда и обратно', () {
      for (final s in FiscalState.values) {
        expect(FiscalStateCodes.fromCode(FiscalStateCodes.of(s)), s);
      }
      expect(
        FiscalStateCodes.fromCode(-1),
        isNull,
        reason: 'незнакомое число — не состояние, а не «первое попавшееся»',
      );
    });

    test('карта кодов полна и взаимно однозначна', () {
      final codes = <int>{};
      for (final s in FiscalState.values) {
        expect(
          () => FiscalStateCodes.of(s),
          returnsNormally,
          reason: 'новому члену ${s.name} не дали стабильного кода',
        );
        expect(
          codes.add(FiscalStateCodes.of(s)),
          isTrue,
          reason: '${s.name} делит код с другим состоянием',
        );
      }
      expect(codes.length, FiscalState.values.length);
    });

    test('порядок членов закреплён — перестановка обязана краснеть', () {
      // Этот сторож НЕ запрещает перестановку. Он делает её осознанной:
      // тот, кто переставил, правит список ниже и тем самым подтверждает,
      // что заново прошёл проверку «никто не хранит index».
      expect(FiscalState.values.map((s) => s.name).toList(), [
        'notRequired',
        'operatorAbsent',
        'fiscalModuleAbsent',
        'done',
        'queued',
        'failed',
        'unchanged',
      ]);
    });

    test('index состояния фискализации нигде не хранится и не сравнивается', () {
      // Обход исходников, а не размышление: дефект здесь текстовый.
      //
      // **Первая редакция этого сторожа была поддельной.** Её образец
      // `FiscalState[A-Za-z]*\.index` не ловил `FiscalState.failed.index`
      // — между именем перечисления и `.index` стоит член. Подсадка
      // строки в `local_payment_service.dart` прошла мимо, и сторож
      // остался зелёным. Найдено диверсией, не чтением: образец, который
      // не проверили подсадкой, — это не проверка, а надежда.
      final patterns = <RegExp>[
        // FiscalState.failed.index, FiscalState.values.first.index
        RegExp(r'FiscalState(\s*\.\s*\w+)*\s*\.\s*index'),
        // fiscal.state.index, outcome.fiscal.state.index, f.state.index
        RegExp(r'\.\s*state\s*\.\s*index'),
        // любая переменная с «fiscal» в имени
        RegExp(r'\bfiscal\w*\s*\.\s*index', caseSensitive: false),
        // FiscalState.values[7] — обращение к списку по номеру
        RegExp(r'FiscalState\s*\.\s*values\s*\['),
      ];

      final offenders = <String>[];
      var scanned = 0;
      var mentioning = 0;
      for (final dir in ['lib', 'test']) {
        final root = Directory(dir);
        if (!root.existsSync()) continue;
        for (final f in root.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          scanned++;
          // Сам сторож про index говорит — себя он не ловит.
          if (f.path.replaceAll(r'\', '/').endsWith(
            'test/domain/fiscal/fiscal_state_codes_test.dart',
          )) {
            continue;
          }
          final text = f.readAsStringSync();
          if (!text.contains('FiscalState')) continue;
          mentioning++;
          final lines = text.split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (patterns.any((p) => p.hasMatch(line))) {
              offenders.add('${f.path}:${i + 1}: ${line.trim()}');
            }
          }
        }
      }

      // Пустой обход тоже даёт пустой список нарушителей. Обход, который
      // ничего не прочёл, обязан краснеть, а не молча соглашаться: это
      // ровно тот способ, которым зелёный цвет значит «не смотрели туда».
      expect(
        scanned,
        greaterThan(500),
        reason: 'обход не нашёл исходников — сторож ничего не проверил',
      );
      expect(
        mentioning,
        greaterThanOrEqualTo(4),
        reason: 'файлов с FiscalState найдено меньше, чем их есть в дереве',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'index перечисления — не стабильное число. В базу едет '
            'FiscalStateCodes.of(...), по проводу — имя члена, никогда '
            'index:\n${offenders.join('\n')}',
      );
    });
  });
}
