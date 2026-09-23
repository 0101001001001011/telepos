import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/utils/decimal_util.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/report_dao.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/reports/report_models.dart';
import 'package:telepos/presentation/common/widgets/scroll_assist.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';

ReportDao get _reportDao {
  final db = GetIt.I<AppDatabase>();
  return ReportDao(db);
}

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

DateTime _dateFromBucket(int dayBucket) =>
    DateTime.fromMillisecondsSinceEpoch(dayBucket * 86400 * 1000);

final _revenueByDayProvider =
    FutureProvider.family<List<RevenueByDay>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getRevenueByDay(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return RevenueByDay(
          dayTimestamp: r.read<int>('day_bucket'),
          revenue: r.readDecimal('revenue'),
          count: r.read<int>('cnt'),
        );
      }).toList();
    });

final _hourlyProvider =
    FutureProvider.family<List<HourlyDistribution>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getHourlyDistribution(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return HourlyDistribution(
          hour: r.read<int>('hour_of_day'),
          count: r.read<int>('cnt'),
          revenue: r.readDecimal('revenue'),
        );
      }).toList();
    });

final _cashierProvider =
    FutureProvider.family<List<CashierPerformance>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getCashierPerformance(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return CashierPerformance(
          userId: r.read<int?>('user_id') ?? 0,
          name: r.read<String?>('name') ?? 'N/A',
          saleCount: r.read<int>('sale_count'),
          revenue: r.readDecimal('revenue'),
        );
      }).toList();
    });

class SalesTab extends ConsumerStatefulWidget {
  const SalesTab({super.key});

  @override
  ConsumerState<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends ConsumerState<SalesTab> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reportState = ref.watch(reportsProvider);
    final range = reportState.dateRange;

    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(_revenueByDayProvider);
      ref.invalidate(_hourlyProvider);
      ref.invalidate(_cashierProvider);
    });

    final revenueAsync = ref.watch(_revenueByDayProvider(range));
    final hourlyAsync = ref.watch(_hourlyProvider(range));
    final cashierAsync = ref.watch(_cashierProvider(range));

    return ScrollAssist(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            revenueAsync.when(
              data: (data) => _buildRevenueByDayChart(context, data),
              loading: () => _buildChartLoading(l10n.repChartRevenueByDay),
              error: (e, _) => _buildChartError(l10n.repChartRevenueByDay, e),
            ),

            const SizedBox(height: 16),

            hourlyAsync.when(
              data: (data) => _buildHourlyChart(context, data),
              loading: () => _buildChartLoading(l10n.repHourlyDistribution),
              error: (e, _) => _buildChartError(l10n.repHourlyDistribution, e),
            ),

            const SizedBox(height: 16),

            cashierAsync.when(
              data: (data) => _buildCashierTable(context, data),
              loading: () => _buildChartLoading(l10n.repCashierPerformance),
              error: (e, _) => _buildChartError(l10n.repCashierPerformance, e),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueByDayChart(
    BuildContext context,
    List<RevenueByDay> data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repChartRevenueByDay,
        subtitle: l10n.repNoDataForPeriod,
        child: Center(
          child: Text(
            l10n.serviceNoOrders,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final dates = data.map((d) => _dateFromBucket(d.dayTimestamp)).toList();
    final revenues = data.map((d) => d.revenue.toDouble()).toList();
    final maxRevenue = revenues.reduce(math.max);
    final interval = _niceInterval(maxRevenue);

    return ReportChartCard(
      title: l10n.repChartRevenueByDay,
      subtitle: l10n.repDaysCountTapHint(data.length),
      height: 280,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'sales_revenue_by_day',
        [l10n.globalDate, l10n.repColRevenue, l10n.globalQuantity],
        [
          for (var i = 0; i < data.length; i++)
            [
              '${dates[i].day.toString().padLeft(2, '0')}.${dates[i].month.toString().padLeft(2, '0')}.${dates[i].year}',
              data[i].revenue.toStringAsFixed(2),
              data[i].count.toString(),
            ],
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue * 1.15,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final idx = group.x.toInt();
                final item = data[idx];
                final d = dates[idx];
                return BarTooltipItem(
                  '${d.day}.${d.month.toString().padLeft(2, '0')}\n'
                  '${ReportMoney.withCurrency(item.revenue)}\n'
                  '${l10n.repReceiptsCount(item.count)}',
                  const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            touchCallback: (FlTouchEvent event, barTouchResponse) {
              if (event is FlTapUpEvent &&
                  barTouchResponse != null &&
                  barTouchResponse.spot != null) {
                final idx = barTouchResponse.spot!.touchedBarGroupIndex;
                if (idx >= 0 && idx < data.length) {
                  _showDayDetailDialog(context, data[idx]);
                }
              }
            },
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
                interval: math.max(1, data.length / 7).roundToDouble(),
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
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: interval,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: context.semantic.canvas, strokeWidth: 1),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: revenues[i],
                    color: AppColors.info,
                    width: math.max(4, 600 / (data.length * 2)),
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

  void _showDayDetailDialog(BuildContext context, RevenueByDay day) {
    final l10n = AppLocalizations.of(context)!;
    final d = _dateFromBucket(day.dayTimestamp);
    final avgCheck = day.count > 0
        ? (day.revenue / Decimal.fromInt(day.count))
              .toDecimal(scaleOnInfinitePrecision: 3)
              .money
        : Decimal.zero;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              label: l10n.repColRevenue,
              value: ReportMoney.withCurrency(day.revenue),
            ),
            _DetailRow(label: l10n.repReceiptCountLabel, value: '${day.count}'),
            _DetailRow(
              label: l10n.repKpiAvgCheck,
              value: ReportMoney.withCurrency(avgCheck),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalClose),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(
    BuildContext context,
    List<HourlyDistribution> data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repHourlyDistribution,
        subtitle: l10n.repNoDataForPeriod,
        child: Center(
          child: Text(
            l10n.serviceNoOrders,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final hourMap = <int, HourlyDistribution>{};
    for (final item in data) {
      hourMap[item.hour] = item;
    }
    final fullDay = List.generate(24, (h) {
      return hourMap[h] ??
          HourlyDistribution(hour: h, count: 0, revenue: Decimal.zero);
    });

    final maxCount = fullDay.map((d) => d.count).reduce(math.max).toDouble();
    final countInterval = _niceInterval(maxCount);

    return ReportChartCard(
      title: l10n.repHourlyDistribution,
      subtitle: l10n.repSalesCountByHour,
      height: 280,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'sales_hourly',
        [l10n.repColHour, l10n.globalQuantity, l10n.repColRevenue],
        fullDay
            .map(
              (d) => [
                '${d.hour}:00',
                d.count.toString(),
                d.revenue.toStringAsFixed(2),
              ],
            )
            .toList(),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount * 1.15,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = fullDay[group.x.toInt()];
                return BarTooltipItem(
                  '${item.hour}:00 - ${item.hour}:59\n'
                  '${l10n.repSalesCountLine(item.count)}\n'
                  '${ReportMoney.withCurrency(item.revenue)}',
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
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 3,
                getTitlesWidget: (value, meta) {
                  final h = value.toInt();
                  if (h < 0 || h >= 24 || h % 3 != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '$h:00',
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
                reservedSize: 40,
                interval: countInterval,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toInt().toString(),
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
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: countInterval,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: context.semantic.canvas, strokeWidth: 1),
          ),
          barGroups: [
            for (var i = 0; i < fullDay.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: fullDay[i].count.toDouble(),
                    color: AppColors.warning,
                    width: 12,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashierTable(
    BuildContext context,
    List<CashierPerformance> data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repCashierPerformance,
        subtitle: l10n.repNoDataForPeriod,
        child: Center(
          child: Text(
            l10n.serviceNoOrders,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ReportChartCard(
      title: l10n.repCashierPerformance,
      subtitle: l10n.repCashiersCount(data.length),
      height: math.max(250, (data.length * 48 + 56).toDouble()),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'sales_cashiers',
        [l10n.loginCashier, l10n.syncSales, l10n.repColRevenue],
        data
            .map(
              (d) => [
                d.name,
                d.saleCount.toString(),
                d.revenue.toStringAsFixed(2),
              ],
            )
            .toList(),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(selectedSurfaceOf(context)),
          columnSpacing: 32,
          columns: [
            DataColumn(
              label: Text(
                l10n.loginCashier,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                l10n.syncSales,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                l10n.repColRevenue,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              numeric: true,
            ),
          ],
          rows: [
            for (final cashier in data)
              DataRow(
                cells: [
                  DataCell(
                    Text(cashier.name, style: const TextStyle(fontSize: 13)),
                  ),
                  DataCell(
                    Text(
                      '${cashier.saleCount}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      ReportMoney.withCurrency(cashier.revenue),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
          ],
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

  Widget _buildChartError(String title, Object error) {
    return ReportChartCard(
      title: title,
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.repErrorWith('$error'),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
