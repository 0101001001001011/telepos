import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/app_typography.dart';

void main() {
  final light = AppTheme.light;
  final dark = AppTheme.dark;

  test('схема цветов собрана из палитры Telegram', () {
    expect(light.colorScheme.primary, AppColors.tgBlue);
    expect(light.colorScheme.surface, AppColors.tgSheet);
    expect(light.colorScheme.onSurface, AppColors.tgInk);
    expect(light.colorScheme.onSurfaceVariant, AppColors.tgMuted);
    expect(light.colorScheme.outlineVariant, AppColors.tgHairline);
    expect(light.scaffoldBackgroundColor, AppColors.tgCanvas);
  });

  test('семантическое расширение зарегистрировано в обеих темах', () {
    for (final entry in {'светлая': light, 'тёмная': dark}.entries) {
      final semantic = entry.value.extension<AppSemanticColors>();
      expect(semantic, isNotNull, reason: '${entry.key} без расширения');
      expect(semantic!.success, AppColors.tgGreen);
      expect(semantic.warning, AppColors.tgAmber);
    }
    expect(light.extension<AppSemanticColors>()!.canvas, AppColors.tgCanvas);
    expect(
      dark.extension<AppSemanticColors>()!.canvas,
      AppColors.darkBackground,
    );
  });

  test('теней нет нигде', () {
    // Плоское разделение фоном и hairline — это то, чем язык Telegram
    // отличается от Material. Одна забытая тень выдаёт всю тему.
    expect(light.cardTheme.elevation, 0);
    expect(light.appBarTheme.elevation, 0);
    expect(light.appBarTheme.scrolledUnderElevation, 0);
    expect(light.dialogTheme.elevation, 0);
    expect(light.bottomSheetTheme.elevation, 0);
    expect(light.snackBarTheme.elevation, 0);
    expect(light.floatingActionButtonTheme.elevation, 0);
    expect(light.elevatedButtonTheme.style?.elevation?.resolve(const {}), 0);
  });

  test('поверхности не подкрашиваются surfaceTint', () {
    // Material 3 подмешивает акцент в поверхность по высоте. У плоской темы
    // высоты нет, а подмешивание остаётся и красит белое в голубоватое.
    expect(light.cardTheme.surfaceTintColor, Colors.transparent);
    expect(light.appBarTheme.surfaceTintColor, Colors.transparent);
    expect(light.dialogTheme.surfaceTintColor, Colors.transparent);
    expect(light.bottomSheetTheme.surfaceTintColor, Colors.transparent);
  });

  test('радиусы берутся из токенов, а не выдуманы на месте', () {
    final card = light.cardTheme.shape! as RoundedRectangleBorder;
    expect(card.borderRadius, BorderRadius.circular(AppTokens.radiusSection));

    final button =
        light.elevatedButtonTheme.style!.shape!.resolve(const {})!
            as RoundedRectangleBorder;
    expect(button.borderRadius, BorderRadius.circular(AppTokens.radiusControl));
  });

  test('типографика подключена целиком', () {
    expect(light.textTheme.bodyLarge?.fontSize, AppTypography.body.fontSize);
    // Сверяется с ролью, а не с числом: число здесь уже устаревало —
    // стояло -0.4 от роли, которой не стало 2026-08-04.
    expect(
      light.textTheme.headlineSmall?.letterSpacing,
      AppTypography.title.letterSpacing,
    );
    expect(light.textTheme.bodyLarge?.fontFamily, AppTypography.family);
  });

  test('поле ввода не обведено рамкой', () {
    // Границу задаёт секция. Рамка вокруг каждого поля внутри неё была
    // половиной ощущения «дёшево»: два прямоугольника там, где нужен один.
    expect(light.inputDecorationTheme.filled, isFalse);
    expect(light.inputDecorationTheme.border, InputBorder.none);
    expect(light.inputDecorationTheme.enabledBorder, InputBorder.none);
    expect(light.inputDecorationTheme.focusedBorder, InputBorder.none);
  });

  test('кнопка набрана текстовым синим, а не заливочным', () {
    // Белый на tgBlue даёт 3.31:1 при пороге 4.5:1. Кнопка — это текст, и
    // она обязана брать tgBlueText, иначе подпись не дотягивает до AA.
    final background = light.elevatedButtonTheme.style?.backgroundColor
        ?.resolve(const {});
    expect(background, AppColors.tgBlueText);
  });

  test('высота кнопки не ниже порога доступности', () {
    // Тема задаёт ПОРОГ — 48, ниже которого палец промахивается. Высота
    // главной кнопки мастера (52) принадлежит WizardActions: заданная всем
    // кнопкам приложения, она ломает плотные строки действий в диалогах,
    // и это измерено, а не предположено.
    final size = light.elevatedButtonTheme.style?.minimumSize?.resolve(
      const {},
    );
    expect(size, isNotNull);
    expect(size!.height, greaterThanOrEqualTo(48.0));
    // Прежде здесь стояло `lessThan(rowHeightTouch)` с оговоркой, что
    // предпочтение мастера не должно становиться правилом для всех: тема
    // держала порог 48, а мастер просил 52.
    //
    // 2026-08-04 строка сжата до 48 — плотность Telegram, — и различать стало
    // нечего: предпочтение мастера СОВПАЛО с порогом. Утверждение убрано не
    // потому, что правило нарушено, а потому, что оно перестало быть
    // применимым; порог по-прежнему проверяется строкой выше.
    expect(size.height, AppTokens.rowHeightTouch);
  });

  test('разделитель нулевой толщины: её задаёт вызывающий по dpr', () {
    // Толщина берётся из AppTokens.hairlineOf(context), потому что зависит
    // от плотности экрана. Тема не может знать dpr и не должна угадывать.
    expect(light.dividerTheme.thickness, 0);
    expect(light.dividerTheme.space, 0);
    expect(light.dividerTheme.color, AppColors.tgHairline);
  });

  test('тёмная тема существует и отличается от светлой', () {
    expect(dark.brightness, Brightness.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.scaffoldBackgroundColor, isNot(light.scaffoldBackgroundColor));
  });

  test('акцент тёмной темы — свой, и это не расхождение', () {
    // Здесь стояло `expect(dark.primary, light.primary)` с пояснением «тёмная
    // тема — это другая подложка, а не другой продукт». Утверждение было
    // красивым и неверным: дневной #3390EC на тёмной секции #2C2C2C даёт
    // 4.22:1 при пороге AA 4.5:1. Тест закреплял дефект — и не мог его
    // заметить, потому что тёмную тему до 2026-08-04 не показывали вовсе.
    //
    // Числа — в `app_colors_test.dart`; здесь проверяется, что тема их берёт.
    expect(dark.colorScheme.primary, AppColors.tgBlueDark);
    expect(light.colorScheme.primary, AppColors.tgBlue);
    expect(dark.colorScheme.primary, isNot(light.colorScheme.primary));
  });

  test('тёмная тема собрана из тёмной палитры целиком', () {
    expect(dark.colorScheme.surface, AppColors.tgDarkSheet);
    expect(dark.colorScheme.onSurface, AppColors.tgDarkInk);
    expect(dark.colorScheme.onSurfaceVariant, AppColors.tgDarkMuted);
    expect(dark.colorScheme.outlineVariant, AppColors.tgDarkHairline);
    expect(dark.colorScheme.error, AppColors.tgRedDark);
    expect(dark.scaffoldBackgroundColor, AppColors.tgDarkCanvas);
  });

  test('подпись кнопки в тёмной теме — тёмная по светлому синему', () {
    // Белый на синем в тёмной теме давал 3.31:1 — тот же промах, ради
    // которого в светлой заводился второй синий. В тёмной он лечится иначе:
    // акцент светлее фона, значит текст по нему обязан быть тёмным (8.40:1).
    final fill = dark.elevatedButtonTheme.style?.backgroundColor?.resolve(
      const {},
    );
    final label = dark.elevatedButtonTheme.style?.foregroundColor?.resolve(
      const {},
    );
    expect(fill, AppColors.tgBlueDark);
    expect(label, AppColors.tgInk);
  });

  test('бегунок переключателя белый в обеих темах', () {
    // Он брался из `scheme.onPrimary` — в светлой это белый, и подмена не
    // была заметна. В тёмной onPrimary стал тёмным (текст на светлом синем),
    // и бегунок вместе с ним превратился бы в чёрную точку на зелёной
    // дорожке. Роли совпали случайно, а не по смыслу.
    for (final theme in {'светлая': light, 'тёмная': dark}.entries) {
      expect(
        theme.value.switchTheme.thumbColor?.resolve(const {}),
        AppColors.tgSheet,
        reason: '${theme.key}: бегунок не белый',
      );
    }
  });
}
