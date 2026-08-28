import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/l10n/app_localizations.dart';

class DeferredSale {
  const DeferredSale({
    required this.id,
    required this.createdAt,
    required this.itemCount,
    required this.total,
    this.customerName,
    this.comment,
  });

  final int id;
  final DateTime createdAt;
  final int itemCount;
  final Decimal total;
  final String? customerName;
  final String? comment;
}

enum DeferredSaleAction { resume, delete }

class DeferredSaleResult {
  const DeferredSaleResult({required this.action, required this.sale});

  final DeferredSaleAction action;
  final DeferredSale sale;
}

class DeferredSaleDialog extends StatelessWidget {
  const DeferredSaleDialog({super.key, required this.sales});

  final List<DeferredSale> sales;

  static Future<DeferredSaleResult?> show({
    required BuildContext context,
    required List<DeferredSale> sales,
  }) {
    return showDialog<DeferredSaleResult>(
      context: context,
      builder: (context) => DeferredSaleDialog(sales: sales),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatMoney(Decimal value) {
    final symbol = GetIt.I<CurrencyService>().symbol;
    return '${value.toStringAsFixed(2)} $symbol';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.semantic.canvas),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pause_circle_outline,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.deferredSales,
                    style: AppTextStyles.h3,
                  ),
                  const Spacer(),
                  Text(
                    '${sales.length}',
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(TeleposIcons.close),
                  ),
                ],
              ),
            ),

            if (sales.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.noDeferredSales,
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return _DeferredSaleTile(
                      sale: sale,
                      formatDateTime: _formatDateTime,
                      formatMoney: _formatMoney,
                      onResume: () => Navigator.of(context).pop(
                        DeferredSaleResult(
                          action: DeferredSaleAction.resume,
                          sale: sale,
                        ),
                      ),
                      onDelete: () => Navigator.of(context).pop(
                        DeferredSaleResult(
                          action: DeferredSaleAction.delete,
                          sale: sale,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeferredSaleTile extends StatelessWidget {
  const _DeferredSaleTile({
    required this.sale,
    required this.formatDateTime,
    required this.formatMoney,
    required this.onResume,
    required this.onDelete,
  });

  final DeferredSale sale;
  final String Function(DateTime) formatDateTime;
  final String Function(Decimal) formatMoney;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onResume,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  '#${sale.id}',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${sale.itemCount} ${AppLocalizations.of(context)!.positions}',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatMoney(sale.total),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDateTime(sale.createdAt),
                    style: context.styles.caption,
                  ),
                  if (sale.customerName != null)
                    Text(sale.customerName!, style: context.styles.caption),
                ],
              ),
            ),

            IconButton(
              onPressed: onDelete,
              icon: const Icon(TeleposIcons.delete),
              color: Theme.of(context).colorScheme.error,
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
