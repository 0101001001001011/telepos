import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/catalog/selling_hours.dart';
import 'package:telepos/domain/catalog/selling_hours_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';

/// Часы, в которые категорию продавать нельзя.
///
/// # Зачем экран
///
/// Механизм запрета в продукте БЫЛ — таблица, DAO, договор, — и заполнить
/// его было нечем: ни одного экрана. То есть настройка существовала только
/// на бумаге, а запрет не работал ни в одной стране.
///
/// # Почему часы ставит человек, а не страна
///
/// Ночной запрет продажи алкоголя есть в Казахстане, России, Киргизии,
/// Узбекистане, в большинстве штатов США, в Польше, Турции. Часы везде
/// разные, меняются законом и различаются внутри одной страны. Зашить их
/// значило бы обещать соблюдение закона, которого мы не знаем.
class SellingHoursScreen extends ConsumerStatefulWidget {
  const SellingHoursScreen({super.key});

  @override
  ConsumerState<SellingHoursScreen> createState() => _SellingHoursScreenState();
}

class _SellingHoursScreenState extends ConsumerState<SellingHoursScreen> {
  List<SellingHoursRule> _rules = const [];
  List<Category> _categories = const [];
  bool _loading = true;

  SellingHoursRepository get _repo => GetIt.I<SellingHoursRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final rules = await _repo.all();
    final categories = await GetIt.I<AppDatabase>()
        .select(GetIt.I<AppDatabase>().categories)
        .get();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _categories = categories;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sellingHoursTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('selling-hours-add'),
        onPressed: _categories.isEmpty ? null : () => _edit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.sellingHoursAdd),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSection(
                  header: l10n.sellingHoursTitle,
                  footer: _categories.isEmpty
                      ? l10n.sellingHoursNoCategories
                      : l10n.sellingHoursExplainer,
                  children: [
                    for (final rule in _rules) _tile(context, l10n, rule),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _tile(
    BuildContext context,
    AppLocalizations l10n,
    SellingHoursRule rule,
  ) {
    final ban = rule.ban;
    // Непригодное окно называется СЛОВАМИ, а не прячется: владелец, у
    // которого запрет не сработал, обязан увидеть причину здесь, а не
    // выяснять её ночной продажей.
    final broken = ban == null || ban.isEmpty;

    return ListTile(
      key: ValueKey('selling-hours-${rule.id}'),
      leading: Icon(
        rule.isActive ? Icons.block : Icons.block_outlined,
        color: broken
            ? Theme.of(context).colorScheme.error
            : (rule.isActive ? AppColors.warning : null),
      ),
      title: Text(
        rule.categoryName.isEmpty
            ? l10n.sellingHoursCategoryGone(rule.categoryId)
            : rule.categoryName,
      ),
      subtitle: Text(
        broken
            ? l10n.sellingHoursBroken('${rule.beginTime}–${rule.endTime}')
            : (rule.isActive
                  ? l10n.sellingHoursBanned(ban.label)
                  : l10n.sellingHoursOff(ban.label)),
        style: broken
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.globalDelete,
        onPressed: () async {
          await _repo.remove(rule.id!);
          await _load();
        },
      ),
      onTap: () => _edit(rule),
    );
  }

  Future<void> _edit(SellingHoursRule? existing) async {
    final saved = await showDialog<SellingHoursRule>(
      context: context,
      builder: (ctx) =>
          _SellingHoursDialog(categories: _categories, initial: existing),
    );
    if (saved == null) return;
    await _repo.save(saved);
    await _load();
  }
}

class _SellingHoursDialog extends StatefulWidget {
  const _SellingHoursDialog({required this.categories, this.initial});

  final List<Category> categories;
  final SellingHoursRule? initial;

  @override
  State<_SellingHoursDialog> createState() => _SellingHoursDialogState();
}

class _SellingHoursDialogState extends State<_SellingHoursDialog> {
  late int _categoryId;
  late final TextEditingController _from;
  late final TextEditingController _to;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initial?.categoryId ?? widget.categories.first.id;
    _from = TextEditingController(text: widget.initial?.beginTime ?? '23:00');
    _to = TextEditingController(text: widget.initial?.endTime ?? '08:00');
    _active = widget.initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ban = SellingBan.parse(_from.text, _to.text);
    final usable = ban != null && !ban.isEmpty;

    return AlertDialog(
      title: Text(l10n.sellingHoursAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            key: const ValueKey('selling-hours-category'),
            initialValue: _categoryId,
            decoration: InputDecoration(labelText: l10n.sellingHoursCategory),
            items: [
              for (final c in widget.categories)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name ?? '#${c.id}'),
                ),
            ],
            onChanged: (v) => setState(() => _categoryId = v ?? _categoryId),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('selling-hours-from'),
                  controller: _from,
                  decoration: InputDecoration(labelText: l10n.sellingHoursFrom),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('selling-hours-to'),
                  controller: _to,
                  decoration: InputDecoration(labelText: l10n.sellingHoursTo),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Что именно получится, сказано ДО сохранения. Ночное окно
          // выглядит опечаткой («с 23 до 8» — как это?), и без этой строки
          // владелец правил бы его, пока не сломал.
          Text(
            usable
                ? (ban.crossesMidnight
                      ? l10n.sellingHoursPreviewNight(ban.label)
                      : l10n.sellingHoursPreviewDay(ban.label))
                : l10n.sellingHoursBadTime,
            style: TextStyle(
              fontSize: 12,
              color: usable
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            title: Text(l10n.sellingHoursActive),
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        ElevatedButton(
          key: const ValueKey('selling-hours-save'),
          // Непригодное окно сохранить НЕЛЬЗЯ. Сохрани мы его — запрет
          // молча не сработал бы, и узнал бы об этом не владелец, а
          // проверяющий.
          onPressed: usable
              ? () => Navigator.of(context).pop(
                  SellingHoursRule(
                    id: widget.initial?.id,
                    categoryId: _categoryId,
                    categoryName: '',
                    beginTime: _from.text.trim(),
                    endTime: _to.text.trim(),
                    isActive: _active,
                  ),
                )
              : null,
          child: Text(l10n.globalSave),
        ),
      ],
    );
  }
}
