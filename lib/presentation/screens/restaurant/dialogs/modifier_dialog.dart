import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/restaurant/selected_modifier.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ModifierGroupWithOptions {
  const ModifierGroupWithOptions({required this.group, required this.options});

  final ModifierGroup group;
  final List<ModifierOption> options;
}

class ModifierDialog extends StatefulWidget {
  const ModifierDialog({
    required this.productName,
    required this.basePrice,
    required this.groups,
    super.key,
  });

  final String productName;
  final Decimal basePrice;
  final List<ModifierGroupWithOptions> groups;

  static Future<List<SelectedModifier>?> show({
    required BuildContext context,
    required String productName,
    required Decimal basePrice,
    required List<ModifierGroupWithOptions> groups,
  }) {
    return showDialog<List<SelectedModifier>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ModifierDialog(
        productName: productName,
        basePrice: basePrice,
        groups: groups,
      ),
    );
  }

  @override
  State<ModifierDialog> createState() => _ModifierDialogState();
}

class _ModifierDialogState extends State<ModifierDialog> {
  late final Map<int, Set<int>> _selections;

  @override
  void initState() {
    super.initState();
    _selections = {};
    for (final gwo in widget.groups) {
      final defaults = <int>{};
      for (final opt in gwo.options) {
        if (opt.isDefault) {
          defaults.add(opt.id);
        }
      }
      _selections[gwo.group.id] = defaults;
    }
  }

  Decimal get _totalAdjustment {
    var total = Decimal.zero;
    for (final gwo in widget.groups) {
      final selected = _selections[gwo.group.id] ?? {};
      for (final opt in gwo.options) {
        if (selected.contains(opt.id)) {
          total += Decimal.parse(opt.priceAdjustment.toStringAsFixed(3));
        }
      }
    }
    return total;
  }

  Decimal get _finalPrice {
    return widget.basePrice + _totalAdjustment;
  }

  bool get _isValid {
    for (final gwo in widget.groups) {
      final selected = _selections[gwo.group.id] ?? {};
      if (gwo.group.isRequired && selected.isEmpty) return false;
      if (selected.length < gwo.group.minSelection) return false;
    }
    return true;
  }

  void _toggleSingleChoice(int groupId, int optionId) {
    setState(() {
      _selections[groupId] = {optionId};
    });
  }

  void _toggleMultipleChoice(int groupId, int optionId, int maxSelection) {
    setState(() {
      final current = _selections[groupId] ?? {};
      if (current.contains(optionId)) {
        current.remove(optionId);
      } else if (current.length < maxSelection) {
        current.add(optionId);
      }
      _selections[groupId] = current;
    });
  }

  List<SelectedModifier> _buildResult() {
    final result = <SelectedModifier>[];
    for (final gwo in widget.groups) {
      final selected = _selections[gwo.group.id] ?? {};
      for (final opt in gwo.options) {
        if (selected.contains(opt.id)) {
          result.add(
            SelectedModifier(
              groupId: gwo.group.id,
              optionId: opt.id,
              priceAdjustment: opt.priceAdjustment,
            ),
          );
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 480.0 : screenWidth * 0.92;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F23),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: const TextStyle(
                            color: Color(0xFFE8E8F0),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.basePrice}',
                          style: const TextStyle(
                            color: Color(0xFF9898B8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(
                      TeleposIcons.close,
                      color: Color(0xFF9898B8),
                    ),
                    iconSize: 24,
                    splashRadius: 24,
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.groups
                      .map((g) => _buildGroup(context, g))
                      .toList(),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F23),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.globalTotal,
                          style: TextStyle(
                            color: Color(0xFF9898B8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$_finalPrice',
                          style: const TextStyle(
                            color: Color(0xFFE8E8F0),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isValid
                          ? () => Navigator.of(context).pop(_buildResult())
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        disabledBackgroundColor: const Color(0xFF2A2A4A),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF6B6B8D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                      ),
                      child: Text(
                        l10n.globalAdd,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, ModifierGroupWithOptions gwo) {
    final l10n = AppLocalizations.of(context)!;
    final isSingle = gwo.group.modifierType == 0;
    final selected = _selections[gwo.group.id] ?? {};

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  gwo.group.name,
                  style: const TextStyle(
                    color: Color(0xFFE8E8F0),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (gwo.group.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.modifierRequired,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (!isSingle)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    l10n.modifierMax(gwo.group.maxSelection),
                    style: const TextStyle(
                      color: Color(0xFF6B6B8D),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          ...gwo.options.map((opt) {
            final isSelected = selected.contains(opt.id);
            return _buildOptionTile(
              option: opt,
              isSelected: isSelected,
              isSingle: isSingle,
              onTap: () {
                if (isSingle) {
                  _toggleSingleChoice(gwo.group.id, opt.id);
                } else {
                  _toggleMultipleChoice(
                    gwo.group.id,
                    opt.id,
                    gwo.group.maxSelection,
                  );
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required ModifierOption option,
    required bool isSelected,
    required bool isSingle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? const Color(0xFF252545) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  isSingle
                      ? (isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked)
                      : (isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank),
                  color: isSelected
                      ? const Color(0xFF3A7BFF)
                      : const Color(0xFF6B6B8D),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.name,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFE8E8F0)
                          : const Color(0xFF9898B8),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (option.priceAdjustment != 0)
                  Text(
                    option.priceAdjustment > 0
                        ? '+${option.priceAdjustment.toStringAsFixed(0)}'
                        : option.priceAdjustment.toStringAsFixed(0),
                    style: TextStyle(
                      color: option.priceAdjustment > 0
                          ? AppColors.warning
                          : AppColors.success,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
