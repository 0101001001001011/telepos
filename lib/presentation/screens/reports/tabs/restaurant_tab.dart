import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/core/utils/decimal_util.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/report_dao.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_kpi_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

class _RestaurantKpi {
  const _RestaurantKpi({
    required this.totalRevenue,
    required this.orderCount,
    required this.avgCheck,
    required this.totalTips,
  });
  final Decimal totalRevenue;
  final int orderCount;
  final Decimal avgCheck;
  final Decimal totalTips;
}

class _OrderTypeData {
  const _OrderTypeData({
    required this.orderType,
    required this.orderCount,
    required this.totalRevenue,
    required this.avgCheck,
  });
  final int orderType;
  final int orderCount;
  final Decimal totalRevenue;
  final Decimal avgCheck;

  String label(AppLocalizations l10n) {
    switch (orderType) {
      case 0:
        return l10n.restaurantOrderDineIn;
      case 1:
        return l10n.restaurantOrderTakeout;
      case 2:
        return l10n.restaurantOrderDelivery;
      default:
        return l10n.expenseTypeOther;
    }
  }
}

class _TableTurnover {
  const _TableTurnover({
    required this.id,
    required this.name,
    required this.zone,
    required this.capacity,
    required this.seatingCount,
    required this.totalRevenue,
    required this.avgCheck,
    required this.totalTips,
  });
  final int id;
  final String name;
  final String zone;
  final int capacity;
  final int seatingCount;
  final Decimal totalRevenue;
  final Decimal avgCheck;
  final Decimal totalTips;
}

class _DishPopularity {
  const _DishPopularity({
    required this.ucode,
    required this.name,
    required this.qtySold,
    required this.revenue,
    required this.costPrice,
    required this.foodCostPct,
  });
  final int ucode;
  final String name;
  final Decimal qtySold;
  final Decimal revenue;
  final Decimal costPrice;
  final double foodCostPct;
}

class _TipsData {
  const _TipsData({
    required this.waiterName,
    required this.orderCount,
    required this.revenue,
    required this.totalTips,
    required this.tipPercent,
  });
  final String waiterName;
  final int orderCount;
  final Decimal revenue;
  final Decimal totalTips;
  final double tipPercent;
}

ReportDao get _reportDao {
  final db = GetIt.I<AppDatabase>();
  return ReportDao(db);
}

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

final _restaurantKpiProvider =
    FutureProvider.family<_RestaurantKpi, DateTimeRange>((ref, range) async {
      final dao = _reportDao;
      final startTs = _toTs(range.start);
      final endTs = _toTs(range.end);

      final orderTypeRows = await dao.getRestaurantOrderTypes(startTs, endTs);
      var totalRevenue = Decimal.zero;
      int orderCount = 0;
      for (final r in orderTypeRows) {
        totalRevenue += r.readDecimal('total_revenue');
        orderCount += (r.read<int?>('order_count') ?? 0);
      }
      final avgCheck = orderCount > 0
          ? (totalRevenue / Decimal.fromInt(orderCount))
                .toDecimal(scaleOnInfinitePrecision: 3)
                .money
          : Decimal.zero;

      final tipsRows = await dao.getTipsAnalysis(startTs, endTs);
      var totalTips = Decimal.zero;
      for (final r in tipsRows) {
        totalTips += r.readDecimal('total_tips');
      }

      return _RestaurantKpi(
        totalRevenue: totalRevenue,
        orderCount: orderCount,
        avgCheck: avgCheck,
        totalTips: totalTips,
      );
    });

final _orderTypesProvider =
    FutureProvider.family<List<_OrderTypeData>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getRestaurantOrderTypes(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return _OrderTypeData(
          orderType: r.read<int>('order_type'),
          orderCount: r.read<int>('order_count'),
          totalRevenue: r.readDecimal('total_revenue'),
          avgCheck: r.readDecimal('avg_check'),
        );
      }).toList();
    });

final _tableTurnoverProvider =
    FutureProvider.family<List<_TableTurnover>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getTableTurnover(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return _TableTurnover(
          id: r.read<int>('id'),
          name: r.read<String>('name'),
          zone: r.read<String?>('zone') ?? '',
          capacity: r.read<int>('capacity'),
          seatingCount: r.read<int>('seating_count'),
          totalRevenue: r.readDecimal('total_revenue'),
          avgCheck: r.readDecimal('avg_check'),
          totalTips: r.readDecimal('total_tips'),
        );
      }).toList();
    });

final _dishPopularityProvider =
    FutureProvider.family<List<_DishPopularity>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getDishPopularity(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return _DishPopularity(
          ucode: r.read<int>('ucode'),
          name: r.read<String?>('name') ?? 'N/A',
          qtySold: r.readDecimal('qty_sold'),
          revenue: r.readDecimal('revenue'),
          costPrice: r.readDecimal('cost_price'),
          foodCostPct: r.read<double?>('food_cost_pct') ?? 0.0,
        );
      }).toList();
    });

final _tipsProvider = FutureProvider.family<List<_TipsData>, DateTimeRange>((
  ref,
  range,
) async {
  final dao = _reportDao;
  final rows = await dao.getTipsAnalysis(_toTs(range.start), _toTs(range.end));

  return rows.map((r) {
    return _TipsData(
      waiterName: r.read<String>('waiter_name'),
      orderCount: r.read<int>('order_count'),
      revenue: r.readDecimal('revenue'),
      totalTips: r.readDecimal('total_tips'),
      tipPercent: r.read<double?>('tip_percent') ?? 0.0,
    );
  }).toList();
});

class RestaurantTab extends ConsumerStatefulWidget {
  const RestaurantTab({super.key});

  @override
  ConsumerState<RestaurantTab> createState() => _RestaurantTabState();
}

class _RestaurantTabState extends ConsumerState<RestaurantTab> {
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reportState = ref.watch(reportsProvider);
    final range = reportState.dateRange;

    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(_restaurantKpiProvider);
      ref.invalidate(_orderTypesProvider);
      ref.invalidate(_tableTurnoverProvider);
      ref.invalidate(_dishPopularityProvider);
      ref.invalidate(_tipsProvider);
    });

    final kpiAsync = ref.watch(_restaurantKpiProvider(range));
    final orderTypesAsync = ref.watch(_orderTypesProvider(range));
    final tableTurnoverAsync = ref.watch(_tableTurnoverProvider(range));
    final dishesAsync = ref.watch(_dishPopularityProvider(range));
    final tipsAsync = ref.watch(_tipsProvider(range));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (kpi) => _buildKpiRow(kpi, l10n),
            loading: () => _buildKpiRowLoading(),
            error: (e, _) => _buildKpiRowError(e, l10n),
          ),

          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final children = [
                orderTypesAsync.when(
                  data: (data) => _buildOrderTypePieChart(data, l10n),
                  loading: () => _buildChartLoading(l10n.repOrderTypesTitle),
                  error: (e, _) =>
                      _buildChartError(l10n.repOrderTypesTitle, e, l10n),
                ),

                if (isWide) const SizedBox(width: 16),
                if (!isWide) const SizedBox(height: 20),

                tableTurnoverAsync.when(
                  data: (data) => _buildTableTurnoverChart(context, data, l10n),
                  loading: () => _buildChartLoading(l10n.repTableTurnoverTitle),
                  error: (e, _) =>
                      _buildChartError(l10n.repTableTurnoverTitle, e, l10n),
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

          const SizedBox(height: 20),

          dishesAsync.when(
            data: (data) => _buildDishPopularityChart(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repDishPopularityTitle),
            error: (e, _) =>
                _buildChartError(l10n.repDishPopularityTitle, e, l10n),
          ),

          const SizedBox(height: 20),

          dishesAsync.when(
            data: (data) => _buildFoodCostTable(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repFoodCostAnalysisShort),
            error: (e, _) =>
                _buildChartError(l10n.repFoodCostAnalysisShort, e, l10n),
          ),

          const SizedBox(height: 20),

          tipsAsync.when(
            data: (data) => _buildTipsTable(context, data, l10n),
            loading: () => _buildChartLoading(l10n.repTipsByWaiterTitle),
            error: (e, _) =>
                _buildChartError(l10n.repTipsByWaiterTitle, e, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow(_RestaurantKpi kpi, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cards = [
          ReportKpiCard(
            title: l10n.repKpiRestaurantRevenue,
            value: ReportMoney.full(kpi.totalRevenue),
            icon: Icons.restaurant,
            color: AppColors.primary,
            subtitle: l10n.repSubtitleForPeriod,
          ),
          ReportKpiCard(
            title: l10n.repKpiOrders,
            value: '${kpi.orderCount}',
            icon: Icons.receipt_long_outlined,
            color: AppColors.info,
            subtitle: l10n.repSubtitleTotal,
          ),
          ReportKpiCard(
            title: l10n.repKpiAvgCheck,
            value: ReportMoney.full(kpi.avgCheck),
            icon: Icons.analytics_outlined,
            color: AppColors.warning,
            subtitle: tillCurrencySymbol(),
          ),
          ReportKpiCard(
            title: l10n.repKpiTips,
            value: ReportMoney.full(kpi.totalTips),
            icon: Icons.volunteer_activism,
            color: AppColors.success,
            subtitle: l10n.repSubtitleTotal,
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

  Widget _buildKpiRowError(Object error, AppLocalizations l10n) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Text(
        '${l10n.repKpiLoadError}: $error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildOrderTypePieChart(
    List<_OrderTypeData> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repOrderTypesTitle,
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

    final values = data.map((d) => d.totalRevenue.toDouble()).toList();
    final total = data
        .fold(Decimal.zero, (Decimal sum, d) => sum + d.totalRevenue)
        .toDouble();

    final pieColors = <Color>[
      AppColors.warning,
      AppColors.info,
      AppColors.success,
      AppColors.primary,
    ];

    return ReportChartCard(
      title: l10n.repOrderTypesTitle,
      subtitle: l10n.repOrderTypesSubtitle,
      height: 220,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'restaurant_order_types',
        [
          l10n.restaurantOrderType,
          l10n.tableHeaderQty,
          l10n.repColRevenue,
          l10n.repKpiAvgCheck,
          l10n.discountPercent,
        ],
        data
            .map(
              (d) => [
                d.label(l10n),
                d.orderCount.toString(),
                d.totalRevenue.toStringAsFixed(2),
                d.avgCheck.toStringAsFixed(2),
                total > 0
                    ? '${(d.totalRevenue.toDouble() / total * 100).toStringAsFixed(1)}%'
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
                                l10n.repOrdersRevenueTooltip(
                                  data[i].orderCount,
                                  ReportMoney.withCurrency(
                                    data[i].totalRevenue,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
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
                    label: data[i].label(l10n),
                    value: l10n.repOrdersShort(data[i].orderCount),
                    subValue: ReportMoney.withCurrency(data[i].totalRevenue),
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

  Widget _buildTableTurnoverChart(
    BuildContext context,
    List<_TableTurnover> data,
    AppLocalizations l10n,
  ) {
    final activeData = data.where((d) => d.seatingCount > 0).toList();
    if (activeData.isEmpty) {
      return ReportChartCard(
        title: l10n.repTableTurnoverTitle,
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

    final displayData = activeData.take(10).toList();
    final maxCount = displayData
        .map((d) => d.seatingCount)
        .reduce(math.max)
        .toDouble();
    final interval = _niceInterval(maxCount);

    final zoneColors = <String, Color>{};
    final palette = [
      AppColors.primary,
      AppColors.info,
      AppColors.warning,
      AppColors.success,
      AppColors.paymentMixed,
    ];
    var colorIdx = 0;
    for (final t in displayData) {
      if (!zoneColors.containsKey(t.zone)) {
        zoneColors[t.zone] = palette[colorIdx % palette.length];
        colorIdx++;
      }
    }

    return ReportChartCard(
      title: l10n.repTableTurnoverTitle,
      subtitle: l10n.repTableTurnoverSubtitle,
      height: 280,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'restaurant_table_turnover',
        [
          l10n.repColTable,
          l10n.restaurantTableZone,
          l10n.restaurantTableCapacity,
          l10n.repColSeatings,
          l10n.repColRevenue,
          l10n.repColAvgCheckShort,
          l10n.restTips,
        ],
        data
            .map(
              (d) => [
                d.name,
                d.zone,
                d.capacity.toString(),
                d.seatingCount.toString(),
                d.totalRevenue.toStringAsFixed(2),
                d.avgCheck.toStringAsFixed(2),
                d.totalTips.toStringAsFixed(2),
              ],
            )
            .toList(),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final table = displayData[group.x.toInt()];
                return BarTooltipItem(
                  '${table.name}${table.zone.isNotEmpty ? ' (${table.zone})' : ''}\n'
                  '${l10n.repSeatingsLine(table.seatingCount)}\n'
                  '${ReportMoney.withCurrency(table.totalRevenue)}',
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
                  if (idx < 0 || idx >= displayData.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: SizedBox(
                      width: 50,
                      child: Text(
                        displayData[idx].name,
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
                    toY: displayData[i].seatingCount.toDouble(),
                    color: zoneColors[displayData[i].zone] ?? AppColors.primary,
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

  Widget _buildDishPopularityChart(
    BuildContext context,
    List<_DishPopularity> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repDishPopularityTitle,
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
    final quantities = displayData.map((d) => d.qtySold.toDouble()).toList();
    final maxQty = quantities.reduce(math.max);

    final barColors = [
      AppColors.primary,
      AppColors.info,
      AppColors.warning,
      AppColors.success,
      AppColors.paymentMixed,
      Theme.of(context).colorScheme.error,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFF84CC16),
    ];

    return ReportChartCard(
      title: l10n.repDishPopularityTitle,
      subtitle: l10n.repDishPopularitySubtitle,
      height: math.max(220, displayData.length * 40.0 + 60),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'restaurant_dish_popularity',
        [
          l10n.catalogTypeDish,
          l10n.repColSalesCount,
          l10n.repColRevenue,
          l10n.dishTabCosting,
          'Food Cost %',
        ],
        data
            .map(
              (d) => [
                d.name,
                d.qtySold.toStringAsFixed(1),
                d.revenue.toStringAsFixed(2),
                d.costPrice.toStringAsFixed(2),
                '${d.foodCostPct.toStringAsFixed(1)}%',
              ],
            )
            .toList(),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxQty * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dish = displayData[group.x.toInt()];
                return BarTooltipItem(
                  '${dish.name}\n'
                  '${l10n.repPiecesDot(dish.qtySold.toStringAsFixed(0))}\n'
                  '${ReportMoney.withCurrency(dish.revenue)}',
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
            getDrawingHorizontalLine: (value) =>
                FlLine(color: context.semantic.canvas, strokeWidth: 1),
          ),
          barGroups: [
            for (var i = 0; i < displayData.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: quantities[i],
                    color: barColors[i % barColors.length],
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

  Widget _buildFoodCostTable(
    BuildContext context,
    List<_DishPopularity> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repFoodCostAnalysisTitle,
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

    return ReportChartCard(
      title: l10n.repFoodCostAnalysisTitle,
      subtitle: l10n.repFoodCostAnalysisSubtitle,
      height: math.min(56.0 + data.length * 48.0, 450),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'restaurant_food_cost',
        [
          l10n.catalogTypeDish,
          l10n.repColRevenue,
          l10n.dishTabCosting,
          'Food Cost %',
        ],
        data
            .map(
              (d) => [
                d.name,
                d.revenue.toStringAsFixed(2),
                d.costPrice.toStringAsFixed(2),
                '${d.foodCostPct.toStringAsFixed(1)}%',
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
            DataColumn(label: Text(l10n.repColDish)),
            DataColumn(label: Text(l10n.repColRevenue), numeric: true),
            DataColumn(label: Text(l10n.repColCostShort), numeric: true),
            DataColumn(label: Text(l10n.repColFoodCostPct), numeric: true),
          ],
          rows: data
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _foodCostColor(
                            d.foodCostPct,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${d.foodCostPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _foodCostColor(d.foodCostPct),
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

  Color _foodCostColor(double pct) {
    if (pct < 30) return AppColors.success;
    if (pct <= 40) return AppColors.warning;
    return Theme.of(context).colorScheme.error;
  }

  Widget _buildTipsTable(
    BuildContext context,
    List<_TipsData> data,
    AppLocalizations l10n,
  ) {
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repTipsByWaiterTitle,
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

    return ReportChartCard(
      title: l10n.repTipsByWaiterTitle,
      subtitle: l10n.repTipsByWaiterSubtitle,
      height: math.min(56.0 + data.length * 48.0, 400),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'restaurant_tips',
        [
          l10n.restaurantWaiter,
          l10n.navOrders,
          l10n.repColRevenue,
          l10n.restTips,
          l10n.repColTipsPct,
        ],
        data
            .map(
              (d) => [
                d.waiterName,
                d.orderCount.toString(),
                d.revenue.toStringAsFixed(2),
                d.totalTips.toStringAsFixed(2),
                '${d.tipPercent.toStringAsFixed(1)}%',
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
            DataColumn(label: Text(l10n.repColWaiter)),
            DataColumn(label: Text(l10n.repColOrders), numeric: true),
            DataColumn(label: Text(l10n.repColRevenue), numeric: true),
            DataColumn(label: Text(l10n.repColTips), numeric: true),
            DataColumn(label: Text(l10n.repColTipsPct), numeric: true),
          ],
          rows: data
              .map(
                (d) => DataRow(
                  cells: [
                    DataCell(
                      Text(
                        d.waiterName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    DataCell(
                      Text(
                        '${d.orderCount}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                        ReportMoney.full(d.totalTips),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${d.tipPercent.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.w500),
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

  Widget _buildChartError(String title, Object error, AppLocalizations l10n) {
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    this.subValue,
    this.isHighlighted = false,
  });

  final Color color;
  final String label;
  final String value;
  final String? subValue;
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
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (subValue != null)
                  Text(
                    subValue!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
