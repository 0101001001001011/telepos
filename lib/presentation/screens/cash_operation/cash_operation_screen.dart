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
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_operation_receipt_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/screens/cash_operation/widgets/cash_operation_form.dart';
import 'package:telepos/presentation/screens/cash_operation/widgets/numpad_widget.dart';

/// Сдаёт квитанцию в очередь печати и **не ждёт бумаги** (И30).
///
/// Раньше здесь стояло `await`: деньги уже записаны, движение проведено, а
/// оператор стоит и смотрит на экран, который не закрывается, потому что
/// принтера нет в сети. Этот же дефект проект однажды уже чинил на пути оплаты
/// — там печать давно **отправляется**, а не ожидается. Сдача в очередь быстра
/// и на железе не блокируется вовсе, так что ждать её незачем: недоступный
/// принтер оставляет квитанцию заданием, которое переживёт и перезапуск
/// программы.
///
/// [messenger], [failureLabel] и [failureColor] снимаются вызывающим **до**
/// первого `await`: экран к моменту ответа очереди уже закрыт, и `context`
/// мёртв, а сообщить об отказе всё равно нужно — молчание здесь и было бы той
/// самой потерянной квитанцией, только теперь ещё и незаметной.
///
/// Цвет — доводом, а не константой, и по той же причине, что и остальные два.
/// Соблазн был обратный: «контекста нет, значит здесь роль темы недоступна» —
/// и на этом месте `AppColors.error` уже однажды вернули. Но недоступен
/// контекст, а не тема: цвет снимается там же, где `messenger`, то есть пока
/// контекст ещё жив. Иначе тёмная тема получила бы дневной красный.
void _dispatchCashOperationReceipt(
  int operationId,
  ScaffoldMessengerState messenger,
  String failureLabel,
  Color failureColor,
) {
  unawaited(() async {
    String? failure;
    try {
      final outcome = await GetIt.I<CashOperationReceiptService>().printReceipt(
        operationId,
      );
      // `duplicate` — тоже успех: квитанция уже стоит в очереди, второй бумаги
      // не будет и не должно быть.
      if (!outcome.isRejected) return;
      failure = outcome.message;
    } catch (e) {
      // Служба печати не зарегистрирована или упала. Это не повод отменить
      // проведённую операцию, но и не повод промолчать.
      failure = '$e';
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('$failureLabel: $failure'),
        backgroundColor: failureColor,
      ),
    );
  }());
}

class CashOperationScreen extends ConsumerStatefulWidget {
  const CashOperationScreen({super.key});

  static Future<CashOperationResult?> show(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final layoutType = Breakpoints.fromWidth(width);

    if (layoutType == LayoutType.mobile) {
      return Navigator.of(context).push<CashOperationResult>(
        MaterialPageRoute(builder: (_) => const CashOperationScreen()),
      );
    } else {
      return showDialog<CashOperationResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CashOperationDialog(),
      );
    }
  }

  @override
  ConsumerState<CashOperationScreen> createState() =>
      _CashOperationScreenState();
}

class _CashOperationScreenState extends ConsumerState<CashOperationScreen> {
  CashInOutType _operationType = CashInOutType.investment;
  ExpenseType _expenseType = ExpenseType.other;
  int? _customFieldItemId;
  String _amountText = '0';
  final _commentController = TextEditingController();

  Decimal get _amount {
    try {
      return Decimal.parse(_amountText);
    } catch (_) {
      return Decimal.zero;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cashOpTitle),
        leading: IconButton(
          icon: const Icon(TeleposIcons.close),
          onPressed: () => _close(null),
        ),
        actions: [
          TextButton(
            onPressed: _amount > Decimal.zero ? _onSubmit : null,
            child: Text(
              l10n.globalDone,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CashOperationForm(
                    initialType: _operationType,
                    onTypeChanged: (type) {
                      setState(() => _operationType = type);
                    },
                    onExpenseTypeChanged: (type) {
                      setState(() {
                        _expenseType = type;
                        if (type != ExpenseType.custom) {
                          _customFieldItemId = null;
                        }
                      });
                    },
                    onCustomExpenseTypeSelected: (itemId) {
                      setState(() => _customFieldItemId = itemId);
                    },
                  ),
                  const SizedBox(height: 24),

                  _buildAmountDisplay(),
                  const SizedBox(height: 16),

                  _buildCommentField(),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            child: SafeArea(
              top: false,
              child: NumpadWidget(
                compact: true,
                quickAmounts: const [500, 1000, 2000, 5000, 10000],
                onDigit: _onDigit,
                onDecimal: _onDecimal,
                onBackspace: _onBackspace,
                onClear: _onClear,
                onQuickAmount: _onQuickAmount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.globalAmount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: context.semantic.canvas,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _formatDisplayAmount(),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentField() {
    final l10n = AppLocalizations.of(context)!;
    final needsComment =
        _operationType == CashInOutType.expense && _expenseType.requiresNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          needsComment ? l10n.cashOpCommentRequired : l10n.cashOpComment,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commentController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: l10n.cashOpCommentHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  String _formatDisplayAmount() {
    if (_amountText == '0') return '0.00';
    if (!_amountText.contains('.')) return '$_amountText.00';

    final parts = _amountText.split('.');
    final decimals = parts[1].padRight(2, '0');
    return '${parts[0]}.$decimals';
  }

  void _onDigit(int digit) {
    setState(() {
      if (_amountText == '0') {
        _amountText = '$digit';
      } else {
        if (_amountText.contains('.')) {
          final parts = _amountText.split('.');
          if (parts[1].length >= 2) return;
        }
        _amountText += '$digit';
      }
    });
  }

  void _onDecimal() {
    setState(() {
      if (!_amountText.contains('.')) {
        _amountText += '.';
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountText.length > 1) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      } else {
        _amountText = '0';
      }
    });
  }

  void _onClear() {
    setState(() {
      _amountText = '0';
    });
  }

  void _onQuickAmount(int amount) {
    setState(() {
      _amountText = '$amount';
    });
  }

  void _close(CashOperationResult? result) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
    } else {
      context.go(AppRoutes.shift);
    }
  }

  Future<void> _onSubmit() async {
    if (_amount <= Decimal.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.cashEnterAmount)),
      );
      return;
    }

    // Снимаются до первого `await`: этот экран закроется раньше, чем очередь
    // печати ответит, и `context` к тому моменту будет мёртв.
    final messenger = ScaffoldMessenger.of(context);
    final printErrorLabel = AppLocalizations.of(context)!.printerPrintError;
    // Цвет снимается здесь же и по той же причине, что и подпись выше: к
    // моменту ответа очереди печати `context` может быть мёртв.
    final printErrorColor = Theme.of(context).colorScheme.error;

    try {
      final controller = GetIt.I<CashInOutController>();
      final db = GetIt.I<AppDatabase>();

      final thisPos = await db.thisPosDao.get();
      if (!(thisPos?.cashInOut ?? false)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.salePolicyForbids),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      final accountId = thisPos?.accountId;
      if (accountId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.globalError),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      CashOperationResult result;

      switch (_operationType) {
        case CashInOutType.investment:
          result = await controller.createInvestment(
            amount: _amount,
            accountId: accountId,
            note: _commentController.text.isNotEmpty
                ? _commentController.text
                : null,
          );
        case CashInOutType.expense:
          if (_expenseType == ExpenseType.collection) {
            result = await controller.createInkassaciya(
              amount: _amount,
              fromAccountId: accountId,
              note: _commentController.text.isNotEmpty
                  ? _commentController.text
                  : null,
            );
          } else {
            result = await controller.createExpense(
              amount: _amount,
              accountId: accountId,
              expenseType: _expenseType,
              note: _commentController.text.isNotEmpty
                  ? _commentController.text
                  : null,
              customFieldItemId: _customFieldItemId,
            );
          }
        case CashInOutType.dividend:
          result = await controller.createDividend(
            amount: _amount,
            accountId: accountId,
            note: _commentController.text.isNotEmpty
                ? _commentController.text
                : null,
          );
      }

      if (result.success && result.operationId != null) {
        _dispatchCashOperationReceipt(
          result.operationId!,
          messenger,
          printErrorLabel,
          printErrorColor,
        );
      }

      if (result.success) {
        ref.invalidate(shiftControllerProvider);
      }

      // Отказ говорится СЛОВАМИ и экран НЕ закрывается: до 2026-09-22 он
      // закрывался одинаково при удаче и отказе, и внесение выше потолка
      // исчезало молча — кассир был уверен, что деньги в ящике.
      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cashRefusalText(AppLocalizations.of(context)!, result),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      if (mounted) {
        _close(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cashOpError('$e')),
          ),
        );
      }
    }
  }
}

class _CashOperationDialog extends StatefulWidget {
  const _CashOperationDialog();

  @override
  State<_CashOperationDialog> createState() => _CashOperationDialogState();
}

class _CashOperationDialogState extends State<_CashOperationDialog> {
  CashInOutType _operationType = CashInOutType.investment;
  ExpenseType _expenseType = ExpenseType.other;
  int? _customFieldItemId;
  String _amountText = '0';
  final _commentController = TextEditingController();

  Decimal get _amount {
    try {
      return Decimal.parse(_amountText);
    } catch (_) {
      return Decimal.zero;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(700.0, screenSize.width - 48);
    final dialogMaxHeight = math.min(560.0, screenSize.height - 48);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            Flexible(child: _buildContent()),
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selectedSurfaceOf(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.cashOpTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(TeleposIcons.close),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CashOperationForm(
                  initialType: _operationType,
                  onTypeChanged: (type) {
                    setState(() => _operationType = type);
                  },
                  onExpenseTypeChanged: (type) {
                    setState(() {
                      _expenseType = type;
                      if (type != ExpenseType.custom) {
                        _customFieldItemId = null;
                      }
                    });
                  },
                  onCustomExpenseTypeSelected: (itemId) {
                    setState(() => _customFieldItemId = itemId);
                  },
                ),
                const SizedBox(height: 24),
                _buildAmountDisplay(),
                const SizedBox(height: 16),
                _buildCommentField(),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outline),
        Container(
          width: 260,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NumpadWidget(
                compact: MediaQuery.sizeOf(context).height < 700,
                quickAmounts: const [500, 1000, 2000, 5000, 10000],
                onDigit: _onDigit,
                onDecimal: _onDecimal,
                onBackspace: _onBackspace,
                onClear: _onClear,
                onQuickAmount: _onQuickAmount,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountDisplay() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.globalAmount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: context.semantic.canvas,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _formatDisplayAmount(),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentField() {
    final l10n = AppLocalizations.of(context)!;
    final needsComment =
        _operationType == CashInOutType.expense && _expenseType.requiresNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          needsComment ? l10n.cashOpCommentRequired : l10n.cashOpComment,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commentController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: l10n.cashOpCommentHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.globalCancel),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _amount > Decimal.zero ? _onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(l10n.globalDone),
          ),
        ],
      ),
    );
  }

  String _formatDisplayAmount() {
    if (_amountText == '0') return '0.00';
    if (!_amountText.contains('.')) return '$_amountText.00';

    final parts = _amountText.split('.');
    final decimals = parts[1].padRight(2, '0');
    return '${parts[0]}.$decimals';
  }

  void _onDigit(int digit) {
    setState(() {
      if (_amountText == '0') {
        _amountText = '$digit';
      } else {
        if (_amountText.contains('.')) {
          final parts = _amountText.split('.');
          if (parts[1].length >= 2) return;
        }
        _amountText += '$digit';
      }
    });
  }

  void _onDecimal() {
    setState(() {
      if (!_amountText.contains('.')) {
        _amountText += '.';
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountText.length > 1) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      } else {
        _amountText = '0';
      }
    });
  }

  void _onClear() {
    setState(() {
      _amountText = '0';
    });
  }

  void _onQuickAmount(int amount) {
    setState(() {
      _amountText = '$amount';
    });
  }

  Future<void> _onSubmit() async {
    if (_amount <= Decimal.zero) {
      return;
    }

    // См. одноимённое место в `_CashOperationScreenState._onSubmit`: диалог
    // закроется раньше, чем очередь печати ответит.
    final messenger = ScaffoldMessenger.of(context);
    final printErrorLabel = AppLocalizations.of(context)!.printerPrintError;
    // Цвет снимается здесь же и по той же причине, что и подпись выше: к
    // моменту ответа очереди печати `context` может быть мёртв.
    final printErrorColor = Theme.of(context).colorScheme.error;

    try {
      final controller = GetIt.I<CashInOutController>();
      final db = GetIt.I<AppDatabase>();

      final thisPos = await db.thisPosDao.get();
      if (!(thisPos?.cashInOut ?? false)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.salePolicyForbids),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      final accountId = thisPos?.accountId;
      if (accountId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.globalError),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      CashOperationResult result;

      switch (_operationType) {
        case CashInOutType.investment:
          result = await controller.createInvestment(
            amount: _amount,
            accountId: accountId,
            note: _commentController.text.isNotEmpty
                ? _commentController.text
                : null,
          );
        case CashInOutType.expense:
          if (_expenseType == ExpenseType.collection) {
            result = await controller.createInkassaciya(
              amount: _amount,
              fromAccountId: accountId,
              note: _commentController.text.isNotEmpty
                  ? _commentController.text
                  : null,
            );
          } else {
            result = await controller.createExpense(
              amount: _amount,
              accountId: accountId,
              expenseType: _expenseType,
              note: _commentController.text.isNotEmpty
                  ? _commentController.text
                  : null,
              customFieldItemId: _customFieldItemId,
            );
          }
        case CashInOutType.dividend:
          result = await controller.createDividend(
            amount: _amount,
            accountId: accountId,
            note: _commentController.text.isNotEmpty
                ? _commentController.text
                : null,
          );
      }

      if (result.success && result.operationId != null) {
        _dispatchCashOperationReceipt(
          result.operationId!,
          messenger,
          printErrorLabel,
          printErrorColor,
        );
      }

      // То же правило, что и на полноэкранной версии: отказ виден, и окно
      // остаётся открытым — сумму ещё можно поправить.
      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cashRefusalText(AppLocalizations.of(context)!, result),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

/// Слова отказа кассовой операции.
///
/// Заведено 2026-09-22: при отказе экран просто закрывался, и кассир видел
/// ровно то же, что при успехе. Внесение выше потолка исчезало молча.
String cashRefusalText(AppLocalizations l10n, CashOperationResult result) =>
    switch (result.refusal) {
      CashAmountRefusal.notPositive => l10n.cashRefusedNotPositive,
      CashAmountRefusal.aboveCeiling => l10n.cashRefusedAboveCeiling(
        result.limit ?? '',
      ),
      null => l10n.cashOpError(result.errorDetail ?? ''),
    };
