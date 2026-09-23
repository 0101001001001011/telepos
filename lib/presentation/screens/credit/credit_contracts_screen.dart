import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/hardware/printer/receipt/credit_contract_receipt_builder.dart';
import 'package:telepos/app/theme/app_typography.dart';

/// Договоры рассрочки покупателя — **экран, без которого погашение мёртво**.
///
/// # Зачем экран входит той же задачей, что таблица
///
/// Правило дерева: «таблица, сторож и экран входят одной задачей или не
/// входят вовсе». В базе уже лежат три колонки без единого читателя
/// (`usersAllowedToRefund` и родня), заведённые, мигрированные и забытые.
/// `CreditContracts` стала бы четвёртой: договор писался бы продажей и
/// читался бы ниоткуда.
///
/// # Просрочка считается ЗДЕСЬ, на момент открытия
///
/// `CreditStanding.of(schedule, now)` — чистая функция от хранимых строк.
/// Хранимую колонку пришлось бы кому-то обновлять; фоновой работы,
/// переживающей выключение питания, в дереве нет, и на кассе,
/// простоявшей неделю, хранимое значение врало бы ровно неделю.
///
/// **Но экран не единственный, кто смотрит, и в этом весь ответ на «что,
/// если никто не смотрит».** Экран можно не открыть; заслон, на котором
/// всё держится, стоит на денежном пути — раскладка оплаты отказывается
/// выдать вторую рассрочку тому, кто просрочил первую
/// (`LocalPaymentService._plan`, `credit_overdue`).
///
/// # Отказы показываются словами, а не «не получилось»
///
/// Переплата называет остаток числом, потому что кассиру нужно именно
/// оно: досрочное погашение целиком — это `amount == outstanding`.
class CreditContractsScreen extends StatefulWidget {
  const CreditContractsScreen({
    super.key,
    required this.agentLocalId,
    required this.agentName,
  });

  final int agentLocalId;
  final String agentName;

  @override
  State<CreditContractsScreen> createState() => _CreditContractsScreenState();
}

class _CreditContractsScreenState extends State<CreditContractsScreen> {
  CreditService get _credit => GetIt.I<CreditService>();

  List<CreditContractView> _contracts = const [];
  bool _loading = true;
  String? _error;

  /// Договор, найденный **по номеру с бумажки**.
  ///
  /// # Зачем поиск рядом со списком
  ///
  /// Список отвечает на вопрос «что у этого покупателя», а покупатель
  /// приходит с **бумагой** — и на бумаге номер. Два случая, где списка
  /// мало и оба обычные: платит родственник, и договор не на его имя; в
  /// картотеке два однофамильца, и кассир не знает, чей открыл.
  ///
  /// Найденный по номеру показывается **даже если он чужой** — бумага и
  /// есть основание. Проверить это глазами кассир может тут же: имя
  /// покупателя на бумаге и в шапке экрана.
  CreditContractView? _found;

  final _numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _findByNumber() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      setState(() {
        _found = null;
        _error = null;
      });
      return;
    }
    final view = await _credit.byNumber(number);
    if (!mounted) return;
    setState(() {
      _found = view;
      // «Нет такого» говорится словами, а не пустым экраном: пустота
      // читается как «ищет», и кассир ждёт.
      _error = view == null
          ? AppLocalizations.of(context)!.creditContractNotFound(number)
          : null;
    });
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final contracts = await _credit.activeFor(widget.agentLocalId);
    if (!mounted) return;
    setState(() {
      _contracts = contracts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        AppLocalizations.of(context)!.creditContractsTitleFor(widget.agentName),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('credit_search_number'),
                        controller: _numberController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.creditContractNumberLabel,
                        ),
                        onSubmitted: (_) => _findByNumber(),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    OutlinedButton(
                      key: const Key('credit_search_button'),
                      onPressed: _findByNumber,
                      child: Text(
                        AppLocalizations.of(context)!.receiptInputFind,
                      ),
                    ),
                  ],
                ),
              ),
              if (_found != null) _card(_found!),
              Expanded(
                child: _contracts.isEmpty
                    ? Center(
                        key: const Key('credit_contracts_empty'),
                        child: Text(
                          AppLocalizations.of(context)!.creditNoLiveContracts,
                        ),
                      )
                    : ListView.builder(
                        key: const Key('credit_contracts_list'),
                        padding: const EdgeInsets.all(AppTheme.spacing),
                        itemCount: _contracts.length,
                        itemBuilder: (context, i) => _card(_contracts[i]),
                      ),
              ),
            ],
          ),
    bottomNavigationBar: _error == null
        ? null
        // Цвета берутся у темы, а не константами: константа одинакова в
        // обеих темах, и в тёмной это даёт нечитаемый текст, которого не
        // увидит ни одна другая проба (`no_baked_theme_colors_test`).
        : Builder(
            builder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return Container(
                key: const Key('credit_contracts_error'),
                color: scheme.errorContainer,
                padding: const EdgeInsets.all(AppTheme.spacing),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              );
            },
          ),
  );

  Widget _card(CreditContractView view) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final standing = view.standingAt(now);
    final c = view.contract;

    return Card(
      key: Key('credit_contract_${c.number}'),
      margin: const EdgeInsets.only(bottom: AppTheme.spacing),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '№ ${c.number}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text('${l10n.unitMonthsShort(c.termMonths)}, ${c.scheme.label}'),
            Text(l10n.creditOutstanding('${standing.outstanding}')),
            if (standing.isOverdue)
              Text(
                key: Key('credit_overdue_${c.number}'),
                l10n.creditOverdue(
                  '${standing.overdueAmount}',
                  standing.overdueEntries,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (standing.nextDueDate != null)
              Text(
                l10n.creditNextPayment(
                  _date(standing.nextDueDate!),
                  '${standing.nextDueAmount}',
                ),
              ),
            const SizedBox(height: AppTheme.spacingSmall),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: Key('credit_repay_${c.number}'),
                    onPressed: () => _repay(view, standing),
                    child: Text(l10n.creditTakePayment),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                Expanded(
                  child: OutlinedButton(
                    key: Key('credit_print_${c.number}'),
                    onPressed: () => _print(view),
                    child: Text(l10n.creditPrintContract),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(int epochSeconds) {
    final at = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return '${at.day.toString().padLeft(2, '0')}.'
        '${at.month.toString().padLeft(2, '0')}.${at.year}';
  }

  Future<void> _repay(CreditContractView view, CreditStanding standing) async {
    final amount = await showDialog<Decimal>(
      context: context,
      builder: (_) => _RepayDialog(
        number: view.contract.number,
        outstanding: standing.outstanding,
      ),
    );
    if (amount == null || !mounted) return;

    final db = GetIt.I<AppDatabase>();
    final thisPos = await db.thisPosDao.get();
    final posAccountId = thisPos?.accountId;
    if (posAccountId == null) {
      setState(
        () => _error = AppLocalizations.of(context)!.creditNoTillAccount,
      );
      return;
    }
    final shift = await db.shiftDao.findOpenedShift();

    try {
      final result = await _credit.repay(
        contractNumber: view.contract.number,
        amount: amount,
        userId: shift?.userId ?? 0,
        // Деньги ложатся на счёт кассы. Забудь этот довод — и погашение
        // уменьшило бы долг покупателя **ничем**.
        receivingAccountId: posAccountId,
      );
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            result.closed
                ? AppLocalizations.of(
                    context,
                  )!.creditContractClosed(result.contractNumber)
                : AppLocalizations.of(context)!.creditPartiallyPaid(
                    '${result.allocated}',
                    '${result.standing.outstanding}',
                  ),
          ),
        ),
      );
      await _reload();
      if (_found != null) await _findByNumber();
    } on WireRefusal catch (e) {
      // Причина словами, а не «не получилось»: переплата называет
      // остаток числом, и это то число, которое кассир наберёт следующим.
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _print(CreditContractView view) async {
    final l10n = AppLocalizations.of(context)!;
    final db = GetIt.I<AppDatabase>();
    final thisPos = await db.thisPosDao.get();
    final text = CreditContractReceiptBuilder(
      view: view,
      companyName: thisPos?.companyName ?? '',
      customerName: widget.agentName,
    ).toDebugString();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        key: const Key('credit_contract_preview'),
        content: SingleChildScrollView(
          child: Text(
            text,
            style: const TextStyle(fontFamily: AppTypography.familyMono),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.globalClose),
          ),
        ],
      ),
    );
  }
}

class _RepayDialog extends StatefulWidget {
  const _RepayDialog({required this.number, required this.outstanding});

  final String number;
  final Decimal outstanding;

  @override
  State<_RepayDialog> createState() => _RepayDialogState();
}

class _RepayDialogState extends State<_RepayDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('credit_repay_dialog'),
      title: Text(l10n.creditPaymentFor('${widget.number}')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Остаток показан числом: досрочное погашение целиком — это ровно
          // он, и касса отвергнет всё, что больше.
          Text(l10n.creditOutstandingOnContract('${widget.outstanding}')),
          const SizedBox(height: AppTheme.spacingSmall),
          TextField(
            key: const Key('credit_repay_amount'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.creditPaymentAmount),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        TextButton(
          key: const Key('credit_repay_whole'),
          onPressed: () => Navigator.of(context).pop(widget.outstanding),
          child: Text(l10n.creditPayInFull),
        ),
        FilledButton(
          key: const Key('credit_repay_confirm'),
          onPressed: () {
            final parsed = Decimal.tryParse(
              _controller.text.replaceAll(',', '.'),
            );
            if (parsed == null) return;
            Navigator.of(context).pop(parsed);
          },
          child: Text(l10n.creditAccept),
        ),
      ],
    );
  }
}
