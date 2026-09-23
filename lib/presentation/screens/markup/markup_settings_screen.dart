import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class _CategoryMarkUp {
  _CategoryMarkUp({
    required this.categoryId,
    required this.name,
    required this.markup,
  });
  final int categoryId;

  /// Название категории; `null` — названия нет, экран подставит номер.
  final String? name;
  final Decimal markup;
}

final _categoryMarkUpsProvider = FutureProvider<List<_CategoryMarkUp>>((
  ref,
) async {
  final db = GetIt.I<AppDatabase>();
  final categories = await db.select(db.categories).get();
  final markUps = await db.markUpDao.getAll();
  final byCat = {for (final m in markUps) m.categoryId: m.markup};
  return categories
      .map(
        (c) => _CategoryMarkUp(
          categoryId: c.id,
          // Имя без названия — не текст, а НОМЕР: экран подставит слово
          // сам, когда будет знать язык.
          name: c.name,
          markup: byCat[c.id] ?? Decimal.zero,
        ),
      )
      .toList();
});

class MarkUpSettingsScreen extends ConsumerStatefulWidget {
  const MarkUpSettingsScreen({super.key});

  @override
  ConsumerState<MarkUpSettingsScreen> createState() =>
      _MarkUpSettingsScreenState();
}

class _MarkUpSettingsScreenState extends ConsumerState<MarkUpSettingsScreen> {
  final Map<int, TextEditingController> _ctrls = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(_CategoryMarkUp row) => _ctrls.putIfAbsent(
    row.categoryId,
    () => TextEditingController(
      text: row.markup == Decimal.zero ? '' : row.markup.toString(),
    ),
  );

  Future<void> _save(List<_CategoryMarkUp> rows) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final db = GetIt.I<AppDatabase>();
    var applied = 0;
    for (final row in rows) {
      final raw = _ctrl(row).text.trim().replaceAll(',', '.');
      final value = Decimal.tryParse(raw) ?? Decimal.zero;
      await db.markUpDao.upsertMarkUp(row.categoryId, value);
      if (value > Decimal.zero) applied++;
    }
    ref.invalidate(_categoryMarkUpsProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.markupSaved(applied)),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rowsAsync = ref.watch(_categoryMarkUpsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: Text(AppLocalizations.of(context)!.markupAuto),
      ),
      body: rowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.genericErrorWith('$e'))),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Text(
                l10n.catalogNoCategories,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: selectedSurfaceOf(context),
                child: Text(
                  AppLocalizations.of(context)!.markupHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              row.name ??
                                  l10n.markupCategoryNumbered(row.categoryId),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: _ctrl(row),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '0',
                                suffixText: '%',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(rows),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(TeleposIcons.save),
                    label: Text(AppLocalizations.of(context)!.markupSave),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
