import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/report_dao.dart';
import 'package:telepos/domain/usecases/stock_rule/stock_rule_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';

class _OrderRow {
  _OrderRow({
    required this.ucode,
    required this.name,
    required this.stock,
    required this.recommended,
    this.ruleBased = false,
  });
  final int ucode;
  final String name;
  final Decimal stock;
  final Decimal recommended;

  final bool ruleBased;
}

const _reorderThreshold = 20.0;

final _targetStock = Decimal.fromInt(50);

final _reorderProvider = FutureProvider<List<_OrderRow>>((ref) async {
  final db = GetIt.I<AppDatabase>();
  final reportDao = ReportDao(db);
  final productDao = db.productInfoDao;
  final stockRuleUc = GetIt.I<StockRuleUseCase>();

  final rows = <_OrderRow>[];
  final seen = <int>{};

  final signals = await stockRuleUc.evaluateReorders();
  for (final s in signals) {
    if (!seen.add(s.ucode)) continue;
    final product = await productDao.findByUcode(s.ucode);
    final rec =
        s.suggestedOrderQty != null && s.suggestedOrderQty! > Decimal.zero
        ? s.suggestedOrderQty!
        : _recommendToTarget(s.currentQty);
    rows.add(
      _OrderRow(
        ucode: s.ucode,
        name: product?.name ?? '—',
        stock: s.currentQty,
        recommended: rec,
        ruleBased: true,
      ),
    );
  }

  final low = await reportDao.getLowStockItems(_reorderThreshold);
  for (final r in low) {
    final ucode = r.read<int?>('ucode') ?? 0;
    if (!seen.add(ucode)) continue;
    final stock = r.readDecimal('stock');
    rows.add(
      _OrderRow(
        ucode: ucode,
        name: r.read<String?>('name') ?? '—',
        stock: stock,
        recommended: _recommendToTarget(stock),
        ruleBased: false,
      ),
    );
  }

  return rows;
});

Decimal _recommendToTarget(Decimal stock) {
  var rec = _targetStock - stock;
  if (rec < Decimal.one) rec = Decimal.one;
  return rec;
}

final _suppliersProvider = FutureProvider<List<(int, String)>>((ref) async {
  final db = GetIt.I<AppDatabase>();
  final rows = await db
      .customSelect(
        'SELECT local_id, name FROM agents '
        'WHERE type = 0 AND (is_deleted IS NULL OR is_deleted = 0) ORDER BY name',
      )
      .get();
  return rows
      .map((r) => (r.read<int>('local_id'), r.read<String?>('name') ?? '—'))
      .toList();
});

class SupplierOrderScreen extends ConsumerStatefulWidget {
  const SupplierOrderScreen({super.key});

  @override
  ConsumerState<SupplierOrderScreen> createState() =>
      _SupplierOrderScreenState();
}

class _SupplierOrderScreenState extends ConsumerState<SupplierOrderScreen> {
  final Map<int, TextEditingController> _qty = {};
  int? _supplierId;
  String? _supplierName;

  TextEditingController? _active;

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(_OrderRow row) => _qty.putIfAbsent(
    row.ucode,
    () => TextEditingController(text: row.recommended.toString()),
  );

  void _onKey(String d) {
    final c = _active;
    if (c == null) return;
    setState(() => c.text = c.text + d);
  }

  void _onBackspace() {
    final c = _active;
    if (c == null || c.text.isEmpty) return;
    setState(() => c.text = c.text.substring(0, c.text.length - 1));
  }

  void _onClear() {
    final c = _active;
    if (c == null) return;
    setState(() => c.clear());
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(_reorderProvider);
    final suppliersAsync = ref.watch(_suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: const Text('Заявка поставщику'),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.reorderRulesTitle,
            icon: const Icon(Icons.rule),
            onPressed: () => context.push(AppRoutes.reorderRules),
          ),
        ],
      ),
      body: rowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    TeleposIcons.checkCircle,
                    size: 64,
                    color: AppColors.success,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Все товары в достаточном количестве',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Дозаказ не требуется',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Поставщик:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: suppliersAsync.maybeWhen(
                        data: (suppliers) => DropdownButton<int>(
                          isExpanded: true,
                          value: _supplierId,
                          hint: const Text('Выберите поставщика'),
                          items: suppliers
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.$1,
                                  child: Text(s.$2),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _supplierId = v;
                            _supplierName = suppliers
                                .firstWhere(
                                  (s) => s.$1 == v,
                                  orElse: () => (0, ''),
                                )
                                .$2;
                          }),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: selectedSurfaceOf(context),
                      child: const Row(
                        children: [
                          Expanded(flex: 5, child: Text('Товар', style: _th)),
                          Expanded(flex: 2, child: Text('Остаток', style: _th)),
                          Expanded(
                            flex: 3,
                            child: Text('Заказать', style: _th),
                          ),
                        ],
                      ),
                    ),
                    ...rows.map(
                      (r) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            bottom: BorderSide(color: context.semantic.canvas),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.name),
                                  Text(
                                    r.ruleBased
                                        ? AppLocalizations.of(
                                            context,
                                          )!.supplierOrderRuleBased
                                        : AppLocalizations.of(
                                            context,
                                          )!.supplierOrderGlobalThreshold(
                                            _reorderThreshold.toStringAsFixed(
                                              0,
                                            ),
                                          ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: r.ruleBased
                                          ? AppColors.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                r.stock.toStringAsFixed(0),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 40,
                                child: TextField(
                                  controller: _ctrl(r),
                                  readOnly: true,
                                  showCursor: true,
                                  onTap: () =>
                                      setState(() => _active = _ctrl(r)),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    filled: _active == _ctrl(r),
                                    fillColor: selectedSurfaceOf(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_active != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _active = null),
                          icon: const Icon(Icons.keyboard_hide, size: 18),
                          label: Text(AppLocalizations.of(context)!.globalDone),
                        ),
                      ),
                      NumPad(
                        buttonSize: 48,
                        spacing: 8,
                        showEnter: false,
                        onKeyPressed: _onKey,
                        onBackspace: _onBackspace,
                        onClear: _onClear,
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    Text(
                      'Позиций к заказу: ${rows.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _formOrder(rows),
                      icon: const Icon(Icons.send),
                      label: const Text('Сформировать заявку'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _formOrder(List<_OrderRow> rows) {
    final lines = <List<String>>[];
    for (final r in rows) {
      final qty = Decimal.tryParse(_ctrl(r).text) ?? Decimal.zero;
      if (qty > Decimal.zero) {
        lines.add([r.name, r.stock.toStringAsFixed(0), qty.toStringAsFixed(0)]);
      }
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите количество хотя бы по одному товару'),
        ),
      );
      return;
    }
    try {
      ReportExportButton.exportCsv(context, 'supplier_order', [
        'Товар',
        'Остаток',
        'Заказать',
      ], lines);
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Заявка сформирована: ${lines.length} поз.'
          '${_supplierName != null && _supplierName!.isNotEmpty ? ' · $_supplierName' : ''}',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  static const _th = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
}
