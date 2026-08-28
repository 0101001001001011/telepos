import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class _ShiftSummary {
  _ShiftSummary({
    required this.shift,
    required this.cashier,
    required this.salesTotal,
    required this.refundsTotal,
    required this.salesCount,
    required this.refundsCount,
  });

  final Shift shift;
  final String cashier;
  final Decimal salesTotal;
  final Decimal refundsTotal;
  final int salesCount;
  final int refundsCount;
}

class ShiftHistoryScreen extends ConsumerStatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  ConsumerState<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends ConsumerState<ShiftHistoryScreen> {
  List<_ShiftSummary> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = GetIt.I<AppDatabase>();
      final shifts = await db.shiftDao.findClosedShifts(limit: 100);

      final users = await db.select(db.users).get();
      final names = {for (final u in users) u.id: u.name};

      final items = <_ShiftSummary>[];
      for (final s in shifts) {
        final from = s.openTime;
        final to = s.closeTime ?? (1 << 62);
        final salesRow = await db
            .customSelect(
              'SELECT COUNT(*) c, COALESCE(SUM(amount),0) t FROM sales '
              'WHERE time >= ? AND time <= ? AND state NOT IN (0,3)',
              variables: [
                drift.Variable.withInt(from),
                drift.Variable.withInt(to),
              ],
              readsFrom: {db.sales},
            )
            .getSingle();
        final refRow = await db
            .customSelect(
              'SELECT COUNT(*) c, COALESCE(SUM(amount),0) t FROM refunds '
              'WHERE time >= ? AND time <= ? AND state NOT IN (0)',
              variables: [
                drift.Variable.withInt(from),
                drift.Variable.withInt(to),
              ],
              readsFrom: {db.refunds},
            )
            .getSingle();
        items.add(
          _ShiftSummary(
            shift: s,
            cashier: names[s.userId] ?? '#${s.userId}',
            salesTotal: Decimal.parse(
              salesRow.read<double>('t').toStringAsFixed(2),
            ),
            refundsTotal: Decimal.parse(
              refRow.read<double>('t').toStringAsFixed(2),
            ),
            salesCount: salesRow.read<int>('c'),
            refundsCount: refRow.read<int>('c'),
          ),
        );
      }
      if (mounted)
        setState(() {
          _items = items;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(int unixSec) {
    final d = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000);
    String t(int v) => v.toString().padLeft(2, '0');
    return '${t(d.day)}.${t(d.month)}.${d.year} ${t(d.hour)}:${t(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shiftHistoryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.globalRefresh,
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Text(
                l10n.shiftHistoryEmpty,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _card(_items[i], l10n),
            ),
    );
  }

  Widget _card(_ShiftSummary s, AppLocalizations l10n) {
    final closed = s.shift.closeTime;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.point_of_sale,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.shiftHistoryShiftNo(s.shift.id)} · ${s.cashier}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_fmt(s.shift.openTime)} → ${closed != null ? _fmt(closed) : '—'}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(
                l10n.shiftHistorySales,
                '${s.salesTotal} ₸',
                '${s.salesCount}',
                AppColors.success,
              ),
              _stat(
                l10n.shiftHistoryRefunds,
                '${s.refundsTotal} ₸',
                '${s.refundsCount}',
                AppColors.warning,
              ),
              _stat(
                l10n.shiftHistoryOpeningCash,
                '${s.shift.openingCash ?? 0} ₸',
                '',
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        if (count.isNotEmpty)
          Text(
            '×$count',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
