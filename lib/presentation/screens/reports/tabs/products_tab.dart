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
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/reports/report_models.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

ReportDao get _reportDao {
  final db = GetIt.I<AppDatabase>();
  return ReportDao(db);
}

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

final _topProductsProvider =
    FutureProvider.family<List<ProductRanking>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getTopProducts(
        _toTs(range.start),
        _toTs(range.end),
        20,
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

final _categoryProvider =
    FutureProvider.family<List<CategoryPerformance>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getCategoryPerformance(
        _toTs(range.start),
        _toTs(range.end),
      );

      return rows.map((r) {
        return CategoryPerformance(
          categoryId: r.read<int?>('category_id'),
          // Пустое имя означает «без категории»; подпись подставляется в UI,
          // потому что у провайдера нет BuildContext для словаря.
          name: r.read<String?>('name') ?? '',
          revenue: r.readDecimal('revenue'),
          qty: r.readDecimal('qty'),
        );
      }).toList();
    });

final _lowStockProvider = FutureProvider<List<LowStockItem>>((ref) async {
  final dao = _reportDao;
  final rows = await dao.getLowStockItems(10.0);

  return rows.map((r) {
    return LowStockItem(
      ucode: r.read<int?>('ucode') ?? 0,
      name: r.read<String?>('name') ?? 'N/A',
      stock: r.readDecimal('stock'),
      sellingPrice: r.readDecimal('selling_price'),
    );
  }).toList();
});

class _AbcRow {
  _AbcRow({
    required this.name,
    required this.revenue,
    required this.qty,
    required this.sharePct,
    required this.cumPct,
    required this.category,
  });
  final String name;
  final Decimal revenue;
  final Decimal qty;
  final double sharePct;
  final double cumPct;
  final String category;
}

Future<({double aBoundary, double bBoundary})> _abcThresholds() async {
  const fallback = (aBoundary: 80.0, bBoundary: 95.0);
  try {
    if (!GetIt.I.isRegistered<WmsConfigUseCase>()) return fallback;
    final cfg = await GetIt.I<WmsConfigUseCase>().getConfig();
    final aBand = cfg.lowStockThreshold?.toDouble();
    final bBand = cfg.overStockThreshold?.toDouble();
    if (aBand == null || aBand <= 0) return fallback;
    final aBoundary = aBand;
    final bBoundary = aBoundary + (bBand ?? 15.0);
    return (aBoundary: aBoundary, bBoundary: bBoundary);
  } catch (_) {
    return fallback;
  }
}

final _abcProvider = FutureProvider.family<List<_AbcRow>, DateTimeRange>((
  ref,
  range,
) async {
  final dao = _reportDao;
  final thresholds = await _abcThresholds();
  final aBoundary = thresholds.aBoundary;
  final bBoundary = thresholds.bBoundary;
  final rows = await dao.getTopProducts(
    _toTs(range.start),
    _toTs(range.end),
    1000,
  );
  final items = rows
      .map(
        (r) => (
          name: r.read<String?>('name') ?? 'N/A',
          revenue: r.readDecimal('revenue'),
          qty: r.readDecimal('qty_sold'),
        ),
      )
      .toList();
  final total = items.fold(Decimal.zero, (s, i) => s + i.revenue).toDouble();
  final result = <_AbcRow>[];
  var cumBefore = 0.0;
  for (final i in items) {
    final share = total > 0 ? i.revenue.toDouble() / total * 100 : 0.0;
    final cumAfter = cumBefore + share;
    final cat = cumBefore < aBoundary
        ? 'A'
        : (cumBefore < bBoundary ? 'B' : 'C');
    result.add(
      _AbcRow(
        name: i.name,
        revenue: i.revenue,
        qty: i.qty,
        sharePct: share,
        cumPct: cumAfter,
        category: cat,
      ),
    );
    cumBefore = cumAfter;
  }
  return result;
});

class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key});

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  int _touchedCategoryIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reportState = ref.watch(reportsProvider);
    final range = reportState.dateRange;

    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(_topProductsProvider);
      ref.invalidate(_categoryProvider);
      ref.invalidate(_lowStockProvider);
      ref.invalidate(_abcProvider);
    });

    final productsAsync = ref.watch(_topProductsProvider(range));
    final categoryAsync = ref.watch(_categoryProvider(range));
    final lowStockAsync = ref.watch(_lowStockProvider);
    final abcAsync = ref.watch(_abcProvider(range));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          productsAsync.when(
            data: (data) => _buildTopProductsChart(context, data),
            loading: () => _buildChartLoading(l10n.repTop10Products),
            error: (e, _) => _buildChartError(l10n.repTop10Products, e),
          ),

          const SizedBox(height: 16),

          abcAsync.when(
            data: (data) => _buildAbcCard(context, data),
            loading: () => _buildChartLoading(l10n.setWmsAbcAnalysis),
            error: (e, _) => _buildChartError(l10n.setWmsAbcAnalysis, e),
          ),

          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final children = [
                categoryAsync.when(
                  data: (data) => _buildCategoryPieChart(data),
                  loading: () => _buildChartLoading(l10n.syncTypeCategories),
                  error: (e, _) => _buildChartError(l10n.syncTypeCategories, e),
                ),
                if (isWide) const SizedBox(width: 16),
                if (!isWide) const SizedBox(height: 16),
                lowStockAsync.when(
                  data: (data) => _buildLowStockTable(context, data),
                  loading: () => _buildChartLoading(l10n.repLowStock),
                  error: (e, _) => _buildChartError(l10n.repLowStock, e),
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

  Widget _buildTopProductsChart(
    BuildContext context,
    List<ProductRanking> data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repTop10Products,
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

    final top10 = data.length > 10 ? data.sublist(0, 10) : data;
    final reversed = top10.reversed.toList();

    final reversedRevenues = reversed.map((d) => d.revenue.toDouble()).toList();
    final maxRevenue = reversedRevenues.reduce(math.max);

    return ReportChartCard(
      title: l10n.repTop10Products,
      subtitle: l10n.repByRevenueTapHint,
      height: math.max(280, reversed.length * 36.0),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'products_top',
        [l10n.inventoryProduct, l10n.repColRevenue, l10n.globalQuantity],
        data
            .map(
              (d) => [
                d.name,
                d.revenue.toStringAsFixed(2),
                d.qtySold.toStringAsFixed(2),
              ],
            )
            .toList(),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              direction: TooltipDirection.top,
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = reversed[group.x.toInt()];
                return BarTooltipItem(
                  '${item.name}\n'
                  '${ReportMoney.withCurrency(item.revenue)}\n'
                  '${l10n.repPieces(item.qtySold.toStringAsFixed(1))}',
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
                if (idx >= 0 && idx < reversed.length) {
                  _showProductDetailDialog(context, reversed[idx]);
                }
              }
            },
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
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
                reservedSize: 100,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= reversed.length) {
                    return const SizedBox.shrink();
                  }
                  final name = reversed[idx].name;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: SizedBox(
                      width: 90,
                      child: Text(
                        name.length > 15 ? '${name.substring(0, 14)}...' : name,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: false,
            getDrawingVerticalLine: (value) =>
                FlLine(color: context.semantic.canvas, strokeWidth: 1),
          ),
          barGroups: [
            for (var i = 0; i < reversed.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: reversedRevenues[i],
                    color: AppColors.success,
                    width: 20,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        swapAnimationDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showProductDetailDialog(BuildContext context, ProductRanking product) {
    final l10n = AppLocalizations.of(context)!;
    final avgPrice = product.qtySold > Decimal.zero
        ? (product.revenue / product.qtySold)
              .toDecimal(scaleOnInfinitePrecision: 3)
              .money
        : Decimal.zero;
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
              label: l10n.repColRevenue,
              value: ReportMoney.withCurrency(product.revenue),
            ),
            _DetailRow(
              label: l10n.repColSold,
              value: l10n.repPieces(product.qtySold.toStringAsFixed(1)),
            ),
            _DetailRow(
              label: l10n.repAvgPrice,
              value: ReportMoney.withCurrency(avgPrice),
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

  Widget _buildCategoryPieChart(List<CategoryPerformance> data) {
    final l10n = AppLocalizations.of(context)!;
    String nameOf(CategoryPerformance d) =>
        d.name.isEmpty ? l10n.repNoCategory : d.name;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.syncTypeCategories,
        subtitle: l10n.serviceNoOrders,
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

    final values = data.map((d) => d.revenue.toDouble()).toList();
    final total = data
        .fold(Decimal.zero, (Decimal sum, d) => sum + d.revenue)
        .toDouble();

    final pieColors = <Color>[
      AppColors.primary,
      AppColors.info,
      AppColors.warning,
      AppColors.success,
      AppColors.paymentMixed,
      Theme.of(context).colorScheme.error,
      AppColors.paymentCash,
      AppColors.paymentCard,
      AppColors.warningGold,
      AppColors.statusSync,
    ];

    return ReportChartCard(
      title: l10n.syncTypeCategories,
      subtitle: l10n.repRevenueDistributionTapHint,
      onExport: () => ReportExportButton.exportCsv(
        context,
        'products_categories',
        [l10n.quickProductCategory, l10n.repColRevenue],
        data.map((d) => [nameOf(d), d.revenue.toStringAsFixed(2)]).toList(),
      ),
      height: 260,
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
                        _touchedCategoryIndex = -1;
                        return;
                      }
                      _touchedCategoryIndex =
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
                      radius: i == _touchedCategoryIndex ? 65 : 50,
                      title: total > 0
                          ? '${(values[i] / total * 100).toStringAsFixed(0)}%'
                          : '',
                      titleStyle: TextStyle(
                        fontSize: i == _touchedCategoryIndex ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                      badgeWidget: i == _touchedCategoryIndex
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
                                '${nameOf(data[i])}\n${ReportMoney.withCurrency(data[i].revenue)}',
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < data.length; i++) ...[
                    _LegendItem(
                      color: pieColors[i % pieColors.length],
                      label: nameOf(data[i]),
                      value: ReportMoney.full(data[i].revenue),
                      isHighlighted: i == _touchedCategoryIndex,
                    ),
                    if (i < data.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockTable(BuildContext context, List<LowStockItem> data) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repLowStock,
        subtitle: l10n.repAllInStock,
        child: Center(
          child: Text(
            l10n.repNoLowStock,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final critical = Decimal.fromInt(3);

    return ReportChartCard(
      title: l10n.repLowStock,
      subtitle: l10n.repLowStockCountHint(data.length),
      height: math.max(250, (data.length * 48 + 56).toDouble()),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'products_low_stock',
        [l10n.inventoryProduct, l10n.catalogQuantity, l10n.globalPrice],
        data
            .map(
              (d) => [
                d.name,
                d.stock.toStringAsFixed(1),
                d.sellingPrice.toStringAsFixed(2),
              ],
            )
            .toList(),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(selectedSurfaceOf(context)),
          columnSpacing: 24,
          columns: [
            DataColumn(
              label: Text(
                l10n.inventoryProduct,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                l10n.catalogQuantity,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                l10n.globalPrice,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              numeric: true,
            ),
          ],
          rows: [
            for (final item in data)
              DataRow(
                color: item.stock < critical
                    ? WidgetStateProperty.all(
                        Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.08),
                      )
                    : null,
                onSelectChanged: (_) {
                  _showLowStockDetailDialog(context, item);
                },
                cells: [
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.stock.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: item.stock < critical
                            ? Theme.of(context).colorScheme.error
                            : AppColors.warning,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      ReportMoney.withCurrency(item.sellingPrice),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showLowStockDetailDialog(BuildContext context, LowStockItem item) {
    final l10n = AppLocalizations.of(context)!;
    final stockValue = (item.stock * item.sellingPrice).money;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          item.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              label: l10n.repCurrentStock,
              value: l10n.repPieces(item.stock.toStringAsFixed(1)),
            ),
            _DetailRow(
              label: l10n.catalogPrice,
              value: ReportMoney.withCurrency(item.sellingPrice),
            ),
            _DetailRow(
              label: l10n.repStockValue,
              value: ReportMoney.withCurrency(stockValue),
            ),
            const SizedBox(height: 8),
            if (item.stock < Decimal.fromInt(3))
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Theme.of(context).colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.repStockCritical,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildAbcCard(BuildContext context, List<_AbcRow> data) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.setWmsAbcAnalysis,
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

    Color catColor(String c) => c == 'A'
        ? AppColors.success
        : c == 'B'
        ? AppColors.warning
        : Theme.of(context).colorScheme.onSurfaceVariant;

    final total = data.fold(Decimal.zero, (Decimal s, r) => s + r.revenue);
    Decimal revOf(String c) => data
        .where((r) => r.category == c)
        .fold(Decimal.zero, (s, r) => s + r.revenue);
    int cntOf(String c) => data.where((r) => r.category == c).length;
    double shareOf(String c) =>
        total > Decimal.zero ? (revOf(c) / total).toDouble() * 100 : 0;

    Widget summary(String c, String label) {
      final color = catColor(c);
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Text(
                '$c — $label',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.repAbcGroupSummary(
                  cntOf(c),
                  shareOf(c).toStringAsFixed(0),
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                ReportMoney.withCurrency(revOf(c)),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ReportChartCard(
      title: l10n.setWmsAbcAnalysis,
      subtitle: l10n.repAbcLegend,
      height: math.max(300, data.length * 40.0 + 140),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'products_abc',
        [
          l10n.inventoryProduct,
          l10n.quickProductCategory,
          l10n.repColRevenue,
          l10n.repColSharePct,
          l10n.repColCumulativePct,
        ],
        data
            .map(
              (r) => [
                r.name,
                r.category,
                r.revenue.toStringAsFixed(2),
                r.sharePct.toStringAsFixed(1),
                r.cumPct.toStringAsFixed(1),
              ],
            )
            .toList(),
      ),
      child: Column(
        children: [
          Row(
            children: [
              summary('A', l10n.repAbcFast),
              summary('B', l10n.repAbcMedium),
              summary('C', l10n.repAbcRare),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final r in data)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: catColor(r.category),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.category,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            ReportMoney.withCurrency(r.revenue),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              '${r.sharePct.toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
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
          AppLocalizations.of(context)!.repErrorWith('$error'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 13,
          ),
        ),
      ),
    );
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
                  '$value ${tillCurrencySymbol()}',
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
