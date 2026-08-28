import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/app_typography.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';

/// Нижняя панель на узком экране.
///
/// Строение прежнее — иконка и подпись под ней, — и это осознанно: убрать
/// подписи означало бы заставить кассира угадывать назначение по силуэту
/// иконки, а «Возврат» и «Приёмка» силуэтом не различаются. Снято то, что
/// делало панель материальной:
///
/// * тень, которой в плоской теме взяться неоткуда;
/// * собственная типографика `BottomNavigationBar` — свои кегли мимо
///   `AppTypography` и разный размер подписи у выбранного и невыбранного,
///   из-за которого панель дышала при каждом переходе;
/// * граница сверху появилась взамен тени и держит край волоском.
class TgBottomBar extends StatelessWidget {
  const TgBottomBar({
    required this.destinations,
    required this.currentRoute,
    required this.onSelected,
    super.key,
  });

  final List<NavDestination> destinations;

  final String currentRoute;

  final void Function(NavDestination) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: context.semantic.hairline,
            width: AppTokens.hairlineOf(context),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppTokens.bottomBarHeight,
          child: Row(
            children: destinations.map((dest) {
              return Expanded(
                child: _TgBottomItem(
                  destination: dest,
                  isSelected: NavDestinations.routeMatches(
                    currentRoute,
                    dest.route,
                  ),
                  onTap: () => onSelected(dest),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _TgBottomItem extends StatelessWidget {
  const _TgBottomItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Подпись — это текст на поверхности, а не заливка: порог 4.5:1, и туда
    // идёт текстовый синий. Иконка окрашена тем же, иначе выбранный пункт
    // читался бы двумя разными синими.
    final color = isSelected
        ? context.semantic.accentFill
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            destination.getIcon(isSelected),
            size: AppTokens.iconSizeNav,
            color: color,
          ),
          const SizedBox(height: AppTokens.space4),
          Text(
            destination.getLabel(context),
            style: AppTypography.label.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
