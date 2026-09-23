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
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_export_button.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';

ReportDao get _reportDao {
  final db = GetIt.I<AppDatabase>();
  return ReportDao(db);
}

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

final _topCustomersProvider =
    FutureProvider.family<List<CustomerRanking>, DateTimeRange>((
      ref,
      range,
    ) async {
      final dao = _reportDao;
      final rows = await dao.getTopCustomers(
        _toTs(range.start),
        _toTs(range.end),
        20,
      );

      return rows.map((r) {
        return CustomerRanking(
          localId: r.read<int?>('customer_local_id') ?? 0,
          // Подпись «без имени» — дело интерфейса: у провайдера нет
          // `BuildContext`, поэтому пустое имя доезжает пустым, а словарь
          // подставляется на месте показа (`_nameOf`).
          name: r.read<String?>('name') ?? '',
          revenue: r.readDecimal('revenue'),
          saleCount: r.read<int>('sale_count'),
        );
      }).toList();
    });

String _nameOf(CustomerRanking c, AppLocalizations l10n) =>
    c.name.isEmpty ? l10n.supplyNoName : c.name;

class CustomersTab extends ConsumerWidget {
  const CustomersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportState = ref.watch(reportsProvider);
    final range = reportState.dateRange;

    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(_topCustomersProvider);
    });

    final customersAsync = ref.watch(_topCustomersProvider(range));

    return customersAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return _buildEmptyState(context);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopCustomersChart(context, data.take(10).toList()),

              const SizedBox(height: 20),

              _buildCustomersTable(context, data),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          l10n.repErrorWith('$e'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // Контекст здесь не для удобства: приглушённый цвет подписи — роль темы, и
  // взять его можно только из `Theme.of`. Без него подпись красилась дневной
  // константой и в тёмной теме сливалась с фоном.
  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          Text(
            l10n.repNoCustomerData,
            style: AppTextStyles.h3.copyWith(color: AppColors.textDisabled),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.repSalesWithoutCustomerHidden,
            style: context.styles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomersChart(
    BuildContext context,
    List<CustomerRanking> data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return ReportChartCard(
        title: l10n.repTop10Customers,
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

    final maxRevenue = data.map((d) => d.revenue.toDouble()).reduce(math.max);
    final interval = _niceInterval(maxRevenue);

    final reversed = data.reversed.toList();
    final reversedRevenues = reversed.map((d) => d.revenue.toDouble()).toList();

    return ReportChartCard(
      title: l10n.repTop10Customers,
      subtitle: l10n.repByRevenueTapHint,
      height: math.max(220, data.length * 36.0),
      onExport: () => ReportExportButton.exportCsv(
        context,
        'customers_top',
        [l10n.paymentCustomerDefault, l10n.syncSales, l10n.repColRevenue],
        data
            .map(
              (d) => [
                _nameOf(d, l10n),
                d.saleCount.toString(),
                d.revenue.toStringAsFixed(2),
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
              getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final customer = reversed[group.x.toInt()];
                return BarTooltipItem(
                  l10n.repCustomerTooltip(
                    _nameOf(customer, l10n),
                    ReportMoney.withCurrency(customer.revenue),
                    customer.saleCount,
                  ),
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
                  _showCustomerDetailDialog(context, reversed[idx]);
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 100,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= reversed.length) {
                    return const SizedBox.shrink();
                  }
                  final name = _nameOf(reversed[idx], l10n);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: SizedBox(
                      width: 90,
                      child: Text(
                        name.length > 14 ? '${name.substring(0, 13)}...' : name,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
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
            drawHorizontalLine: false,
            verticalInterval: interval,
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
                    color: AppColors.info,
                    width: 20,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetailDialog(
    BuildContext context,
    CustomerRanking customer,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final avgCheck = customer.saleCount > 0
        ? (customer.revenue / Decimal.fromInt(customer.saleCount))
              .toDecimal(scaleOnInfinitePrecision: 3)
              .money
        : Decimal.zero;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _nameOf(customer, l10n),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              label: l10n.repColRevenue,
              value: ReportMoney.withCurrency(customer.revenue),
            ),
            _DetailRow(
              label: l10n.repReceiptCountLabel,
              value: '${customer.saleCount}',
            ),
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

  Widget _buildCustomersTable(
    BuildContext context,
    List<CustomerRanking> data,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: context.semantic.canvas),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.repAllCustomers,
                    style: AppTextStyles.h3.copyWith(fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => ReportExportButton.exportCsv(
                    context,
                    'customers_all',
                    [
                      l10n.paymentCustomerDefault,
                      l10n.syncSales,
                      l10n.repColRevenue,
                    ],
                    data
                        .map(
                          (d) => [
                            _nameOf(d, l10n),
                            d.saleCount.toString(),
                            d.revenue.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  tooltip: l10n.repExport,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                context.semantic.canvas.withValues(alpha: 0.5),
              ),
              columns: [
                DataColumn(
                  label: Text(
                    l10n.paymentCustomerDefault,
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
              rows: data.map((customer) {
                return DataRow(
                  onSelectChanged: (_) {
                    _showCustomerDetailDialog(context, customer);
                  },
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          _nameOf(customer, l10n),
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${customer.saleCount}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        ReportMoney.withCurrency(customer.revenue),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
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
