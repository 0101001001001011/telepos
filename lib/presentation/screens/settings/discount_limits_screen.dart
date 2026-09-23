import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/discount_tables.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/role_label.dart';

/// Экран пределов ручной скидки — задача 12 плана «Полнота продажи».
///
/// # Почему он входит той же задачей, что и таблица
///
/// В `ThisPosEntries` уже лежат три колонки без единого читателя
/// (`usersAllowedToRefund` и две соседние): заведены, мигрированы и забыты.
/// `DiscountLimits` стала бы четвёртой такой, если бы таблица приехала без
/// экрана: предел, который нельзя увидеть и изменить, отличим от
/// несуществующего только чтением исходника. Поэтому таблица, читатель,
/// сторож и экран — одна работа.
///
/// # Заслонка на двух дверях — сказана словами, а не оставлена выводом
///
/// `Настройки → Политика продаж → «запретить снижение цены»` закрывает
/// **одну** дверь: правку цены строки. Скидку она не закрывает вовсе —
/// касса при пределе 100 % разрешит скидку в сто процентов, то есть отдаст
/// строку бесплатно. Владелец, включивший запрет снижения цены, обычно
/// уверен, что закрыл обе; на этом экране написано, что нет. Проба
/// «`blockPriceDecrease = true` при пределе 100 % — касса скидку РАЗРЕШАЕТ»
/// держит это утверждение фактом со стороны кассы, эта строка — со стороны
/// человека.
class DiscountLimitsScreen extends ConsumerStatefulWidget {
  const DiscountLimitsScreen({super.key});

  @override
  ConsumerState<DiscountLimitsScreen> createState() =>
      _DiscountLimitsScreenState();
}

class _DiscountLimitsScreenState extends ConsumerState<DiscountLimitsScreen> {
  AppDatabase get _db => GetIt.I<AppDatabase>();

  /// Ключи строк: `-1` (умолчание) и четыре роли.
  static const _rows = <int>[
    DiscountLimitRoles.anyRole,
    ...[0, 1, 2, 3], // UserRole.values.map((r) => r.index) — но const
  ];

  final _maxControllers = <int, TextEditingController>{};
  final _approvalControllers = <int, TextEditingController>{};

  bool _loading = true;
  bool _blockPriceDecrease = false;

  @override
  void initState() {
    super.initState();
    for (final role in _rows) {
      _maxControllers[role] = TextEditingController();
      _approvalControllers[role] = TextEditingController();
    }
    // `addPostFrameCallback`, не `initState`: правило дерева — чтение базы из
    // `initState` роняет диалоги на `InheritedWidget`.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _maxControllers.values) {
      c.dispose();
    }
    for (final c in _approvalControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final limits = await _db.select(_db.discountLimits).get();
    final pos = await _db.thisPosDao.get();
    if (!mounted) return;
    setState(() {
      for (final row in limits) {
        _maxControllers[row.role]?.text = _say(row.maxPercentPerLine);
        final approval = row.approvalAbovePercent;
        _approvalControllers[row.role]?.text = approval == null
            ? ''
            : _say(approval);
      }
      _blockPriceDecrease = pos?.isKassaPriceDecreasingBlocked ?? false;
      _loading = false;
    });
  }

  /// Число для человека: без хвоста нулей у целого предела.
  static String _say(Decimal value) => value == value.truncate()
      ? value.truncate().toString()
      : value.toString();

  /// Пустой предел роли означает «своей строки нет» — строка снимается, и
  /// роль наследует умолчание. Это не то же самое, что «ноль процентов»:
  /// ноль запрещает скидку насовсем, отсутствие строки отдаёт решение
  /// умолчанию, и различать их обязан экран, а не читатель.
  Future<void> _save(int role) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final maxText = _maxControllers[role]!.text.trim();
    final approvalText = _approvalControllers[role]!.text.trim();

    if (role != DiscountLimitRoles.anyRole && maxText.isEmpty) {
      await (_db.delete(
        _db.discountLimits,
      )..where((t) => t.role.equals(role))).go();
      _approvalControllers[role]!.text = '';
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.discountLimitsInherited)),
      );
      return;
    }

    final max = _percentOrNull(maxText);
    final approval = approvalText.isEmpty ? null : _percentOrNull(approvalText);
    if (max == null || (approvalText.isNotEmpty && approval == null)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.discountLimitsInvalid),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    await _db
        .into(_db.discountLimits)
        .insertOnConflictUpdate(
          DiscountLimitsCompanion.insert(
            role: Value(role),
            maxPercentPerLine: Value(max),
            approvalAbovePercent: Value(approval),
          ),
        );
    messenger.showSnackBar(SnackBar(content: Text(l10n.discountLimitsSaved)));
    await _load();
  }

  static Decimal? _percentOrNull(String text) {
    final value = Decimal.tryParse(text.replaceAll(',', '.'));
    if (value == null) return null;
    if (value < Decimal.zero || value > Decimal.fromInt(100)) return null;
    return value;
  }

  String _roleTitle(AppLocalizations l10n, int role) =>
      role == DiscountLimitRoles.anyRole
      ? l10n.discountLimitsDefaultRow
      : UserRole.fromIndex(role).label(l10n);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.discountLimitsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTokens.space16),
              children: [
                _Note(
                  icon: Icons.info_outline,
                  color: theme.colorScheme.primary,
                  text: l10n.discountLimitsIntro,
                ),
                const SizedBox(height: AppTokens.space12),
                // Ловушка названа словами, а не оставлена выводом владельца.
                // Показывается только когда она настоящая: запрет снижения
                // цены включён, а скидка при этом не ограничена ничем.
                if (_blockPriceDecrease && _defaultIsUnlimited) ...[
                  _Note(
                    key: const ValueKey('discount-limits-two-doors'),
                    icon: Icons.report_problem_outlined,
                    color: AppColors.warning,
                    text: l10n.discountLimitsTwoDoors,
                  ),
                  const SizedBox(height: AppTokens.space12),
                ],
                for (final role in _rows) ...[
                  _LimitRow(
                    key: ValueKey('discount-limits-row-$role'),
                    title: _roleTitle(l10n, role),
                    isDefault: role == DiscountLimitRoles.anyRole,
                    maxController: _maxControllers[role]!,
                    approvalController: _approvalControllers[role]!,
                    onSave: () => _save(role),
                  ),
                  const SizedBox(height: AppTokens.space8),
                ],
                const SizedBox(height: AppTokens.space8),
                _Note(
                  icon: Icons.hourglass_empty,
                  color: theme.colorScheme.outline,
                  text: l10n.discountLimitsApprovalNotYet,
                ),
              ],
            ),
    );
  }

  bool get _defaultIsUnlimited {
    final text = _maxControllers[DiscountLimitRoles.anyRole]!.text.trim();
    return Decimal.tryParse(text) == Decimal.fromInt(100);
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    super.key,
    required this.title,
    required this.isDefault,
    required this.maxController,
    required this.approvalController,
    required this.onSave,
  });

  final String title;
  final bool isDefault;
  final TextEditingController maxController;
  final TextEditingController approvalController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.space8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('discount-limits-max'),
                    controller: maxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.discountLimitsMaxPercent,
                      hintText: isDefault
                          ? null
                          : l10n.discountLimitsInheritHint,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: TextField(
                    controller: approvalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.discountLimitsApprovalAbove,
                      hintText: l10n.discountLimitsApprovalHint,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('discount-limits-save'),
                onPressed: onSave,
                child: Text(l10n.globalSave),
              ),
            ),
          ],
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusSection),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppTokens.iconSizeHint),
          const SizedBox(width: AppTokens.space12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
