import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/reports/kz_reports_controller.dart';
import 'package:telepos/presentation/controllers/reports/reports_controller.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_chart_card.dart';
import 'package:telepos/presentation/screens/reports/widgets/report_money_format.dart';
import 'package:telepos/presentation/common/utils/till_money.dart';

class KzReportsTab extends ConsumerWidget {
  const KzReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final range = ref.watch(reportsProvider).dateRange;

    ref.listen(reportRefreshProvider, (_, __) {
      ref.invalidate(f910IncomeReportProvider);
      ref.invalidate(f300VatReportProvider);
      ref.invalidate(cashBookReportProvider);
      ref.invalidate(vatReportProvider);
      ref.invalidate(arApReportProvider);
      ref.invalidate(cashCollectionReportProvider);
      ref.invalidate(profitCogsReportProvider);
      ref.invalidate(writeoffReportProvider);
    });

    final f910Async = ref.watch(f910IncomeReportProvider(range));
    final f300Async = ref.watch(f300VatReportProvider(range));
    final cashBookAsync = ref.watch(cashBookReportProvider(range));
    final vatAsync = ref.watch(vatReportProvider(range));
    final arApAsync = ref.watch(arApReportProvider);
    final cashAsync = ref.watch(cashCollectionReportProvider(range));
    final profitAsync = ref.watch(profitCogsReportProvider(range));
    final writeoffAsync = ref.watch(writeoffReportProvider(range));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          f910Async.when(
            data: (d) => _buildF910(context, d, l10n),
            loading: () => _loading(l10n.repF910Title),
            error: (e, _) =>
                _error(context, l10n.repF910Title, e, l10n.repError),
          ),
          const SizedBox(height: 20),
          f300Async.when(
            data: (d) => _buildF300(context, d, l10n),
            loading: () => _loading(l10n.repF300Title),
            error: (e, _) =>
                _error(context, l10n.repF300Title, e, l10n.repError),
          ),
          const SizedBox(height: 20),
          cashBookAsync.when(
            data: (d) => _buildCashBook(context, d, l10n),
            loading: () => _loading(l10n.repCashBookTitle),
            error: (e, _) =>
                _error(context, l10n.repCashBookTitle, e, l10n.repError),
          ),
          const SizedBox(height: 20),
          vatAsync.when(
            data: (d) => _buildVat(context, d, l10n),
            loading: () => _loading(l10n.repVatPeriodTitle),
            error: (e, _) =>
                _error(context, l10n.repVatPeriodTitle, e, l10n.repError),
          ),
          const SizedBox(height: 20),
          arApAsync.when(
            data: (d) => _buildArAp(context, d, l10n),
            loading: () => _loading(l10n.repArApTitle),
            error: (e, _) =>
                _error(context, l10n.repArApTitle, e, l10n.repError),
          ),
          const SizedBox(height: 20),
          cashAsync.when(
            data: (d) => _buildCashCollection(context, d, l10n),
            loading: () => _loading(l10n.repCashCollectionTitle),
            error: (e, _) =>
                _error(context, l10n.repCashCollectionTitle, e, l10n.repError),
          ),
          const SizedBox(height: 20),
          profitAsync.when(
            data: (d) => _buildProfit(context, d, l10n),
            loading: () => _loading(l10n.repProfitCogsTitle),
            error: (e, _) =>
                _error(context, l10n.repProfitCogsTitle, e, l10n.repError),
          ),
          const SizedBox(height: 20),
          writeoffAsync.when(
            data: (d) => _buildWriteoff(context, d, l10n),
            loading: () => _loading(l10n.repWriteoffTitle),
            error: (e, _) =>
                _error(context, l10n.repWriteoffTitle, e, l10n.repError),
          ),
        ],
      ),
    );
  }

  Widget _buildF910(
    BuildContext context,
    F910IncomeReport report,
    AppLocalizations l10n,
  ) {
    return ReportChartCard(
      title: l10n.repF910Title,
      subtitle: l10n.repF910Subtitle(
        ReportMoney.withCurrency(report.taxableIncome),
        report.taxRatePercent.toString(),
        ReportMoney.withCurrency(report.estimatedTax),
      ),
      height: _tableHeight(3),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16,
          columns: [
            DataColumn(label: Text(l10n.repColIndicator)),
            DataColumn(label: Text(l10n.repColCount), numeric: true),
            DataColumn(
              label: Text(l10n.repColSumTenge(tillCurrencySymbol())),
              numeric: true,
            ),
          ],
          rows: [
            DataRow(
              cells: [
                DataCell(Text(l10n.repF910RowSalesIncome)),
                DataCell(Text('${report.saleCount}')),
                DataCell(Text(ReportMoney.full(report.salesIncome))),
              ],
            ),
            DataRow(
              cells: [
                DataCell(Text(l10n.repF910RowRefunds)),
                DataCell(Text('${report.refundCount}')),
                DataCell(
                  Text(
                    ReportMoney.full(report.refundTotal),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            DataRow(
              cells: [
                DataCell(
                  Text(
                    l10n.repF910RowTaxableIncome,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const DataCell(Text('')),
                DataCell(
                  Text(
                    ReportMoney.full(report.taxableIncome),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
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

  Widget _buildF300(
    BuildContext context,
    F300VatReport report,
    AppLocalizations l10n,
  ) {
    final rows = <DataRow>[
      for (final b in report.taxableBuckets)
        DataRow(
          cells: [
            DataCell(
              Text(l10n.repF300TaxableTurnoverRate(b.ratePercent.toString())),
            ),
            DataCell(Text(ReportMoney.full(b.net))),
            DataCell(
              Text(
                ReportMoney.full(b.vat),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ),
          ],
        ),
      if (report.zeroRatedTurnover > Decimal.zero)
        DataRow(
          cells: [
            DataCell(Text(l10n.repF300ZeroRatedTurnover)),
            DataCell(Text(ReportMoney.full(report.zeroRatedTurnover))),
            const DataCell(Text('—')),
          ],
        ),
    ];
    return ReportChartCard(
      title: l10n.repF300Title,
      subtitle: l10n.repF300Subtitle(
        ReportMoney.withCurrency(report.taxableTurnover),
        ReportMoney.withCurrency(report.outputVat),
      ),
      height: _tableHeight(rows.length),
      child: rows.isEmpty
          ? _empty(context, l10n)
          : SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(l10n.repColRow)),
                  DataColumn(
                    label: Text(l10n.repColTurnoverExclVat),
                    numeric: true,
                  ),
                  DataColumn(label: Text(l10n.repColVat), numeric: true),
                ],
                rows: rows,
              ),
            ),
    );
  }

  Widget _buildCashBook(
    BuildContext context,
    CashBookReport report,
    AppLocalizations l10n,
  ) {
    final display = report.entries.take(60).toList();
    return ReportChartCard(
      title: l10n.repCashBookTitle,
      subtitle: l10n.repCashBookSubtitle(
        ReportMoney.withCurrency(report.totalIncome),
        ReportMoney.withCurrency(report.totalExpense),
        ReportMoney.withCurrency(report.closingBalance),
      ),
      height: _tableHeight(display.length),
      child: display.isEmpty
          ? _empty(context, l10n)
          : SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(l10n.repColDate)),
                  DataColumn(label: Text(l10n.repColOperation)),
                  DataColumn(label: Text(l10n.repColIncome), numeric: true),
                  DataColumn(label: Text(l10n.repColExpense), numeric: true),
                  DataColumn(label: Text(l10n.repColBalance), numeric: true),
                ],
                rows: [
                  for (final e in display)
                    DataRow(
                      cells: [
                        DataCell(Text(_fmtDate(e.ts))),
                        DataCell(Text(e.kindLabel(l10n))),
                        DataCell(
                          Text(
                            e.income > Decimal.zero
                                ? ReportMoney.full(e.income)
                                : '—',
                          ),
                        ),
                        DataCell(
                          Text(
                            e.expense > Decimal.zero
                                ? ReportMoney.full(e.expense)
                                : '—',
                          ),
                        ),
                        DataCell(
                          Text(
                            ReportMoney.full(e.balanceAfter),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildVat(
    BuildContext context,
    VatReport report,
    AppLocalizations l10n,
  ) {
    return ReportChartCard(
      title: l10n.repVatPeriodTitle,
      subtitle: l10n.repVatPeriodSubtitle(
        ReportMoney.withCurrency(report.totalVat),
        ReportMoney.withCurrency(report.totalGross),
      ),
      height: _tableHeight(report.buckets.length),
      child: report.buckets.isEmpty
          ? _empty(context, l10n)
          : SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(l10n.repColRate)),
                  DataColumn(label: Text(l10n.repColGross), numeric: true),
                  DataColumn(label: Text(l10n.repColVat), numeric: true),
                  DataColumn(label: Text(l10n.repColNet), numeric: true),
                ],
                rows: [
                  for (final b in report.buckets)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(b.hasVat ? '${b.ratePercent}%' : l10n.repNoVat),
                        ),
                        DataCell(Text(ReportMoney.full(b.gross))),
                        DataCell(
                          Text(
                            ReportMoney.full(b.vat),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                        DataCell(Text(ReportMoney.full(b.net))),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildArAp(
    BuildContext context,
    ArApReport report,
    AppLocalizations l10n,
  ) {
    return ReportChartCard(
      title: l10n.repArApTitle,
      subtitle: l10n.repArApSubtitle(
        ReportMoney.full(report.totalReceivable),
        ReportMoney.full(report.totalPayable),
        ReportMoney.full(report.netSaldo),
      ),
      height: _tableHeight(report.balances.length),
      child: report.balances.isEmpty
          ? _empty(context, l10n)
          : SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(l10n.repColCounterparty)),
                  DataColumn(label: Text(l10n.repColType)),
                  DataColumn(label: Text(l10n.repColSaldo), numeric: true),
                ],
                rows: [
                  for (final b in report.balances)
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 160,
                            child: Text(
                              b.name.isEmpty ? l10n.supplyNoName : b.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            b.isReceivable ? l10n.repDebtor : l10n.repCreditor,
                          ),
                        ),
                        DataCell(
                          Text(
                            ReportMoney.full(b.balance),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: b.isReceivable
                                  ? AppColors.success
                                  : Theme.of(context).colorScheme.error,
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

  Widget _buildCashCollection(
    BuildContext context,
    CashCollectionReport report,
    AppLocalizations l10n,
  ) {
    return ReportChartCard(
      title: l10n.repCashCollectionTitle,
      subtitle: l10n.repCashCollectionSubtitle(
        report.count,
        ReportMoney.withCurrency(report.total),
      ),
      height: _tableHeight(report.items.length),
      child: report.items.isEmpty
          ? _empty(context, l10n)
          : SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(l10n.repColDate)),
                  DataColumn(label: Text(l10n.repColAccount)),
                  DataColumn(label: Text(l10n.repColCashier)),
                  DataColumn(label: Text(l10n.repColAmount), numeric: true),
                ],
                rows: [
                  for (final i in report.items)
                    DataRow(
                      cells: [
                        DataCell(Text(_fmtDate(i.docTime))),
                        DataCell(
                          Text(
                            i.accountName.isEmpty
                                ? l10n.cashTitle
                                : i.accountName,
                          ),
                        ),
                        DataCell(Text(i.userName)),
                        DataCell(
                          Text(
                            ReportMoney.full(i.amount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfit(
    BuildContext context,
    ProfitCogsReport report,
    AppLocalizations l10n,
  ) {
    final note = report.usesRealCogs
        ? l10n.repProfitCostRealCogs
        : l10n.repProfitCostWholesale;
    final display = report.items.take(30).toList();
    return ReportChartCard(
      title: l10n.repProfitMarginTitle,
      subtitle: l10n.repProfitMarginSubtitle(
        ReportMoney.withCurrency(report.totalProfit),
        report.totalMarginPct.toStringAsFixed(1),
        note,
      ),
      height: _tableHeight(display.length),
      child: display.isEmpty
          ? _empty(context, l10n)
          : SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(l10n.repColProduct)),
                  DataColumn(label: Text(l10n.repColRevenue), numeric: true),
                  DataColumn(label: Text(l10n.repColCogs), numeric: true),
                  DataColumn(label: Text(l10n.repColProfit), numeric: true),
                  DataColumn(label: Text(l10n.repColMarginPct), numeric: true),
                ],
                rows: [
                  for (final i in display)
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 140,
                            child: Text(
                              i.name.isEmpty ? l10n.supplyNoName : i.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(ReportMoney.full(i.revenue))),
                        DataCell(Text(ReportMoney.full(i.cogs))),
                        DataCell(
                          Text(
                            ReportMoney.full(i.profit),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: i.profit >= Decimal.zero
                                  ? AppColors.success
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        DataCell(Text('${i.marginPct.toStringAsFixed(1)}%')),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildWriteoff(
    BuildContext context,
    WriteoffReport report,
    AppLocalizations l10n,
  ) {
    return ReportChartCard(
      title: l10n.repWriteoffTitle,
      subtitle: l10n.repWriteoffSubtitle(
        report.docCount,
        ReportMoney.withCurrency(report.total),
      ),
      height: _tableHeight(report.buckets.length),
      child: report.buckets.isEmpty
          ? _empty(context, l10n)
          : SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  DataColumn(label: Text(l10n.repColReason)),
                  DataColumn(label: Text(l10n.repColDocuments), numeric: true),
                  DataColumn(label: Text(l10n.repColAmount), numeric: true),
                ],
                rows: [
                  for (final b in report.buckets)
                    DataRow(
                      cells: [
                        DataCell(Text(b.reasonLabel(l10n))),
                        DataCell(Text('${b.docCount}')),
                        DataCell(
                          Text(
                            ReportMoney.full(b.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
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

  double _tableHeight(int rows) =>
      (56.0 + rows.clamp(1, 20) * 48.0).clamp(120.0, 520.0);

  String _fmtDate(int? ts) {
    if (ts == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Widget _empty(BuildContext context, AppLocalizations l10n) => Center(
    child: Text(
      l10n.repNoData,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );

  Widget _loading(String title) => ReportChartCard(
    title: title,
    child: const Center(child: CircularProgressIndicator()),
  );

  Widget _error(
    BuildContext context,
    String title,
    Object e, [
    String? errorLabel,
  ]) => ReportChartCard(
    title: title,
    child: Center(
      child: Text(
        errorLabel != null ? '$errorLabel: $e' : '$e',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
