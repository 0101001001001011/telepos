import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:decimal/decimal.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/data/database/daos/report_dao.dart';
import 'package:telepos/presentation/controllers/reports/report_models.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';

class _PriceHistoryEntry {
  const _PriceHistoryEntry({
    required this.ucode,
    required this.productName,
    required this.supplierName,
    required this.editTime,
    required this.unitPrice,
    required this.quantity,
  });
  final int ucode;
  final String productName;
  final String supplierName;
  final int editTime;
  final Decimal unitPrice;
  final Decimal quantity;
}

class _PriceChange {
  const _PriceChange({
    required this.productName,
    required this.supplierName,
    required this.oldPrice,
    required this.newPrice,
    required this.changePct,
    required this.date,
  });
  final String productName;
  final String supplierName;
  final Decimal oldPrice;
  final Decimal newPrice;
  final double changePct;
  final DateTime date;
}

ReportDao get _reportDao {
  final db = GetIt.I<AppDatabase>();
  return ReportDao(db);
}

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

final _supplierVolumeProvider =
    FutureProvider.family<List<SupplierVolume>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getSupplierVolume(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return SupplierVolume(
          localId: r.read<int?>('supplier_id') ?? 0,
          name: r.read<String?>('name') ?? 'N/A',
          supplyCount: r.read<int>('supply_count'),
        );
      }).toList();
    });

final _priceHistoryProvider =
    FutureProvider.family<List<_PriceHistoryEntry>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getSupplierPriceHistory(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return _PriceHistoryEntry(
          ucode: r.read<int>('ucode'),
          productName: r.read<String?>('name') ?? 'N/A',
          supplierName: r.read<String?>('supplier_name') ?? 'N/A',
          editTime: r.read<int>('edit_time'),
          unitPrice: r.readDecimal('unit_price'),
          quantity: r.readDecimal('quantity'),
        );
      }).toList();
    });

final _priceChangesProvider =
    FutureProvider.family<List<_PriceChange>, DateTimeRange>((
      ref,
      range,
    ) async {
      final history = await ref.watch(_priceHistoryProvider(range).future);

      final grouped = <int, List<_PriceHistoryEntry>>{};
      for (final e in history) {
        grouped.putIfAbsent(e.ucode, () => []).add(e);
      }

      final changes = <_PriceChange>[];
      for (final entries in grouped.values) {
        if (entries.length < 2) continue;
        for (var i = 1; i < entries.length; i++) {
          final prev = entries[i - 1];
          final curr = entries[i];
          if (prev.unitPrice != curr.unitPrice &&
              prev.unitPrice > Decimal.zero) {
            final changePct =
                ((curr.unitPrice - prev.unitPrice) / prev.unitPrice)
                    .toDouble() *
                100;
            changes.add(
              _PriceChange(
                productName: curr.productName,
                supplierName: curr.supplierName,
                oldPrice: prev.unitPrice,
                newPrice: curr.unitPrice,
                changePct: changePct,
                date: DateTime.fromMillisecondsSinceEpoch(curr.editTime * 1000),
              ),
            );
          }
        }
      }

      changes.sort((a, b) => b.date.compareTo(a.date));
      return changes;
    });

class SuppliersTab extends ConsumerWidget {
  const SuppliersTab({required this.dateRange, super.key});

  final DateTimeRange dateRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(_supplierVolumeProvider);
      ref.invalidate(_priceHistoryProvider);
      ref.invalidate(_priceChangesProvider);
    });

    final suppliersAsync = ref.watch(_supplierVolumeProvider(dateRange));
    final priceHistoryAsync = ref.watch(_priceHistoryProvider(dateRange));
    final priceChangesAsync = ref.watch(_priceChangesProvider(dateRange));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          suppliersAsync.when(
            data: (data) => data.isEmpty
                ? _buildEmptyState(context, l10n)
                : Column(
                    children: [
                      _buildSupplierChart(context, data, l10n),
                      const SizedBox(height: 20),
                      _buildSupplierTable(context, data, l10n),
                    ],
                  ),
            loading: () => _buildChartLoading(l10n.repSupplierVolumeTitle),
            error: (e, _) =>
                _buildChartError(context, l10n.repSupplierVolumeTitle, e, l10n),
          ),

          const SizedBox(height: 20),

          priceHistoryAsync.when(
            data: (data) => _buildPriceTrendChart(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repPriceTrendTitle),
            error: (e, _) =>
                _buildChartError(context, l10n.repPriceTrendTitle, e, l10n),
          ),

          const SizedBox(height: 20),

          priceChangesAsync.when(
            data: (data) => _buildPriceChangesTable(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repPriceChangesShort),
            error: (e, _) =>
                _buildChartError(context, l10n.repPriceChangesShort, e, l10n),
          ),
        ],
      ),
    );
  }

  // Контекст здесь не для удобства: приглушённый цвет подписи — роль темы, и
  // взять его можно только из `Theme.of`. Без него подпись красилась дневной
  // константой и в тёмной теме сливалась с фоном.
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.repNoSupplierData,
              style: AppTextStyles.h3.copyWith(color: AppColors.textDisabled),
            ),
            const SizedBox(height: 8),
            Text(l10n.repNoSuppliesForPeriod, style: context.styles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierChart(
    BuildContext context,
    List<SupplierVolume> data,
    AppLocalizations l10n,
  ) {
    final maxCount = data.map((d) => d.supplyCount).reduce(math.max).toDouble();
    final interval = _niceInterval(maxCount);

    return ReportChartCard(
      title: l10n.repSupplierVolumeTitle,
      subtitle: l10n.repSuppliersCount(data.length),
      height: 280,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'suppliers_volume',
        [l10n.agentTypeSupplier, l10n.repColSupplyCount],
        data.map((d) => [d.name, d.supplyCount.toString()]).toList(),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final supplier = data[group.x.toInt()];
                return BarTooltipItem(
                  l10n.repSupplierTooltip(supplier.name, supplier.supplyCount),
                  const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final name = data[idx].name;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: SizedBox(
                      width: 60,
                      child: Text(
                        name.length > 10 ? '${name.substring(0, 9)}...' : name,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: context.semantic.canvas, strokeWidth: 1),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].supplyCount.toDouble(),
                    color: AppColors.info,
                    width: 28,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierTable(
    BuildContext context,
    List<SupplierVolume> data,
    AppLocalizations l10n,
  ) {
    final sorted = List<SupplierVolume>.from(data)
      ..sort((a, b) => b.supplyCount.compareTo(a.supplyCount));

    return ReportChartCard(
      title: l10n.repSupplierTableTitle,
      subtitle: l10n.repSupplierTableSubtitle,
      height: math.min(56.0 + sorted.length * 48.0, 400),
      onExport: () => ReportExportButton.exportCsv(context, 'suppliers_table', [
        l10n.agentTypeSupplier,
        l10n.repColSupplyCount,
      ], sorted.map((d) => [d.name, d.supplyCount.toString()]).toList()),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 24,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            DataColumn(label: Text(l10n.repColSupplier)),
            DataColumn(label: Text(l10n.repColSupplyCount), numeric: true),
          ],
          rows: sorted
              .map(
                (s) => DataRow(
                  cells: [
                    DataCell(
                      Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    DataCell(
                      Text(
                        '${s.supplyCount}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPriceTrendChart(
    BuildContext context,
    List<_PriceHistoryEntry> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repPriceTrendTitle,
        subtitle: l10n.repNoData,
        child: Center(
          child: Text(
            l10n.repNoData,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final grouped = <int, List<_PriceHistoryEntry>>{};
    for (final e in data) {
      grouped.putIfAbsent(e.ucode, () => []).add(e);
    }

    final topProducts = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final displayProducts = topProducts.take(5).toList();

    if (displayProducts.isEmpty ||
        displayProducts.every((e) => e.value.length < 2)) {
      return ReportChartCard(
        title: l10n.repPriceTrendTitle,
        subtitle: l10n.repNotEnoughDataForChart,
        child: Center(
          child: Text(
            l10n.repNoData,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    int minTs = data.first.editTime;
    int maxTs = data.first.editTime;
    double maxPrice = 0;
    for (final e in data) {
      if (e.editTime < minTs) minTs = e.editTime;
      if (e.editTime > maxTs) maxTs = e.editTime;
      final price = e.unitPrice.toDouble();
      if (price > maxPrice) maxPrice = price;
    }
    final tsRange = maxTs - minTs;

    final lineColors = [
      AppColors.primary,
      AppColors.info,
      AppColors.warning,
      AppColors.success,
      Theme.of(context).colorScheme.error,
    ];

    return ReportChartCard(
      title: l10n.repPriceTrendTitle,
      subtitle: l10n.repPriceTrendSubtitle,
      height: 300,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'supplier_price_history',
        [
          l10n.inventoryProduct,
          l10n.agentTypeSupplier,
          l10n.globalDate,
          l10n.globalPrice,
          l10n.tableHeaderQty,
        ],
        data.map((d) {
          final dt = DateTime.fromMillisecondsSinceEpoch(d.editTime * 1000);
          return [
            d.productName,
            d.supplierName,
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}',
            d.unitPrice.toStringAsFixed(2),
            d.quantity.toStringAsFixed(1),
          ];
        }).toList(),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (var i = 0; i < displayProducts.length; i++)
                  _LegendDot(
                    color: lineColors[i % lineColors.length],
                    label: displayProducts[i].value.first.productName,
                  ),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxPrice * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: context.semantic.canvas, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final ts = (minTs + value * tsRange / 100).round();
                        final dt = DateTime.fromMillisecondsSinceEpoch(
                          ts * 1000,
                        );
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${dt.day}.${dt.month.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            ReportMoney.compact(value),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                lineBarsData: [
                  for (var i = 0; i < displayProducts.length; i++)
                    LineChartBarData(
                      spots: displayProducts[i].value.map((e) {
                        final x = tsRange > 0
                            ? (e.editTime - minTs) / tsRange * 100
                            : 0.0;
                        return FlSpot(x, e.unitPrice.toDouble());
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: lineColors[i % lineColors.length],
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChangesTable(
    BuildContext context,
    List<_PriceChange> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repPriceChangesTitle,
        subtitle: l10n.repNoData,
        child: Center(
          child: Text(
            l10n.repNoData,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final displayData = data.take(30).toList();

    return ReportChartCard(
      title: l10n.repPriceChangesTitle,
      subtitle: l10n.repPriceChangesSubtitle,
      height: math.min(56.0 + displayData.length * 48.0, 450),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'supplier_price_changes',
        [
          l10n.inventoryProduct,
          l10n.agentTypeSupplier,
          l10n.repOldPrice,
          l10n.repNewPrice,
          l10n.repColChangePct,
          l10n.globalDate,
        ],
        data
            .map(
              (d) => [
                d.productName,
                d.supplierName,
                d.oldPrice.toStringAsFixed(2),
                d.newPrice.toStringAsFixed(2),
                '${d.changePct >= 0 ? '+' : ''}${d.changePct.toStringAsFixed(1)}%',
                '${d.date.day.toString().padLeft(2, '0')}.${d.date.month.toString().padLeft(2, '0')}.${d.date.year}',
              ],
            )
            .toList(),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            DataColumn(label: Text(l10n.repColProduct)),
            DataColumn(label: Text(l10n.repColSupplier)),
            DataColumn(label: Text(l10n.repColWas), numeric: true),
            DataColumn(label: Text(l10n.repColBecame), numeric: true),
            DataColumn(label: Text(l10n.repColChangePctShort), numeric: true),
          ],
          rows: displayData
              .map(
                (d) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          d.productName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: Text(
                          d.supplierName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        ReportMoney.full(d.oldPrice),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        ReportMoney.full(d.newPrice),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (d.changePct > 0
                                      ? Theme.of(context).colorScheme.error
                                      : AppColors.success)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${d.changePct >= 0 ? '+' : ''}${d.changePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: d.changePct > 0
                                ? Theme.of(context).colorScheme.error
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildChartLoading(String title) {
    return ReportChartCard(
      title: title,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildChartError(
    BuildContext context,
    String title,
    Object error,
    AppLocalizations l10n,
  ) {
    return ReportChartCard(
      title: title,
      child: Center(
        child: Text(
          '${l10n.repError}: $error',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  double _niceInterval(double maxValue) {
    if (maxValue <= 0) return 1;
    final rawInterval = maxValue / 5;
    final magnitude = math.pow(10, (math.log(rawInterval) / math.ln10).floor());
    final residual = rawInterval / magnitude;
    double nice;
    if (residual <= 1.5) {
      nice = 1;
    } else if (residual <= 3) {
      nice = 2;
    } else if (residual <= 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label.length > 15 ? '${label.substring(0, 14)}...' : label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
