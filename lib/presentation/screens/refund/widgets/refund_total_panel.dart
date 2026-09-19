import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

class RefundTotalPanel extends ConsumerWidget {
  const RefundTotalPanel({this.onRefund, this.compact = false, super.key});

  final VoidCallback? onRefund;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundControllerProvider);

    if (compact) {
      return _CompactTotalPanel(state: state, onRefund: onRefund);
    }

    return _FullTotalPanel(state: state);
  }
}

class _FullTotalPanel extends StatelessWidget {
  const _FullTotalPanel({required this.state});

  final RefundState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `Expanded` вокруг заголовка — не оформление. На планшете в
          // портрете (900×1400) правая колонка узкая, и без него эта строка
          // переполнялась на 13 точек: часть заголовка кассир не видел
          // вовсе, а поверх панели шла жёлто-чёрная лента переполнения.
          // Измерено пробой `test/web/wt_refund_route_test.dart` (шаг 4
          // задачи 20) — на настоящем маршруте браузерного терминала.
          Row(
            children: [
              const Icon(
                Icons.assignment_return,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.refundTotalAmount,
                  style: AppTextStyles.h3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spacing),

          if (state.receiptInfo != null) ...[
            _InfoRow(
              label: l10n.receiptNumber,
              value: '${state.receiptInfo!.receiptNo}',
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            _InfoRow(
              label: l10n.refundPosLabel,
              value:
                  state.receiptInfo!.posName ??
                  'POS-${state.receiptInfo!.posId}',
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacingSmall),
          ],

          _InfoRow(
            label: l10n.refundSelectedItems(state.selectedCount),
            value: l10n.refundSelectedOfTotal(
              '${state.selectedCount}',
              '${state.items.length}',
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),

          if (state.total != state.selectedTotal) ...[
            _InfoRow(label: l10n.refundTotalProducts, value: '${state.total}'),
            const SizedBox(height: AppTheme.spacingSmall),
          ],

          const Divider(height: 1),
          const SizedBox(height: AppTheme.spacing),

          _InfoRow(
            label: l10n.refundToReturn,
            value: '${state.selectedTotal}',
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _CompactTotalPanel extends StatelessWidget {
  const _CompactTotalPanel({required this.state, this.onRefund});

  final RefundState state;
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = state.canRefund;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Та же порода, что в полной панели, и та же починка.
                  // Разбор круга правки перемерил компактную на телефонах:
                  // 360×800 — **два** переполнения (98 точек здесь и ещё 6
                  // ниже), 390×844 — 68, 412×915 — 46. Браузерный терминал
                  // целится не только в планшет, и половина исправленного
                  // дефекта — приглашение к третьему кругу.
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.refundToReturnLabel,
                          style: AppTextStyles.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(mode: state.mode),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.selectedTotal}',
                    style: AppTextStyles.h2.copyWith(color: AppColors.warning),
                  ),
                  if (state.selectedCount > 0)
                    Text(
                      l10n.refundSelectedItemsShort(
                        '${state.selectedCount}',
                        '${state.items.length}',
                      ),
                      style: context.styles.caption,
                    ),
                ],
              ),
            ),

            const SizedBox(width: AppTheme.spacingSmall),

            // Кнопка не сжимается: она — цель пальца, и ужимать её ниже 48
            // точек нельзя (проба «цель не меньше 48»). Сжимается подпись
            // слева, а число суммы не сжимается никогда.
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? onRefund : null,
                icon: const Icon(Icons.assignment_return),
                label: Text(
                  l10n.refundAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.black,
                  disabledBackgroundColor: context.semantic.canvas,
                  disabledForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    // Подпись сжимается, число — нет.
    //
    // Число здесь всегда деньги или счёт строк, и обрезать его нельзя ни при
    // какой ширине: «1 05» вместо «1050» хуже, чем отсутствие строки.
    // Подпись же сокращается без потери смысла. До этой правки не сжималось
    // ничто, и на планшете в портрете строка «выбрано N из M»
    // переполнялась на 78 точек — то есть само число уезжало за край
    // (измерено пробой шага 4 задачи 20).
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: isTotal
                ? AppTextStyles.h3
                : AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppTheme.spacingSmall),
        Text(
          value,
          style: isTotal
              ? AppTextStyles.h2.copyWith(color: AppColors.warning)
              : AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});

  final RefundMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isByReceipt = mode == RefundMode.byReceipt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isByReceipt ? l10n.refundByReceipt : l10n.refundWithoutReceipt,
        style: context.styles.caption.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
