import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    this.barcode,
    this.discount,
  });

  final String name;
  final Decimal quantity;
  final Decimal price;
  final Decimal total;
  final String? barcode;
  final Decimal? discount;
}

class ReceiptData {
  const ReceiptData({
    required this.receiptNo,
    required this.posId,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.cashier,
    this.customer,
    this.paymentMethod,
    this.fiscalNumber,
    this.ofdUrl,
  });

  final int receiptNo;
  final int posId;
  final DateTime date;
  final List<ReceiptItem> items;
  final Decimal subtotal;
  final Decimal discount;
  final Decimal total;
  final String? cashier;
  final String? customer;
  final String? paymentMethod;
  final String? fiscalNumber;
  final String? ofdUrl;
}

class ReceiptView extends StatelessWidget {
  const ReceiptView({
    super.key,
    required this.data,
    this.showHeader = true,
    this.showFooter = true,
    this.currencySymbol = '₸',
    this.width = 300,
  });

  final ReceiptData data;
  final bool showHeader;
  final bool showFooter;
  final String currencySymbol;
  final double width;

  String _formatMoney(Decimal value) {
    final str = value.toStringAsFixed(2);
    final parts = str.split('.');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(' ');
      buffer.write(parts[0][i]);
      count++;
    }
    return '${buffer.toString().split('').reversed.join('')}.${parts[1]} $currencySymbol';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Поверхность темы, а НЕ «бумага».
        //
        // Соблазн оставить белым здесь есть: это чек. Но этот виджет никуда не
        // печатается — он нигде не снимается в изображение и вообще ни разу не
        // вызван, — а весь текст внутри берёт стили из темы и в тёмной
        // становится белым. Белая подложка означала бы белое по белому. Там,
        // где бумага действительно нужна (`label_preview.dart`), стоит
        // `Colors.white`, и это осознанно.
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.semantic.canvas),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHeader) _buildHeader(context),
          const Divider(),
          _buildItems(context),
          const Divider(),
          _buildTotals(context),
          if (showFooter) ...[const Divider(), _buildFooter(context)],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.receiptHeader(data.receiptNo),
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text('POS: ${data.posId}', style: context.styles.caption),
        Text(_formatDateTime(data.date), style: context.styles.caption),
        if (data.cashier != null)
          Text(
            '${l10n.cashier} ${data.cashier}',
            style: context.styles.caption,
          ),
        if (data.customer != null)
          Text('${l10n.buyer} ${data.customer}', style: context.styles.caption),
      ],
    );
  }

  Widget _buildItems(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.body.copyWith(height: 1.5),
        children: data.items
            .map((item) => _buildItemSpan(context, item))
            .expand((spans) => spans)
            .toList(),
      ),
    );
  }

  List<InlineSpan> _buildItemSpan(BuildContext context, ReceiptItem item) {
    final spans = <InlineSpan>[];

    spans.add(
      TextSpan(
        text: '${item.name}\n',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );

    spans.add(
      TextSpan(
        text:
            '  ${item.quantity} x ${_formatMoney(item.price)} = ${_formatMoney(item.total)}\n',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );

    if (item.discount != null && item.discount! > Decimal.zero) {
      spans.add(
        TextSpan(
          text:
              '  ${AppLocalizations.of(context)!.receiptDiscountItem} -${_formatMoney(item.discount!)}\n',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return spans;
  }

  Widget _buildTotals(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildTotalRow(context, l10n.receiptSubtotal, data.subtotal),
        if (data.discount > Decimal.zero)
          _buildTotalRow(
            context,
            l10n.discountTitle,
            data.discount,
            isDiscount: true,
          ),
        const SizedBox(height: 8),
        _buildTotalRow(
          context,
          l10n.tableHeaderTotal,
          data.total,
          isBold: true,
        ),
        if (data.paymentMethod != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${l10n.receiptPayment} ${data.paymentMethod}',
              style: context.styles.caption,
            ),
          ),
      ],
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    String label,
    Decimal value, {
    bool isBold = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.body,
        ),
        Text(
          isDiscount ? '-${_formatMoney(value)}' : _formatMoney(value),
          style:
              (isBold
                      ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)
                      : AppTextStyles.body)
                  .copyWith(
                    color: isDiscount
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (data.fiscalNumber != null)
          Text(
            '${l10n.fiscalMark} ${data.fiscalNumber}',
            style: context.styles.caption,
            textAlign: TextAlign.center,
          ),
        if (data.ofdUrl != null)
          Text(
            data.ofdUrl!,
            style: context.styles.caption.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        Text(
          l10n.thankYouForPurchase,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ReceiptItemTile extends StatelessWidget {
  const ReceiptItemTile({
    super.key,
    required this.item,
    this.currencySymbol = '₸',
    this.onTap,
    this.onDelete,
  });

  final ReceiptItem item;
  final String currencySymbol;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  String _formatMoney(Decimal value) {
    return '${value.toStringAsFixed(2)} $currencySymbol';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantity} x ${_formatMoney(item.price)}',
                    style: context.styles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMoney(item.total),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.discount != null && item.discount! > Decimal.zero)
                  Text(
                    '-${_formatMoney(item.discount!)}',
                    style: context.styles.caption.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(TeleposIcons.delete, size: 20),
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
