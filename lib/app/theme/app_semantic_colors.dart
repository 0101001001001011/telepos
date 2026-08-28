import 'package:flutter/material.dart';

/// Роли, которых нет в [ColorScheme].
///
/// Шесть основных ролей палитры ложатся в стандартную схему: акцент →
/// `primary`, основной текст → `onSurface`, вторичный → `onSurfaceVariant`,
/// поверхность секции → `surface`, разделитель → `outlineVariant`. Успех и
/// предупреждение в `ColorScheme` отсутствуют, а фон **под** секциями
/// отличается от поверхности самих секций — эти четыре роли живут здесь.
///
/// Расширение, а не статические константы, потому что экран обязан брать цвет
/// из `Theme.of(context)`. Иначе тему нельзя подменить в тесте и нельзя завести
/// тёмную: цвет, взятый мимо темы, остаётся светлым в тёмной.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.canvas,
    required this.hairline,
    required this.accentFill,
  });

  /// Подтверждение: смена прошла, чек напечатан, оплата принята.
  final Color success;

  /// Предупреждение: продолжать можно, но стоит посмотреть.
  final Color warning;

  /// Фон под сгруппированными секциями.
  ///
  /// Отдельная роль, а не оттенок `surface`: секция и подложка обязаны
  /// различаться, иначе сгруппированный список перестаёт читаться как
  /// сгруппированный и превращается в сплошное полотно.
  final Color canvas;

  /// Цвет разделителя. Толщина берётся из `AppTokens.hairlineOf`.
  final Color hairline;

  /// Заливка акцентом **под текстом**: кнопка, выделенная строка навигации.
  ///
  /// Отдельная роль от `ColorScheme.primary`, потому что порог контраста у них
  /// разный. Измерено (см. `AppColors.tgBlueText`): белый на `tgBlue` даёт
  /// 3.31:1 при пороге AA 4.5:1 для текста, а под не-текстовым элементом порог
  /// 3:1, и там `tgBlue` проходит. Пока это жило локальной переменной внутри
  /// `_build`, каждый экран, которому понадобилась залитая акцентом строка,
  /// брал `primary` — и молча ронял контраст подписи.
  ///
  /// В тёмной теме ограничение снимается само: фон другой, и туда идёт
  /// дневной `tgBlue`.
  final Color accentFill;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? canvas,
    Color? hairline,
    Color? accentFill,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      canvas: canvas ?? this.canvas,
      hairline: hairline ?? this.hairline,
      accentFill: accentFill ?? this.accentFill,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accentFill: Color.lerp(accentFill, other.accentFill, t)!,
    );
  }
}

/// Короткий доступ: `context.semantic.success`.
extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>()!;
}

/// То же самое там, где `ThemeData` уже на руках.
///
/// Заведено не для симметрии: часть построителей принимает готовую `theme`
/// параметром и контекста не видит вовсе. Без этой формы каждому такому методу
/// пришлось бы менять сигнатуру ради цвета, который уже лежит в переданной теме.
extension AppSemanticColorsTheme on ThemeData {
  AppSemanticColors get semantic => extension<AppSemanticColors>()!;
}
