import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/utils/decimal_util.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/report_dao.dart';
import 'package:telepos/domain/usecases/cogs/calculate_cogs_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/domain/tax/tax_amounts.dart';

int _toTs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

ReportDao get _reportDao => ReportDao(GetIt.I<AppDatabase>());

@immutable
class VatBucket {
  const VatBucket({
    required this.ratePercent,
    required this.gross,
    required this.vat,
  });

  final int ratePercent;
  final Decimal gross;
  final Decimal vat;

  Decimal get net => (gross - vat).money;

  bool get hasVat => ratePercent > 0;
}

@immutable
class VatReport {
  const VatReport({required this.buckets});

  final List<VatBucket> buckets;

  Decimal get totalGross =>
      buckets.fold(Decimal.zero, (s, b) => s + b.gross).money;

  Decimal get totalVat => buckets.fold(Decimal.zero, (s, b) => s + b.vat).money;

  Decimal get totalNet => (totalGross - totalVat).money;
}

/// Налог отчёта — ОБЩЕЙ формулой продукта.
///
/// Здесь лежала шестая её запись, со своим округлением
/// (`scaleOnInfinitePrecision: 6` против 10 у общей). Отчёт по НДС мог
/// разойтись с чеком и фискальным документом на копейку — а именно по
/// этому отчёту и отчитываются перед налоговой.
Decimal vatFromGross(Decimal gross, int ratePercent) =>
    taxFromGross(gross, Decimal.fromInt(ratePercent));

final vatReportProvider = FutureProvider.family<VatReport, DateTimeRange>((
  ref,
  range,
) async {
  final rows = await _reportDao.getVatByRate(
    _toTs(range.start),
    _toTs(range.end),
  );
  final buckets = rows.map((r) {
    final rate = r.read<int>('vat_rate');
    final gross = r.readDecimal('gross');
    return VatBucket(
      ratePercent: rate,
      gross: gross,
      vat: vatFromGross(gross, rate),
    );
  }).toList();
  return VatReport(buckets: buckets);
});

@immutable
class AgentBalance {
  const AgentBalance({
    required this.localId,
    required this.name,
    required this.agentType,
    required this.balance,
  });

  final int localId;
  final String name;
  final int agentType;
  final Decimal balance;

  bool get isReceivable => balance > Decimal.zero;
  bool get isPayable => balance < Decimal.zero;

  Decimal get payableAbs => isPayable ? -balance : Decimal.zero;
}

@immutable
class ArApReport {
  const ArApReport({required this.balances});

  final List<AgentBalance> balances;

  List<AgentBalance> get receivables =>
      balances.where((b) => b.isReceivable).toList();

  List<AgentBalance> get payables =>
      balances.where((b) => b.isPayable).toList();

  Decimal get totalReceivable =>
      receivables.fold(Decimal.zero, (s, b) => s + b.balance).money;

  Decimal get totalPayable =>
      payables.fold(Decimal.zero, (s, b) => s + b.payableAbs).money;

  Decimal get netSaldo => (totalReceivable - totalPayable).money;
}

final arApReportProvider = FutureProvider<ArApReport>((ref) async {
  final rows = await _reportDao.getAgentBalances();
  final balances = rows
      .map(
        (r) => AgentBalance(
          localId: r.read<int>('local_id'),
          // Пусто — значит имени НЕТ. Экран подставит слово своим языком.
          name: r.read<String?>('name') ?? '',
          agentType: r.read<int?>('agent_type') ?? -1,
          balance: r.readDecimal('balance'),
        ),
      )
      .where((b) => b.balance != Decimal.zero)
      .toList();
  return ArApReport(balances: balances);
});

@immutable
class CashCollectionItem {
  const CashCollectionItem({
    required this.id,
    required this.amount,
    required this.accountName,
    required this.userName,
    required this.note,
    required this.docTime,
  });

  final int id;
  final Decimal amount;
  final String accountName;
  final String userName;
  final String? note;
  final int? docTime;
}

@immutable
class CashCollectionReport {
  const CashCollectionReport({required this.items});

  final List<CashCollectionItem> items;

  Decimal get total => items.fold(Decimal.zero, (s, i) => s + i.amount).money;

  int get count => items.length;
}

final cashCollectionReportProvider =
    FutureProvider.family<CashCollectionReport, DateTimeRange>((
      ref,
      range,
    ) async {
      final rows = await _reportDao.getCashCollection(
        _toTs(range.start),
        _toTs(range.end),
      );
      final items = rows
          .map(
            (r) => CashCollectionItem(
              id: r.read<int>('id'),
              amount: r.readDecimal('amount'),
              accountName: r.read<String?>('account_name') ?? '',
              userName: r.read<String?>('user_name') ?? '—',
              note: r.read<String?>('note'),
              docTime: r.read<int?>('doc_time'),
            ),
          )
          .toList();
      return CashCollectionReport(items: items);
    });

@immutable
class ProfitCogsItem {
  const ProfitCogsItem({
    required this.ucode,
    required this.name,
    required this.qtySold,
    required this.revenue,
    required this.unitCost,
  });

  final int ucode;
  final String name;
  final Decimal qtySold;
  final Decimal revenue;
  final Decimal unitCost;

  Decimal get cogs => (qtySold * unitCost).money;

  Decimal get profit => (revenue - cogs).money;

  Decimal get marginPct => revenue > Decimal.zero
      ? (profit * DecimalUtil.hundred / revenue).toDecimal(
          scaleOnInfinitePrecision: 4,
        )
      : Decimal.zero;
}

@immutable
class ProfitCogsReport {
  const ProfitCogsReport({required this.items, required this.usesRealCogs});

  final List<ProfitCogsItem> items;
  final bool usesRealCogs;

  Decimal get totalRevenue =>
      items.fold(Decimal.zero, (s, i) => s + i.revenue).money;

  Decimal get totalCogs => items.fold(Decimal.zero, (s, i) => s + i.cogs).money;

  Decimal get totalProfit => (totalRevenue - totalCogs).money;

  Decimal get totalMarginPct => totalRevenue > Decimal.zero
      ? (totalProfit * DecimalUtil.hundred / totalRevenue).toDecimal(
          scaleOnInfinitePrecision: 4,
        )
      : Decimal.zero;
}

final profitCogsReportProvider =
    FutureProvider.family<ProfitCogsReport, DateTimeRange>((ref, range) async {
      final rows = await _reportDao.getProfitCogs(
        _toTs(range.start),
        _toTs(range.end),
      );

      CalculateCogsUseCase? cogsUseCase;
      if (GetIt.I.isRegistered<CalculateCogsUseCase>()) {
        cogsUseCase = GetIt.I<CalculateCogsUseCase>();
      }

      var anyRealCogs = false;
      final items = <ProfitCogsItem>[];
      for (final r in rows) {
        final ucode = r.read<int>('ucode');
        final qtySold = r.readDecimal('qty_sold');
        final wholesale = r.readDecimal('unit_cost');

        var unitCost = wholesale;
        if (cogsUseCase != null && qtySold > Decimal.zero) {
          try {
            final res = await cogsUseCase.calculate(
              ucode: ucode,
              quantity: qtySold,
            );
            if (res.fromBatches && res.resolvedQuantity > Decimal.zero) {
              unitCost = res.unitCost;
              anyRealCogs = true;
            }
          } catch (_) {}
        }

        items.add(
          ProfitCogsItem(
            ucode: ucode,
            name: r.read<String?>('name') ?? 'N/A',
            qtySold: qtySold,
            revenue: r.readDecimal('revenue'),
            unitCost: unitCost,
          ),
        );
      }
      return ProfitCogsReport(items: items, usesRealCogs: anyRealCogs);
    });

@immutable
class WriteoffBucket {
  const WriteoffBucket({
    required this.reason,
    required this.docCount,
    required this.total,
  });

  final int reason;
  final int docCount;
  final Decimal total;

  /// Причина списания словами языка интерфейса.
  ///
  /// Словарь — доводом: это модель отчёта, контекста у неё нет. Тот же
  /// приём, что у `_reasonLabel` на экранах списания и оборудования.
  String reasonLabel(AppLocalizations l10n) => switch (reason) {
    0 => l10n.writeoffReasonBreakage,
    1 => l10n.writeoffReasonExpired,
    2 => l10n.writeoffReasonDamage,
    3 => l10n.writeoffReasonLoss,
    4 => l10n.writeoffReasonOther,
    _ => l10n.writeoffReasonUnspecified,
  };
}

@immutable
class WriteoffReport {
  const WriteoffReport({required this.buckets});

  final List<WriteoffBucket> buckets;

  Decimal get total => buckets.fold(Decimal.zero, (s, b) => s + b.total).money;

  int get docCount => buckets.fold(0, (s, b) => s + b.docCount);
}

final writeoffReportProvider =
    FutureProvider.family<WriteoffReport, DateTimeRange>((ref, range) async {
      final rows = await _reportDao.getWriteoffByReason(
        _toTs(range.start),
        _toTs(range.end),
      );
      final buckets = rows
          .map(
            (r) => WriteoffBucket(
              reason: r.read<int>('reason'),
              docCount: r.read<int>('doc_count'),
              total: r.readDecimal('total'),
            ),
          )
          .toList();
      return WriteoffReport(buckets: buckets);
    });

@immutable
class F910IncomeReport {
  const F910IncomeReport({
    required this.salesIncome,
    required this.saleCount,
    required this.refundTotal,
    required this.refundCount,
    this.taxRatePercent = 3,
  });

  final Decimal salesIncome;
  final int saleCount;

  final Decimal refundTotal;
  final int refundCount;

  final int taxRatePercent;

  Decimal get taxableIncome {
    final net = (salesIncome - refundTotal).money;
    return net > Decimal.zero ? net : Decimal.zero;
  }

  Decimal get estimatedTax {
    final rate = Decimal.fromInt(taxRatePercent);
    return (taxableIncome * rate / DecimalUtil.hundred)
        .toDecimal(scaleOnInfinitePrecision: 6)
        .money;
  }
}

final f910IncomeReportProvider =
    FutureProvider.family<F910IncomeReport, DateTimeRange>((ref, range) async {
      final row = await _reportDao.getIncomeForPeriod(
        _toTs(range.start),
        _toTs(range.end),
      );
      return F910IncomeReport(
        salesIncome: row.readDecimal('sales_income'),
        saleCount: row.read<int>('sale_count'),
        refundTotal: row.readDecimal('refund_total'),
        refundCount: row.read<int>('refund_count'),
      );
    });

@immutable
class F300VatReport {
  const F300VatReport({required this.vat});

  final VatReport vat;

  List<VatBucket> get taxableBuckets =>
      vat.buckets.where((b) => b.hasVat).toList();

  List<VatBucket> get zeroRatedBuckets =>
      vat.buckets.where((b) => !b.hasVat).toList();

  Decimal get taxableTurnover =>
      taxableBuckets.fold(Decimal.zero, (s, b) => s + b.net).money;

  Decimal get zeroRatedTurnover =>
      zeroRatedBuckets.fold(Decimal.zero, (s, b) => s + b.gross).money;

  Decimal get outputVat => vat.totalVat;

  Decimal get totalTurnoverGross => vat.totalGross;
}

final f300VatReportProvider =
    FutureProvider.family<F300VatReport, DateTimeRange>((ref, range) async {
      final vat = await ref.watch(vatReportProvider(range).future);
      return F300VatReport(vat: vat);
    });

@immutable
class CashBookEntry {
  const CashBookEntry({
    required this.ts,
    required this.kind,
    required this.income,
    required this.expense,
    required this.balanceAfter,
    required this.accountName,
    required this.ref,
  });

  final int ts;

  final int kind;

  final Decimal income;

  final Decimal expense;

  final Decimal balanceAfter;

  final String accountName;
  final String ref;

  /// Род движения денег словами языка интерфейса.
  String kindLabel(AppLocalizations l10n) => switch (kind) {
    0 => l10n.historySale,
    1 => l10n.cashOpTypeInvestment,
    2 => l10n.cashOpTypeExpense,
    3 => l10n.cashOpTypeDividend,
    _ => '—',
  };
}

@immutable
class CashBookReport {
  const CashBookReport({required this.openingBalance, required this.entries});

  final Decimal openingBalance;
  final List<CashBookEntry> entries;

  Decimal get totalIncome =>
      entries.fold(Decimal.zero, (s, e) => s + e.income).money;

  Decimal get totalExpense =>
      entries.fold(Decimal.zero, (s, e) => s + e.expense).money;

  Decimal get closingBalance =>
      (openingBalance + totalIncome - totalExpense).money;

  int get count => entries.length;
}

final cashBookReportProvider =
    FutureProvider.family<CashBookReport, DateTimeRange>((ref, range) async {
      final rows = await _reportDao.getCashBookMovements(
        _toTs(range.start),
        _toTs(range.end),
      );

      var balance = Decimal.zero;
      final entries = <CashBookEntry>[];
      for (final r in rows) {
        final direction = r.read<int>('direction');
        final amount = r.readDecimal('amount');
        final income = direction > 0 ? amount : Decimal.zero;
        final expense = direction < 0 ? amount : Decimal.zero;
        balance = (balance + income - expense).money;
        entries.add(
          CashBookEntry(
            ts: r.read<int?>('ts') ?? 0,
            kind: r.read<int>('kind'),
            income: income,
            expense: expense,
            balanceAfter: balance,
            accountName: r.read<String?>('account_name') ?? '',
            ref: r.read<String?>('ref') ?? '',
          ),
        );
      }
      return CashBookReport(openingBalance: Decimal.zero, entries: entries);
    });
