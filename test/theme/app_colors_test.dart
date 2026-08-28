import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';

void main() {
  test('палитра содержит ровно те значения, что в спеке', () {
    expect(AppColors.tgBlue, const Color(0xFF3390EC));
    expect(AppColors.tgBluePressed, const Color(0xFF2B7CD3));
    expect(AppColors.tgInk, const Color(0xFF111114));
    expect(AppColors.tgMuted, const Color(0xFF707579));
    expect(AppColors.tgSheet, const Color(0xFFFFFFFF));
    expect(AppColors.tgCanvas, const Color(0xFFF3F4F6));
    expect(AppColors.tgHairline, const Color(0xFFE5E5EA));
    expect(AppColors.tgGreen, const Color(0xFF4FAE4E));
    expect(AppColors.tgRed, const Color(0xFFDF3F40));
    expect(AppColors.tgAmber, const Color(0xFFF5A623));
  });

  test('бирюзы Flat UI в палитре не осталось', () {
    expect(AppColors.primary, isNot(const Color(0xFF1ABC9C)));
    expect(AppColors.primary, AppColors.tgBlue);
  });

  test('старые имена сохранены — на них ссылается всё приложение', () {
    // Переименование ради переименования потребовало бы править сотню
    // экранов и не дало бы ничего. Псевдонимы обязаны продолжать
    // существовать, иначе смена палитры перестаёт быть одним коммитом.
    expect(AppColors.success, AppColors.tgGreen);
    expect(AppColors.error, AppColors.tgRed);
    expect(AppColors.warning, AppColors.tgAmber);
    expect(AppColors.surface, AppColors.tgSheet);
    expect(AppColors.textPrimary, AppColors.tgInk);
    expect(AppColors.textSecondary, AppColors.tgMuted);
    expect(AppColors.divider, AppColors.tgHairline);
  });

  test('белый текст на текстовом акценте проходит AA', () {
    // Не вкус, а WCAG AA для обычного текста: 4.5:1. Кнопка «Далее» — белым
    // по акценту, и если это не проходит, неверна палитра, а не экран.
    final ratio = _contrast(AppColors.tgSheet, AppColors.tgBlueText);
    expect(ratio, greaterThanOrEqualTo(4.5), reason: 'вышло $ratio:1');
  });

  test('текстовый акцент на белом проходит AA', () {
    // Ссылки и подписи акцентом — та же величина в другую сторону.
    final ratio = _contrast(AppColors.tgBlueText, AppColors.tgSheet);
    expect(ratio, greaterThanOrEqualTo(4.5), reason: 'вышло $ratio:1');
  });

  test('акцент как не-текстовый элемент проходит свой порог 3:1', () {
    // Заливка, рельс, галочка, рамка фокуса. Здесь порог другой, и
    // телеграмный #3390EC его проходит — потому и остаётся.
    final ratio = _contrast(AppColors.tgBlue, AppColors.tgSheet);
    expect(ratio, greaterThanOrEqualTo(3.0), reason: 'вышло $ratio:1');
  });

  test('два синих различимы по назначению, но не по виду', () {
    // Если бы они совпали, второй был бы не нужен; если бы разошлись сильно,
    // интерфейс выглядел бы собранным из двух палитр.
    expect(AppColors.tgBlueText, isNot(AppColors.tgBlue));
    expect(
      _contrast(AppColors.tgBlueText, AppColors.tgBlue),
      lessThan(1.8),
      reason: 'между собой они обязаны читаться как один цвет',
    );
  });

  test('основной текст на поверхности читается с большим запасом', () {
    expect(_contrast(AppColors.tgInk, AppColors.tgSheet), greaterThan(15));
  });

  test('вторичный текст проходит порог, а не «почти проходит»', () {
    // #707579 на белом — это ровно тот случай, где легко промахнуться:
    // выглядит спокойно и может не пройти. Проверяем числом.
    expect(
      _contrast(AppColors.tgMuted, AppColors.tgSheet),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('разделитель заметен на поверхности, но не спорит с текстом', () {
    final onSheet = _contrast(AppColors.tgHairline, AppColors.tgSheet);
    expect(onSheet, greaterThan(1.05), reason: 'иначе линии не видно вовсе');
    expect(
      onSheet,
      lessThan(2.0),
      reason: 'разделитель громче этого начинает читаться как рамка',
    );
  });

  // ── Тёмная тема ─────────────────────────────────────────────────────────
  //
  // Тех же измерений, что и для светлой, здесь не было вовсе: тёмная тема была
  // подключена только 2026-08-04, и до того ни одно её значение не появлялось
  // на экране. «Работает в светлой» перестаёт быть ответом — значит и «читается
  // в светлой» тоже.

  test('тёмная палитра — ночная схема Telegram Desktop', () {
    // Изменено 2026-08-27 по замечанию заказчика, и замечание оказалось
    // фактическим: спека `2026-08-04-telegram-desktop-app-design.md`
    // называла «тёмной палитрой Telegram» значения #212121/#2C2C2C/#3A3A3A —
    // это нейтральные серые Material, а ночная тема Telegram Desktop
    // синеватая (#0E1621/#17212B/#232E3C). Акцент #6AB3F3 при этом был взят
    // у Telegram и остался: то есть акцент был телеграмный, а поверхности
    // вокруг него — нет.
    expect(AppColors.tgDarkCanvas, const Color(0xFF0E1621));
    expect(AppColors.tgDarkSheet, const Color(0xFF17212B));
    expect(AppColors.tgDarkHairline, const Color(0xFF232E3C));
    expect(AppColors.tgDarkInk, const Color(0xFFFFFFFF));
    expect(AppColors.tgDarkMuted, const Color(0xFF94A6B8));
    expect(AppColors.tgBlueDark, const Color(0xFF6AB3F3));
  });

  test('серых нейтралей Material в тёмной теме не осталось', () {
    // **Этот тест перевёрнут 2026-08-27, и это не подгонка под правку.**
    //
    // До этого он утверждал обратное — что синеватых нейтралей быть не
    // должно, — и довод был: «спека называет серую, а третьей палитры,
    // которой нет ни в одном согласованном документе, в коде быть не должно».
    // Довод верный по форме, но опирался на утверждение спеки, которое
    // оказалось фактически неверным: #212121/#2C2C2C — палитра Material, а не
    // Telegram. Заказчик это и заметил.
    //
    // Проверяется теперь то же самое с другой стороны: две палитры в одном
    // продукте расходятся тем вернее, чем реже на них смотрят, — поэтому
    // серых Material здесь быть не должно.
    expect(AppColors.darkBackground, isNot(const Color(0xFF212121)));
    expect(AppColors.darkSurface, isNot(const Color(0xFF2C2C2C)));
    expect(AppColors.darkBorder, isNot(const Color(0xFF3A3A3A)));
  });

  test('основной текст тёмной темы читается с большим запасом', () {
    // #FFFFFF на секции #2C2C2C — 13.97:1.
    final ratio = _contrast(AppColors.tgDarkInk, AppColors.tgDarkSheet);
    expect(ratio, greaterThan(13), reason: 'вышло $ratio:1');
  });

  test('приглушённый текст тёмной темы проходит AA', () {
    // #AAAAAA: на секции 6.01:1, на холсте 6.93:1. Порог 4.5:1.
    expect(
      _contrast(AppColors.tgDarkMuted, AppColors.tgDarkSheet),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColors.tgDarkMuted, AppColors.tgDarkCanvas),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('ночной акцент заметно лучше дневного на тёмной секции', () {
    // **Довод пересмотрен 2026-08-27 — ровно так, как требовал прежний
    // текст этого теста:** он говорил «если это число выросло, изменилась
    // палитра, и решение надо пересматривать». Оно выросло.
    //
    // Было: на серой секции #2C2C2C дневной #3390EC давал 4.22:1 при пороге
    // 4.5 — то есть просто не проходил, и этого хватало как обоснования.
    // Стало: на телеграмной секции #17212B он даёт 4.92:1 и порог берёт.
    //
    // Ночной остаётся, но причина теперь другая и записана честно: 7.26
    // против 4.92 — разница не косметическая, и #6AB3F3 и есть тот цвет,
    // которым Telegram Desktop красит ночную тему.
    final daylight = _contrast(AppColors.tgBlue, AppColors.tgDarkSheet);
    final night = _contrast(AppColors.tgBlueDark, AppColors.tgDarkSheet);

    expect(night, greaterThanOrEqualTo(4.5), reason: 'вышло $night:1');
    expect(
      night,
      greaterThan(daylight + 2),
      reason:
          'ночной $night:1 против дневного $daylight:1 — если разрыв сошёлся, '
          'отдельный акцент тёмной темы перестал окупаться, и решение надо '
          'пересматривать заново',
    );
  });

  test('акцент тёмной темы проходит AA и на холсте, и на секции', () {
    // #6AB3F3: на секции 6.22:1, на холсте 7.17:1.
    expect(
      _contrast(AppColors.tgBlueDark, AppColors.tgDarkSheet),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColors.tgBlueDark, AppColors.tgDarkCanvas),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('подпись кнопки в тёмной теме проходит AA', () {
    // Здесь была самая дорогая ошибка тёмной темы: заливка бралась дневная
    // (#3390EC), подпись белая — 3.31:1, то есть ровно то, ради чего в
    // светлой заводился второй синий, в тёмной оставалось несделанным.
    // Комментарий в теме утверждал, что «в тёмной ограничение снимается
    // само»; фон вокруг кнопки к контрасту подписи ВНУТРИ неё отношения не
    // имеет.
    //
    // Стало: заливка #6AB3F3, подпись tgInk — 8.40:1.
    final broken = _contrast(AppColors.tgSheet, AppColors.tgBlue);
    expect(broken, lessThan(4.5), reason: 'белый на дневном синем: $broken:1');

    final fixed = _contrast(AppColors.tgInk, AppColors.tgBlueDark);
    expect(fixed, greaterThanOrEqualTo(4.5), reason: 'вышло $fixed:1');
  });

  test('красный тёмной темы проходит AA, дневной — нет', () {
    // Звёздочка обязательного поля и текст ошибки. Дневной #DF3F40 на секции
    // #2C2C2C — 3.27:1; #FF6B6B — 5.03:1.
    expect(_contrast(AppColors.tgRed, AppColors.tgDarkSheet), lessThan(4.5));
    expect(
      _contrast(AppColors.tgRedDark, AppColors.tgDarkSheet),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('зелёный и жёлтый в тёмной теме порог берут без замены', () {
    // Измерено, а не предположено: #4FAE4E — 4.99:1, #F5A623 — 6.89:1.
    // Поэтому у них тёмных двойников нет, и это решение, а не забывчивость.
    expect(
      _contrast(AppColors.tgGreen, AppColors.tgDarkSheet),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColors.tgAmber, AppColors.tgDarkSheet),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('в тёмной теме секция отделяется от холста так же слабо, как в светлой',
      () {
    // Разделение фоном — приём Telegram, и сила его в обеих темах одна.
    // Если бы в тёмной секция отличалась от холста заметно сильнее, экран
    // читался бы набором карточек, а не сплошным списком.
    final light = _contrast(AppColors.tgSheet, AppColors.tgCanvas);
    final dark = _contrast(AppColors.tgDarkSheet, AppColors.tgDarkCanvas);
    expect(dark, closeTo(light, 0.2), reason: 'светлая $light, тёмная $dark');
  });

  test('разделитель тёмной темы заметен, но не спорит с текстом', () {
    // Те же границы, что у светлой: #3A3A3A на #2C2C2C даёт 1.23:1.
    final onSheet = _contrast(AppColors.tgDarkHairline, AppColors.tgDarkSheet);
    expect(onSheet, greaterThan(1.05), reason: 'иначе линии не видно вовсе');
    expect(onSheet, lessThan(2.0), reason: 'громче этого читается как рамка');
  });

  test('расширение интерполируется и не теряет ролей', () {
    const a = AppSemanticColors(
      success: Color(0xFF000000),
      warning: Color(0xFF000000),
      canvas: Color(0xFF000000),
      hairline: Color(0xFF000000),
      accentFill: Color(0xFF000000),
    );
    const b = AppSemanticColors(
      success: Color(0xFFFFFFFF),
      warning: Color(0xFFFFFFFF),
      canvas: Color(0xFFFFFFFF),
      hairline: Color(0xFFFFFFFF),
      accentFill: Color(0xFFFFFFFF),
    );
    final mid = a.lerp(b, 0.5);
    expect(mid.success, isNot(a.success));
    expect(mid.warning, isNot(a.warning));
    expect(mid.canvas, isNot(a.canvas));
    expect(mid.hairline, isNot(a.hairline));
    expect(mid.accentFill, isNot(a.accentFill));
  });

  test('copyWith меняет названное и не трогает остальное', () {
    const base = AppSemanticColors(
      success: Color(0xFF111111),
      warning: Color(0xFF222222),
      canvas: Color(0xFF333333),
      hairline: Color(0xFF444444),
      accentFill: Color(0xFF555555),
    );
    final changed = base.copyWith(success: const Color(0xFF999999));
    expect(changed.success, const Color(0xFF999999));
    expect(changed.warning, base.warning);
    expect(changed.canvas, base.canvas);
    expect(changed.hairline, base.hairline);
    expect(changed.accentFill, base.accentFill);
  });
}

/// Контраст по WCAG 2.1: (L1 + 0.05) / (L2 + 0.05).
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _luminance(Color c) {
  double channel(double srgb) => srgb <= 0.03928
      ? srgb / 12.92
      : math.pow((srgb + 0.055) / 1.055, 2.4) as double;

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
