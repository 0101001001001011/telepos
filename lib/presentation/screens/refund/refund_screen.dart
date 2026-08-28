import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/presentation/screens/payment/receipt_data_enricher.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/presentation/screens/refund/widgets/receipt_input_dialog.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_action_buttons.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_items_list.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_items_table.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_mode_selector.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_total_panel.dart';

class RefundScreen extends ConsumerStatefulWidget {
  const RefundScreen({super.key});

  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(refundControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_refundErrorMessage(l10n, next)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 900 && screenWidth < 1200;

    if (isDesktop) {
      return _DesktopLayout(
        searchController: _searchController,
        searchFocus: _searchFocus,
        onLoadReceipt: _showReceiptDialog,
        onSearch: _focusSearch,
        onQuantity: _showQuantityDialog,
        onRefund: _handleRefund,
      );
    }

    if (isTablet) {
      return _TabletLayout(
        searchController: _searchController,
        searchFocus: _searchFocus,
        onLoadReceipt: _showReceiptDialog,
        onSearch: _focusSearch,
        onQuantity: _showQuantityDialog,
        onRefund: _handleRefund,
      );
    }

    return _MobileLayout(
      searchController: _searchController,
      searchFocus: _searchFocus,
      onLoadReceipt: _showReceiptDialog,
      onRefund: _handleRefund,
    );
  }

  String _refundErrorMessage(AppLocalizations l10n, String error) {
    final code = error.split(':').first;
    switch (code) {
      case 'error.receipt_not_found':
        return l10n.refundReceiptNotFound;
      case 'error.not_authorized':
        return l10n.refundErrorNotAuthenticated;
      default:
        return l10n.globalError;
    }
  }

  void _showReceiptDialog() async {
    final db = GetIt.I<AppDatabase>();
    final thisPos = await db.thisPosDao.get();
    final posId = thisPos?.id ?? 1;
    final posName = thisPos?.cashBoxName ?? 'POS-$posId';

    if (!mounted) return;

    final result = await ReceiptInputDialog.show(
      context,
      availablePosIds: [posId],
      posNames: {posId: posName},
    );

    if (result != null) {
      ref
          .read(refundControllerProvider.notifier)
          .loadReceipt(result.receiptNo, result.posId);
    }
  }

  void _focusSearch() {
    final notifier = ref.read(refundControllerProvider.notifier);
    if (ref.read(refundControllerProvider).mode != RefundMode.withoutReceipt) {
      notifier.setMode(RefundMode.withoutReceipt);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _showQuantityDialog() {
    final state = ref.read(refundControllerProvider);
    if (state.selectedItem == null) return;

    final item = state.selectedItem!;
    final controller = TextEditingController(text: '${item.quantity}');

    showDialog(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl10n.globalQuantity),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: AppTextStyles.productName),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                dl10n.refundMaxQuantity('${item.maxQuantity}'),
                style: context.styles.caption,
              ),
              const SizedBox(height: AppTheme.spacing),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: dl10n.globalQuantity,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                ),
                onSubmitted: (value) {
                  _submitQuantity(item.id, value);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () {
                _submitQuantity(item.id, controller.text);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.black,
              ),
              child: Text(dl10n.globalOk),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  void _submitQuantity(String itemId, String value) {
    final quantity = Decimal.tryParse(value);
    if (quantity != null) {
      ref
          .read(refundControllerProvider.notifier)
          .updateQuantity(itemId, quantity);
    }
  }

  void _handleRefund() async {
    final state = ref.read(refundControllerProvider);
    if (!state.canRefund) return;

    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl10n.refundConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dl10n.refundSelectedCount('${state.selectedCount}')),
              const SizedBox(height: 8),
              Text(
                dl10n.refundAmountValue('${state.selectedTotal}'),
                style: AppTextStyles.h3.copyWith(color: AppColors.warning),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.black,
              ),
              child: Text(dl10n.globalConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final refundState = ref.read(refundControllerProvider);

      final success = await ref
          .read(refundControllerProvider.notifier)
          .processRefund();

      if (success && mounted) {
        await _printRefundReceipt(refundState);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.refundSuccess),
              backgroundColor: AppColors.success,
            ),
          );
          ref.read(refundControllerProvider.notifier).clear();
        }
      }
    }
  }

  Future<void> _printRefundReceipt(RefundState refundState) async {
    try {
      if (!GetIt.I.isRegistered<ReceiptPrintService>()) return;
      final printService = GetIt.I<ReceiptPrintService>();

      final db = GetIt.I<AppDatabase>();
      final thisPos = await db.thisPosDao.get();
      final shift = await db.shiftDao.findOpenedShift();

      String cashierName = 'Cashier';
      if (shift != null) {
        final users = await (db.select(
          db.users,
        )..where((u) => u.id.equals(shift.userId))).get();
        if (users.isNotEmpty) {
          cashierName = users.first.name ?? 'Cashier';
        }
      }

      final selectedItems = refundState.items
          .where((i) => i.isSelected)
          .toList();
      final products = selectedItems.map((item) {
        return ReceiptProductLine(
          name: item.name,
          quantity: item.quantity,
          price: item.price,
          total: item.total,
        );
      }).toList();

      final payments = await _buildRefundPaymentLines(db, refundState);

      final req = await buildReceiptRequisites(
        db,
        posId: thisPos?.id,
        operationId: refundState.receiptInfo?.receiptNo,
        isSale: false,
      );

      final receiptData = RefundReceiptData(
        refundId: 0,
        originalReceiptNo: refundState.receiptInfo?.receiptNo,
        posId: thisPos?.id ?? 1,
        posName: thisPos?.cashBoxName ?? 'POS',
        storeName: thisPos?.companyName ?? '',
        dateTime: DateTime.now(),
        cashierName: cashierName,
        products: products,
        payments: payments,
        totalAmount: refundState.selectedTotal,
        seller: req.seller,
        fiscal: req.fiscal,
        isVatPayer: req.isVatPayer,
        vatAmount: req.vatFromGross(refundState.selectedTotal),
        vatRatePercent: req.vatRatePercent,
        currencySymbol: req.currencySymbol,
      );

      // Сдача в очередь: недоступный принтер оставляет задание в хранилище, а
      // не теряет чек возврата вместе с локальными переменными.
      final outcome = await printService.printRefundReceipt(receiptData);
      if (outcome.isRejected) {
        talker.warning(
          'Чек возврата не принят в очередь печати: ${outcome.message}',
        );
      }
    } catch (e, stack) {
      talker.warning(
        'Refund receipt print failed (non-blocking): $e',
        e,
        stack,
      );
    }
  }

  Future<List<ReceiptPaymentLine>> _buildRefundPaymentLines(
    AppDatabase db,
    RefundState refundState,
  ) async {
    final refundTotal = refundState.selectedTotal;
    final receiptInfo = refundState.receiptInfo;

    if (receiptInfo == null) {
      return [
        ReceiptPaymentLine(name: 'Cash', amount: refundTotal, isCash: true),
      ];
    }

    try {
      final salePayments = await db.paymentDao.findBySale(
        receiptInfo.receiptNo,
        receiptInfo.posId,
      );

      if (salePayments.isEmpty) {
        return [
          ReceiptPaymentLine(name: 'Cash', amount: refundTotal, isCash: true),
        ];
      }

      final saleTotal = salePayments.fold<Decimal>(
        Decimal.zero,
        (sum, p) => sum + p.amount,
      );

      final lines = <ReceiptPaymentLine>[];
      var remaining = refundTotal;

      for (var i = 0; i < salePayments.length; i++) {
        final payment = salePayments[i];
        final isLast = i == salePayments.length - 1;

        Decimal lineAmount;
        if (isLast) {
          lineAmount = remaining;
        } else if (saleTotal > Decimal.zero) {
          final ratio = (payment.amount / saleTotal).toDecimal(
            scaleOnInfinitePrecision: 10,
          );
          lineAmount = (refundTotal * ratio).truncate(scale: 3);
          if (lineAmount > remaining) lineAmount = remaining;
        } else {
          lineAmount = Decimal.zero;
        }

        if (lineAmount <= Decimal.zero) continue;

        final account = await db.accountDao.findById(payment.payeeAccountId);
        final isCash =
            account == null || account.type == 0 || account.type == 2;
        final name = account?.name ?? (isCash ? 'Cash' : 'Card');

        lines.add(
          ReceiptPaymentLine(name: name, amount: lineAmount, isCash: isCash),
        );
        remaining -= lineAmount;
      }

      if (lines.isEmpty) {
        return [
          ReceiptPaymentLine(name: 'Cash', amount: refundTotal, isCash: true),
        ];
      }
      return lines;
    } catch (e) {
      talker.warning('Refund payment-line build failed, using cash: $e');
      return [
        ReceiptPaymentLine(name: 'Cash', amount: refundTotal, isCash: true),
      ];
    }
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({
    required this.searchController,
    required this.searchFocus,
    required this.onLoadReceipt,
    required this.onSearch,
    required this.onQuantity,
    required this.onRefund,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onLoadReceipt;
  final VoidCallback onSearch;
  final VoidCallback onQuantity;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundControllerProvider);
    final isWithoutReceipt = state.mode == RefundMode.withoutReceipt;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                const RefundModeSelector(),
                const SizedBox(height: AppTheme.spacing),

                if (isWithoutReceipt) ...[
                  _SearchField(
                    controller: searchController,
                    focusNode: searchFocus,
                    onSearch: (query) {
                      ref.read(refundControllerProvider.notifier).search(query);
                    },
                    onSelect: (result) {
                      ref
                          .read(refundControllerProvider.notifier)
                          .addProduct(result);
                      searchController.clear();
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing),
                ],

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const RefundItemsTable(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing),

          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: RefundActionButtons(
                    onLoadReceipt: onLoadReceipt,
                    onSearch: onSearch,
                    onQuantity: onQuantity,
                    onRefund: onRefund,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing),

                const RefundTotalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({
    required this.searchController,
    required this.searchFocus,
    required this.onLoadReceipt,
    required this.onSearch,
    required this.onQuantity,
    required this.onRefund,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onLoadReceipt;
  final VoidCallback onSearch;
  final VoidCallback onQuantity;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundControllerProvider);
    final isWithoutReceipt = state.mode == RefundMode.withoutReceipt;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 65,
            child: Column(
              children: [
                const RefundModeSelector(),
                const SizedBox(height: AppTheme.spacing),

                if (isWithoutReceipt) ...[
                  _SearchField(
                    controller: searchController,
                    focusNode: searchFocus,
                    onSearch: (query) {
                      ref.read(refundControllerProvider.notifier).search(query);
                    },
                    onSelect: (result) {
                      ref
                          .read(refundControllerProvider.notifier)
                          .addProduct(result);
                      searchController.clear();
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing),
                ],

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadius,
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const RefundItemsTable(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing),

          Expanded(
            flex: 35,
            child: Column(
              children: [
                const RefundTotalPanel(),
                const SizedBox(height: AppTheme.spacing),

                Expanded(
                  child: RefundActionButtons(
                    onLoadReceipt: onLoadReceipt,
                    onSearch: onSearch,
                    onQuantity: onQuantity,
                    onRefund: onRefund,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({
    required this.searchController,
    required this.searchFocus,
    required this.onLoadReceipt,
    required this.onRefund,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onLoadReceipt;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(refundControllerProvider);
    final isWithoutReceipt = state.mode == RefundMode.withoutReceipt;
    final isByReceipt = state.mode == RefundMode.byReceipt;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing),
          child: Column(
            children: [
              const RefundModeSelector(),
              const SizedBox(height: AppTheme.spacing),

              if (isByReceipt)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onLoadReceipt,
                    icon: const Icon(Icons.receipt_long),
                    label: Text(l10n.refundLoadReceipt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: AppColors.black,
                    ),
                  ),
                ),

              if (isWithoutReceipt)
                _SearchField(
                  controller: searchController,
                  focusNode: searchFocus,
                  onSearch: (query) {
                    ref.read(refundControllerProvider.notifier).search(query);
                  },
                  onSelect: (result) {
                    ref
                        .read(refundControllerProvider.notifier)
                        .addProduct(result);
                    searchController.clear();
                  },
                ),
            ],
          ),
        ),

        const Expanded(child: RefundItemsList()),

        RefundTotalPanel(compact: true, onRefund: onRefund),
      ],
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({
    required this.controller,
    required this.onSearch,
    required this.onSelect,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final void Function(String) onSearch;
  final void Function(RefundSearchResult) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(refundControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: l10n.refundSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(TeleposIcons.close),
                    onPressed: () {
                      controller.clear();
                      onSearch('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
          ),
          onChanged: onSearch,
        ),

        if (state.isSearching)
          const Padding(
            padding: EdgeInsets.all(AppTheme.spacing),
            child: CircularProgressIndicator(),
          )
        else if (state.searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: state.searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = state.searchResults[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                  title: Text(result.name),
                  subtitle: result.barcode != null
                      ? Text(result.barcode!)
                      : null,
                  trailing: Text(
                    '${result.price}',
                    style: AppTextStyles.priceItem,
                  ),
                  onTap: () => onSelect(result),
                );
              },
            ),
          ),
      ],
    );
  }
}
