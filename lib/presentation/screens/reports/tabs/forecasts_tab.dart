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
import 'package:telepos/core/utils/forecast_util.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/report_dao.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/reports/report_models.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

class _StockDepletion {
  const _StockDepletion({
    required this.ucode,
    required this.name,
    required this.stock,
    required this.avgDailySales,
    required this.weightedAvgDailySales,
    required this.daysUntilOut,
    required this.sparklineData,
    this.supplierName,
    this.lastPurchasePrice,
  });
  final int ucode;
  final String name;
  final double stock;
  final double avgDailySales;
  final double weightedAvgDailySales;
  final double daysUntilOut;
  final List<double> sparklineData;
  final String? supplierName;
  final Decimal? lastPurchasePrice;
}

ReportDao get _reportDao {
  final db = GetIt.I<AppDatabase>();
  return ReportDao(db);
}

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

DateTime _dateFromBucket(int dayBucket) =>
    DateTime.fromMillisecondsSinceEpoch(dayBucket * 86400 * 1000);

final _revenueHistoryProvider = FutureProvider<List<RevenueByDay>>((ref) async {
  final dao = _reportDao;
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 90));
  final rows = await dao.getRevenueByDay(_toTs(start), _toTs(now));

  return rows.map((r) {
    return RevenueByDay(
      dayTimestamp: r.read<int>('day_bucket'),
      revenue: r.readDecimal('revenue'),
      count: r.read<int>('cnt'),
    );
  }).toList();
});

final _stockDepletionExtendedProvider =
    FutureProvider.family<List<_StockDepletion>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final startTs = _toTs(range.start);
      final endTs = _toTs(range.end);

      final rows = await dao.getStockDepletionExtended(startTs, endTs);

      final supplierRows = await dao.getLastSupplierForProducts();
      final supplierMap = <int, String>{};
      for (final row in supplierRows) {
        final ucode = row.read<int>('ucode');
        final name = row.read<String?>('supplier_name');
        if (name != null) supplierMap[ucode] = name;
      }

      final now = DateTime.now();
      final sparkStart = _toTs(now.subtract(const Duration(days: 7)));
      final sparkEnd = _toTs(now);

      final results = <_StockDepletion>[];

      for (final r in rows) {
        final ucode = r.read<int>('ucode');
        final name = r.read<String?>('name') ?? 'N/A';
        final stock = r.read<double?>('stock') ?? 0.0;
        final totalSold = r.read<double?>('total_sold') ?? 0.0;
        final daysInRange = r.read<double?>('days_in_range') ?? 1.0;
        final effectiveDays = daysInRange > 0 ? daysInRange : 1.0;
        final avgDailySales = totalSold / effectiveDays;
        final lastPurchasePrice = r.readDecimalOrNull('last_purchase_price');

        final dailyRows = await dao.getDailyProductSales(
          sparkStart,
          sparkEnd,
          ucode,
        );
        final sparkline = dailyRows
            .map((dr) => dr.read<double?>('qty_sold') ?? 0.0)
            .toList();

        final weightedAvg = _weightedMovingAverage(sparkline);
        final effectiveAvg = weightedAvg > 0 ? weightedAvg : avgDailySales;
        final daysUntilOut = effectiveAvg > 0
            ? stock / effectiveAvg
            : double.infinity;

        results.add(
          _StockDepletion(
            ucode: ucode,
            name: name,
            stock: stock,
            avgDailySales: avgDailySales,
            weightedAvgDailySales: effectiveAvg,
            daysUntilOut: daysUntilOut,
            sparklineData: sparkline,
            supplierName: supplierMap[ucode],
            lastPurchasePrice: lastPurchasePrice,
          ),
        );
      }

      results.sort((a, b) => a.daysUntilOut.compareTo(b.daysUntilOut));
      return results;
    });

double _weightedMovingAverage(List<double> data) {
  if (data.isEmpty) return 0;
  double weightedSum = 0;
  double weightTotal = 0;
  for (int i = 0; i < data.length; i++) {
    final weight = (i + 1).toDouble();
    weightedSum += data[i] * weight;
    weightTotal += weight;
  }
  return weightTotal > 0 ? weightedSum / weightTotal : 0;
}

enum _SortColumn { name, stock, avgSales, daysLeft }

class ForecastsTab extends ConsumerStatefulWidget {
  const ForecastsTab({required this.dateRange, super.key});

  final DateTimeRange dateRange;

  @override
  ConsumerState<ForecastsTab> createState() => _ForecastsTabState();
}

class _ForecastsTabState extends ConsumerState<ForecastsTab> {
  int _forecastHorizon = 14;
  _SortColumn _sortColumn = _SortColumn.daysLeft;
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(_revenueHistoryProvider);
      ref.invalidate(_stockDepletionExtendedProvider);
    });

    final revenueAsync = ref.watch(_revenueHistoryProvider);
    final depletionAsync = ref.watch(
      _stockDepletionExtendedProvider(widget.dateRange),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          revenueAsync.when(
            data: (data) => _buildRevenueForecast(data),
            loading: () => _buildChartLoading(l10n.repRevenueForecast),
            error: (e, _) => _buildChartError(l10n.repRevenueForecast, e),
          ),

          const SizedBox(height: 20),

          depletionAsync.when(
            data: (data) => data.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildDepletionTable(data),
                      const SizedBox(height: 20),
                      _buildRecommendedPurchases(data),
                    ],
                  ),
            loading: () => _buildChartLoading(l10n.repStockForecast),
            error: (e, _) => _buildChartError(l10n.repStockForecast, e),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, size: 64, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(
              l10n.repNoForecastData,
              style: AppTextStyles.h3.copyWith(color: AppColors.textDisabled),
            ),
            const SizedBox(height: 8),
            Text(l10n.repNotEnoughSalesData, style: context.styles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueForecast(List<RevenueByDay> data) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repRevenueForecastHw,
        subtitle: l10n.repNoDataLast90,
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

    final revenueValues = data.map((d) => d.revenue.toDouble()).toList();
    final dates = data.map((d) => _dateFromBucket(d.dayTimestamp)).toList();

    final seasonLength = HoltWinters.detectSeasonLength(revenueValues);

    final forecastValues = HoltWinters.forecast(
      data: revenueValues,
      seasonLength: seasonLength,
      forecastHorizon: _forecastHorizon,
    );

    final displayStart = math.max(0, data.length - 30);
    final displayRevenues = revenueValues.sublist(displayStart);
    final displayDates = dates.sublist(displayStart);
    final actualSpots = <FlSpot>[];
    for (var i = 0; i < displayRevenues.length; i++) {
      actualSpots.add(FlSpot(i.toDouble(), displayRevenues[i]));
    }

    final forecastSpots = <FlSpot>[
      FlSpot((displayRevenues.length - 1).toDouble(), displayRevenues.last),
    ];
    final upperBound = <FlSpot>[
      FlSpot((displayRevenues.length - 1).toDouble(), displayRevenues.last),
    ];
    final lowerBound = <FlSpot>[
      FlSpot((displayRevenues.length - 1).toDouble(), displayRevenues.last),
    ];

    for (var i = 0; i < _forecastHorizon; i++) {
      final x = (displayRevenues.length + i).toDouble();
      final val = forecastValues[i];
      forecastSpots.add(FlSpot(x, val));
      upperBound.add(FlSpot(x, val * 1.20));
      lowerBound.add(FlSpot(x, math.max(0, val * 0.80)));
    }

    final allYValues = [
      ...displayRevenues,
      ...forecastValues,
      ...forecastValues.map((v) => v * 1.20),
    ];
    final maxY = allYValues.reduce(math.max);
    final interval = _niceInterval(maxY);
    final totalPoints = displayRevenues.length + _forecastHorizon;

    final algorithmLabel = revenueValues.length >= seasonLength * 2
        ? l10n.repHoltWintersSeason(seasonLength)
        : l10n.repForecastSmaLowData;

    return ReportChartCard(
      title: l10n.repRevenueForecast,
      subtitle: l10n.repForecastSubtitle(
        displayRevenues.length,
        _forecastHorizon,
        algorithmLabel,
      ),
      height: 320,
      onExport: () {
        final rows = <List<dynamic>>[];
        for (var i = 0; i < displayRevenues.length; i++) {
          final d = displayDates[i];
          rows.add([
            '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}',
            displayRevenues[i].toStringAsFixed(2),
            l10n.repActual,
          ]);
        }
        for (var i = 0; i < forecastValues.length; i++) {
          rows.add([
            l10n.repDayOffset(i + 1),
            forecastValues[i].toStringAsFixed(2),
            l10n.repForecast,
          ]);
        }
        ReportExportButton.exportCsv(context, 'forecast_revenue', [
          l10n.globalDate,
          l10n.repColRevenue,
          l10n.setupSummaryFiscalType,
        ], rows);
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildHorizonChip(7, l10n.repRangeDays7),
                const SizedBox(width: 6),
                _buildHorizonChip(14, l10n.repRangeDays14),
                const SizedBox(width: 6),
                _buildHorizonChip(30, l10n.repRangeDays30),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.15,
                minX: 0,
                maxX: (totalPoints - 1).toDouble(),
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
                      interval: math.max(1, totalPoints / 6).roundToDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= totalPoints) {
                          return const SizedBox.shrink();
                        }
                        String label;
                        if (idx < displayDates.length) {
                          final d = displayDates[idx];
                          label =
                              '${d.day}.${d.month.toString().padLeft(2, '0')}';
                        } else {
                          final projDay = idx - displayDates.length + 1;
                          label = '+$projDay';
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            label,
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
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final idx = spot.x.toInt();
                        final isForecast = idx >= displayRevenues.length;
                        if (spot.barIndex == 2 || spot.barIndex == 3) {
                          return null;
                        }
                        final prefix = isForecast
                            ? l10n.repForecast
                            : l10n.repActual;
                        return LineTooltipItem(
                          '$prefix\n${ReportMoney.compact(spot.y)} ${tillCurrencySymbol()}',
                          TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontStyle: isForecast
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: AppColors.info,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: displayRevenues.length <= 31,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.info,
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
                          AppColors.info.withValues(alpha: 0.25),
                          AppColors.info.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: forecastSpots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: AppColors.success,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dashArray: [6, 4],
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.success.withValues(alpha: 0.7),
                            strokeWidth: 1.5,
                            strokeColor: AppColors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: upperBound,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: lowerBound,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                betweenBarsData: [
                  BetweenBarsData(
                    fromIndex: 2,
                    toIndex: 3,
                    color: AppColors.success.withValues(alpha: 0.12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonChip(int horizon, String label) {
    final isSelected = _forecastHorizon == horizon;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (_forecastHorizon != horizon) {
          setState(() {
            _forecastHorizon = horizon;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.semantic.canvas,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? AppColors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDepletionTable(List<_StockDepletion> data) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = List<_StockDepletion>.from(data);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case _SortColumn.name:
          cmp = a.name.compareTo(b.name);
        case _SortColumn.stock:
          cmp = a.stock.compareTo(b.stock);
        case _SortColumn.avgSales:
          cmp = a.weightedAvgDailySales.compareTo(b.weightedAvgDailySales);
        case _SortColumn.daysLeft:
          cmp = a.daysUntilOut.compareTo(b.daysUntilOut);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return ReportChartCard(
      title: l10n.repStockoutForecast,
      subtitle: l10n.repWeightedAvgHint,
      height: math.min(56.0 + sorted.length * 56.0, 440),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'forecast_stock_depletion',
        [
          l10n.inventoryProduct,
          l10n.catalogQuantity,
          l10n.repColAvgSalesPerDay,
          l10n.repColDaysLeft,
        ],
        sorted
            .map(
              (d) => [
                d.name,
                d.stock.toStringAsFixed(1),
                d.weightedAvgDailySales.toStringAsFixed(2),
                d.daysUntilOut.isInfinite
                    ? '-'
                    : d.daysUntilOut.toStringAsFixed(0),
              ],
            )
            .toList(),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            sortColumnIndex: _sortColumn.index,
            sortAscending: _sortAscending,
            columns: [
              DataColumn(
                label: Text(l10n.inventoryProduct),
                onSort: (_, asc) => _onSort(_SortColumn.name, asc),
              ),
              DataColumn(
                label: Text(l10n.catalogQuantity),
                numeric: true,
                onSort: (_, asc) => _onSort(_SortColumn.stock, asc),
              ),
              DataColumn(
                label: Text(l10n.repColSalesPerDay),
                numeric: true,
                onSort: (_, asc) => _onSort(_SortColumn.avgSales, asc),
              ),
              DataColumn(label: Text(l10n.repRangeDays7)),
              DataColumn(
                label: Text(l10n.repColDaysLeft),
                numeric: true,
                onSort: (_, asc) => _onSort(_SortColumn.daysLeft, asc),
              ),
            ],
            rows: sorted.map((item) {
              final rowColor = _rowColor(item.daysUntilOut);
              final daysText = item.daysUntilOut.isInfinite
                  ? '-'
                  : item.daysUntilOut.toStringAsFixed(0);

              return DataRow(
                color: WidgetStateProperty.all(rowColor),
                cells: [
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        item.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(Text(item.stock.toStringAsFixed(1))),
                  DataCell(Text(item.weightedAvgDailySales.toStringAsFixed(2))),
                  DataCell(_buildSparkline(item.sparklineData)),
                  DataCell(
                    Text(
                      daysText,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _daysTextColor(item.daysUntilOut),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _onSort(_SortColumn column, bool ascending) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = ascending;
      }
    });
  }

  Widget _buildSparkline(List<double> data) {
    if (data.isEmpty) {
      return SizedBox(
        width: 60,
        height: 24,
        child: Center(
          child: Text(
            '-',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }

    return SizedBox(
      width: 60,
      height: 24,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.primary,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedPurchases(List<_StockDepletion> data) {
    final l10n = AppLocalizations.of(context)!;
    const leadTimeDays = 7;
    const safetyStockDays = 3;
    const totalCoverDays = leadTimeDays + safetyStockDays;

    final urgent = data
        .where((d) => !d.daysUntilOut.isInfinite && d.daysUntilOut < 30)
        .toList();

    if (urgent.isEmpty) {
      return ReportChartCard(
        title: l10n.repRecommendedPurchases,
        subtitle: l10n.repNoUrgentItems,
        height: 80,
        child: Center(
          child: Text(
            l10n.repAllCovered30,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ReportChartCard(
      title: l10n.repRecommendedPurchases,
      subtitle: l10n.repLeadTimeHint(leadTimeDays, safetyStockDays),
      height: math.min(56.0 + urgent.length * 48.0, 440),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'forecast_recommended_purchases',
        [
          l10n.inventoryProduct,
          l10n.agentTypeSupplier,
          l10n.repColDaysLeft,
          l10n.repColRecommendedOrder,
          l10n.repColEstimatedAmount,
        ],
        urgent.map((d) {
          final recommendedQty = d.weightedAvgDailySales * totalCoverDays;
          final price = d.lastPurchasePrice;
          final estimatedCost = price != null
              ? (price * DecimalUtil.fromDouble(recommendedQty)).money
              : null;
          return [
            d.name,
            d.supplierName ?? '-',
            d.daysUntilOut.toStringAsFixed(0),
            recommendedQty.toStringAsFixed(1),
            estimatedCost?.toStringAsFixed(2) ?? '-',
          ];
        }).toList(),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 48,
            columns: [
              DataColumn(label: Text(l10n.inventoryProduct)),
              DataColumn(label: Text(l10n.agentTypeSupplier)),
              DataColumn(label: Text(l10n.repColDays), numeric: true),
              DataColumn(
                label: Text(l10n.repColRecommendedOrder),
                numeric: true,
              ),
              DataColumn(
                label: Text(l10n.repColEstimatedAmount),
                numeric: true,
              ),
            ],
            rows: urgent.map((item) {
              final recommendedQty =
                  item.weightedAvgDailySales * totalCoverDays;
              final price = item.lastPurchasePrice;
              final estimatedCost = price != null
                  ? (price * DecimalUtil.fromDouble(recommendedQty)).money
                  : null;
              final daysColor = _daysTextColor(item.daysUntilOut);

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 130,
                      child: Text(
                        item.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Text(
                        item.supplierName ?? '-',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: item.supplierName != null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.daysUntilOut.toStringAsFixed(0),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: daysColor,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      recommendedQty.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    Text(
                      estimatedCost != null
                          ? ReportMoney.full(estimatedCost)
                          : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
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

  Color _rowColor(double days) {
    if (days.isInfinite) return AppColors.success.withValues(alpha: 0.06);
    if (days < 7)
      return Theme.of(context).colorScheme.error.withValues(alpha: 0.08);
    if (days < 14) return const Color(0xFFF57C00).withValues(alpha: 0.08);
    if (days < 30) return AppColors.warning.withValues(alpha: 0.06);
    return AppColors.success.withValues(alpha: 0.06);
  }

  Color _daysTextColor(double days) {
    if (days.isInfinite) return AppColors.success;
    if (days < 7) return Theme.of(context).colorScheme.error;
    if (days < 14) return const Color(0xFFF57C00);
    if (days < 30) return const Color(0xFFC89800);
    return AppColors.success;
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
