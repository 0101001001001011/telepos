import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/agent/agent_controller.dart';
import 'package:telepos/core/locale/till_conventions.dart';

class AgentTable extends StatelessWidget {
  const AgentTable({
    super.key,
    required this.items,
    this.compact = false,
    this.onSelect,
  });

  final List<AgentItem> items;
  final bool compact;
  final ValueChanged<AgentItem>? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        child: DataTable(
          columnSpacing: compact ? 16 : 24,
          horizontalMargin: compact ? 12 : 16,
          headingRowHeight: compact ? 48 : 56,
          dataRowMinHeight: compact ? 44 : 52,
          dataRowMaxHeight: compact ? 52 : 60,
          showCheckboxColumn: false,
          columns: [
            DataColumn(label: Text(l10n.agentName)),
            DataColumn(label: Text(l10n.agentPhone)),
            DataColumn(label: Text(l10n.agentBalance), numeric: true),
            DataColumn(label: Text(l10n.agentLastOperation)),
          ],
          rows: items.map((item) => _buildRow(context, item)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, AgentItem item) {
    return DataRow(
      onSelectChanged: (_) => _onSelect(context, item),
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: item.hasDebt
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 12,
                    color: item.hasDebt
                        ? Theme.of(context).colorScheme.error
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.bin != null)
                    Text(
                      AppLocalizations.of(context)!.agentBinLabel(item.bin!),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        DataCell(
          Text(
            item.formattedPhone.isNotEmpty ? item.formattedPhone : '—',
            style: AppTextStyles.body,
          ),
        ),

        DataCell(
          Text(
            item.balance.toStringAsFixed(2),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: item.hasDebt
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),

        DataCell(
          Text(
            item.lastOperationDate != null
                ? _formatDate(item.lastOperationDate!)
                : '—',
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return TillConventions.current.formatDate(date);
  }

  void _onSelect(BuildContext context, AgentItem item) {
    if (onSelect != null) {
      onSelect!(item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.agentSelectedMessage(item.name),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
