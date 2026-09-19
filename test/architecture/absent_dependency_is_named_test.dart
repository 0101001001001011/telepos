@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ниже провода отсутствие зависимости не имеет права выглядеть успехом —
/// задача 41 плана «Продажа с браузерного терминала».
///
/// # Что было измерено
///
/// Обход 2026-09-07: всё, что пересекает провод, отказывает по имени; всё,
/// что ниже, деградирует молча. `LocalPaymentService` на `9ac079a5` молчал на
/// трёх ветках, каждая из которых — не побочное действие, а **исчезающая
/// проверка** или неотличимый от успеха исход:
///
/// - `final shifts = _shifts; if (shifts == null) return;` — потолок возраста
///   смены (задача 27);
/// - `if (await _kaspiConfig(terminalId) == null) return;` — доказательство
///   карты пропускалось и при «терминала нет», и при сломанной привязке;
/// - `final drawer = _drawer; if (drawer == null) return null;` — «ящика нет»
///   давало тот же `null`, что «ящик открылся».
///
/// Правило заказчика (2026-09-07): всё внешнее эмулируется, эмулятор есть
/// всегда, и «зависимости нет» — ошибка настройки, которую надо **назвать**.
///
/// # Форма, которую ловит сторож
///
/// 1. Необнуляемость зависимости обходится полем `final Foo? _foo;` и ранним
///    выходом по нему — прямо (`if (_foo == null) return`) или через местную
///    копию (`final foo = _foo; if (foo == null) return`), в том числе в
///    составе `||`.
/// 2. Проверка, которой «нечем проверять», — `if (await _читатель(...) ==
///    null) return;`: метод вернул «ничего», и метод проверки вышел молча.
///
/// # Разрешительный список полон по построению, а не по обходу
///
/// Каждая строка — **поимённо, с доводом**, и сторож краснеет, когда строка
/// перестаёт быть нужной. Строка здесь — не разрешение молчать, а признание,
/// что молчание названо и почему оно ещё стоит.
const _roots = ['lib/data/sale', 'lib/data/refund', 'lib/data/print'];

const _allowed = <String, String>{
  'lib/data/sale/local_payment_service.dart:_printer':
      'Касса без очереди печати (`ReceiptPrintService` не зарегистрирован) '
      'чека не печатает. По правилу «эмулятор есть всегда» это ошибка '
      'настройки — ОТКРЫТО: в сборке кассы очередь регистрируется всегда, '
      'пустой порт возможен только у проб; довести до обязательного довода '
      'тем же приёмом, что ящик.',
  'lib/data/sale/local_payment_service.dart:_bonuses':
      'Программа лояльности — настройка магазина, а не устройство: касса без '
      'неё законно не начисляет кэшбэк. Не проверка и не железо.',
};

/// Нарушения в одном исходнике: имена полей (или читателей) с ранним
/// выходом по отсутствию.
Set<String> offendersIn(String source) {
  final code = source
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
  final found = <String>{};

  final nullableFields = {
    for (final m in RegExp(
      r'final\s+[\w<>., ]+\?\s+(_\w+)\s*;',
    ).allMatches(code))
      m.group(1)!,
  };

  for (final field in nullableFields) {
    final names = <String>{field};
    for (final m in RegExp(
      r'final\s+(\w+)\s*=\s*' + RegExp.escape(field) + r'\s*;',
    ).allMatches(code)) {
      names.add(m.group(1)!);
    }
    for (final name in names) {
      final early = RegExp(
        r'if\s*\(\s*' +
            RegExp.escape(name) +
            r'\s*==\s*null\s*(?:\|\|[^)]*)?\)\s*return\b',
      );
      if (early.hasMatch(code)) found.add(field);
    }
  }

  for (final m in RegExp(
    r'if\s*\(\s*await\s+(_\w+)\s*\([^)]*\)\s*==\s*null\s*\)\s*return\s*;',
  ).allMatches(code)) {
    found.add('${m.group(1)}()');
  }
  return found;
}

void main() {
  test('разбор видит все три формы, стоявшие на 9ac079a5', () {
    // Полюс — точные строки `9ac079a5`, а не настоящее дерево: две из трёх
    // форм починены, и сторож, проверяющий зрение только на дереве, после
    // починки стал бы зелёным по построению.
    const base = '''
      final ShiftService? _shifts;
      final CashDrawerOpener? _drawer;
      Future<void> _requireShiftNotOverAge() async {
        final shifts = _shifts;
        if (shifts == null) return;
      }
      Future<void> _requireCardProof(int terminalId) async {
        if (await _kaspiConfig(terminalId) == null) return;
      }
      Future<CompletionTrouble?> _openDrawer(int receiptNo) async {
        final drawer = _drawer;
        if (drawer == null) return null;
      }
      final BonusService? _bonuses;
      Future<void> _accrue() async {
        final bonuses = _bonuses;
        if (bonuses == null || customerId == null) return;
      }
      final Foo? _quiet;
      Future<void> _loud() async {
        final quiet = _quiet;
        if (quiet == null) throw StateError('названо');
      }
    ''';
    expect(offendersIn(base), {
      '_shifts',
      '_drawer',
      '_kaspiConfig()',
      '_bonuses',
    });
  });

  test('ниже провода отсутствие зависимости не выходит молча', () {
    final offenders = <String>{};
    var scanned = 0;
    for (final root in _roots) {
      final dir = Directory(root);
      expect(dir.existsSync(), isTrue, reason: 'каталога $root нет');
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        scanned++;
        final path = file.path.replaceAll(r'\', '/');
        for (final name in offendersIn(file.readAsStringSync())) {
          offenders.add('$path:$name');
        }
      }
    }
    // Порог — измеренный, а не круглый: в трёх каталогах 14 файлов
    // (2026-09-15). Первая редакция стояла на 20 и краснела на пороге, а не
    // на форме — сторож, красный не тем, ничего не доказывает.
    expect(
      scanned,
      greaterThanOrEqualTo(12),
      reason: 'обход не пошёл — проверка ничего не значит',
    );

    expect(
      offenders.difference(_allowed.keys.toSet()),
      isEmpty,
      reason:
          'Зависимость отсутствует, а метод выходит так, будто всё прошло. '
          'Сделайте её обязательным доводом (отсутствие станет ошибкой '
          'сборки) или назовите отсутствие отказом/записью; если молчание '
          'законно — впишите поимённо с доводом.',
    );
    expect(
      _allowed.keys.toSet().difference(offenders),
      isEmpty,
      reason:
          'Строка разрешительного списка больше не нужна — снимите её, иначе '
          'список начнёт разрешать то, чего уже нет.',
    );
  });
}
