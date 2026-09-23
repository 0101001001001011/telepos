import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/presentation/controllers/agent/customer_payment_controller.dart';
import 'package:telepos/presentation/controllers/agent/supplier_payment_controller.dart';
import 'package:telepos/presentation/dialogs/record_customer_payment_dialog.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/presentation/dialogs/record_supplier_payment_dialog.dart';
import 'package:telepos/core/locale/till_conventions.dart';

class AgentDetailsDialog extends ConsumerStatefulWidget {
  const AgentDetailsDialog({super.key, required this.agent, this.onSelect});

  final AgentItem agent;
  final void Function(AgentItem)? onSelect;

  @override
  ConsumerState<AgentDetailsDialog> createState() => _AgentDetailsDialogState();
}

class _AgentDetailsDialogState extends ConsumerState<AgentDetailsDialog> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth > 600 ? 450.0 : screenWidth * 0.9;
    final hasDebt = widget.agent.hasDebt;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: hasDebt
                ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              widget.agent.name.isNotEmpty
                  ? widget.agent.name[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: hasDebt
                    ? Theme.of(context).colorScheme.error
                    : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.agent.name, style: AppTextStyles.h3),
                if (widget.agent.phone != null)
                  Text(
                    widget.agent.formattedPhone,
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(),
              const SizedBox(height: 16),

              _buildBalanceSection(),
              const SizedBox(height: 16),

              _buildRecordPaymentButton(),
              const SizedBox(height: 16),

              _buildRefundPrepaymentButton(),

              _buildCreditContractsButton(),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        TeleposIcons.error,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
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
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _handleDelete,
          child: Text(
            l10n.globalDelete,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalClose),
        ),
        if (widget.onSelect != null)
          ElevatedButton(
            onPressed: () {
              widget.onSelect!(widget.agent);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            child: Text(l10n.globalSelect),
          ),
      ],
    );
  }

  Widget _buildInfoSection() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (widget.agent.phone != null)
            _buildInfoRow(
              Icons.phone,
              l10n.agentPhone,
              widget.agent.formattedPhone,
            ),

          if (widget.agent.bin != null) ...[
            if (widget.agent.phone != null) const SizedBox(height: 12),
            _buildInfoRow(Icons.badge, l10n.agentBinIin, widget.agent.bin!),
          ],

          if (widget.agent.lastOperationDate != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              l10n.agentLastOperation,
              _formatDate(widget.agent.lastOperationDate!),
            ),
          ],

          if (widget.agent.phone == null && widget.agent.bin == null)
            Text(
              l10n.agentNoAdditionalInfo,
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceSection() {
    final l10n = AppLocalizations.of(context)!;
    final hasDebt = widget.agent.hasDebt;
    final balance = widget.agent.balance;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasDebt
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasDebt
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.agentBalance,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasDebt ? l10n.agentDebt : l10n.agentNoDebt,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: hasDebt
                      ? Theme.of(context).colorScheme.error
                      : AppColors.success,
                ),
              ),
            ],
          ),
          Text(
            balance.toStringAsFixed(2),
            style: AppTextStyles.h2.copyWith(
              color: hasDebt
                  ? Theme.of(context).colorScheme.error
                  : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  /// Договоры рассрочки покупателя — задача 24.
  ///
  /// # Почему кнопка стоит здесь, а не в «Ещё»
  ///
  /// Погашение начинается с человека: покупатель приносит деньги и
  /// называет себя, а не номер договора. Кассир уже нашёл его в
  /// картотеке, чтобы посмотреть долг, — договор лежит рядом с тем же
  /// долгом и на том же счёте.
  ///
  /// # Кнопка ПОКАЗЫВАЕТСЯ и без права
  ///
  /// Право `op.creditRepay` проверяет **экран договоров** и сама служба;
  /// спрятанная кнопка запретом не является (I162), а исчезнувшая
  /// оставляет кассира с вопросом «куда делись рассрочки» и без единого
  /// способа на него ответить. Кнопки нет только у поставщика: рассрочку
  /// продают покупателю.
  Widget _buildCreditContractsButton() {
    if (widget.agent.type == AgentType.supplier) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('agent_credit_contracts_button'),
          // Через маршрутизатор, а не `MaterialPageRoute`: право
          // `op.creditRepay` проверяет `redirect` по карте маршрутов, и
          // экран, вытолкнутый мимо таблицы, прошёл бы мимо проверки.
          onPressed: () => context.push(
            Uri(
              path: AppRoutes.creditContracts,
              queryParameters: {
                'agentId': '${widget.agent.localId}',
                'agentName': widget.agent.name,
              },
            ).toString(),
          ),
          icon: const Icon(Icons.event_repeat_outlined, size: 18),
          label: Text(AppLocalizations.of(context)!.creditContractsTitle),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  /// «Выдать аванс» — дыра 2 ревизии 2026-09-19, **соседняя с приёмом**.
  ///
  /// Кнопка стоит ровно под «Принять оплату / погасить долг» и намеренно:
  /// приём и выдача — одна работа двумя сторонами, и искать их в разных
  /// местах кассиру незачем. Под обеими один контроллер и один юзкейс.
  ///
  /// # Почему переход, а не диалог
  ///
  /// Право `op.creditRepay` на кассе проверяет `redirect` по карте
  /// маршрутов; у `showDialog` такой проверки нет вовсе (I162), а выдача
  /// выпускает деньги из кассы и уменьшает расчётный счёт покупателя.
  /// Экран сверх того спрашивает право перед вызовом.
  ///
  /// Кнопка **не прячется** и у покупателя без аванса: пропавшая оставила
  /// бы кассира с вопросом «куда делась выдача» и без ответа, а остаток
  /// экран показывает словами в первой же строке. Нет её только у
  /// поставщика: аванс вносит покупатель.
  Widget _buildRefundPrepaymentButton() {
    if (widget.agent.type == AgentType.supplier) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('agent_refund_prepayment_button'),
          onPressed: () => context.push(
            Uri(
              path: AppRoutes.prepaymentRefund,
              queryParameters: {
                'agentId': '${widget.agent.localId}',
                'agentName': widget.agent.name,
              },
            ).toString(),
          ),
          icon: const Icon(Icons.undo, size: 18),
          label: Text(l10n.agentRefundPrepayment),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordPaymentButton() {
    final l10n = AppLocalizations.of(context)!;
    final isSupplier = widget.agent.type == AgentType.supplier;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading
            ? null
            : (isSupplier ? _handleSupplierPayment : _handleRecordPayment),
        icon: const Icon(Icons.payments, size: 18),
        label: Text(
          isSupplier ? l10n.supplierRepayTitle : l10n.customerPaymentTitle,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Future<void> _handleRecordPayment() async {
    final outcome = await showDialog<CustomerPaymentOutcome>(
      context: context,
      builder: (_) => RecordCustomerPaymentDialog(
        agentId: widget.agent.localId,
        agentName: widget.agent.name,
        currentBalance: widget.agent.balance,
      ),
    );

    if (outcome == null || !outcome.success) return;
    if (!mounted) return;

    final currentQuery = ref.read(agentSearchProvider).searchQuery;
    ref.read(agentSearchProvider.notifier).search(currentQuery);

    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.agentPaymentAccepted),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleSupplierPayment() async {
    final l10n = AppLocalizations.of(context)!;
    final outcome = await showDialog<SupplierPaymentOutcome>(
      context: context,
      builder: (_) => RecordSupplierPaymentDialog(
        supplierId: widget.agent.localId,
        supplierName: widget.agent.name,
        currentBalance: widget.agent.balance,
      ),
    );

    if (outcome == null || !outcome.success) return;
    if (!mounted) return;

    final currentQuery = ref.read(agentSearchProvider).searchQuery;
    ref.read(agentSearchProvider.notifier).search(currentQuery);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.supplierRepayDone),
        backgroundColor: AppColors.success,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return TillConventions.current.formatDate(date);
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl10n.agentDeleteQuestion),
          content: Text(dl10n.agentDeleteConfirmMsg(widget.agent.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dl10n.globalCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: AppColors.white,
              ),
              child: Text(dl10n.globalDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = GetIt.I<AppDatabase>();
      await db.agentDao.softDelete(widget.agent.localId);

      final currentQuery = ref.read(agentSearchProvider).searchQuery;
      ref.read(agentSearchProvider.notifier).search(currentQuery);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.agentDeletedWithName(widget.agent.name)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = l10n.agentDeleteError(e.toString());
        _isLoading = false;
      });
    }
  }
}

Future<void> showAgentDetailsDialog(
  BuildContext context,
  AgentItem agent, {
  void Function(AgentItem)? onSelect,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AgentDetailsDialog(agent: agent, onSelect: onSelect),
  );
}
