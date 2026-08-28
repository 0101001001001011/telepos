import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

class SaleActionButtons extends ConsumerWidget {
  const SaleActionButtons({
    this.onQuickProducts,
    this.onQuantity,
    this.onEdit,
    this.onDefer,
    this.onDeferredList,
    this.onMark,
    this.onDelete,
    this.onWeigh,
    this.onPrintLabel,
    this.showWeigh = false,
    this.showPrintLabel = false,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onQuickProducts;
  final VoidCallback? onQuantity;
  final VoidCallback? onEdit;
  final VoidCallback? onDefer;
  final VoidCallback? onDeferredList;
  final VoidCallback? onMark;
  final VoidCallback? onDelete;

  final VoidCallback? onWeigh;

  final VoidCallback? onPrintLabel;

  final bool showWeigh;

  final bool showPrintLabel;

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleControllerProvider);
    final hasSelection = state.selectedItem != null;
    final hasItems = state.isNotEmpty;

    final l10n = AppLocalizations.of(context)!;

    final buttons = <_ButtonDef>[
      _ButtonDef(
        Icons.remove,
        '1',
        hasSelection
            ? () =>
                  ref.read(saleControllerProvider.notifier).decrementQuantity()
            : null,
      ),
      _ButtonDef(
        TeleposIcons.add,
        '1',
        hasSelection
            ? () =>
                  ref.read(saleControllerProvider.notifier).incrementQuantity()
            : null,
      ),
      _ButtonDef(
        Icons.dialpad,
        l10n.globalQuantity,
        hasSelection ? onQuantity : null,
      ),
      _ButtonDef(Icons.edit, l10n.globalEdit, hasSelection ? onEdit : null),
      _ButtonDef(Icons.grid_view, l10n.quickProducts, onQuickProducts),
      _ButtonDef(Icons.history, l10n.actionDeferredList, onDeferredList),
      _ButtonDef(
        Icons.pause_circle_outline,
        l10n.actionDefer,
        hasItems ? onDefer : null,
      ),
      _ButtonDef(
        Icons.qr_code_scanner,
        l10n.actionMark,
        hasSelection ? onMark : null,
      ),
      if (showWeigh)
        _ButtonDef(
          Icons.scale,
          l10n.actionWeigh,
          hasSelection ? onWeigh : null,
        ),
      if (showPrintLabel)
        _ButtonDef(
          Icons.label_outline,
          l10n.actionPrintLabel,
          hasSelection ? onPrintLabel : null,
        ),
      _ButtonDef(
        TeleposIcons.delete,
        l10n.globalDelete,
        hasSelection
            ? () =>
                  ref.read(saleControllerProvider.notifier).removeSelectedItem()
            : null,
        color: Theme.of(context).colorScheme.error,
      ),
    ];

    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: buttons
              .map(
                (b) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _IconOnlyButton(
                    icon: b.icon,
                    tooltip: b.label,
                    onPressed: b.onPressed,
                    color: b.color,
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 350 ? 3 : 2;
        final spacing = 6.0;
        final btnWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: buttons
              .map(
                (b) => SizedBox(
                  width: btnWidth,
                  child: _ActionButton(
                    icon: b.icon,
                    label: b.label,
                    onPressed: b.onPressed,
                    color: b.color,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ButtonDef {
  const _ButtonDef(this.icon, this.label, this.onPressed, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final effectiveColor = color ?? AppColors.primary;

    return Material(
      color: isEnabled
          ? effectiveColor.withValues(alpha: 0.1)
          : context.semantic.canvas,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isEnabled
                    ? effectiveColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: context.styles.caption.copyWith(
                    color: isEnabled
                        ? effectiveColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconOnlyButton extends StatelessWidget {
  const _IconOnlyButton({
    required this.icon,
    required this.tooltip,
    this.color,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final effectiveColor = color ?? AppColors.primary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isEnabled
            ? effectiveColor.withValues(alpha: 0.1)
            : context.semantic.canvas,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 20,
              color: isEnabled ? effectiveColor : AppColors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Material(
      color: isEnabled ? AppColors.success : context.semantic.canvas,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment,
                size: 24,
                color: isEnabled
                    ? AppColors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.payBtn,
                style: AppTextStyles.h3.copyWith(
                  color: isEnabled
                      ? AppColors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SaleActionsFab extends ConsumerWidget {
  const SaleActionsFab({
    this.onQuickProducts,
    this.onQuantity,
    this.onEdit,
    this.onDefer,
    this.onMark,
    this.onDelete,
    this.onWeigh,
    this.onPrintLabel,
    this.showWeigh = false,
    this.showPrintLabel = false,
    super.key,
  });

  final VoidCallback? onQuickProducts;
  final VoidCallback? onQuantity;
  final VoidCallback? onEdit;
  final VoidCallback? onDefer;
  final VoidCallback? onMark;
  final VoidCallback? onDelete;

  final VoidCallback? onWeigh;

  final VoidCallback? onPrintLabel;

  final bool showWeigh;

  final bool showPrintLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleControllerProvider);
    final hasSelection = state.selectedItem != null;
    final hasItems = state.isNotEmpty;

    return PopupMenuButton<String>(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.more_vert, color: AppColors.white),
      ),
      onSelected: (value) {
        switch (value) {
          case 'quick':
            onQuickProducts?.call();
          case 'quantity':
            onQuantity?.call();
          case 'increment':
            ref.read(saleControllerProvider.notifier).incrementQuantity();
          case 'decrement':
            ref.read(saleControllerProvider.notifier).decrementQuantity();
          case 'edit':
            onEdit?.call();
          case 'defer':
            onDefer?.call();
          case 'mark':
            onMark?.call();
          case 'weigh':
            onWeigh?.call();
          case 'printLabel':
            onPrintLabel?.call();
          case 'delete':
            ref.read(saleControllerProvider.notifier).removeSelectedItem();
        }
      },
      itemBuilder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return [
          PopupMenuItem(
            value: 'quick',
            child: _PopupItem(icon: Icons.grid_view, label: l10n.quickProducts),
          ),
          if (hasSelection) ...[
            PopupMenuItem(
              value: 'quantity',
              child: _PopupItem(
                icon: Icons.dialpad,
                label: l10n.globalQuantity,
              ),
            ),
            PopupMenuItem(
              value: 'increment',
              child: _PopupItem(
                icon: TeleposIcons.add,
                label: l10n.actionIncrease,
              ),
            ),
            PopupMenuItem(
              value: 'decrement',
              child: _PopupItem(icon: Icons.remove, label: l10n.actionDecrease),
            ),
            PopupMenuItem(
              value: 'edit',
              child: _PopupItem(icon: Icons.edit, label: l10n.globalEdit),
            ),
            PopupMenuItem(
              value: 'mark',
              child: _PopupItem(
                icon: Icons.qr_code_scanner,
                label: l10n.actionMark,
              ),
            ),
            if (showWeigh)
              PopupMenuItem(
                value: 'weigh',
                child: _PopupItem(icon: Icons.scale, label: l10n.actionWeigh),
              ),
            if (showPrintLabel)
              PopupMenuItem(
                value: 'printLabel',
                child: _PopupItem(
                  icon: Icons.label_outline,
                  label: l10n.actionPrintLabel,
                ),
              ),
            PopupMenuItem(
              value: 'delete',
              child: _PopupItem(
                icon: TeleposIcons.delete,
                label: l10n.globalDelete,
                isDestructive: true,
              ),
            ),
          ],
          if (hasItems)
            PopupMenuItem(
              value: 'defer',
              child: _PopupItem(
                icon: Icons.pause_circle_outline,
                label: l10n.actionDefer,
              ),
            ),
        ];
      },
    );
  }
}

class _PopupItem extends StatelessWidget {
  const _PopupItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: AppTextStyles.body.copyWith(color: color)),
      ],
    );
  }
}
