import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/core/utils/decimal_util.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/report_dao.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/reports/report_models.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_kpi_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';

class _ProfitKpi {
  const _ProfitKpi({
    required this.revenue,
    required this.count,
    required this.avgCheck,
    required this.expenses,
    required this.refundTotal,
  });
  final Decimal revenue;
  final int count;
  final Decimal avgCheck;
  final Decimal expenses;
  final Decimal refundTotal;
}

class _ProductProfit {
  const _ProductProfit({
    required this.name,
    required this.revenue,
    required this.costPrice,
    required this.profit,
    required this.marginPct,
  });
  final String name;
  final Decimal revenue;
  final Decimal costPrice;
  final Decimal profit;
  final double marginPct;
}

ReportDao get _reportDao {
  final db = GetIt.I<AppDatabase>();
  return ReportDao(db);
}

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

DateTime _dateFromBucket(int dayBucket) =>
    DateTime.fromMillisecondsSinceEpoch(dayBucket * 86400 * 1000);

final _profitProvider = FutureProvider.family<_ProfitKpi, DateTimeRange>((
  ref,
  range,
) async {
  final dao = _reportDao;
  final startTs = _toTs(range.start);
  final endTs = _toTs(range.end);

  final row = await dao.getTotalRevenue(startTs, endTs);
  final revenue = row.readDecimal('total_revenue');
  final saleCount = (row.read<int?>('sale_count') ?? 0);
  final avgCheck = saleCount > 0
      ? (revenue / Decimal.fromInt(saleCount))
            .toDecimal(scaleOnInfinitePrecision: 3)
            .money
      : Decimal.zero;

  final cashFlowRows = await dao.getCashFlow(startTs, endTs);
  var expenses = Decimal.zero;
  for (final r in cashFlowRows) {
    final type = r.read<int>('type');
    if (type == 1) {
      expenses += r.readDecimal('total');
    }
  }

  final refundRows = await dao.getRefundTrend(startTs, endTs);
  var refundTotal = Decimal.zero;
  for (final r in refundRows) {
    refundTotal += r.readDecimal('refund_total');
  }

  return _ProfitKpi(
    revenue: revenue,
    count: saleCount,
    avgCheck: avgCheck,
    expenses: expenses,
    refundTotal: refundTotal,
  );
});

final _cashFlowProvider =
    FutureProvider.family<List<CashFlowItem>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getCashFlow(_toTs(range.start), _toTs(range.end));

      return rows.map((r) {
        return CashFlowItem(
          dayTimestamp: r.read<int>('day_bucket'),
          type: r.read<int>('type'),
          total: r.readDecimal('total'),
        );
      }).toList();
    });

final _refundProvider = FutureProvider.family<List<RefundTrend>, DateTimeRange>(
  (ref, range) async {
    final dao = _reportDao;
    final rows = await dao.getRefundTrend(_toTs(range.start), _toTs(range.end));

    return rows.map((r) {
      return RefundTrend(
        dayTimestamp: r.read<int>('day_bucket'),
        count: r.read<int>('refund_count'),
        total: r.readDecimal('refund_total'),
      );
    }).toList();
  },
);

final _productProfitProvider =
    FutureProvider.family<List<_ProductProfit>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getProductProfit(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return _ProductProfit(
          name: r.read<String?>('name') ?? 'N/A',
          revenue: r.readDecimal('revenue'),
          costPrice: r.readDecimal('cost_price'),
          profit: r.readDecimal('profit'),
          marginPct: r.read<double?>('margin_pct') ?? 0.0,
        );
      }).toList();
    });

class FinanceTab extends ConsumerWidget {
  const FinanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportState = ref.watch(reportsProvider);
    final range = reportState.dateRange;

    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(_profitProvider);
      ref.invalidate(_cashFlowProvider);
      ref.invalidate(_refundProvider);
      ref.invalidate(_productProfitProvider);
    });

    final kpiAsync = ref.watch(_profitProvider(range));
    final cashFlowAsync = ref.watch(_cashFlowProvider(range));
    final refundAsync = ref.watch(_refundProvider(range));
    final profitAsync = ref.watch(_productProfitProvider(range));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (kpi) => _buildKpiRow(kpi, l10n),
            loading: () => _buildKpiRowLoading(),
            error: (e, _) => _buildKpiRowError(context, e, l10n),
          ),

          const SizedBox(height: 20),

          cashFlowAsync.when(
            data: (data) => _buildCashFlowChart(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repCashFlowTitle),
            error: (e, _) =>
                _buildChartError(context, l10n.repCashFlowTitle, e, l10n),
          ),

          const SizedBox(height: 20),

          profitAsync.when(
            data: (data) => _buildTopProfitableChart(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repTopProfitableTitle),
            error: (e, _) =>
                _buildChartError(context, l10n.repTopProfitableTitle, e, l10n),
          ),

          const SizedBox(height: 20),

          profitAsync.when(
            data: (data) => _buildProductProfitTable(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repProductProfitTitle),
            error: (e, _) =>
                _buildChartError(context, l10n.repProductProfitTitle, e, l10n),
          ),

          const SizedBox(height: 20),

          refundAsync.when(
            data: (data) => _buildRefundTrendChart(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repRefundTrendTitle),
            error: (e, _) =>
                _buildChartError(context, l10n.repRefundTrendTitle, e, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(_ProfitKpi kpi, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cards = [
          ReportKpiCard(
            title: l10n.repKpiRevenue,
            value: ReportMoney.full(kpi.revenue),
            icon: Icons.monetization_on_outlined,
            color: AppColors.info,
            subtitle: l10n.repSubtitleForPeriod,
          ),
          ReportKpiCard(
            title: l10n.repKpiExpenses,
            value: ReportMoney.full(kpi.expenses),
            icon: Icons.money_off_outlined,
            color: AppColors.warning,
            subtitle: l10n.repSubtitleCashExpenses,
          ),
          ReportKpiCard(
            title: l10n.repKpiRefunds,
            value: ReportMoney.full(kpi.refundTotal),
            icon: Icons.assignment_return_outlined,
            color: Theme.of(context).colorScheme.error,
            subtitle: l10n.repSubtitleRefundTotal,
          ),
          ReportKpiCard(
            title: l10n.repKpiSales,
            value: '${kpi.count}',
            icon: Icons.receipt_long_outlined,
            color: AppColors.success,
            subtitle: l10n.repSubtitleReceipts,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKpiRowLoading() {
    return const SizedBox(
      height: 100,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildKpiRowError(
    BuildContext context,
    Object error,
    AppLocalizations l10n,
  ) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Text(
        '${l10n.repKpiLoadError}: $error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildCashFlowChart(
    BuildContext context,
    List<CashFlowItem> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repCashFlowTitle,
        subtitle: l10n.repNoDataForPeriod,
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

    final dayMap = <int, Map<int, double>>{};
    for (final item in data) {
      final dayKey = _dateFromBucket(item.dayTimestamp).millisecondsSinceEpoch;
      dayMap.putIfAbsent(dayKey, () => {});
      dayMap[dayKey]![item.type] = item.total.toDouble();
    }

    final sortedDays = dayMap.keys.toList()..sort();
    final dates = sortedDays
        .map((ms) => DateTime.fromMillisecondsSinceEpoch(ms))
        .toList();

    double maxStacked = 0;
    for (final dayAmounts in dayMap.values) {
      final total = dayAmounts.values.fold(0.0, (s, v) => s + v);
      if (total > maxStacked) maxStacked = total;
    }

    final interval = _niceInterval(maxStacked);

    return ReportChartCard(
      title: l10n.repCashFlowTitle,
      subtitle: l10n.repDaysCount(dates.length),
      height: 280,
      onExport: () {
        final rows = <List<dynamic>>[];
        for (var i = 0; i < sortedDays.length; i++) {
          final d = dates[i];
          final amounts = dayMap[sortedDays[i]]!;
          rows.add([
            '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
            (amounts[0] ?? 0.0).toStringAsFixed(2),
            (amounts[1] ?? 0.0).toStringAsFixed(2),
            (amounts[2] ?? 0.0).toStringAsFixed(2),
          ]);
        }
        ReportExportButton.exportCsv(context, 'finance_cash_flow', [
          l10n.globalDate,
          l10n.repCashFlowInvestments,
          l10n.repCashFlowExpenses,
          l10n.repCashFlowDividends,
        ], rows);
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(
                  color: AppColors.success,
                  label: l10n.repCashFlowInvestments,
                ),
                const SizedBox(width: 16),
                _LegendDot(
                  color: AppColors.warning,
                  label: l10n.repCashFlowExpenses,
                ),
                const SizedBox(width: 16),
                _LegendDot(
                  color: Theme.of(context).colorScheme.error,
                  label: l10n.repCashFlowDividends,
                ),
              ],
            ),
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxStacked * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.onSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dayKey = sortedDays[group.x.toInt()];
                      final amounts = dayMap[dayKey] ?? {};
                      final d = DateTime.fromMillisecondsSinceEpoch(dayKey);
                      final investment = DecimalUtil.fromDouble(
                        amounts[0] ?? 0.0,
                      );
                      final expense = DecimalUtil.fromDouble(amounts[1] ?? 0.0);
                      final dividend = DecimalUtil.fromDouble(
                        amounts[2] ?? 0.0,
                      );
                      return BarTooltipItem(
                        '${d.day}.${d.month.toString().padLeft(2, '0')}\n'
                        '${l10n.repInvestmentsLine(ReportMoney.withCurrency(investment))}\n'
                        '${l10n.repExpensesLine(ReportMoney.withCurrency(expense))}\n'
                        '${l10n.repDividendsLine(ReportMoney.withCurrency(dividend))}',
                        const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
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
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: math.max(1, dates.length / 6).roundToDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= dates.length) {
                          return const SizedBox.shrink();
                        }
                        final d = dates[idx];
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${d.day}.${d.month.toString().padLeft(2, '0')}',
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
                      interval: interval,
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
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: context.semantic.canvas, strokeWidth: 1),
                ),
                barGroups: [
                  for (var i = 0; i < sortedDays.length; i++)
                    _buildStackedBarGroup(context, i, dayMap[sortedDays[i]]!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildStackedBarGroup(
    BuildContext context,
    int x,
    Map<int, double> amounts,
  ) {
    final investment = amounts[0] ?? 0.0;
    final expense = amounts[1] ?? 0.0;
    final dividend = amounts[2] ?? 0.0;

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: investment + expense + dividend,
          rodStackItems: [
            BarChartRodStackItem(0, investment, AppColors.success),
            BarChartRodStackItem(
              investment,
              investment + expense,
              AppColors.warning,
            ),
            BarChartRodStackItem(
              investment + expense,
              investment + expense + dividend,
              Theme.of(context).colorScheme.error,
            ),
          ],
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          color: Colors.transparent,
        ),
      ],
    );
  }

  Widget _buildRefundTrendChart(
    BuildContext context,
    List<RefundTrend> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repRefundTrendTitle,
        subtitle: l10n.repNoDataForPeriod,
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

    final dates = data.map((d) => _dateFromBucket(d.dayTimestamp)).toList();
    final totals = data.map((d) => d.total.toDouble()).toList();
    final maxTotal = totals.reduce(math.max);
    final interval = _niceInterval(maxTotal);

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), totals[i]));
    }

    return ReportChartCard(
      title: l10n.repRefundTrendTitle,
      subtitle: l10n.repDaysCount(data.length),
      height: 280,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'finance_refunds',
        [l10n.globalDate, l10n.globalQuantity, l10n.globalAmount],
        [
          for (var i = 0; i < data.length; i++)
            [
              '${dates[i].day.toString().padLeft(2, '0')}.${dates[i].month.toString().padLeft(2, '0')}.${dates[i].year}',
              data[i].count.toString(),
              data[i].total.toStringAsFixed(2),
            ],
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxTotal * 1.15,
          gridData: FlGridData(
            show: true,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: context.semantic.canvas, strokeWidth: 1),
            drawVerticalLine: false,
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
                interval: math.max(1, data.length / 6).roundToDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final d = dates[idx];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${d.day}.${d.month.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                interval: interval,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      ReportMoney.compact(value),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final d = idx < dates.length ? dates[idx] : DateTime.now();
                  final cnt = idx < data.length ? data[idx].count : 0;
                  return LineTooltipItem(
                    '${d.day}.${d.month.toString().padLeft(2, '0')}\n'
                    '${ReportMoney.withCurrency(DecimalUtil.fromDouble(spot.y))}\n'
                    '${l10n.repReturnsCount(cnt)}',
                    const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: Theme.of(context).colorScheme.error,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: data.length <= 31,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 3,
                      color: Theme.of(context).colorScheme.error,
                      strokeWidth: 1.5,
                      strokeColor: AppColors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.25),
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProfitableChart(
    BuildContext context,
    List<_ProductProfit> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repTopProfitableTitle,
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

    final displayData = data.take(10).toList();
    final profits = displayData.map((d) => d.profit.toDouble()).toList();
    final maxProfit = profits.reduce(math.max);
    final interval = _niceInterval(maxProfit);

    return ReportChartCard(
      title: l10n.repTopProfitableTitle,
      subtitle: l10n.repTopProfitableSubtitle,
      height: 280,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'finance_top_profitable',
        [
          l10n.inventoryProduct,
          l10n.repColRevenue,
          l10n.dishTabCosting,
          l10n.dishProfitLabel,
          l10n.repColMarginPct,
        ],
        displayData
            .map(
              (d) => [
                d.name,
                d.revenue.toStringAsFixed(2),
                d.costPrice.toStringAsFixed(2),
                d.profit.toStringAsFixed(2),
                '${d.marginPct.toStringAsFixed(1)}%',
              ],
            )
            .toList(),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxProfit * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final product = displayData[group.x.toInt()];
                return BarTooltipItem(
                  '${product.name}\n'
                  '${l10n.repProfitLine(ReportMoney.withCurrency(product.profit))}\n'
                  '${l10n.repMarginLine(product.marginPct.toStringAsFixed(1))}',
                  const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
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
                reservedSize: 52,
                interval: interval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    ReportMoney.compact(value),
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
                  if (idx < 0 || idx >= displayData.length) {
                    return const SizedBox.shrink();
                  }
                  final name = displayData[idx].name;
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
            for (var i = 0; i < displayData.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: profits[i],
                    color: AppColors.success,
                    width: 24,
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

  Widget _buildProductProfitTable(
    BuildContext context,
    List<_ProductProfit> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repProductProfitTitle,
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

    final displayData = data.take(20).toList();

    return ReportChartCard(
      title: l10n.repProductProfitTitle,
      subtitle: l10n.repProductProfitSubtitle,
      height: math.min(56.0 + displayData.length * 48.0, 500),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'finance_product_profit',
        [
          l10n.inventoryProduct,
          l10n.repColRevenue,
          l10n.dishTabCosting,
          l10n.dishProfitLabel,
          l10n.repColMarginPct,
        ],
        data
            .map(
              (d) => [
                d.name,
                d.revenue.toStringAsFixed(2),
                d.costPrice.toStringAsFixed(2),
                d.profit.toStringAsFixed(2),
                '${d.marginPct.toStringAsFixed(1)}%',
              ],
            )
            .toList(),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            DataColumn(label: Text(l10n.repColProduct)),
            DataColumn(label: Text(l10n.repColRevenue), numeric: true),
            DataColumn(label: Text(l10n.repColCostShort), numeric: true),
            DataColumn(label: Text(l10n.repColProfit), numeric: true),
            DataColumn(label: Text(l10n.repColMarginPct), numeric: true),
          ],
          rows: displayData
              .map(
                (d) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Text(
                          d.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        ReportMoney.full(d.revenue),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        ReportMoney.full(d.costPrice),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        ReportMoney.full(d.profit),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: d.profit >= Decimal.zero
                              ? AppColors.success
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (d.marginPct >= 0
                                      ? AppColors.success
                                      : Theme.of(context).colorScheme.error)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${d.marginPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: d.marginPct >= 0
                                ? AppColors.success
                                : Theme.of(context).colorScheme.error,
                            fontSize: 13,
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
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
