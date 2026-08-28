import 'package:flutter/material.dart';

/// Типографика приложения: семь ролей и ни одной больше.
///
/// **Размеры фиксированы и не масштабируются по ширине экрана.** В проекте
/// есть `ResponsiveInfo.adaptiveFontScale` с коэффициентами 1.0/1.1/1.2 — это
/// ловушка: домножение всего кегля на 1.2 растит заголовок и подпись
/// одинаково, и разница между ними перестаёт читаться. Шкала не адаптируется
/// растяжением, она задана. Адаптируется **плотность** — высоты строк и
/// отступы, см. `WizardMetrics`.
///
/// **Веса ограничены тремя: 400, 500, 700.** Веса 600 у Roboto не существует.
/// До 2026-08-03 тема просила его в полудюжине мест, движок его синтезировал,
/// и синтезированное начертание — одна из причин, по которым интерфейс
/// читался дёшево. Проверяется тестом, а не памятью.
class AppTypography {
  AppTypography._();

  /// Основное семейство. С 2026-08-03 это настоящий Roboto: до того под этим
  /// именем в pubspec лежали файлы DejaVu Sans.
  static const String family = 'Roboto';

  /// Моноширинное — только для штрихкодов. Имя честное: настоящего Roboto
  /// Mono в артефактах Flutter нет, файлы остались от DejaVu Sans Mono, и
  /// семейство названо по тому, что это на самом деле.
  static const String familyMono = 'TeleposMono';

  /// Табулярные цифры: все знаки одной ширины.
  ///
  /// Без них колонка сумм меняет ширину при смене цифры, и это читается как
  /// ошибка ещё до того, как число прочли. То же с ИИН, БИН и номером ККМ.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // Роли для плаката здесь больше нет, и это удаление, а не понижение.
  //
  // Она была заголовком шага в 28 пунктов и через слот `headlineSmall`
  // набирала центрированный плакат наверху каждого экрана мастера. Заказчик
  // посмотрел собранный веб 2026-08-04 и сказал: «шрифт конечно верный, а вот
  // на телеграм не похоже», — и плакат оказался главной причиной. В настройках
  // Telegram заголовков по центру не бывает вовсе.
  //
  // Понизить кегль было бы недостаточно: пока роль существует, ею пользуются.
  // Экран, которому «нужен заголовок покрупнее», — это экран, композицию
  // которого надо пересмотреть, а не подкрутить размер.

  /// Заголовок содержимого. Самая крупная роль в приложении, кроме сумм.
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  /// Подпись группы над секцией.
  ///
  /// Мелкая, приглушённая, слева, прижата к секции — то, чем в Telegram
  /// начинается каждая группа настроек. Заведена отдельной ролью, а не через
  /// [label]: у неё своя работа — назвать группу, а не пояснить строку.
  static const TextStyle sectionHeader = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  /// Основной текст и значения полей.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
    fontFeatures: _tabular,
  );

  /// Название строки в секции.
  ///
  /// Отличается от [body] **только весом** — тот же кегль и тот же
  /// интерлиньяж. Иначе строка прыгала бы по высоте при выделении.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );

  /// Подписи, подсказки, вторая строка в строке списка.
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    // Мелкий кегль на стандартном трекинге читается сбитым.
    letterSpacing: 0.1,
  );

  /// Штрихкоды.
  static const TextStyle mono = TextStyle(
    fontFamily: familyMono,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  /// Суммы.
  static const TextStyle money = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  /// Роли, разложенные по слотам Material.
  ///
  /// Заполнены все слоты, которые приложение использует. Пустой слот молча
  /// отдаёт стиль Material по умолчанию — другую гарнитуру, другой размер,
  /// другой трекинг, — и это ровно тот способ, каким тема «почти
  /// применяется»: половина экрана в новой типографике, половина в чужой.
  static const TextTheme textTheme = TextTheme(
    headlineLarge: title,
    headlineMedium: title,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: bodyStrong,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: label,
    labelLarge: bodyStrong,
    labelMedium: label,
    labelSmall: mono,
    displayLarge: title,
    displayMedium: title,
    displaySmall: title,
  );
}
