import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/agent/customer_payment_controller.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

/// Выдача аванса деньгами — **дыра 2 ревизии 2026-09-19**, закрытая
/// экраном.
///
/// # Что было измерено
///
/// `CustomerPaymentUseCase.refundPrepayment` заведён 2026-09-19 (`63426a0f`)
/// целиком: условная запись по счёту покупателя, расходная проводка с видом
/// оплаты, снятие со счёта кассы, фискальный **возврат** той же настройкой,
/// что приём. И ни одного вызывающего: экрана не было, по проводу выдача не
/// едет. То есть деньги, внесённые вперёд, вернуть было нечем — единственным
/// способом выпустить их из кассы оставался «Расход», служебное изъятие, не
/// трогающее счёта покупателя.
///
/// # Почему рядом с приёмом, а не отдельным местом
///
/// Приём живёт диалогом в карточке контрагента
/// (`RecordCustomerPaymentDialog`) — и выдача открывается кнопкой из **той
/// же карточки**, соседней с ним, через тот же контроллер и тот же юзкейс.
/// Разбор, почему выдача при этом маршрут, а приём остался диалогом, — в
/// докстринге `AppRoutes.prepaymentRefund`; коротко: право на кассе
/// проверяется только картой маршрутов, а выдача выпускает деньги наружу.
///
/// # Экран не считает денег
///
/// Остаток аванса приходит **ответом кассы** (`CustomerPaymentController
/// .balanceOf`), а не параметром из карточки: карточка знает сальдо на
/// момент своего открытия, а между открытием и выдачей стоит второй кассир.
/// Сумма к выдаче разбирается `Decimal` и только им.
///
/// Предел «не больше внесённого» экран **не** сторожит и не делает вид:
/// остаток, прочитанный до нажатия, к моменту записи может измениться, и
/// настоящий заслон — условная запись `AccountDao.claimCredit` внутри
/// транзакции выдачи. Экран показывает остаток, чтобы кассир не набирал
/// вслепую, и передаёт отказ кассы словами.
///
/// # Чего этот экран НЕ доказывает
///
/// - **Что в ящике есть наличные.** Сальдо счёта приёма — не содержимое
///   ящика; сторожа на это нет ни у одной выдачи денег в дереве.
/// - **Что выдача закрыта правом на кассе по-настоящему.** Здесь две
///   двери — маршрут и проверка перед вызовом, — а `CustomerPaymentUseCase`
///   права не спрашивает вовсе (у него нет сеанса). Это общее свойство
///   второго фронта кассы, названное в управляющем документе, а не свойство
///   этой работы.
/// - **Что аванс вернулся покупателю с планшета.** Операции провода у
///   выдачи по-прежнему нет: браузерный `/prepayment` умеет только принять.
class PrepaymentRefundScreen extends ConsumerStatefulWidget {
  const PrepaymentRefundScreen({
    super.key,
    required this.agentLocalId,
    required this.agentName,
  });

  final int agentLocalId;
  final String agentName;

  @override
  ConsumerState<PrepaymentRefundScreen> createState() =>
      _PrepaymentRefundScreenState();
}

class _PrepaymentRefundScreenState
    extends ConsumerState<PrepaymentRefundScreen> {
  final _amount = TextEditingController();
  final _intake = TextEditingController();

  /// Чем выдаются деньги. Умолчание — наличные: тот же выбор, что у приёма.
  int _tenderKindId = SystemPaymentKindIds.cash;

  /// Остаток аванса — ответ кассы, а не память экрана. `null` — ещё не
  /// спросили.
  Decimal? _balance;

  bool _submitting = false;
  String? _error;
  String? _done;
  String? _fiscalWarning;

  @override
  void initState() {
    super.initState();
    // `addPostFrameCallback` здесь не нужен: читается не `InheritedWidget`,
    // а `ref`, законный в `initState` у `ConsumerState`.
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final balance = await ref
        .read(customerPaymentControllerProvider.notifier)
        .balanceOf(widget.agentLocalId);
    if (!mounted) return;
    setState(() => _balance = balance);
  }

  @override
  void dispose() {
    _amount.dispose();
    _intake.dispose();
    super.dispose();
  }

  Decimal? _parseMoney(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return Decimal.tryParse(text);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    // Право — **перед вызовом**, а не вместо кнопки. Маршрут уже проверен
    // `redirect`-ом, но экран может быть открыт и иначе (тем же способом,
    // каким восемь `settings.*`-маршрутов однажды прошли мимо проверки), а
    // выдача выпускает деньги из кассы.
    if (!ref.read(hasPermissionProvider(PermissionKeys.opCreditRepay))) {
      talker.warning(
        'Prepayment refund: отказано по праву — у кассира нет '
        '${PermissionKeys.opCreditRepay}',
      );
      setState(() {
        _done = null;
        _fiscalWarning = null;
        _error = l10n.prepaymentRefundNotPermitted;
      });
      return;
    }

    final amount = _parseMoney(_amount.text);
    if (amount == null || amount <= Decimal.zero) {
      setState(() {
        _done = null;
        _fiscalWarning = null;
        _error = l10n.prepaymentRefundAmountInvalid;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _done = null;
      _fiscalWarning = null;
    });

    final outcome = await ref
        .read(customerPaymentControllerProvider.notifier)
        .refund(
          agentId: widget.agentLocalId,
          amount: amount,
          tenderKindId: _tenderKindId,
          intakeOperationId: int.tryParse(_intake.text.trim()),
          note: 'Возврат аванса покупателю (${widget.agentName})',
        );

    if (!mounted) return;

    if (!outcome.success) {
      final reason = outcome.errorMessage;
      if (reason != null) {
        talker.warning('Prepayment refund refused: $reason');
      }
      setState(() {
        _submitting = false;
        // Причина кассы написана по-русски и годна к показу: у выдачи нет
        // пути через провод, значит и кода, по которому словарь нашёл бы
        // фразу, здесь не образуется. Фраза словаря называет **что** не
        // вышло, причина — **почему**.
        _error = reason == null
            ? l10n.prepaymentRefundFailed
            : '${l10n.prepaymentRefundFailed}: $reason';
      });
      return;
    }

    setState(() {
      _submitting = false;
      _balance = outcome.newAgentBalance ?? _balance;
      _done = l10n.prepaymentRefundDone(
        (outcome.newAgentBalance ?? Decimal.zero).toString(),
      );
      // Деньги отданы, документа нет — это **не** неудача выдачи, и
      // показывать её отказом значило бы предложить кассиру выдать их
      // второй раз. Отдельной строкой, рядом с успехом.
      _fiscalWarning = outcome.fiscalError == null
          ? null
          : l10n.prepaymentRefundFiscalFailed;
      _amount.clear();
      _intake.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final balance = _balance;
    final nothingToPay = balance != null && balance <= Decimal.zero;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.prepaymentRefundTitle} — ${widget.agentName}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.prepaymentRefundHint,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (balance != null)
              Text(
                nothingToPay
                    ? l10n.prepaymentRefundNothing
                    : l10n.prepaymentRefundBalance(balance.toString()),
                key: const Key('prepayment_refund_balance'),
                style: TextStyle(
                  color: nothingToPay ? scheme.error : scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('prepayment_refund_amount'),
              controller: _amount,
              enabled: !_submitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.prepaymentRefundAmount,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.prepaymentRefundTender),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              key: const Key('prepayment_refund_tender'),
              segments: [
                ButtonSegment(
                  value: SystemPaymentKindIds.cash,
                  label: Text(l10n.paymentCash),
                ),
                ButtonSegment(
                  value: SystemPaymentKindIds.card,
                  label: Text(l10n.paymentCard),
                ),
              ],
              selected: {_tenderKindId},
              onSelectionChanged: _submitting
                  ? null
                  : (s) => setState(() => _tenderKindId = s.single),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('prepayment_refund_intake'),
              controller: _intake,
              enabled: !_submitting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.prepaymentRefundIntake,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('prepayment_refund_error'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            if (_done != null) ...[
              const SizedBox(height: 12),
              Text(
                _done!,
                key: const Key('prepayment_refund_done'),
                style: TextStyle(color: scheme.primary),
              ),
            ],
            if (_fiscalWarning != null) ...[
              const SizedBox(height: 8),
              Text(
                _fiscalWarning!,
                key: const Key('prepayment_refund_fiscal_warning'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('prepayment_refund_submit'),
              onPressed: _submitting ? null : _submit,
              child: Text(l10n.prepaymentRefundSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
