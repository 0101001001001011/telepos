import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';

/// Иллюстрация с заголовком под ней — как первый запуск Telegram.
///
/// **Живёт ровно на трёх экранах:** выбор «восстановить или с нуля», первый
/// шаг мастера и завершение. Ещё один — нечитаемое состояние, и он к тому же
/// роду: там тоже картинка (знак обрыва связи) объясняет больше, чем строка.
///
/// На шагах, где заполняют поля, этого блока НЕТ. До 2026-08-04 он стоял на
/// всех одиннадцати: центрированный заголовок, под ним центрированный
/// подзаголовок, и содержимое, отжатое ими вниз. Заказчик посмотрел собранный
/// веб и сказал «на телеграм не похоже» — и это была главная причина. В
/// настройках Telegram заголовков по центру не бывает вовсе: группа
/// начинается мелкой серой подписью слева, и сразу строки.
///
/// Заголовок здесь набирается ролью `title` (20) через слот `headlineSmall` —
/// самой крупной ролью приложения, кроме сумм. Роли крупнее не существует:
/// `display` 28 удалена, и `test/theme/app_typography_test.dart` следит,
/// чтобы она не вернулась.
class WizardHero extends StatelessWidget {
  const WizardHero({
    required this.title,
    required this.metrics,
    this.subtitle,
    this.imageAsset,
    this.illustration,
    super.key,
  }) : assert(
         imageAsset == null || illustration == null,
         'Иллюстрация одна: либо файл, либо виджет. Две сразу означают, что '
         'вызывающий не решил, какая из них настоящая.',
       );

  final String title;
  final String? subtitle;

  /// Картинка из ассетов.
  final String? imageAsset;

  /// Готовый виджет вместо картинки: знак завершения, знак обрыва связи.
  ///
  /// Заведён потому, что до него такой знак ставили в `child` шага — то есть
  /// ПОД заголовок, — и композиция получалась перевёрнутой: подпись сверху,
  /// картинка снизу. В первом запуске Telegram наоборот.
  final Widget? illustration;

  final WizardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final art = illustration ?? _assetArt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (art != null) ...[art, const SizedBox(height: AppTokens.space24)],
        Text(
          title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppTokens.space8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget? _assetArt() {
    final asset = imageAsset;
    if (asset == null) return null;
    return SizedBox(
      height: metrics.heroHeight,
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
