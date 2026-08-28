import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/entities/wms/stock_rule_entity.dart';
import 'package:telepos/domain/usecases/stock_rule/stock_rule_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';

class _ReorderRulesView {
  const _ReorderRulesView({required this.rules, required this.belowCount});
  final List<StockRuleEntity> rules;
  final int belowCount;
}

final _reorderRulesProvider = FutureProvider<_ReorderRulesView>((ref) async {
  final uc = GetIt.I<StockRuleUseCase>();
  final rules = await uc.listRules();
  final signals = await uc.evaluateReorders();
  return _ReorderRulesView(rules: rules, belowCount: signals.length);
});

class ReorderRulesScreen extends ConsumerWidget {
  const ReorderRulesScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    StockRuleEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ReorderRuleDialog(existing: existing),
    );
    if (saved == true) ref.invalidate(_reorderRulesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final viewAsync = ref.watch(_reorderRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reorderRulesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('reorder-add'),
        onPressed: () => _edit(context, ref),
        icon: const Icon(TeleposIcons.add),
        label: Text(l10n.reorderRulesAdd),
      ),
      body: viewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (view) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: selectedSurfaceOf(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  l10n.reorderRulesBelowPoint(view.belowCount),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: view.rules.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.rule_folder_outlined,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.reorderRulesEmpty,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.reorderRulesEmptyHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: view.rules.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final r = view.rules[i];
                          return Material(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              title: Text(
                                l10n.supplierReturnProductFallback(
                                  (r.ucode ?? 0).toString(),
                                ),
                              ),
                              subtitle: Text(
                                '${l10n.reorderRulesMinStock}: ${r.minStock ?? Decimal.zero}'
                                '${r.reorderQty != null ? ' · ${l10n.reorderRulesReorderQty}: ${r.reorderQty}' : ''}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _edit(context, ref, existing: r),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReorderRuleDialog extends ConsumerStatefulWidget {
  const _ReorderRuleDialog({this.existing});
  final StockRuleEntity? existing;

  @override
  ConsumerState<_ReorderRuleDialog> createState() => _ReorderRuleDialogState();
}

class _ReorderRuleDialogState extends ConsumerState<_ReorderRuleDialog> {
  late final TextEditingController _ucode;
  late final TextEditingController _minStock;
  late final TextEditingController _reorderQty;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _ucode = TextEditingController(text: e?.ucode?.toString() ?? '');
    _minStock = TextEditingController(text: e?.minStock?.toString() ?? '');
    _reorderQty = TextEditingController(text: e?.reorderQty?.toString() ?? '');
  }

  @override
  void dispose() {
    _ucode.dispose();
    _minStock.dispose();
    _reorderQty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final ucode = int.tryParse(_ucode.text.trim());
    final minStock = Decimal.tryParse(
      _minStock.text.trim().replaceAll(',', '.'),
    );
    if (ucode == null || minStock == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reorderRulesInvalid)));
      return;
    }
    final reorderQty = Decimal.tryParse(
      _reorderQty.text.trim().replaceAll(',', '.'),
    );
    await GetIt.I<StockRuleUseCase>().upsertRule(
      ucode: ucode,
      minStock: minStock,
      reorderQty: reorderQty,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.reorderRulesSaved),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.reorderRulesEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('reorder-ucode'),
            controller: _ucode,
            enabled: widget.existing == null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.reorderRulesProduct,
              hintText: l10n.reorderRulesProductHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('reorder-minstock'),
            controller: _minStock,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.reorderRulesMinStock),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('reorder-reorderqty'),
            controller: _reorderQty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.reorderRulesReorderQty),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('reorder-save'),
          onPressed: _save,
          child: Text(l10n.reorderRulesSave),
        ),
      ],
    );
  }
}
