import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/cash_operation_label.dart';

class ExpenseTypeItem {
  const ExpenseTypeItem({
    required this.id,
    required this.name,
    required this.isCustom,
    this.staticType,
    this.customFieldItemId,
  });

  final int id;

  final String name;

  final bool isCustom;

  final ExpenseType? staticType;

  final int? customFieldItemId;

  bool get requiresNote => staticType == ExpenseType.other;

  /// Имя здесь пустое, и это не забывчивость: у рода из перечисления
  /// подпись выбирается ПРИ ОТРИСОВКЕ (`localizedName`), иначе она не
  /// переживёт смену языка. Стоял `type.displayName` — русское слово из
  /// домена; на отрисовке его перекрывал `localizedName`, так что в списке
  /// оно не показывалось, зато уезжало в историю: тот же `displayName`
  /// склеивался с комментарием и писался в `cash_operations.note`.
  ///
  /// Поле `name` несёт только имя СВОЕГО рода из справочника — его завёл
  /// человек, и переводить его некому.
  factory ExpenseTypeItem.fromStatic(ExpenseType type) => ExpenseTypeItem(
    id: type.index,
    name: '',
    isCustom: false,
    staticType: type,
  );

  factory ExpenseTypeItem.fromCustom(int customFieldItemId, String name) =>
      ExpenseTypeItem(
        id: 1000 + customFieldItemId,
        name: name,
        isCustom: true,
        customFieldItemId: customFieldItemId,
      );
}

class CashOperationForm extends StatefulWidget {
  const CashOperationForm({
    super.key,
    required this.onTypeChanged,
    required this.onExpenseTypeChanged,
    this.initialType = CashInOutType.investment,
    this.showExpenseTypes = false,
    this.onCustomExpenseTypeSelected,
  });

  final void Function(CashInOutType type) onTypeChanged;
  final void Function(ExpenseType type) onExpenseTypeChanged;
  final void Function(int customFieldItemId)? onCustomExpenseTypeSelected;
  final CashInOutType initialType;
  final bool showExpenseTypes;

  @override
  State<CashOperationForm> createState() => _CashOperationFormState();
}

class _CashOperationFormState extends State<CashOperationForm> {
  late CashInOutType _selectedType;
  ExpenseTypeItem? _selectedExpenseType;
  List<ExpenseTypeItem> _expenseTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadExpenseTypes();
  }

  Future<void> _loadExpenseTypes() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final customItems = await db.customFieldDao.getExpenseTypeItems();

      final items = <ExpenseTypeItem>[];

      for (final type in ExpenseType.values) {
        if (type != ExpenseType.custom) {
          items.add(ExpenseTypeItem.fromStatic(type));
        }
      }

      for (final item in customItems) {
        if (item.name != null && item.name!.isNotEmpty) {
          items.add(ExpenseTypeItem.fromCustom(item.id, item.name!));
        }
      }

      setState(() {
        _expenseTypes = items;
        _selectedExpenseType = items.isNotEmpty ? items.first : null;
        _isLoading = false;
      });

      if (_selectedExpenseType != null && !_selectedExpenseType!.isCustom) {
        widget.onExpenseTypeChanged(_selectedExpenseType!.staticType!);
      }
    } catch (e) {
      setState(() {
        _expenseTypes = ExpenseType.values
            .where((t) => t != ExpenseType.custom)
            .map(ExpenseTypeItem.fromStatic)
            .toList();
        _selectedExpenseType = _expenseTypes.isNotEmpty
            ? _expenseTypes.first
            : null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cashOpOperationType,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildOperationTypeSelector(),

        if (_selectedType == CashInOutType.expense) ...[
          const SizedBox(height: 20),
          Text(
            l10n.cashExpenseTypes,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildExpenseTypeSelector(),
        ],
      ],
    );
  }

  Widget _buildOperationTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _OperationTypeCard(
            type: CashInOutType.investment,
            isSelected: _selectedType == CashInOutType.investment,
            onTap: () => _onTypeSelected(CashInOutType.investment),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OperationTypeCard(
            type: CashInOutType.expense,
            isSelected: _selectedType == CashInOutType.expense,
            onTap: () => _onTypeSelected(CashInOutType.expense),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OperationTypeCard(
            type: CashInOutType.dividend,
            isSelected: _selectedType == CashInOutType.dividend,
            onTap: () => _onTypeSelected(CashInOutType.dividend),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _expenseTypes.map((item) {
        return _ExpenseTypeItemChip(
          item: item,
          isSelected: _selectedExpenseType?.id == item.id,
          onTap: () => _onExpenseTypeItemSelected(item),
        );
      }).toList(),
    );
  }

  void _onTypeSelected(CashInOutType type) {
    setState(() {
      _selectedType = type;
    });
    widget.onTypeChanged(type);
  }

  void _onExpenseTypeItemSelected(ExpenseTypeItem item) {
    setState(() {
      _selectedExpenseType = item;
    });

    if (item.isCustom) {
      widget.onCustomExpenseTypeSelected?.call(item.customFieldItemId!);
      widget.onExpenseTypeChanged(ExpenseType.custom);
    } else {
      widget.onExpenseTypeChanged(item.staticType!);
    }
  }
}

class _OperationTypeCard extends StatelessWidget {
  const _OperationTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final CashInOutType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? _getColor(context)
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? _getColor(context).withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(
              _getIcon(),
              size: 28,
              color: isSelected
                  ? _getColor(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              _getTitle(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? _getColor(context)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case CashInOutType.investment:
        return Icons.add_circle_outline;
      case CashInOutType.expense:
        return Icons.shopping_cart_outlined;
      case CashInOutType.dividend:
        return Icons.remove_circle_outline;
    }
  }

  String _getTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case CashInOutType.investment:
        return l10n.cashInvestment;
      case CashInOutType.expense:
        return l10n.cashOpExpense;
      case CashInOutType.dividend:
        return l10n.cashOpDividend;
    }
  }

  Color _getColor(BuildContext context) {
    switch (type) {
      case CashInOutType.investment:
        return AppColors.success;
      case CashInOutType.expense:
        return AppColors.warning;
      case CashInOutType.dividend:
        return Theme.of(context).colorScheme.error;
    }
  }
}


class _ExpenseTypeItemChip extends StatelessWidget {
  const _ExpenseTypeItemChip({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final ExpenseTypeItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = item.staticType != null
        ? item.staticType!.localizedName(AppLocalizations.of(context)!)
        : item.name;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.semantic.canvas,
          borderRadius: BorderRadius.circular(20),
          border: item.isCustom
              ? Border.all(
                  color: isSelected ? AppColors.primary : AppColors.info,
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.isCustom) ...[
              Icon(
                Icons.label_outline,
                size: 14,
                color: isSelected ? AppColors.white : AppColors.info,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppColors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
