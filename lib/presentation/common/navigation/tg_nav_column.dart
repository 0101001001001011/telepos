import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/app_typography.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';

/// Левая колонка назначений — **список**, а не рельс.
///
/// Разница не косметическая. `NavigationRail` расставляет плитки: иконка
/// крупная, подпись под ней мелкая и вторичная, выделение — пятно вокруг
/// иконки. Список Telegram устроен наоборот: подпись — главное, иконка при ней,
/// выделена вся строка целиком. Поэтому это не «рельс с другими цветами», а
/// другой элемент; сохранены только назначения и их фильтрация по правам.
///
/// Ширина фиксирована (`AppTokens.navColumnWidth`): рельс мерил себя по самой
/// длинной подписи, и колонка меняла ширину при смене режима работы.
class TgNavColumn extends StatelessWidget {
  const TgNavColumn({
    required this.destinations,
    required this.currentRoute,
    required this.onSelected,
    this.footer,
    this.isCollapsed = false,
    super.key,
  });

  final List<NavDestination> destinations;

  final String currentRoute;

  final void Function(NavDestination) onSelected;

  /// Подвал колонки: меню дополнительных назначений. Прижат к низу, как
  /// «Настройки» в списке Telegram.
  final Widget? footer;

  /// Свёрнута ли колонка: остаются иконки, подписи уходят в подсказку.
  ///
  /// Умолчание `false` — развёрнутая: это прежнее поведение, и ни один
  /// существующий вызов не задет.
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Ширина меняется вместе с состоянием, а не анимируется отдельно:
      // `AnimatedContainer` в `_TabletScaffold`/`_DesktopScaffold` завернул бы
      // сюда `Row`, и содержимое поехало бы вместе с колонкой. Здесь ширина —
      // свойство самой колонки, и `AnimatedSize` снаружи не нужен.
      width: isCollapsed
          ? AppTokens.navColumnCollapsedWidth
          : AppTokens.navColumnWidth,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              // Прокрутка, а не переполнение: в режиме склада назначений
              // тринадцать, и на экране 800 точек в высоту они в столбик не
              // помещаются. Рельс в этом случае обрезал последние пункты
              // молча — попасть в них было нельзя вовсе.
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space8,
                  vertical: AppTokens.space8,
                ),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final dest = destinations[index];
                  return TgNavRow(
                    destination: dest,
                    isSelected: NavDestinations.routeMatches(
                      currentRoute,
                      dest.route,
                    ),
                    isCollapsed: isCollapsed,
                    onTap: () => onSelected(dest),
                  );
                },
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

/// Граница между колонкой и содержимым — волосок, а не разделитель Material.
///
/// `VerticalDivider(thickness: 1)` рисует **логический** пиксель: на экране с
/// `devicePixelRatio` 2 это линия в два физических, и колонка отделяется от
/// содержимого рамкой вместо волоска. Разница в один пиксель, и видна она
/// каждому.
class TgVerticalHairline extends StatelessWidget {
  const TgVerticalHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppTokens.hairlineOf(context),
      child: ColoredBox(color: context.semantic.hairline),
    );
  }
}

/// Строка левой колонки: 48 в высоту, иконка 20, подпись 15.
///
/// Выделенная строка залита акцентом целиком и скруглена на 8. Подпись при
/// выделении **не меняет вес** — иначе строка дёргала бы ширину текста при
/// переходе, и список читался бы как дрожащий.
class TgNavRow extends StatelessWidget {
  const TgNavRow({
    required this.destination,
    required this.isSelected,
    required this.onTap,
    this.isCollapsed = false,
    super.key,
  });

  final NavDestination destination;

  final bool isSelected;

  /// Свёрнутая строка: только иконка, подпись — подсказкой при наведении.
  final bool isCollapsed;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Заливка берёт `accentFill`, а не `primary`: под белой подписью дневной
    // синий даёт 3.31:1 при пороге AA 4.5:1. См. `AppSemanticColors.accentFill`.
    final foreground = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space4),
      child: Material(
        color: isSelected ? context.semantic.accentFill : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Подсказка только в свёрнутом виде: у развёрнутой строки подпись и
          // так на месте, и всплывающая поверх неё та же строка — шум.
          child: Tooltip(
            message: isCollapsed ? destination.getLabel(context) : '',
            child: SizedBox(
              height: AppTokens.rowHeightTouch,
              child: Row(
                // Свёрнутая строка центрирует иконку: слева-направо она
                // уехала бы к краю, потому что подписи, которая её держала,
                // больше нет.
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!isCollapsed) const SizedBox(width: AppTokens.space12),
                  Icon(
                    destination.getIcon(isSelected),
                    size: AppTokens.iconSizeNav,
                    color: foreground,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: Text(
                        destination.getLabel(context),
                        style: AppTypography.body.copyWith(color: foreground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
