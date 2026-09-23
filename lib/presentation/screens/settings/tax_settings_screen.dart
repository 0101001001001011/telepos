/// Экран налоговой настройки: пресет, юрисдикции, категории, правила.
///
/// # Зачем он входит той же работой, что и схема
///
/// Схема v55 завела три таблицы, и без экрана они повторили бы судьбу трёх
/// колонок в `ThisPosEntries`, у которых нет ни одного читателя: заведены,
/// мигрированы и забыты. Настройка, которую нельзя увидеть и изменить,
/// отличима от несуществующей только чтением исходника.
///
/// Решение заказчика 2026-09-21: «пресеты как всегда устареют, поэтому
/// пользователь должен иметь возможность всё установить сам».
///
/// # Почему ставка показана, а не только задана
///
/// Пользователь задаёт доли, а платит покупатель по сумме. Между ними —
/// дерево юрисдикций, категории и даты, и ошибиться в нём легко. Поэтому
/// наверху стоит выведенная ставка для обычного товара: единственное число,
/// по которому видно, что настройка получилась.
///
/// Считает его тот же движок, что и чек, — `TaxConfiguration.resolve`.
/// Посчитать здесь отдельно значило бы показать не то, что напечатается.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/tax_settings_dao.dart';
import 'package:telepos/data/tax/tax_preset_catalog.dart';
import 'package:telepos/domain/tax/tax_preset.dart';
import 'package:telepos/domain/tax/tax_resolution.dart' as domain;
import 'package:telepos/l10n/app_localizations.dart';

class TaxSettingsScreen extends ConsumerStatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  ConsumerState<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends ConsumerState<TaxSettingsScreen> {
  AppDatabase get _db => GetIt.I<AppDatabase>();

  TaxPresetCatalog? _catalog;
  TaxConfiguration? _config;
  List<TaxRuleRow> _rules = const [];

  String? _country;
  String? _region;
  String? _city;
  String? _presetId;

  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // `addPostFrameCallback`, не `initState`: правило дерева — чтение из
    // `initState` роняет диалоги на `InheritedWidget`.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final catalog = await TaxPresetCatalog.load(
        DefaultAssetBundle.of(context),
      );
      final config = await _db.taxSettingsDao.load();
      final rules = await _db.taxSettingsDao.allRules();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _config = config;
        _rules = rules;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      // Отказ показывается, а не глотается: пустой список наборов и
      // испорченный файл выглядят на экране одинаково, а чинятся по-разному.
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final config = await _db.taxSettingsDao.load();
    final rules = await _db.taxSettingsDao.allRules();
    if (!mounted) return;
    setState(() {
      _config = config;
      _rules = rules;
    });
  }

  Future<void> _applyPreset(TaxPreset preset) async {
    await _db.taxSettingsDao.applyPreset(preset);
    await _refresh();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.taxSettingsPresetApplied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.taxSettingsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTokens.space16),
              children: [
                if (_loadError != null) ...[
                  _Note(
                    key: const ValueKey('tax-settings-load-error'),
                    icon: Icons.error_outline,
                    color: theme.colorScheme.error,
                    text: _loadError!,
                  ),
                  const SizedBox(height: AppTokens.space12),
                ],
                _Note(
                  icon: Icons.info_outline,
                  color: theme.colorScheme.primary,
                  text: l10n.taxSettingsIntro,
                ),
                const SizedBox(height: AppTokens.space12),
                _resolvedRate(l10n, theme),
                const SizedBox(height: AppTokens.space16),
                _presetSection(l10n, theme),
                const SizedBox(height: AppTokens.space16),
                _jurisdictionSection(l10n, theme),
                const SizedBox(height: AppTokens.space16),
                _categorySection(l10n, theme),
                const SizedBox(height: AppTokens.space16),
                _Note(
                  icon: Icons.gavel_outlined,
                  color: theme.colorScheme.outline,
                  text: l10n.taxSettingsResponsibility,
                ),
              ],
            ),
    );
  }

  /// Выведенная ставка — тем же движком, что считает чек.
  Widget _resolvedRate(AppLocalizations l10n, ThemeData theme) {
    final config = _config;
    if (config == null || !config.isConfigured) {
      return _Note(
        key: const ValueKey('tax-settings-not-configured'),
        icon: Icons.warning_amber_outlined,
        color: AppColors.warning,
        text: l10n.taxSettingsNotConfigured,
      );
    }

    final resolved = config.resolve();
    return Card(
      key: const ValueKey('tax-settings-resolved'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.taxSettingsRateForStandard(
                _formatRate(resolved.totalRatePercent),
              ),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppTokens.space8),
            // Разбивка, а не одна сумма: по ней видно, какая доля откуда, —
            // и именно её покупатель читает на чеке.
            for (final share in resolved.shares)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(share.name, style: theme.textTheme.bodyMedium),
                    Text(
                      '${_formatRate(share.ratePercent)}%',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _presetSection(AppLocalizations l10n, ThemeData theme) {
    final catalog = _catalog;
    if (catalog == null) return const SizedBox.shrink();

    final countries = catalog.countries();
    final regions = _country == null
        ? const <String>[]
        : catalog.regions(_country!);
    final cities = (_country == null || _region == null)
        ? const <String>[]
        : catalog.cities(_country!, _region!);

    final candidates = _country == null
        ? const <TaxPreset>[]
        : catalog.matching(
            countryCode: _country!,
            region: _region,
            city: _city,
          );

    final chosen = _presetId == null ? null : catalog.byId(_presetId!);

    return _Section(
      title: l10n.taxSettingsPresetSection,
      children: [
        _Dropdown<String>(
          key: const ValueKey('tax-preset-country'),
          label: l10n.taxSettingsCountry,
          value: _country,
          items: countries,
          itemLabel: (c) => c,
          // Смена страны сбрасывает нижние уровни: иначе на экране остался
          // бы Денвер под Казахстаном, а применился бы он по коду.
          onChanged: (value) => setState(() {
            _country = value;
            _region = null;
            _city = null;
            _presetId = null;
          }),
        ),
        // Второй уровень показывается только когда он есть. У Казахстана
        // ставка одна на страну, и пустое поле «штат» там — вопрос без
        // ответа.
        if (regions.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space8),
          _Dropdown<String>(
            key: const ValueKey('tax-preset-region'),
            label: l10n.taxSettingsRegion,
            value: _region,
            items: regions,
            itemLabel: (r) => r,
            onChanged: (value) => setState(() {
              _region = value;
              _city = null;
              _presetId = null;
            }),
          ),
        ],
        if (cities.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space8),
          _Dropdown<String>(
            key: const ValueKey('tax-preset-city'),
            label: l10n.taxSettingsCity,
            value: _city,
            items: cities,
            itemLabel: (c) => c,
            onChanged: (value) => setState(() {
              _city = value;
              _presetId = null;
            }),
          ),
        ],
        if (_country != null && candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.space8),
            child: _Note(
              icon: Icons.info_outline,
              color: theme.colorScheme.outline,
              text: l10n.taxSettingsNoPresetsForCountry,
            ),
          ),
        if (candidates.isNotEmpty) ...[
          const SizedBox(height: AppTokens.space8),
          _Dropdown<String>(
            key: const ValueKey('tax-preset-preset'),
            label: l10n.taxSettingsPreset,
            value: _presetId,
            items: candidates.map((p) => p.id).toList(),
            itemLabel: (id) => candidates.firstWhere((p) => p.id == id).title,
            onChanged: (value) => setState(() => _presetId = value),
          ),
        ],
        if (chosen != null) ...[
          const SizedBox(height: AppTokens.space12),
          // Источник и дата — на виду, а не в файле. Пресет стареет, и
          // человек, который решает, применять ли его, обязан видеть, чем
          // он подтверждён и на какой день верен.
          Text(
            l10n.taxSettingsPresetValidFrom(chosen.validFrom),
            style: theme.textTheme.bodySmall,
          ),
          Text(
            l10n.taxSettingsPresetSource(chosen.source),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppTokens.space8),
          _Note(
            icon: Icons.swap_horiz,
            color: AppColors.warning,
            text: l10n.taxSettingsPresetReplaces,
          ),
          const SizedBox(height: AppTokens.space8),
          FilledButton.icon(
            key: const ValueKey('tax-preset-apply'),
            onPressed: () => _applyPreset(chosen),
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.taxSettingsApplyPreset),
          ),
        ],
      ],
    );
  }

  Widget _jurisdictionSection(AppLocalizations l10n, ThemeData theme) {
    final config = _config;
    if (config == null) return const SizedBox.shrink();

    final nodes = config.jurisdictions.values.toList()
      ..sort((a, b) {
        final byDepth = a.depth.compareTo(b.depth);
        if (byDepth != 0) return byDepth;
        return a.sortOrder.compareTo(b.sortOrder);
      });

    return _Section(
      title: l10n.taxSettingsJurisdictions,
      children: [
        _Note(
          icon: Icons.place_outlined,
          color: theme.colorScheme.outline,
          text: l10n.taxSettingsTillLocationHint,
        ),
        const SizedBox(height: AppTokens.space8),
        for (final node in nodes)
          _JurisdictionTile(
            key: ValueKey('tax-jurisdiction-${node.id}'),
            node: node,
            isTillLocation: config.tillJurisdictionIds.contains(node.id),
            rules: _rules.where((r) => r.jurisdictionId == node.id).toList(),
            categories: config.categories,
            onTillLocationChanged: (value) async {
              await _db.taxSettingsDao.setTillLocation(node.id, value: value);
              await _refresh();
            },
            onDelete: () async {
              await _db.taxSettingsDao.removeJurisdiction(node.id);
              await _refresh();
            },
          ),
        const SizedBox(height: AppTokens.space8),
        OutlinedButton.icon(
          key: const ValueKey('tax-add-jurisdiction'),
          onPressed: () => _addJurisdiction(l10n),
          icon: const Icon(Icons.add),
          label: Text(l10n.taxSettingsAddJurisdiction),
        ),
      ],
    );
  }

  Widget _categorySection(AppLocalizations l10n, ThemeData theme) {
    final config = _config;
    if (config == null) return const SizedBox.shrink();

    return _Section(
      title: l10n.taxSettingsCategories,
      children: [
        for (final category in config.categories)
          ListTile(
            key: ValueKey('tax-category-${category.id}'),
            dense: true,
            title: Text(category.title),
            subtitle: Text(category.code),
            trailing: category.isDefault
                ? Icon(Icons.star, color: theme.colorScheme.primary, size: 18)
                : null,
          ),
        const SizedBox(height: AppTokens.space8),
        OutlinedButton.icon(
          key: const ValueKey('tax-add-category'),
          onPressed: () => _addCategory(l10n),
          icon: const Icon(Icons.add),
          label: Text(l10n.taxSettingsAddCategory),
        ),
      ],
    );
  }

  Future<void> _addJurisdiction(AppLocalizations l10n) async {
    final name = await _askText(
      l10n,
      l10n.taxSettingsAddJurisdiction,
      l10n.taxSettingsName,
    );
    if (name == null || name.isEmpty) return;
    await _db.taxSettingsDao.addJurisdiction(name: name);
    await _refresh();
  }

  Future<void> _addCategory(AppLocalizations l10n) async {
    final title = await _askText(
      l10n,
      l10n.taxSettingsAddCategory,
      l10n.taxSettingsName,
    );
    if (title == null || title.isEmpty) return;
    // Код выводится из названия: заставлять человека придумывать ещё и код
    // значит спрашивать то, что он не знает зачем. Устойчивость кода нужна
    // пресетам, а заведённая руками категория пресетом не приедет.
    final code = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await _db.taxSettingsDao.addCategory(
      code: code.isEmpty ? 'c${DateTime.now().millisecondsSinceEpoch}' : code,
      title: title,
    );
    await _refresh();
  }

  Future<String?> _askText(
    AppLocalizations l10n,
    String title,
    String label,
  ) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const ValueKey('tax-text-input'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.taxSettingsCancel),
          ),
          FilledButton(
            key: const ValueKey('tax-text-ok'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.taxSettingsAdd),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }
}

/// Доля в процентах без хвоста нулей: «2.9», а не «2.90».
String _formatRate(Decimal rate) {
  final text = rate.toString();
  if (!text.contains('.')) return text;
  final trimmed = text.replaceAll(RegExp(r'0+$'), '');
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

class _JurisdictionTile extends StatelessWidget {
  const _JurisdictionTile({
    super.key,
    required this.node,
    required this.isTillLocation,
    required this.rules,
    required this.categories,
    required this.onTillLocationChanged,
    required this.onDelete,
  });

  final domain.TaxJurisdictionNode node;
  final bool isTillLocation;
  final List<TaxRuleRow> rules;
  final List<TaxCategory> categories;
  final ValueChanged<bool> onTillLocationChanged;
  final VoidCallback onDelete;

  String _kindLabel(AppLocalizations l10n, int kind) => switch (kind) {
    1 => l10n.taxSettingsRuleZero,
    2 => l10n.taxSettingsRuleExempt,
    _ => l10n.taxSettingsRuleTaxed,
  };

  String _categoryLabel(AppLocalizations l10n, int? id) {
    if (id == null) return l10n.taxSettingsAllCategories;
    for (final c in categories) {
      if (c.id == id) return c.title;
    }
    return '#$id';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.space8),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Отступ по глубине: иерархия читается глазом, а не по
                // подписи «уровень 3».
                SizedBox(width: node.depth * 12.0),
                Expanded(
                  child: Text(node.name, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  key: ValueKey('tax-jurisdiction-delete-${node.id}'),
                  tooltip: l10n.taxSettingsDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
            SwitchListTile(
              key: ValueKey('tax-jurisdiction-till-${node.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.taxSettingsTillLocation),
              value: isTillLocation,
              onChanged: onTillLocationChanged,
            ),
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${_categoryLabel(l10n, rule.categoryId)} — '
                        '${_kindLabel(l10n, rule.kind)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${_formatRate(rule.ratePercent)}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTokens.space8),
        ...children,
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      // Названия наборов и юрисдикций приходят из файлов и от пользователя;
      // длину их никто не ограничивает, и без `isExpanded` длинное имя
      // разрывает строку.
      isExpanded: true,
      initialValue: items.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppTokens.space8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
