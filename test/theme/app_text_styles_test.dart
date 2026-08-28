import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';

import '../support/contrast.dart';

/// Роли, у которых цвет несёт смысл «приглушённо».
const _muted = {'caption', 'tableHeader', 'productQuantity', 'barcode'};

/// Что здесь доказывается.
///
/// До 2026-08-04 каждый стиль в [AppTextStyles] запекал цвет светлой темы:
/// `color: AppColors.textPrimary` и подобное. 559 обращений в 87 файлах брали
/// его как есть, и с подключением тёмной темы весь текст приложения, кроме
/// мастера настройки, стал рисоваться чернилами #111114 по секции #2C2C2C —
/// **1.17:1** при пороге AA 4.5:1. Это не «плохо читается», это невидимо.
///
/// Проверка идёт по **отрисованному** дереву, а не по объявлению стиля.
/// Утверждение «стиль без цвета возьмёт его из темы» — это утверждение о
/// поведении Flutter (`Text` сливает свой стиль с `DefaultTextStyle`, а тот
/// приходит из `textTheme.bodyMedium`, куда `ThemeData` подставляет
/// `colorScheme.onSurface`). Проверять его по исходнику значит проверять свою
/// же веру в него. Поэтому каждая роль здесь рисуется настоящим `Text` внутри
/// настоящей темы, а цвет вынимается из `RenderParagraph`.
void main() {
  // Роль → как её получить. Первые берут цвет из темы сами (у них его нет),
  // вторые обязаны спросить контекст: приглушённость — это смысл, а не
  // оформление, и `onSurface` вместо `onSurfaceVariant` был бы тихим регрессом.
  final roles = <String, TextStyle Function(BuildContext)>{
    'h1': (_) => AppTextStyles.h1,
    'h2': (_) => AppTextStyles.h2,
    'h3': (_) => AppTextStyles.h3,
    'body': (_) => AppTextStyles.body,
    'button': (_) => AppTextStyles.button,
    'tableCell': (_) => AppTextStyles.tableCell,
    'priceTotal': (_) => AppTextStyles.priceTotal,
    'priceItem': (_) => AppTextStyles.priceItem,
    'productName': (_) => AppTextStyles.productName,
    'actionButton': (_) => AppTextStyles.actionButton,
    'numpadButton': (_) => AppTextStyles.numpadButton,
    'tabLabel': (_) => AppTextStyles.tabLabel,
    'caption': (c) => c.styles.caption,
    'tableHeader': (c) => c.styles.tableHeader,
    'productQuantity': (c) => c.styles.productQuantity,
    'barcode': (c) => c.styles.barcode,
  };

  /// Рисует все роли в заданной теме и возвращает разрешённый цвет каждой.
  Future<Map<String, Color>> resolve(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                for (final entry in roles.entries)
                  Text(
                    'Шрифт',
                    key: ValueKey(entry.key),
                    style: entry.value(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    // pumpAndSettle обязателен, и это не перестраховка. `MaterialApp` меняет
    // тему через `AnimatedTheme` за 200 мс: на первом кадре после смены темы
    // цвета ещё прежние. Без этой строки второй вызов возвращал цвета первой
    // темы, и проверка «роли меняются вместе с темой» краснела на исправном
    // коде — измерено, именно так она и упала.
    await tester.pumpAndSettle();

    final out = <String, Color>{};
    for (final name in roles.keys) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(ValueKey(name)),
      );
      final span = paragraph.text as TextSpan;
      final color = span.style?.color;
      expect(
        color,
        isNotNull,
        reason:
            'роль $name отрисована без цвета: ни стиль, ни DefaultTextStyle '
            'его не дали — значит текст красится чем попало',
      );
      out[name] = color!;
    }
    return out;
  }

  for (final theme in <String, ThemeData>{
    'светлая': AppTheme.light,
    'тёмная': AppTheme.dark,
  }.entries) {
    testWidgets('${theme.key}: каждая роль берёт порог AA на секции и на холсте', (
      tester,
    ) async {
      final colors = await resolve(tester, theme.value);
      final scheme = theme.value.colorScheme;
      final semantic = theme.value.extension<AppSemanticColors>()!;

      final table = StringBuffer('\nКОНТРАСТ (${theme.key})\n');
      final failures = <String>[];

      for (final entry in colors.entries) {
        final onSheet = contrast(entry.value, scheme.surface);
        final onCanvas = contrast(entry.value, semantic.canvas);
        table.writeln(
          '${entry.key.padRight(16)} ${_hex(entry.value)}  '
          'секция ${onSheet.toStringAsFixed(2)}:1  '
          'холст ${onCanvas.toStringAsFixed(2)}:1',
        );
        // Секция — то, на чём текст стоит: в сгруппированном списке Telegram
        // строка лежит внутри секции, а холст виден только между ними. Порог
        // на секции безусловный.
        if (onSheet < 4.5) {
          failures.add(
            '${entry.key} на секции ${onSheet.toStringAsFixed(2)}:1',
          );
        }
        // Холст — там же порог, но с одним **измеренным и неисправленным**
        // исключением, см. ниже.
        final mutedOnLightCanvas =
            theme.key == 'светлая' && _muted.contains(entry.key);
        if (onCanvas < 4.5 && !mutedOnLightCanvas) {
          failures.add(
            '${entry.key} на холсте ${onCanvas.toStringAsFixed(2)}:1',
          );
        }
        if (mutedOnLightCanvas) {
          // ДЕФЕКТ ПАЛИТРЫ, а не этого изменения. #707579 на белой секции даёт
          // 4.66:1 и порог берёт; на холсте #F3F4F6 — **4.23:1**, и не берёт.
          // Прежний `app_colors_test` мерил только на секции и потому молчал.
          //
          // Здесь это не «подкручено»: цвет тот же самый, что был запечён в
          // `caption` до правки, то есть светлая тема выглядит ровно как
          // выглядела. Исправление — сдвинуть `tgMuted` примерно на 7% темнее
          // (нужна яркость ≤ 0.1602, сейчас 0.1727), а это правка палитры из
          // согласованной с заказчиком спеки и переснятые эталоны светлой темы.
          // Отдельное решение, не побочный эффект правки тёмной темы.
          //
          // Число закреплено точно: станет хуже — тест покраснеет; станет
          // лучше — тоже покраснеет и приведёт сюда, к причине.
          expect(
            onCanvas,
            closeTo(4.23, 0.01),
            reason:
                'известный незакрытый дефект палитры: приглушённый текст на '
                'холсте светлой темы, вышло $onCanvas:1',
          );
        }
      }

      // ignore: avoid_print
      print(table);
      expect(failures, isEmpty, reason: 'порог AA 4.5:1 не взят: $failures');
    });
  }

  testWidgets('роли действительно меняются вместе с темой', (tester) async {
    // Без этой проверки предыдущая проходила бы и на запечённом цвете: она
    // мерит контраст, а запечённые чернила на СВЕТЛОЙ секции его берут. Ловит
    // ровно ту ошибку, которая тут и была, — цвет, не зависящий от темы.
    final light = await resolve(tester, AppTheme.light);
    final dark = await resolve(tester, AppTheme.dark);

    final frozen = <String>[
      for (final name in light.keys)
        if (light[name] == dark[name]) name,
    ];
    expect(
      frozen,
      isEmpty,
      reason:
          'эти роли отдали один и тот же цвет в обеих темах, то есть берут его '
          'мимо темы: $frozen',
    );
  });

  testWidgets(
    'приглушённая роль остаётся приглушённой, а не становится основной',
    (tester) async {
      // Вынести caption из AppTextStyles и просто убрать цвет было бы тише и
      // проще — и подпись сравнялась бы с основным текстом. Разница ролей
      // проверяется, а не подразумевается.
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = await resolve(tester, theme);
        for (final muted in _muted) {
          expect(
            colors[muted],
            theme.colorScheme.onSurfaceVariant,
            reason: '$muted обязан быть onSurfaceVariant',
          );
          expect(
            colors[muted],
            isNot(colors['body']),
            reason: '$muted сравнялся с основным текстом',
          );
        }
      }
    },
  );

  testWidgets('дневные чернила на ночной секции — то самое 1.17:1', (
    tester,
  ) async {
    // Фиксация цены ошибки, а не проверка кода. Если однажды кто-то вернёт
    // `color: AppColors.textPrimary` в общий стиль, это число объясняет, что
    // именно он вернул.
    final ratio = contrast(AppColors.textPrimary, AppColors.tgDarkSheet);
    expect(ratio, lessThan(1.5), reason: 'вышло $ratio:1');
    expect(ratio, greaterThan(1.0));
  });

  test('в AppTextStyles не осталось запечённого цвета', () {
    // Страж. Поведенческие проверки выше перечисляют роли поимённо и потому
    // молчат о роли, которую заведут завтра. Эта смотрит на исходник и краснеет
    // на любое `color:` внутри класса — включая ещё не написанные стили.
    final source = File('lib/app/theme/app_theme.dart').readAsStringSync();
    final body = _classBody(source, 'AppTextStyles');
    expect(
      body,
      isNotNull,
      reason: 'класс AppTextStyles не найден — страж потерял цель',
    );

    final offenders = <String>[];
    for (final line in body!.split('\n')) {
      final code = line.contains('//')
          ? line.substring(0, line.indexOf('//'))
          : line;
      if (RegExp(r'\bcolor\s*:').hasMatch(code)) {
        offenders.add(code.trim());
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Цвет в общем стиле — это цвет ОДНОЙ темы. Роль «основной текст» '
          'тема разрешает сама через onSurface; роль, у которой цвет несёт '
          'смысл, живёт в AppTextStylesOf и берёт его из ColorScheme. '
          'Найдено:\n${offenders.join('\n')}',
    );
  });

  test('AppTextStylesOf берёт цвет только из темы', () {
    // Вторая половина того же правила: класс с контекстом бесполезен, если
    // внутри него снова стоит константа палитры.
    final source = File('lib/app/theme/app_theme.dart').readAsStringSync();
    final body = _classBody(source, 'AppTextStylesOf');
    expect(body, isNotNull);
    expect(
      RegExp(r'AppColors\.').hasMatch(body!),
      isFalse,
      reason: 'AppTextStylesOf обязан красить только тем, что пришло из темы',
    );
  });
}

/// Тело класса по имени: от `class Имя` до закрывающей скобки нужного уровня.
String? _classBody(String source, String name) {
  final start = source.indexOf(RegExp('class $name\\b'));
  if (start == -1) return null;
  final open = source.indexOf('{', start);
  if (open == -1) return null;
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  return null;
}

String _hex(Color c) {
  String p(double v) =>
      (v * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${p(c.r)}${p(c.g)}${p(c.b)}';
}

// `contrast` переехал в `test/support/contrast.dart` — у него появился
// второй потребитель (рамка поля кода привязки в `login_screen_test.dart`).
