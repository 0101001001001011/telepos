import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class _ProductRef {
  _ProductRef(this.ucode, this.name);
  final int ucode;
  final String name;
}

final _productsProvider = FutureProvider<List<_ProductRef>>((ref) async {
  final db = GetIt.I<AppDatabase>();
  final rows = await db
      .customSelect(
        'SELECT ucode, name FROM product_infos '
        'WHERE (is_deleted IS NULL OR is_deleted = 0) ORDER BY name',
      )
      .get();
  return rows
      .map(
        (r) =>
            _ProductRef(r.read<int>('ucode'), r.read<String?>('name') ?? '—'),
      )
      .toList();
});

final _promotionsProvider = FutureProvider<List<Promotion>>((ref) async {
  return GetIt.I<AppDatabase>().promotionDao.getAll();
});

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final promosAsync = ref.watch(_promotionsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: Text(l10n.promoTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(TeleposIcons.add),
        label: Text(l10n.promoNew),
      ),
      body: promosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.promoError(e.toString()))),
        data: (promos) {
          if (promos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.promoEmpty, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.promoEmptyHint,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: promos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = promos[i];
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
                    Icon(
                      p.type == 0 ? Icons.repeat : Icons.card_giftcard,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${p.type == 0 ? "1+1" : l10n.promoTypeGift} · '
                            '${l10n.promoBuyGetFree(p.triggerQty, p.rewardQty)}'
                            '${p.supplierFunded ? " · ${l10n.promoSupplierTag}" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: p.enabled,
                      onChanged: (v) async {
                        await GetIt.I<AppDatabase>().promotionDao.setEnabled(
                          p.id,
                          v,
                        );
                        ref.invalidate(_promotionsProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openCreateForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _PromotionForm(onSaved: () => ref.invalidate(_promotionsProvider)),
    );
  }
}

class _PromotionForm extends ConsumerStatefulWidget {
  const _PromotionForm({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_PromotionForm> createState() => _PromotionFormState();
}

class _PromotionFormState extends ConsumerState<_PromotionForm> {
  final _nameCtrl = TextEditingController();
  int _type = 0;
  int? _triggerUcode;
  int? _rewardUcode;
  bool _supplierFunded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<_ProductRef> products) async {
    final l10n = AppLocalizations.of(context)!;
    final trigger = _triggerUcode;
    if (trigger == null) return;
    final reward = _type == 0 ? trigger : (_rewardUcode ?? trigger);
    final name = _nameCtrl.text.trim().isEmpty
        ? (_type == 0 ? l10n.promoDefaultName11 : l10n.promoTypeGift)
        : _nameCtrl.text.trim();

    setState(() => _saving = true);
    await GetIt.I<AppDatabase>().promotionDao.insertPromotion(
      PromotionsCompanion.insert(
        name: name,
        type: Value(_type),
        triggerUcode: trigger,
        triggerQty: Value(_type == 0 ? 2 : 1),
        rewardUcode: reward,
        rewardQty: const Value(1),
        supplierFunded: Value(_supplierFunded),
      ),
    );
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync = ref.watch(_productsProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: productsAsync.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) =>
            SizedBox(height: 120, child: Center(child: Text('$e'))),
        data: (products) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.promoNew,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.promoNameLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                const ButtonSegment(
                  value: 0,
                  label: Text('1+1'),
                  icon: Icon(Icons.repeat),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(l10n.promoTypeGift),
                  icon: const Icon(Icons.card_giftcard),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _triggerUcode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.promoTriggerLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: products
                  .map(
                    (p) =>
                        DropdownMenuItem(value: p.ucode, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _triggerUcode = v),
            ),
            if (_type == 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _rewardUcode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.promoRewardLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: products
                    .map(
                      (p) =>
                          DropdownMenuItem(value: p.ucode, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _rewardUcode = v),
              ),
            ],
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _supplierFunded,
              onChanged: (v) => setState(() => _supplierFunded = v ?? false),
              title: Text(l10n.promoSupplierFunded),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_saving || _triggerUcode == null)
                    ? null
                    : () => _save(products),
                icon: const Icon(TeleposIcons.save),
                label: Text(l10n.promoSaveButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
