import 'package:decimal/decimal.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/presentation/controllers/app/money_ledger_revision.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/domain/cash/cash_operation_kind.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/data/shift/local_shift_desk.dart';
import 'package:telepos/domain/sale/deferred_claim_port.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/shift/assemble_shift_receipt_use_case.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/domain/shift/shift_status.dart';

/// Род кассовой операции глазами экрана смены.
///
/// Два последних рода — сведение журнала с пересчётом. Они показываются в
/// списке операций наравне с прочими, но в суммы смены НЕ входят: сведение
/// правит запись о деньгах, а не деньги. Сторона вынесена в РОД, а не в
/// знак суммы: суммы всех операций положительны, и недостача, записанная
/// положительным числом без рода, читалась бы как излишек.
///
/// Числа рода живут в `domain/cash/cash_operation_kind.dart`.
enum CashOperationType {
  investment,
  expense,
  dividend,
  reconciliationOverage,
  reconciliationShortage,
  openingCountOverage,
  openingCountShortage,
}

const kShiftMaxAge = Duration(hours: 24);

@immutable
class XReportOutcome {
  const XReportOutcome({
    required this.printed,
    this.fiscal,
    this.skipped = false,
  });

  final bool printed;
  final FiscalReportResult? fiscal;
  final bool skipped;
}

/// Чем кончилась сдача Z-отчёта в печать.
///
/// **Здесь три значения, а не `bool`, и это не педантизм.** До очереди печати
/// `printZReport` возвращала `true` уже после записи в принтер, и `true`
/// означало «бумага вышла» — снекбар «Z-отчёт распечатан» был правдой. Теперь
/// отчёт сдаётся в очередь и печатается, когда принтер сможет (И30: смена не
/// ждёт бумаги), а `true` означает всего лишь «принято». Оставить `bool`
/// значило бы оставить экрану сообщать «распечатан» о документе, которого на
/// бумаге нет и может не быть: срок задания — тридцать минут
/// (`PrintSubmission.documentLifetime`), после чего оно истекает и требует
/// ручного повтора с экрана настроек принтера. Для фискальной отчётности
/// Z-отчёт — документ, а не удобство, и кассир, закрывающий смену, обязан
/// узнать, что бумаги ещё нет, **не дожидаясь** её.
///
/// Передаётся по имени, никогда по индексу.
enum ZReportOutcome {
  /// Задание принято очередью. Бумаги пока нет.
  queued,

  /// Отчёт уже сдан в печать — этим же нажатием, которое ещё идёт, или
  /// раньше. Второго Z-отчёта не будет, и это правильный ответ, а не отказ.
  alreadyQueued,

  /// Сдать не удалось; причина — в [ShiftState.error].
  failed,
}

/// Банкноты для счётчика купюр — ПО СТРАНЕ кассы.
///
/// Здесь стояла константа `[200, 500, 1000, 2000, 5000, 10000, 20000]`,
/// одинаковая для всех стран. На американской кассе кассир пересчитывал
/// купюры, которых не существует, и не мог пересчитать доллар, пятёрку и
/// двадцатку. Для Казахстана список совпадал со списком экрана оплаты —
/// оттого расхождение и жило незаметно.
///
/// Источник один: [CountryCode.banknotes].
/// Номиналы для счётчика купюр этой кассы.
///
/// Отказ даёт умолчание, а не пустой список: счётчик купюр — удобство, и
/// экран смены не имеет права не открыться из-за него. Тот же довод, что у
/// `denominationsProvider` на экране оплаты.
final billDenominationsProvider = FutureProvider<List<int>>((ref) async {
  try {
    final setup = await GetIt.I<StartupStateRepository>().watch().first;
    return billDenominationsOf(setup.countryCode);
  } on Object catch (e) {
    talker.warning('Shift: country unavailable, default bills: $e');
    return billDenominationsOf(null);
  }
});

List<int> billDenominationsOf(int? countryCode) {
  final country =
      (countryCode != null &&
          countryCode >= 0 &&
          countryCode < CountryCode.values.length)
      ? CountryCode.values[countryCode]
      : CountryCode.kzt;
  return country.banknotes;
}

@immutable
class CashOperationItem {
  const CashOperationItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.reasonCode,
    required this.time,
  });

  final int id;
  final CashOperationType type;
  final Decimal amount;
  final String? note;

  /// Основание операции числом (схема v58); `null` — не записано. До v58
  /// основание жило внутри `note` русской прозой, и подпись под операцией
  /// на английской кассе оставалась русской.
  final int? reasonCode;
  final DateTime time;

  String localizedTypeLabel(AppLocalizations l10n) => switch (type) {
    CashOperationType.investment => l10n.cashInvestment,
    CashOperationType.expense => l10n.cashExpense,
    CashOperationType.dividend => l10n.cashWithdrawal,
    CashOperationType.reconciliationOverage => l10n.shiftSurplus,
    CashOperationType.reconciliationShortage => l10n.shiftShortage,
    // Одна подпись на обе стороны: при открытии ожидания ещё нет, и слова
    // «излишек»/«недостача» здесь были бы обвинением. Сторону показывает
    // цвет строки.
    CashOperationType.openingCountOverage ||
    CashOperationType.openingCountShortage => l10n.cashOpeningCount,
  };
}

@immutable
class ShiftState {
  ShiftState({
    this.currentShift,
    this.isOpen = false,
    this.openTime,
    this.cashierName,
    this.cashierId,
    Map<int, int>? billCounts,
    Decimal? billsTotal,
    Decimal? manualTotal,
    Decimal? systemTotal,
    Decimal? openingCash,
    Decimal? investmentTotal,
    Decimal? expenseTotal,
    Decimal? dividendTotal,
    this.cashOperations = const [],
    this.activeSalesCount = 0,
    this.pendingSalesCount = 0,
    this.salesCount = 0,
    Decimal? salesTotal,
    Decimal? cashSalesTotal,
    Decimal? cardSalesTotal,
    this.refundsCount = 0,
    Decimal? refundsTotal,
    Decimal? cashRefundsTotal,
    this.selectedTab = 0,
    this.isLoading = false,
    this.error,
    this.zReportFailed = false,
  }) : billCounts = billCounts ?? {},
       billsTotal = billsTotal ?? Decimal.zero,
       manualTotal = manualTotal ?? Decimal.zero,
       systemTotal = systemTotal ?? Decimal.zero,
       openingCash = openingCash ?? Decimal.zero,
       investmentTotal = investmentTotal ?? Decimal.zero,
       expenseTotal = expenseTotal ?? Decimal.zero,
       dividendTotal = dividendTotal ?? Decimal.zero,
       salesTotal = salesTotal ?? Decimal.zero,
       cashSalesTotal = cashSalesTotal ?? Decimal.zero,
       cardSalesTotal = cardSalesTotal ?? Decimal.zero,
       refundsTotal = refundsTotal ?? Decimal.zero,
       cashRefundsTotal = cashRefundsTotal ?? Decimal.zero;

  final Shift? currentShift;

  final bool isOpen;

  final DateTime? openTime;

  final String? cashierName;

  final int? cashierId;

  final Map<int, int> billCounts;

  final Decimal billsTotal;

  final Decimal manualTotal;

  final Decimal systemTotal;

  final Decimal openingCash;

  bool get hasCounted =>
      billCounts.values.any((c) => c > 0) || manualTotal > Decimal.zero;

  /// Сколько в ящике **обязано** лежать прямо сейчас.
  ///
  /// Внесения здесь со знаком плюс, и это правка 2026-09-22. Прежде их не
  /// было вовсе, а `LocalShiftDesk._cashTotals` оправдывал пропуск словами
  /// «в „должно быть“ они уже вошли выручкой». Неправда: внесение наличных
  /// строки оплаты не создаёт (`CashInOutControllerImpl._createOperation`
  /// пишет только строку операции и двигает остаток счёта), поэтому в
  /// выручку оно не попадало ни на одном из двух путей. Внесли 100 $ — и на
  /// закрытии касса объявляла излишек 100 $, которого не было.
  Decimal get expectedCash =>
      openingCash +
      cashSalesTotal -
      cashRefundsTotal +
      investmentTotal -
      (expenseTotal + dividendTotal);

  /// Расхождение пересчёта с ожиданием — **одно число, а не два**.
  ///
  /// До 2026-09-22 их было два: `difference` считалось от `systemTotal`
  /// (остатка счёта), `reconciliation` — от `expectedCash`. Экраны
  /// показывали первое, стол смены записывал второе, и расходились они
  /// ровно на подъёмные: кассир, пересчитавший ящик верно, видел «излишек
  /// +200». Теперь это синонимы, и `systemTotal` остался тем, чем и был, —
  /// независимой сверкой журнала, а не вторым мнением о расхождении.
  Decimal get difference =>
      hasCounted ? enteredTotal - expectedCash : Decimal.zero;

  Decimal get reconciliation => difference;

  final Decimal investmentTotal;

  final Decimal expenseTotal;

  final Decimal dividendTotal;

  final List<CashOperationItem> cashOperations;

  final int activeSalesCount;

  final int pendingSalesCount;

  final int salesCount;

  final Decimal salesTotal;

  final Decimal cashSalesTotal;

  final Decimal cardSalesTotal;

  final int refundsCount;

  final Decimal refundsTotal;

  final Decimal cashRefundsTotal;

  final int selectedTab;

  final bool isLoading;

  final String? error;

  final bool zReportFailed;

  bool get canClose => isOpen;

  Duration? get shiftAge {
    if (!isOpen || openTime == null) return null;
    return DateTime.now().difference(openTime!);
  }

  bool get isOverAge {
    final age = shiftAge;
    return age != null && age >= kShiftMaxAge;
  }

  bool get hasUnfinishedSales => activeSalesCount > 0 || pendingSalesCount > 0;

  Decimal get enteredTotal => selectedTab == 0 ? billsTotal : manualTotal;

  bool get hasDifference => difference != Decimal.zero;

  ShiftState copyWith({
    Shift? currentShift,
    bool? isOpen,
    DateTime? openTime,
    String? cashierName,
    int? cashierId,
    Map<int, int>? billCounts,
    Decimal? billsTotal,
    Decimal? manualTotal,
    Decimal? systemTotal,
    Decimal? openingCash,
    Decimal? investmentTotal,
    Decimal? expenseTotal,
    Decimal? dividendTotal,
    List<CashOperationItem>? cashOperations,
    int? activeSalesCount,
    int? pendingSalesCount,
    int? salesCount,
    Decimal? salesTotal,
    Decimal? cashSalesTotal,
    Decimal? cardSalesTotal,
    int? refundsCount,
    Decimal? refundsTotal,
    Decimal? cashRefundsTotal,
    int? selectedTab,
    bool? isLoading,
    String? error,
    bool? zReportFailed,
  }) {
    return ShiftState(
      currentShift: currentShift ?? this.currentShift,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      cashierName: cashierName ?? this.cashierName,
      cashierId: cashierId ?? this.cashierId,
      billCounts: billCounts ?? this.billCounts,
      billsTotal: billsTotal ?? this.billsTotal,
      manualTotal: manualTotal ?? this.manualTotal,
      systemTotal: systemTotal ?? this.systemTotal,
      openingCash: openingCash ?? this.openingCash,
      investmentTotal: investmentTotal ?? this.investmentTotal,
      expenseTotal: expenseTotal ?? this.expenseTotal,
      dividendTotal: dividendTotal ?? this.dividendTotal,
      cashOperations: cashOperations ?? this.cashOperations,
      activeSalesCount: activeSalesCount ?? this.activeSalesCount,
      pendingSalesCount: pendingSalesCount ?? this.pendingSalesCount,
      salesCount: salesCount ?? this.salesCount,
      salesTotal: salesTotal ?? this.salesTotal,
      cashSalesTotal: cashSalesTotal ?? this.cashSalesTotal,
      cardSalesTotal: cardSalesTotal ?? this.cardSalesTotal,
      refundsCount: refundsCount ?? this.refundsCount,
      refundsTotal: refundsTotal ?? this.refundsTotal,
      cashRefundsTotal: cashRefundsTotal ?? this.cashRefundsTotal,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      zReportFailed: zReportFailed ?? this.zReportFailed,
    );
  }
}

class ShiftNotifier extends Notifier<ShiftState> {
  bool _loadingInProgress = false;

  bool _zPrintInProgress = false;

  bool _xReportInProgress = false;

  @override
  ShiftState build() {
    // «Деньги изменились» приходит числом (`MoneyLedgerRevision`): тот, кто
    // их изменил, больше не обязан знать имя этого провайдера — а значит и
    // импортировать этот файл вместе со всей базой за ним. Поведение то же,
    // что у прежнего `ref.invalidate(shiftControllerProvider)`: смена
    // перечитывает себя.
    ref.watch(moneyLedgerRevisionProvider);
    _loadingInProgress = false;
    Future.microtask(() {
      if (!ref.mounted) return;
      if (!_loadingInProgress) {
        _loadingInProgress = true;
        _loadShiftData();
      }
    });
    return ShiftState(isLoading: true);
  }

  AppDatabase get _db => GetIt.I<AppDatabase>();

  Future<void> _loadShiftData() async {
    try {
      final shift = await _db.shiftDao.findOpenedShift();

      if (shift != null) {
        final userRow = await _db.shiftDao.findCurrentUser();
        final userName = userRow?.data['name'] as String?;

        final operations = await _loadCashOperations(shift.openTime);

        var investmentTotal = Decimal.zero;
        var expenseTotal = Decimal.zero;
        var dividendTotal = Decimal.zero;

        for (final op in operations) {
          switch (op.type) {
            case CashOperationType.investment:
              investmentTotal += op.amount;
            case CashOperationType.expense:
              expenseTotal += op.amount;
            case CashOperationType.dividend:
              dividendTotal += op.amount;
            case CashOperationType.reconciliationOverage:
            case CashOperationType.reconciliationShortage:
            case CashOperationType.openingCountOverage:
            case CashOperationType.openingCountShortage:
              // Сведение денег не двигает — оно приводит журнал к тому, что
              // человек пересчитал. Сложить его со слагаемыми значило бы
              // посчитать пересчёт дважды.
              break;
          }
        }

        final systemTotal = await _calculateSystemTotal(shift);

        final salesTotals = await _loadSalesTotals(shift.openTime);

        final activeSales = await _countActiveSales();
        final pendingSales = await _countPendingSales();

        if (!ref.mounted) return;
        state = ShiftState(
          currentShift: shift,
          isOpen: shift.isOpened,
          openTime: DateTime.fromMillisecondsSinceEpoch(shift.openTime * 1000),
          cashierName: userName,
          cashierId: shift.userId,
          cashOperations: operations,
          investmentTotal: investmentTotal,
          expenseTotal: expenseTotal,
          dividendTotal: dividendTotal,
          systemTotal: systemTotal,
          openingCash: shift.openingCash ?? Decimal.zero,
          salesCount: salesTotals.salesCount,
          salesTotal: salesTotals.salesTotal,
          cashSalesTotal: salesTotals.cashSalesTotal,
          cardSalesTotal: salesTotals.cardSalesTotal,
          refundsCount: salesTotals.refundsCount,
          refundsTotal: salesTotals.refundsTotal,
          cashRefundsTotal: salesTotals.cashRefundsTotal,
          activeSalesCount: activeSales,
          pendingSalesCount: pendingSales,
          isLoading: false,
        );
      } else {
        if (!ref.mounted) return;
        state = ShiftState(isOpen: false, isLoading: false);
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = ShiftState(
        isLoading: false,
        error: 'error.shift_load_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<List<CashOperationItem>> _loadCashOperations(int shiftOpenTime) async {
    try {
      final rows = await _db
          .customSelect(
            'SELECT * FROM cash_operations WHERE doc_time >= ? ORDER BY doc_time DESC',
            variables: [Variable.withInt(shiftOpenTime)],
            readsFrom: {_db.cashOperations},
          )
          .get();

      return rows.map((row) {
        final typeIndex = row.read<int>('type');
        // `default` здесь был дефектом ожидания: тип 3 попадал в дивиденды
        // и ВЫЧИТАЛСЯ бы из «должно быть». Роды перечислены поимённо, а
        // неизвестный впредь — сведение, то есть в суммы не входит.
        final type = switch (typeIndex) {
          kCashOpInvestment => CashOperationType.investment,
          kCashOpExpense => CashOperationType.expense,
          kCashOpDividend => CashOperationType.dividend,
          kCashOpReconciliationShortage =>
            CashOperationType.reconciliationShortage,
          kCashOpOpeningCountOverage => CashOperationType.openingCountOverage,
          kCashOpOpeningCountShortage =>
            CashOperationType.openingCountShortage,
          _ => CashOperationType.reconciliationOverage,
        };

        final amountDouble = row.read<double>('amount');
        final docTime = row.read<int?>('doc_time') ?? 0;

        return CashOperationItem(
          id: row.read<int>('id'),
          type: type,
          amount: Decimal.parse(amountDouble.toStringAsFixed(3)),
          note: row.read<String?>('note'),
          reasonCode: row.read<int?>('reason_code'),
          time: DateTime.fromMillisecondsSinceEpoch(docTime * 1000),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Decimal> _calculateSystemTotal(Shift shift) async {
    try {
      final thisPos = await _db.thisPosDao.get();
      var posAccountId = thisPos?.accountId;

      if (posAccountId == null) {
        final posAccounts = await _db.accountDao.findByType(AccountType.pos);
        if (posAccounts.isNotEmpty) {
          posAccountId = posAccounts.first.id;
        }
      }

      if (posAccountId == null) return Decimal.zero;

      final account = await _db.accountDao.findById(posAccountId);
      return account?.value ?? Decimal.zero;
    } catch (e) {
      talker.error('Shift: _calculateSystemTotal error: $e');
      return Decimal.zero;
    }
  }

  Future<_SalesTotals> _loadSalesTotals(int shiftOpenTime) async {
    try {
      final salesRows = await _db
          .customSelect(
            'SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0) as total '
            'FROM sales WHERE time >= ? AND state NOT IN (0, 3)',
            variables: [Variable.withInt(shiftOpenTime)],
            readsFrom: {_db.sales},
          )
          .getSingle();

      final salesCount = salesRows.read<int>('cnt');
      final salesTotalDouble = salesRows.read<double>('total');
      final salesTotal = Decimal.parse(salesTotalDouble.toStringAsFixed(2));

      var cashTotal = Decimal.zero;
      var cardTotal = Decimal.zero;

      final paymentRows = await _db
          .customSelect(
            'SELECT a.type as account_type, COALESCE(SUM(p.amount), 0) as total '
            'FROM payments p '
            'JOIN accounts a ON a.id = p.payee_account_id '
            'WHERE p.time >= ? AND p.receipt_no IS NOT NULL '
            'GROUP BY a.type',
            variables: [Variable.withInt(shiftOpenTime)],
            readsFrom: {_db.payments, _db.accounts},
          )
          .get();

      for (final row in paymentRows) {
        final accountType = row.read<int>('account_type');
        final total = Decimal.parse(
          row.read<double>('total').toStringAsFixed(2),
        );
        if (accountType == 0 || accountType == 2) {
          cashTotal += total;
        } else {
          cardTotal += total;
        }
      }

      final refundRows = await _db
          .customSelect(
            'SELECT COUNT(*) as cnt, COALESCE(SUM(amount), 0) as total '
            'FROM refunds WHERE time >= ? AND state NOT IN (0)',
            variables: [Variable.withInt(shiftOpenTime)],
            readsFrom: {_db.refunds},
          )
          .getSingle();

      final refundsCount = refundRows.read<int>('cnt');
      final refundsTotalDouble = refundRows.read<double>('total');
      final refundsTotal = Decimal.parse(refundsTotalDouble.toStringAsFixed(2));

      final cashRefundRows = await _db
          .customSelect(
            'SELECT COALESCE(SUM(-p.amount), 0) as total '
            'FROM payments p JOIN accounts a ON a.id = p.payee_account_id '
            'WHERE p.refund_local_id IS NOT NULL AND p.time >= ? '
            'AND a.type IN (0, 2)',
            variables: [Variable.withInt(shiftOpenTime)],
            readsFrom: {_db.payments, _db.accounts},
          )
          .getSingle();
      final cashRefundsTotal = Decimal.parse(
        cashRefundRows.read<double>('total').toStringAsFixed(2),
      );

      return _SalesTotals(
        salesCount: salesCount,
        salesTotal: salesTotal,
        cashSalesTotal: cashTotal,
        cardSalesTotal: cardTotal,
        refundsCount: refundsCount,
        refundsTotal: refundsTotal,
        cashRefundsTotal: cashRefundsTotal,
      );
    } catch (e) {
      talker.error('Shift: _loadSalesTotals error: $e');
      return _SalesTotals();
    }
  }

  Future<int> _countActiveSales() async {
    try {
      final result = await _db
          .customSelect(
            'SELECT COUNT(*) as cnt FROM sales s '
            'WHERE s.state = 0 AND (s.amount > 0.001 OR EXISTS '
            '(SELECT 1 FROM sale_products sp WHERE sp.receipt_no = s.receipt_no AND sp.pos_id = s.pos_id))',
            readsFrom: {_db.sales, _db.saleProducts},
          )
          .getSingle();
      final cnt = result.read<int>('cnt');
      talker.debug('Shift: activeSales=$cnt');
      return cnt;
    } catch (e) {
      talker.error('Shift: _countActiveSales error: $e');
      return 0;
    }
  }

  Future<int> _countPendingSales() async {
    try {
      return await _db.saleDao.countWithState(3);
    } catch (e) {
      return 0;
    }
  }

  Future<void> openShift(Decimal initialAmount, {int? userId}) async {
    if (state.isOpen) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final effectiveUserId = userId ?? ref.read(appStateProvider).userId ?? 1;

      final shiftService = GetIt.I<ShiftService>();
      await shiftService.onOpenShift(
        effectiveUserId,
        openingCash: initialAmount,
      );
      // Задача 47: открытую здесь смену значок узнаёт сразу, а не с
      // первого начатого чека.
      ref.read(appStateProvider.notifier).setShift(ShiftStatus.open);

      await _loadShiftData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.shift_open_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<void> closeShift() async {
    if (!state.canClose) return;

    final shift = state.currentShift;
    if (shift == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Процедура закрытия живёт **в одном месте на кассу**
      // (`LocalShiftDesk`), и её же зовёт обработчик провода
      // (`TillOps.shiftClose`) — решение заказчика 2026-09-18, «в браузере
      // должно работать то же, что в приложении».
      //
      // До этой правки уборка начатых чеков, выбор суммы и запись
      // расхождения стояли прямо здесь, поверх `GetIt.I<AppDatabase>()`.
      // Оставить их здесь и написать рядом такие же для провода значило бы
      // закрывать смену с кассы одним способом, а с планшета другим, и
      // расходились бы они **в деньгах**: расхождение, записанное одним
      // путём и не записанное другим, не ловится ни инвентаризацией, ни
      // отчётом смены.
      //
      // `counted` — **`null`, когда никто не считал**, а не `systemTotal`:
      // выбор «насчитали против системного итога» делает стойка, тем же
      // правилом, каким его делал этот метод. Передай экран сюда системный
      // итог, он бы сам решал за кассу, каким числом закрывать смену.
      await LocalShiftDesk(
        db: _db,
        shifts: GetIt.I<ShiftService>(),
        logger: talker,
        // Отзыв отложенных чеков при закрытии смены: без него соседняя касса
        // продолжала бы показывать корзину, которой уже нет.
        claim: GetIt.I.isRegistered<DeferredClaimPort>()
            ? GetIt.I<DeferredClaimPort>()
            : null,
      ).close(counted: state.hasCounted ? state.enteredTotal : null);

      ref.read(appStateProvider.notifier).setShift(ShiftStatus.closed);

      await _loadShiftData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.shift_close_failed:${safeErrorText(e)}',
      );
    }
  }

  Future<ZReportOutcome> printZReport() async {
    final shift = state.currentShift;
    if (shift == null) return ZReportOutcome.failed;

    if (_zPrintInProgress) return ZReportOutcome.alreadyQueued;
    _zPrintInProgress = true;

    state = state.copyWith(zReportFailed: false, error: null);

    try {
      final assembleReceipt = GetIt.I<AssembleShiftReceiptUseCase>();
      // Не считали — в отчёт идёт ОЖИДАНИЕ, а не остаток счёта. Стояло
      // `state.systemTotal`, и на смене с подъёмными Z-отчёт занижал
      // наличные ровно на сумму, с которой смену открыли. Тем же правилом
      // живёт `LocalShiftDesk.close`.
      final cashInPos = state.hasCounted
          ? state.enteredTotal
          : state.expectedCash;
      final receipt = await assembleReceipt.assemble(shift.id, cashInPos);
      if (receipt == null) {
        state = state.copyWith(
          error: 'error.shift_zreport_failed',
          zReportFailed: true,
        );
        return ZReportOutcome.failed;
      }

      // Денежный блок Z-отчёта обязан СХОДИТЬСЯ: бланк печатает четыре
      // строки — «На начало», «Приход», «Расход», «Итого в ящике» — и этим
      // утверждает равенство `начало + приход − расход = итого`.
      //
      // До 2026-09-22 оно не держалось ни в одном месте. «Приход» брался
      // `receipt.cashPaymentsSum` — это выручка наличными БЕЗ возвратов
      // (запрос отбирает по `receipt_no`, а возврат ссылается на
      // `refund_local_id`), внесения в него не входили вовсе, а возвраты
      // не вычитались нигде. «На начало» приезжало от прошлой смены.
      //
      // Теперь все слагаемые — из одного состояния, и равенство держится
      // по построению: `expectedCash` собран из них же.
      final cashIncome = state.cashSalesTotal + state.investmentTotal;
      final cashExpense =
          state.cashRefundsTotal + state.expenseTotal + state.dividendTotal;

      final cashStart = await _resolveOpeningCash(receipt.openingCash);

      // Расхождение печатается отдельной строкой и только когда оно есть:
      // без неё пересчитанный ящик ломал бы равенство бланка молча —
      // «итого» отличалось бы от суммы трёх строк, и прочитать почему
      // было бы неоткуда.
      final cashDiscrepancy = state.difference;

      final printService = GetIt.I<ReceiptPrintService>();
      // «Принято» больше не значит «бумага вышла»: Z-отчёт сдаётся в очередь
      // печати и печатается, когда принтер сможет. Ошибкой смены считается
      // только отказ принять задание — иначе закрытие смены снова начало бы
      // зависеть от того, есть ли прямо сейчас бумага.
      final outcome = await printService.printZReport(
        storeName: receipt.companyName ?? '',
        posName: receipt.posName ?? '',
        cashierName: receipt.shiftUserName,
        shiftStart: DateTime.fromMillisecondsSinceEpoch(
          receipt.shiftOpenTime * 1000,
        ),
        shiftEnd: DateTime.fromMillisecondsSinceEpoch(
          receipt.shiftCloseTime * 1000,
        ),
        saleCount: state.salesCount,
        saleTotal: receipt.saleAmount,
        refundCount: state.refundsCount,
        refundTotal: state.refundsTotal,
        cashStart: cashStart,
        cashEnd: receipt.cashInPos,
        cashIncome: cashIncome,
        cashExpense: cashExpense,
        cashDiscrepancy: cashDiscrepancy,
        // Оба числа — **из той же сборки отчёта**, что и выручка, а не
        // посчитанные здесь заново: второе мнение о том, сколько выпущено
        // сертификатов, разошлось бы с первым молча. Разбор источников — в
        // докстрингах `ShiftReceipt.certificatesIssued` и
        // `ShiftReceipt.certificatesRedeemed`.
        certificatesIssued: receipt.certificatesIssued,
        certificatesRedeemed: receipt.certificatesRedeemed,
      );

      if (outcome.isRejected) {
        state = state.copyWith(
          error: 'error.shift_zreport_failed',
          zReportFailed: true,
        );
        return ZReportOutcome.failed;
      }
      // «Принято» — не «напечатано», и наружу это уезжает разными значениями:
      // экран обязан сказать кассиру, что бумаги ещё нет, а не поздравить его
      // с распечатанным отчётом.
      return outcome.isAccepted
          ? ZReportOutcome.queued
          : ZReportOutcome.alreadyQueued;
    } catch (e) {
      debugPrint('Z-report print error: $e');
      state = state.copyWith(
        error: 'error.shift_zreport_failed:${safeErrorText(e)}',
        zReportFailed: true,
      );
      return ZReportOutcome.failed;
    } finally {
      _zPrintInProgress = false;
    }
  }

  Future<XReportOutcome> runXReport() async {
    if (_xReportInProgress) {
      return const XReportOutcome(printed: false, skipped: true);
    }
    _xReportInProgress = true;
    try {
      final printed = await _printXReport();

      FiscalReportResult fiscal;
      try {
        if (!await GetIt.I<FiscalService>().isEnabled()) {
          return XReportOutcome(printed: printed, skipped: true);
        }
        fiscal = await GetIt.I<FiscalService>().xReport();
      } catch (e, st) {
        talker.error('Shift: runXReport fiscal error: $e', e, st);
        fiscal = FiscalReportResult.failure(
          'error.shift_xreport_failed:${safeErrorText(e)}',
        );
      }
      return XReportOutcome(printed: printed, fiscal: fiscal);
    } catch (e, st) {
      talker.error('Shift: runXReport error: $e', e, st);
      return XReportOutcome(
        printed: false,
        fiscal: FiscalReportResult.failure(
          'error.shift_xreport_failed:${safeErrorText(e)}',
        ),
      );
    } finally {
      _xReportInProgress = false;
    }
  }

  Future<bool> _printXReport() async {
    try {
      final shift = state.currentShift;
      if (shift == null) return false;

      final assembleReceipt = GetIt.I<AssembleShiftReceiptUseCase>();
      final cashInPos = state.hasCounted
          ? state.enteredTotal
          : state.systemTotal;
      final receipt = await assembleReceipt.assemble(shift.id, cashInPos);
      if (receipt == null) return false;

      final printService = GetIt.I<ReceiptPrintService>();
      // Как и у Z-отчёта: неудачей считается только отказ очереди принять
      // задание, а не отсутствие бумаги в эту секунду.
      final outcome = await printService.printXReport(
        storeName: receipt.companyName ?? '',
        posName: receipt.posName ?? '',
        cashierName: receipt.shiftUserName,
        dateTime: DateTime.now(),
        saleCount: state.salesCount,
        saleTotal: receipt.saleAmount,
        refundCount: state.refundsCount,
        refundTotal: state.refundsTotal,
        cashInDrawer: cashInPos,
        certificatesIssued: receipt.certificatesIssued,
        certificatesRedeemed: receipt.certificatesRedeemed,
      );
      return !outcome.isRejected;
    } catch (e, st) {
      talker.error('Shift: _printXReport error: $e', e, st);
      return false;
    }
  }

  Future<FiscalResult> runCorrection(FiscalCorrectionRequest req) async {
    try {
      final fiscal = GetIt.I<FiscalService>();
      return await fiscal.correction(req);
    } catch (e, st) {
      talker.error('Shift: runCorrection error: $e', e, st);
      return FiscalResult.failure(
        'error.shift_correction_failed:${safeErrorText(e)}',
      );
    }
  }

  /// Подъёмные для Z-отчёта.
  ///
  /// Запасной путь оставлен только для смен, открытых ДО появления
  /// столбца `shifts.opening_cash`: у них объявления нет и взять его
  /// неоткуда, кроме закрытия предыдущей смены. Прежде сюда попадала любая
  /// смена с нулём, в том числе честно открытая с пустым ящиком, — и в
  /// отчёт печаталось чужое число. Отличает их `null`, см.
  /// `ShiftReceipt.openingCash`.
  Future<Decimal> _resolveOpeningCash(Decimal? receiptOpeningCash) async {
    if (receiptOpeningCash != null) {
      return receiptOpeningCash;
    }
    try {
      final lastClosed = await _db.shiftDao.findLastClosed();
      return lastClosed?.cashInPosOnShiftClose ?? Decimal.zero;
    } catch (e) {
      talker.error('Shift: _resolveOpeningCash error: $e');
      return Decimal.zero;
    }
  }

  void setBillCount(int denomination, int count) {
    if (count < 0) count = 0;

    final newCounts = Map<int, int>.from(state.billCounts);
    newCounts[denomination] = count;

    final billsTotal = _calculateBillsTotal(newCounts);

    state = state.copyWith(billCounts: newCounts, billsTotal: billsTotal);
  }

  void incrementBill(int denomination) {
    final current = state.billCounts[denomination] ?? 0;
    setBillCount(denomination, current + 1);
  }

  void decrementBill(int denomination) {
    final current = state.billCounts[denomination] ?? 0;
    if (current > 0) {
      setBillCount(denomination, current - 1);
    }
  }

  void clearBills() {
    state = state.copyWith(billCounts: {}, billsTotal: Decimal.zero);
  }

  void setManualTotal(Decimal amount) {
    state = state.copyWith(manualTotal: amount);
  }

  void clearManualTotal() {
    state = state.copyWith(manualTotal: Decimal.zero);
  }

  void selectTab(int index) {
    if (index < 0 || index > 2) return;
    state = state.copyWith(selectedTab: index);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadShiftData();
  }

  Decimal _calculateBillsTotal(Map<int, int> counts) {
    var total = Decimal.zero;
    for (final entry in counts.entries) {
      total += Decimal.fromInt(entry.key) * Decimal.fromInt(entry.value);
    }
    return total;
  }
}

final shiftControllerProvider = NotifierProvider<ShiftNotifier, ShiftState>(
  ShiftNotifier.new,
);

final canCloseShiftProvider = Provider<bool>((ref) {
  final state = ref.watch(shiftControllerProvider);
  return state.canClose;
});

final shiftDifferenceProvider = Provider<Decimal>((ref) {
  final state = ref.watch(shiftControllerProvider);
  return state.difference;
});

class _SalesTotals {
  _SalesTotals({
    this.salesCount = 0,
    Decimal? salesTotal,
    Decimal? cashSalesTotal,
    Decimal? cardSalesTotal,
    this.refundsCount = 0,
    Decimal? refundsTotal,
    Decimal? cashRefundsTotal,
  }) : salesTotal = salesTotal ?? Decimal.zero,
       cashSalesTotal = cashSalesTotal ?? Decimal.zero,
       cardSalesTotal = cardSalesTotal ?? Decimal.zero,
       refundsTotal = refundsTotal ?? Decimal.zero,
       cashRefundsTotal = cashRefundsTotal ?? Decimal.zero;

  final int salesCount;
  final Decimal salesTotal;
  final Decimal cashSalesTotal;
  final Decimal cardSalesTotal;
  final int refundsCount;
  final Decimal refundsTotal;
  final Decimal cashRefundsTotal;
}
