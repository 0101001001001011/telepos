import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_typography.dart';

void main() {
  _guardAgainstDisplay();
  final styles = <String, TextStyle>{
    'title': AppTypography.title,
    'sectionHeader': AppTypography.sectionHeader,
    'body': AppTypography.body,
    'bodyStrong': AppTypography.bodyStrong,
    'label': AppTypography.label,
    'mono': AppTypography.mono,
    'money': AppTypography.money,
  };

  test('используются только веса, которые у Roboto есть', () {
    // 400, 500, 700 — и всё. Веса 600 у Roboto не существует: до 2026-08-03
    // тема просила его в полудюжине мест, движок его синтезировал, и это
    // была одна из причин, по которым интерфейс читался дёшево.
    // Не `const`: с Flutter 3.47 у `FontWeight` есть собственный
    // `operator ==` (`dart:ui`, сравнение по `value`), а Dart запрещает
    // элементы с непримитивным равенством в константных коллекциях —
    // «does not have a primitive equality». Константность здесь была
    // случайностью, а не смыслом: множество читается один раз при сборке
    // набора. Сравнение от правки не пострадало, а стало точнее — раньше
    // `contains` работал на тождестве канонизированных констант, теперь на
    // значении, и `FontWeight(400)` из чужого кода тоже будет узнан.
    final allowed = {FontWeight.w400, FontWeight.w500, FontWeight.w700};
    styles.forEach((name, style) {
      expect(
        allowed.contains(style.fontWeight),
        isTrue,
        reason: '$name просит ${style.fontWeight}, а такого начертания нет',
      );
    });
  });

  test('у каждой роли задан размер и интерлиньяж', () {
    // Стиль без height наследует межстрочное расстояние гарнитуры, и тогда
    // одна и та же строка занимает разную высоту в разных ролях.
    styles.forEach((name, style) {
      expect(style.fontSize, isNotNull, reason: '$name без размера');
      expect(style.height, isNotNull, reason: '$name без интерлиньяжа');
    });
  });

  test('размеры и интерлиньяж соответствуют спеке', () {
    expect(AppTypography.title.fontSize, 20);
    expect(AppTypography.title.height, closeTo(26 / 20, 0.001));
    expect(AppTypography.body.fontSize, 15);
    expect(AppTypography.body.height, closeTo(20 / 15, 0.001));
    expect(AppTypography.sectionHeader.fontSize, 13);
    expect(AppTypography.label.fontSize, 13);
    expect(AppTypography.money.fontSize, 22);
  });

  test('заголовки идут с отрицательным трекингом, подпись с положительным', () {
    // Крупный кегль на стандартном трекинге выглядит разреженным, мелкий —
    // сбитым. Знак здесь важнее величины.
    expect(AppTypography.title.letterSpacing, lessThan(0));
    expect(AppTypography.label.letterSpacing, greaterThan(0));
  });

  test('цифры табулярные везде, где показываются числа', () {
    // Колонка сумм, которая пляшет по ширине при смене цифры, читается как
    // ошибка ещё до того, как её прочли. То же с ИИН, БИН и номером ККМ.
    for (final entry in {
      'body': AppTypography.body,
      'bodyStrong': AppTypography.bodyStrong,
      'money': AppTypography.money,
    }.entries) {
      expect(
        entry.value.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: '${entry.key} без табулярных цифр',
      );
    }
  });

  test('семейства названы честно', () {
    // `RobotoMono` в проекте никогда не было: под этим именем лежал
    // DejaVu Sans Mono. Имя переименовано, файлы остались.
    expect(AppTypography.family, 'Roboto');
    expect(AppTypography.mono.fontFamily, 'TeleposMono');
    for (final entry in styles.entries) {
      if (entry.key == 'mono') continue;
      expect(
        entry.value.fontFamily,
        AppTypography.family,
        reason: '${entry.key} набран не тем семейством',
      );
    }
  });

  test('bodyStrong отличается от body только весом', () {
    // Иначе это не «тот же текст жирнее», а другая роль, и строка секции
    // начнёт прыгать по высоте при выделении.
    expect(AppTypography.bodyStrong.fontSize, AppTypography.body.fontSize);
    expect(AppTypography.bodyStrong.height, AppTypography.body.height);
    expect(
      AppTypography.bodyStrong.fontWeight,
      isNot(AppTypography.body.fontWeight),
    );
  });

  test('шкала убывает от заголовка к подписи', () {
    expect(
      AppTypography.title.fontSize!,
      greaterThan(AppTypography.body.fontSize!),
    );
    expect(
      AppTypography.body.fontSize!,
      greaterThan(AppTypography.label.fontSize!),
    );
  });

  test('textTheme раздаёт роли по слотам Material', () {
    final t = AppTypography.textTheme;
    expect(t.headlineSmall?.fontSize, AppTypography.title.fontSize);
    expect(t.titleLarge?.fontSize, AppTypography.title.fontSize);
    expect(t.bodyLarge?.fontSize, AppTypography.body.fontSize);
    expect(t.titleMedium?.fontWeight, AppTypography.bodyStrong.fontWeight);
    expect(t.bodySmall?.fontSize, AppTypography.label.fontSize);
  });

  test('в textTheme нет пустых слотов из тех, что мы используем', () {
    // Пустой слот молча отдаёт стиль Material по умолчанию — другую
    // гарнитуру, другой размер, другой трекинг. Это ровно тот способ, каким
    // тема «почти применилась».
    final t = AppTypography.textTheme;
    for (final entry in {
      'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge,
      'titleMedium': t.titleMedium,
      'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium,
      'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge,
    }.entries) {
      expect(entry.value, isNotNull, reason: '${entry.key} не заполнен');
      expect(
        entry.value!.fontSize,
        isNotNull,
        reason: '${entry.key} без размера',
      );
    }
  });
}

/// Роль `display` удалена и не должна вернуться.
///
/// Она была заголовком шага в 28 пунктов и через слот `headlineSmall` набирала
/// центрированный плакат наверху каждого экрана мастера. Заказчик посмотрел
/// собранный веб 2026-08-04 и сказал: «шрифт конечно верный, а вот на телеграм
/// не похоже» — плакат оказался главной причиной.
///
/// Сторож нужен потому, что удаление роли ничем не защищено: первый же экран,
/// которому «нужен заголовок покрупнее», заведёт её обратно, и вернётся не
/// одна константа, а вся композиция.
void _guardAgainstDisplay() {
  test('в приложении не осталось кегля крупнее title', () {
    final t = AppTypography.textTheme;
    final biggest = <double>[
      t.displayLarge!.fontSize!,
      t.displayMedium!.fontSize!,
      t.displaySmall!.fontSize!,
      t.headlineLarge!.fontSize!,
      t.headlineMedium!.fontSize!,
      t.headlineSmall!.fontSize!,
      t.titleLarge!.fontSize!,
    ];

    for (final size in biggest) {
      expect(
        size,
        lessThanOrEqualTo(AppTypography.title.fontSize!),
        reason: 'крупный слот Material снова раздаёт кегль больше title — '
            'это возвращает плакат через заднюю дверь',
      );
    }

    // Деньги — единственное исключение, и оно намеренное: Telegram ничего не
    // продаёт, а сумму к оплате кассир читает через зал.
    expect(AppTypography.money.fontSize, greaterThan(AppTypography.title.fontSize!));
  });
}
