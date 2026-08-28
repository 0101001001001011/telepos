import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/presentation/screens/payment/receipt_data_enricher.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/widgets/account_selector.dart';
import 'package:telepos/presentation/screens/payment/widgets/denomination_grid.dart';
import 'package:telepos/presentation/screens/payment/widgets/iin_input.dart';
import 'package:telepos/presentation/screens/payment/widgets/loyalty_panel.dart';
import 'package:telepos/presentation/screens/payment/widgets/payment_amount_panel.dart';
import 'package:telepos/presentation/common/widgets/keyboards/payment_num_pad.dart';
import 'package:telepos/presentation/screens/payment/widgets/payment_type_selector.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({this.amount, this.isRefund = false, super.key});

  final Decimal? amount;

  final bool isRefund;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Decimal amount = widget.amount ?? ref.read(saleTotalProvider);
      ref.read(paymentControllerProvider.notifier).initialize(amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    ref.listen<PaymentState>(paymentControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    if (isDesktop) {
      return _DesktopLayout(
        isRefund: widget.isRefund,
        onComplete: _handleComplete,
        onCancel: _handleCancel,
      );
    }

    if (isTablet) {
      return _TabletLayout(
        isRefund: widget.isRefund,
        onComplete: _handleComplete,
        onCancel: _handleCancel,
      );
    }

    return _MobileLayout(
      isRefund: widget.isRefund,
      onComplete: _handleComplete,
      onCancel: _handleCancel,
    );
  }

  Future<void> _handleComplete() async {
    final notifier = ref.read(paymentControllerProvider.notifier);
    final preState = ref.read(paymentControllerProvider);

    if (preState.isProcessing) return;
    var popped = false;
    try {
      await _handleCompleteInner(notifier, preState, () => popped = true);
    } finally {
      if (!popped && mounted) notifier.setProcessing(false);
    }
  }

  Future<void> _handleCompleteInner(
    PaymentNotifier notifier,
    PaymentState preState,
    void Function() markPopped,
  ) async {
    if (!widget.isRefund && preState.paymentType == PaymentType.card) {
      final terminalResult = await notifier.chargeCardViaTerminal(
        preState.amountToPay,
      );

      if (terminalResult.isDeclined) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                terminalResult.message ??
                    AppLocalizations.of(context)!.kaspiNoConnection,
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
    }

    final paymentState = ref.read(paymentControllerProvider);
    final success = await notifier.processPayment();

    if (success && mounted) {
      notifier.setProcessing(true);
      await _onPaymentRecorded(paymentState);
      markPopped();
    }
  }

  Future<void> _onPaymentRecorded(PaymentState paymentState) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (!widget.isRefund) {
      // Deliberately not awaited. The money is already recorded; a receipt that
      // did not print is a reprint, not a lost sale, and making the cashier
      // wait on a printer that may be absent or busy is what this used to do.
      // The synchronous prefix of _printSaleReceipt captures the sale state
      // before the navigation below tears this screen down.
      unawaited(
        _printSaleReceipt(
          paymentState,
          ScaffoldMessenger.of(context),
          l10n.printerPrintError,
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isRefund ? l10n.refundSuccess : l10n.paymentSuccessMessage,
          ),
          backgroundColor: AppColors.success,
        ),
      );

      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(AppRoutes.sale);
      }
    }
  }

  Future<void> _printSaleReceipt(
    PaymentState paymentState,
    ScaffoldMessengerState messenger,
    String printErrorText,
  ) async {
    try {
      if (!GetIt.I.isRegistered<ReceiptPrintService>()) return;
      final printService = GetIt.I<ReceiptPrintService>();

      final saleState = ref.read(saleControllerProvider);
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

      final products = saleState.items.map((item) {
        return ReceiptProductLine(
          name: item.name,
          quantity: item.quantity,
          price: item.price,
          total: item.total,
          discountAmount: item.discount,
          originalPrice: item.discount > Decimal.zero ? item.price : null,
        );
      }).toList();

      final payments = <ReceiptPaymentLine>[];
      final isCashPayment = paymentState.paymentType == PaymentType.cash;
      final isMixed = paymentState.paymentType == PaymentType.mixed;

      if (isCashPayment) {
        payments.add(
          ReceiptPaymentLine(
            name: 'Cash',
            amount: paymentState.amountToPay,
            isCash: true,
          ),
        );
      } else if (paymentState.paymentType == PaymentType.card) {
        final cardLabel = paymentState.terminalCardMask != null
            ? 'Card ${paymentState.terminalCardMask}'
            : 'Card';
        payments.add(
          ReceiptPaymentLine(
            name: cardLabel,
            amount: paymentState.amountToPay,
            isCash: false,
          ),
        );
      } else if (isMixed) {
        final cashPortion = paymentState.amountToPay - paymentState.cardAmount;
        if (cashPortion > Decimal.zero) {
          payments.add(
            ReceiptPaymentLine(name: 'Cash', amount: cashPortion, isCash: true),
          );
        }
        if (paymentState.cardAmount > Decimal.zero) {
          payments.add(
            ReceiptPaymentLine(
              name: 'Card',
              amount: paymentState.cardAmount,
              isCash: false,
            ),
          );
        }
      }

      final req = await buildReceiptRequisites(
        db,
        posId: saleState.posId ?? thisPos?.id,
        operationId: saleState.receiptNo,
        isSale: true,
      );

      final receiptData = SaleReceiptData(
        receiptNo: saleState.receiptNo ?? 0,
        posId: saleState.posId ?? thisPos?.id ?? 1,
        posName: thisPos?.cashBoxName ?? 'POS',
        storeName: thisPos?.companyName ?? '',
        dateTime: DateTime.now(),
        cashierName: cashierName,
        products: products,
        payments: payments,
        totalAmount: saleState.total,
        change: paymentState.change > Decimal.zero ? paymentState.change : null,
        customerName: paymentState.loyaltyCustomer?.name,
        seller: req.seller,
        fiscal: req.fiscal,
        isVatPayer: req.isVatPayer,
        vatAmount: req.vatFromGross(saleState.total),
        vatRatePercent: req.vatRatePercent,
        currencySymbol: req.currencySymbol,
      );

      // Сдача в очередь, а не запись в принтер. «Принято» здесь означает, что
      // чек будет напечатан, когда принтер сможет, — и что при недоступном
      // принтере он **остался заданием в хранилище**, а не исчез вместе с
      // локальными переменными этой функции, как было до очереди. Предупреждать
      // оператора надо только об отказе принять задание: снимок «бумаги нет
      // прямо сейчас» — это уже не отказ.
      final outcome = await printService.printSaleReceipt(receiptData);
      if (outcome.isRejected) {
        talker.warning('Чек не принят в очередь печати: ${outcome.message}');
        messenger.showSnackBar(
          SnackBar(
            content: Text(printErrorText),
            backgroundColor: AppColors.warning,
          ),
        );
      }

      final hasCash = isCashPayment || isMixed;
      if (hasCash) {
        await _openCashDrawer(printService);
      }
    } catch (e, stack) {
      talker.warning('Receipt print failed (non-blocking): $e', e, stack);
      // The sale succeeded, so this must not look like a failed payment — but
      // it must not be invisible either, or the cashier hands over goods
      // believing a receipt was produced.
      messenger.showSnackBar(
        SnackBar(
          content: Text(printErrorText),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _openCashDrawer(ReceiptPrintService printService) async {
    try {
      if (GetIt.I.isRegistered<CashDrawerService>()) {
        final drawer = GetIt.I<CashDrawerService>();
        if (drawer.mode == CashDrawerMode.serialPort) {
          final result = await drawer.open();
          if (result.success) return;
          talker.warning(
            'Cash drawer serial open failed, falling back to printer: '
            '${result.errorMessage}',
          );
        }
      }
    } catch (e, stack) {
      talker.warning('Cash drawer service error (non-blocking): $e', e, stack);
    }
    await printService.openCashDrawer();
  }

  void _handleCancel() {
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go(AppRoutes.sale);
    }
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({
    required this.isRefund,
    required this.onComplete,
    required this.onCancel,
  });

  final bool isRefund;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

    final screenSize = MediaQuery.sizeOf(context);
    final screenH = screenSize.height;
    final cardMaxH = screenH >= 900
        ? (screenH - 48 > 920 ? 920.0 : screenH - 48)
        : math.min(768.0, screenH - 32);
    final cardWidth = math.min(780.0, screenSize.width - 48);

    return Scaffold(
      backgroundColor: AppColors.modalOverlay,
      body: Center(
        child: Container(
          width: cardWidth,
          constraints: BoxConstraints(maxHeight: cardMaxH),
          margin: const EdgeInsets.all(AppTheme.spacingLarge),
          decoration: BoxDecoration(
            color: context.semantic.canvas,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _Header(
                title: isRefund ? l10n.refundTitle : l10n.paymentTitle,
                amount: state.totalAmount,
                color: isRefund ? AppColors.warning : AppColors.primary,
                onClose: onCancel,
              ),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing),
                        child: Column(
                          children: [
                            const PaymentTypeSelector(),
                            const SizedBox(height: AppTheme.spacing),
                            const PaymentAmountPanel(),
                            const SizedBox(height: AppTheme.spacing),
                            if (state.paymentType != PaymentType.card)
                              const Expanded(child: _PaymentInputTabs())
                            else
                              const Spacer(),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.spacing),
                        child: Column(
                          children: [
                            const AccountSelector(),
                            const SizedBox(height: AppTheme.spacing),
                            const LoyaltyPanel(),
                            const SizedBox(height: AppTheme.spacing),
                            const IinInput(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _Footer(
                canComplete: state.canComplete,
                isProcessing: state.isProcessing,
                isRefund: isRefund,
                onComplete: onComplete,
                onCancel: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletLayout extends ConsumerWidget {
  const _TabletLayout({
    required this.isRefund,
    required this.onComplete,
    required this.onCancel,
  });

  final bool isRefund;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isRefund ? l10n.refundTitle : l10n.paymentTitle),
        backgroundColor: isRefund ? AppColors.warning : AppColors.primary,
        foregroundColor: isRefund ? AppColors.black : AppColors.white,
        leading: IconButton(
          icon: const Icon(TeleposIcons.close),
          onPressed: onCancel,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing),
            child: Center(
              child: Text(
                '${state.totalAmount}',
                style: AppTextStyles.h2.copyWith(
                  color: isRefund ? AppColors.black : AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing),
              child: Column(
                children: [
                  const PaymentTypeSelector(),
                  const SizedBox(height: AppTheme.spacing),
                  const PaymentAmountPanel(),
                  const SizedBox(height: AppTheme.spacing),
                  if (state.paymentType != PaymentType.card)
                    const Expanded(child: _PaymentInputTabs())
                  else
                    const Spacer(),
                ],
              ),
            ),
          ),

          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing),
              child: Column(
                children: [
                  const AccountSelector(),
                  const SizedBox(height: AppTheme.spacing),
                  const LoyaltyPanel(),
                  const SizedBox(height: AppTheme.spacing),
                  const IinInput(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _Footer(
        canComplete: state.canComplete,
        isProcessing: state.isProcessing,
        isRefund: isRefund,
        onComplete: onComplete,
        onCancel: onCancel,
      ),
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({
    required this.isRefund,
    required this.onComplete,
    required this.onCancel,
  });

  final bool isRefund;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isRefund ? l10n.refundTitle : l10n.paymentTitle),
            Text(
              '${state.totalAmount}',
              style: context.styles.caption.copyWith(
                color: isRefund
                    ? AppColors.black.withValues(alpha: 0.7)
                    : AppColors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        backgroundColor: isRefund ? AppColors.warning : AppColors.primary,
        foregroundColor: isRefund ? AppColors.black : AppColors.white,
        leading: IconButton(
          icon: const Icon(TeleposIcons.close),
          onPressed: onCancel,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          children: [
            const PaymentTypeSelector(),
            const SizedBox(height: AppTheme.spacing),
            const PaymentAmountPanel(),
            const SizedBox(height: AppTheme.spacing),
            const DenominationRow(),
            const SizedBox(height: AppTheme.spacing),
            const AccountSelector(),
            const SizedBox(height: AppTheme.spacing),
            const LoyaltyPanelCompact(),
            const SizedBox(height: AppTheme.spacing),
            const IinInputCompact(),
            if (state.paymentType != PaymentType.card) ...[
              const SizedBox(height: AppTheme.spacing),
              const _PaymentNumPadSection(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _FooterCompact(
        canComplete: state.canComplete,
        isProcessing: state.isProcessing,
        change: state.change,
        isRefund: isRefund,
        onComplete: onComplete,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.amount,
    required this.color,
    required this.onClose,
  });

  final String title;
  final Decimal amount;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.borderRadiusLarge),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(TeleposIcons.close),
            color: AppColors.white,
          ),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.h2.copyWith(color: AppColors.white)),
          const Spacer(),
          Text(
            '$amount',
            style: AppTextStyles.h1.copyWith(color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.canComplete,
    required this.isProcessing,
    required this.isRefund,
    required this.onComplete,
    required this.onCancel,
  });

  final bool canComplete;
  final bool isProcessing;
  final bool isRefund;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.borderRadiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isProcessing ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing),
              ),
              child: Text(l10n.globalCancel),
            ),
          ),
          const SizedBox(width: AppTheme.spacing),

          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canComplete && !isProcessing ? onComplete : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRefund
                    ? AppColors.warning
                    : AppColors.success,
                foregroundColor: isRefund ? AppColors.black : AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing),
                disabledBackgroundColor: context.semantic.canvas,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isRefund
                          ? l10n.paymentRefundButton
                          : l10n.paymentPayButton,
                      style: AppTextStyles.h3.copyWith(
                        color: isRefund ? AppColors.black : AppColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentInputTabs extends StatelessWidget {
  const _PaymentInputTabs();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(l10n.paymentDenominations),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dialpad, size: 18),
                      const SizedBox(width: 6),
                      Text(l10n.paymentNumpad),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          const Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(child: DenominationGrid()),
                SingleChildScrollView(child: _PaymentNumPadSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentNumPadSection extends ConsumerWidget {
  const _PaymentNumPadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeInput = ref.watch(
      paymentControllerProvider.select((s) => s.activeInput),
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dialpad,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(l10n.paymentNumpad, style: AppTextStyles.h3),
              const Spacer(),
              Text(
                activeInput == PaymentInputField.cash
                    ? l10n.paymentTypeCash
                    : l10n.paymentTypeCard,
                style: context.styles.caption.copyWith(
                  color: activeInput == PaymentInputField.cash
                      ? AppColors.paymentCash
                      : AppColors.paymentCard,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),
          Center(
            child: CompactPaymentNumPad(
              onKeyPressed: (key) =>
                  ref.read(paymentControllerProvider.notifier).numpadKey(key),
              onBackspace: () => ref
                  .read(paymentControllerProvider.notifier)
                  .numpadBackspace(),
              onClear: () =>
                  ref.read(paymentControllerProvider.notifier).numpadClear(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterCompact extends StatelessWidget {
  const _FooterCompact({
    required this.canComplete,
    required this.isProcessing,
    required this.change,
    required this.isRefund,
    required this.onComplete,
  });

  final bool canComplete;
  final bool isProcessing;
  final Decimal change;
  final bool isRefund;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            if (change > Decimal.zero)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.paymentChangeLabel}:',
                      style: context.styles.caption,
                    ),
                    Text(
                      '$change',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              flex: change > Decimal.zero ? 1 : 2,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: canComplete && !isProcessing ? onComplete : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRefund
                        ? AppColors.warning
                        : AppColors.success,
                    foregroundColor: isRefund
                        ? AppColors.black
                        : AppColors.white,
                    disabledBackgroundColor: context.semantic.canvas,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isRefund
                              ? l10n.paymentRefundButton
                              : l10n.paymentPayButton,
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
