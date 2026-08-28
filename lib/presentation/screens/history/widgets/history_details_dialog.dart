import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';

class HistoryDetailsDialog extends ConsumerStatefulWidget {
  const HistoryDetailsDialog({super.key, required this.item});

  final HistoryItem item;

  @override
  ConsumerState<HistoryDetailsDialog> createState() =>
      _HistoryDetailsDialogState();
}

class _HistoryDetailsDialogState extends ConsumerState<HistoryDetailsDialog> {
  bool _isLoading = true;
  List<_ProductLine> _products = [];
  List<_PaymentLine> _payments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  Future<void> _loadDetails() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final db = GetIt.I<AppDatabase>();
      talker.debug(
        'HistoryDetails: loading type=${widget.item.type}, '
        'receiptNo=${widget.item.receiptNo}, posId=${widget.item.posId}, id=${widget.item.id}',
      );

      if (widget.item.type == HistoryItemType.sale) {
        final saleProducts = await db.saleProductDao.findBySale(
          widget.item.receiptNo,
          widget.item.posId,
        );
        talker.debug('HistoryDetails: found ${saleProducts.length} products');

        final products = <_ProductLine>[];
        for (final sp in saleProducts) {
          final product = await db.productInfoDao.findByUcode(sp.ucode);
          products.add(
            _ProductLine(
              name:
                  product?.name ??
                  l10n.historyProductUcode(sp.ucode.toString()),
              quantity: sp.quantity,
              price: sp.price,
              total: sp.quantity * sp.price,
              discount: sp.priceBefore - sp.price,
            ),
          );
        }

        final salePayments = await db.paymentDao.findBySale(
          widget.item.receiptNo,
          widget.item.posId,
        );
        talker.debug('HistoryDetails: found ${salePayments.length} payments');

        final payments = <_PaymentLine>[];
        for (final payment in salePayments) {
          final account = await db.accountDao.findById(payment.payeeAccountId);
          payments.add(
            _PaymentLine(
              accountName:
                  account?.name ??
                  l10n.historyAccountId(payment.payeeAccountId.toString()),
              amount: payment.amount,
              isCash: account?.type == 0,
            ),
          );
        }

        if (mounted) {
          setState(() {
            _products = products;
            _payments = payments;
            _isLoading = false;
          });
        }
      } else {
        final refundProducts = await db.saleProductDao.findUniversalByRefund(
          widget.item.id,
        );

        final products = <_ProductLine>[];
        for (final rp in refundProducts) {
          products.add(
            _ProductLine(
              name: l10n.historyRefundProductId(rp.id.toString()),
              quantity: rp.quantity,
              price: rp.price,
              total: rp.quantity * rp.price,
              discount: (rp.priceBefore ?? rp.price) - rp.price,
            ),
          );
        }

        final refundPayments = await db.paymentDao.findByRefund(widget.item.id);

        final payments = <_PaymentLine>[];
        for (final payment in refundPayments) {
          final account = await db.accountDao.findById(payment.payeeAccountId);
          payments.add(
            _PaymentLine(
              accountName:
                  account?.name ??
                  l10n.historyAccountId(payment.payeeAccountId.toString()),
              amount: payment.amount,
              isCash: account?.type == 0,
            ),
          );
        }

        if (mounted) {
          setState(() {
            _products = products;
            _payments = payments;
            _isLoading = false;
          });
        }
      }
    } catch (e, stack) {
      talker.error('HistoryDetails: load error: $e', e, stack);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSale = widget.item.type == HistoryItemType.sale;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isSale ? Icons.shopping_cart : Icons.assignment_return,
            color: isSale ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSale ? l10n.historySale : l10n.historyRefund,
                  style: AppTextStyles.h3,
                ),
                Text(
                  l10n.historyReceiptNo(widget.item.formattedReceiptNo),
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildSyncBadge(),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : _error != null
            ? _buildError()
            : _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalClose),
        ),
        ElevatedButton.icon(
          onPressed: _handlePrint,
          icon: const Icon(Icons.print, size: 18),
          label: Text(l10n.historyPrint),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncBadge() {
    final l10n = AppLocalizations.of(context)!;
    final (color, label) = switch (widget.item.syncState) {
      HistorySyncState.synced => (AppColors.success, l10n.historySyncSynced),
      HistorySyncState.pendingSync => (
        AppColors.warning,
        l10n.historySyncPending,
      ),
      HistorySyncState.beingSent => (AppColors.info, l10n.historySyncSending),
      HistorySyncState.deferred => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        l10n.historySyncDeferred,
      ),
      HistorySyncState.inProgress => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        l10n.historySyncInProgress,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(TeleposIcons.error, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoSection(),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            l10n.historyProducts,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _buildProductsList(),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            l10n.historyPayment,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _buildPaymentsList(),
          const SizedBox(height: 16),

          _buildTotalSection(),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow(l10n.globalDate, _formatDateTime(widget.item.time)),
          const SizedBox(height: 8),
          _buildInfoRow('POS', '${widget.item.posId}'),
          if (widget.item.customerName != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(l10n.historyClient, widget.item.customerName!),
          ],
          const SizedBox(height: 8),
          _buildInfoRow(
            l10n.historyFiscalization,
            widget.item.ofdState == HistoryOfdState.fiscalized
                ? l10n.historyFiscalYes
                : widget.item.ofdState == HistoryOfdState.error
                ? l10n.historyFiscalError
                : l10n.historyFiscalNo,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildProductsList() {
    if (_products.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.semantic.canvas,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            l10n.historyNoProducts,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _products.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildProductRow(_products[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildProductRow(_ProductLine product) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.quantity} × ${product.price.toStringAsFixed(2)}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.total.toStringAsFixed(2),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              if (product.discount > Decimal.zero)
                Text(
                  '-${product.discount.toStringAsFixed(2)}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    if (_payments.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.semantic.canvas,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            l10n.historyNoPayments,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _payments.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildPaymentRow(_payments[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow(_PaymentLine payment) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            payment.isCash ? Icons.payments : Icons.credit_card,
            size: 20,
            color: payment.isCash ? AppColors.success : AppColors.info,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(payment.accountName, style: AppTextStyles.body)),
          Text(
            payment.amount.toStringAsFixed(2),
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    final l10n = AppLocalizations.of(context)!;
    final isSale = widget.item.type == HistoryItemType.sale;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSale
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.globalTotal, style: AppTextStyles.h3),
          Text(
            '${widget.item.typePrefix}${widget.item.amount.toStringAsFixed(2)}',
            style: AppTextStyles.h2.copyWith(
              color: isSale ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    final d = time.day.toString().padLeft(2, '0');
    final m = time.month.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$d.$m.${time.year} $h:$min';
  }

  Future<void> _handlePrint() async {
    final l10n = AppLocalizations.of(context)!;
    final printService = GetIt.I<ReceiptPrintService>();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.historyPrintingReceipt(widget.item.formattedReceiptNo),
        ),
        duration: const Duration(seconds: 1),
      ),
    );

    bool success;
    if (widget.item.type == HistoryItemType.sale) {
      final db = GetIt.I<AppDatabase>();
      String? tableName;
      String? zoneName;
      int? guestCount;
      String? waiterName;
      try {
        final restOrder = await db.restaurantOrderDao.findBySale(
          widget.item.receiptNo,
          widget.item.posId,
        );
        if (restOrder != null) {
          guestCount = restOrder.partySize;
          if (restOrder.tableId != null) {
            final table = await db.restaurantTableDao.findById(
              restOrder.tableId!,
            );
            if (table != null) {
              tableName = table.name;
              zoneName = table.zone;
            }
          }
          if (restOrder.waiterId != null) {
            final waiter = await db.userDao.findById(restOrder.waiterId!);
            waiterName = waiter?.name;
          }
        }
      } catch (_) {}

      final data = SaleReceiptData(
        receiptNo: widget.item.receiptNo,
        posId: widget.item.posId,
        posName: 'POS ${widget.item.posId}',
        storeName: 'TelePOS',
        dateTime: widget.item.time,
        cashierName: l10n.loginCashier,
        products: _products
            .map(
              (p) => ReceiptProductLine(
                name: p.name,
                quantity: p.quantity,
                price: p.price,
                total: p.total,
                discountAmount: p.discount,
              ),
            )
            .toList(),
        payments: _payments
            .map(
              (p) => ReceiptPaymentLine(
                name: p.accountName,
                amount: p.amount,
                isCash: p.isCash,
              ),
            )
            .toList(),
        totalAmount: widget.item.amount,
        isDuplicate: true,
        tableName: tableName,
        zoneName: zoneName,
        guestCount: guestCount,
        waiterName: waiterName,
      );
      // Задание принято — чек будет; отказ очереди — единственная неудача.
      success = !(await printService.printSaleDuplicate(data)).isRejected;
    } else {
      final data = RefundReceiptData(
        refundId: widget.item.id,
        originalReceiptNo: widget.item.receiptNo,
        posId: widget.item.posId,
        posName: 'POS ${widget.item.posId}',
        storeName: 'TelePOS',
        dateTime: widget.item.time,
        cashierName: l10n.loginCashier,
        products: _products
            .map(
              (p) => ReceiptProductLine(
                name: p.name,
                quantity: p.quantity,
                price: p.price,
                total: p.total,
              ),
            )
            .toList(),
        payments: _payments
            .map(
              (p) => ReceiptPaymentLine(
                name: p.accountName,
                amount: p.amount,
                isCash: p.isCash,
              ),
            )
            .toList(),
        totalAmount: widget.item.amount,
        isDuplicate: true,
      );
      success = !(await printService.printRefundDuplicate(data)).isRejected;
    }

    if (mounted) {
      Navigator.of(context).pop();
      final printL10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? printL10n.historyReceiptPrinted
                : printL10n.historyPrintError,
          ),
          backgroundColor: success
              ? AppColors.success
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _ProductLine {
  const _ProductLine({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    required this.discount,
  });

  final String name;
  final Decimal quantity;
  final Decimal price;
  final Decimal total;
  final Decimal discount;
}

class _PaymentLine {
  const _PaymentLine({
    required this.accountName,
    required this.amount,
    required this.isCash,
  });

  final String accountName;
  final Decimal amount;
  final bool isCash;
}

Future<void> showHistoryDetailsDialog(
  BuildContext context,
  HistoryItem item,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => HistoryDetailsDialog(item: item),
  );
}
