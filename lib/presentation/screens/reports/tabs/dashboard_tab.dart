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
import 'package:telepos/presentation/controllers/reports/report_models.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_kpi_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';

ReportDao get _reportDao {
  final db = GetIt.I<AppDatabase>();
  return ReportDao(db);
}

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

DateTime _dateFromBucket(int dayBucket) =>
    DateTime.fromMillisecondsSinceEpoch(dayBucket * 86400 * 1000);

final _dashboardKpiProvider =
    FutureProvider.family<DashboardKpis, DateTimeRange>((ref, range) async {
      final dao = _reportDao;
      final startTs = _toTs(range.start);
      final endTs = _toTs(range.end);

      final row = await dao.getTotalRevenue(startTs, endTs);
      final totalRevenue = row.readDecimal('total_revenue');
      final saleCount = (row.read<int?>('sale_count') ?? 0);
      final avgCheck = saleCount > 0
          ? (totalRevenue / Decimal.fromInt(saleCount))
                .toDecimal(scaleOnInfinitePrecision: 3)
                .money
          : Decimal.zero;

      final days = range.end.difference(range.start).inDays;
      var prevRevenue = Decimal.zero;
      if (days > 0) {
        final prevStart = range.start.subtract(Duration(days: days));
        final prevEnd = range.start;
        final prevRow = await dao.getTotalRevenue(
          _toTs(prevStart),
          _toTs(prevEnd),
        );
        prevRevenue = prevRow.readDecimal('total_revenue');
      }

      return DashboardKpis(
        todayRevenue: totalRevenue,
        yesterdayRevenue: prevRevenue,
        todaySalesCount: saleCount,
        avgCheck: avgCheck,
      );
    });

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

final _topProductsProvider =
    FutureProvider.family<List<ProductRanking>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getTopProducts(
        _toTs(range.start),
        _toTs(range.end),
        5,
      );

      return rows.map((r) {
        return ProductRanking(
          ucode: r.read<int?>('ucode') ?? 0,
          name: r.read<String?>('name') ?? 'N/A',
          revenue: r.readDecimal('revenue'),
          qtySold: r.readDecimal('qty_sold'),
        );
      }).toList();
    });

final _paymentMethodsProvider =
    FutureProvider.family<List<PaymentMethodBreakdown>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getPaymentMethods(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return PaymentMethodBreakdown(
          accountId: r.read<int?>('payee_account_id') ?? 0,
          name: r.read<String?>('account_name') ?? 'N/A',
          accountType: r.read<int>('account_type'),
          total: r.readDecimal('total'),
        );
      }).toList();
    });

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(reportsProvider);
    final range = reportState.dateRange;

    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(_dashboardKpiProvider);
      ref.invalidate(_revenueByDayProvider);
      ref.invalidate(_topProductsProvider);
      ref.invalidate(_paymentMethodsProvider);
    });

    final kpiAsync = ref.watch(_dashboardKpiProvider(range));
    final revenueAsync = ref.watch(_revenueByDayProvider(range));
    final productsAsync = ref.watch(_topProductsProvider(range));
    final paymentsAsync = ref.watch(_paymentMethodsProvider(range));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (kpi) => _buildKpiRow(kpi),
            loading: () => _buildKpiRowLoading(),
            error: (e, _) => _buildKpiRowError(e),
          ),

          const SizedBox(height: 20),

          revenueAsync.when(
            data: (data) => _buildRevenueChart(data),
            loading: () => _buildChartLoading('Выручка по дням'),
            error: (e, _) => _buildChartError('Выручка по дням', e),
          ),

          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final children = [
                productsAsync.when(
                  data: (data) => _buildTopProductsChart(context, data),
                  loading: () => _buildChartLoading('Топ-5 товаров'),
                  error: (e, _) => _buildChartError('Топ-5 товаров', e),
                ),

                if (isWide) const SizedBox(width: 16),
                if (!isWide) const SizedBox(height: 20),

                paymentsAsync.when(
                  data: (data) => _buildPaymentMethodsChart(data),
                  loading: () => _buildChartLoading('Способы оплаты'),
                  error: (e, _) => _buildChartError('Способы оплаты', e),
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[0]),
                    children[1],
                    Expanded(child: children[2]),
                  ],
                );
              }
              return Column(children: children);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(DashboardKpis kpi) {
    final hasTrend = kpi.yesterdayRevenue > Decimal.zero;
    final trend = hasTrend ? kpi.changePercent : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cards = [
          ReportKpiCard(
            title: 'Выручка',
            value: ReportMoney.full(kpi.todayRevenue),
            icon: Icons.monetization_on_outlined,
            color: AppColors.primary,
            trend: trend,
            subtitle: 'за период',
          ),
          ReportKpiCard(
            title: 'Продажи',
            value: '${kpi.todaySalesCount}',
            icon: Icons.receipt_long_outlined,
            color: AppColors.info,
            subtitle: 'чеков',
          ),
          ReportKpiCard(
            title: 'Средний чек',
            value: ReportMoney.full(kpi.avgCheck),
            icon: Icons.analytics_outlined,
            color: AppColors.warning,
            subtitle: '₸',
          ),
          ReportKpiCard(
            title: 'Изменение',
            value: trend != null
                ? '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%'
                : 'N/A',
            icon: Icons.trending_up,
            color: (trend ?? 0) >= 0
                ? AppColors.success
                : Theme.of(context).colorScheme.error,
            subtitle: 'vs пред. период',
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

  Widget _buildKpiRowError(Object error) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Text(
        'Ошибка загрузки KPI: $error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildRevenueChart(List<RevenueByDay> data) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: 'Выручка по дням',
        subtitle: 'Нет данных за выбранный период',
        child: Center(
          child: Text(
            'Нет данных',
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

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), revenues[i]));
    }

    return ReportChartCard(
      title: 'Выручка по дням',
      subtitle: '${data.length} дней',
      height: 280,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'dashboard_revenue_by_day',
        ['Дата', 'Выручка'],
        [
          for (var i = 0; i < data.length; i++)
            [
              '${dates[i].day.toString().padLeft(2, '0')}.${dates[i].month.toString().padLeft(2, '0')}.${dates[i].year}',
              data[i].revenue.toStringAsFixed(2),
            ],
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxRevenue * 1.15,
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
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final idx = spot.x.toInt();
                  final d = idx < dates.length ? dates[idx] : DateTime.now();
                  return LineTooltipItem(
                    '${d.day}.${d.month.toString().padLeft(2, '0')}\n${ReportMoney.compact(spot.y)} ₸',
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
              color: AppColors.info,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: data.length <= 31,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsChart(
    BuildContext context,
    List<ProductRanking> data,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: 'Топ-5 товаров',
        subtitle: 'Нет данных',
        child: Center(
          child: Text(
            'Нет данных',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final revenues = data.map((d) => d.revenue.toDouble()).toList();
    final maxRevenue = revenues.reduce(math.max);

    final barColors = [
      AppColors.primary,
      AppColors.info,
      AppColors.warning,
      AppColors.success,
      AppColors.paymentMixed,
    ];

    return ReportChartCard(
      title: 'Топ-5 товаров',
      subtitle: 'по выручке (нажмите для деталей)',
      height: 220,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'dashboard_top_products',
        ['Товар', 'Выручка'],
        data.map((d) => [d.name, d.revenue.toStringAsFixed(2)]).toList(),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final product = data[group.x.toInt()];
                return BarTooltipItem(
                  '${product.name}\n${ReportMoney.full(product.revenue)} ₸',
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
                  _showProductDetailDialog(context, data[idx]);
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
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
                    color: barColors[i % barColors.length],
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

  void _showProductDetailDialog(BuildContext context, ProductRanking product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          product.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              label: 'Выручка',
              value: '${ReportMoney.full(product.revenue)} ₸',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsChart(List<PaymentMethodBreakdown> data) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: 'Способы оплаты',
        subtitle: 'Нет данных',
        child: Center(
          child: Text(
            'Нет данных',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final totalDec = data.fold(Decimal.zero, (Decimal sum, d) => sum + d.total);
    final total = totalDec.toDouble();
    final values = data.map((d) => d.total.toDouble()).toList();

    final pieColors = <Color>[
      AppColors.paymentCash,
      AppColors.paymentCard,
      AppColors.paymentMixed,
      AppColors.warning,
      AppColors.primary,
    ];

    return ReportChartCard(
      title: 'Способы оплаты',
      subtitle: 'распределение (нажмите на сектор)',
      height: 220,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'dashboard_payment_methods',
        ['Способ оплаты', 'Сумма', 'Процент'],
        data
            .map(
              (d) => [
                d.name,
                d.total.toStringAsFixed(2),
                total > 0
                    ? '${(d.total.toDouble() / total * 100).toStringAsFixed(1)}%'
                    : '0%',
              ],
            )
            .toList(),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedPieIndex = -1;
                        return;
                      }
                      _touchedPieIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: [
                  for (var i = 0; i < data.length; i++)
                    PieChartSectionData(
                      value: values[i],
                      color: pieColors[i % pieColors.length],
                      radius: i == _touchedPieIndex ? 65 : 50,
                      title: total > 0
                          ? '${(values[i] / total * 100).toStringAsFixed(0)}%'
                          : '',
                      titleStyle: TextStyle(
                        fontSize: i == _touchedPieIndex ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                      badgeWidget: i == _touchedPieIndex
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${ReportMoney.full(data[i].total)} ₸',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                      badgePositionPercentageOffset: 1.4,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < data.length; i++) ...[
                  _LegendItem(
                    color: pieColors[i % pieColors.length],
                    label: data[i].name,
                    value: ReportMoney.full(data[i].total),
                    isHighlighted: i == _touchedPieIndex,
                  ),
                  if (i < data.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
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
          'Ошибка: $error',
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  final Color color;
  final String label;
  final String value;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: isHighlighted
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
          : EdgeInsets.zero,
      decoration: isHighlighted
          ? BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isHighlighted
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isHighlighted
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$value ₸',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
