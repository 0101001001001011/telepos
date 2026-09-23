/// Вход в оплату по QR/СБП — **последний вид оплаты, у которого не было
/// входа**.
///
/// # Дефект, ради которого файл заведён
///
/// Намерение, эмулятор, координатор, HTTP-провайдер и приём денег
/// намерения в чек стояли целиком — а позвать их было неоткуда: ни
/// операции провода, ни производителя координатора, ни хранилища адреса
/// провайдера, ни кнопки. Единственная достижимая поверхность QR —
/// панель «деньги без чека» — показывала только беду.
///
/// # Что видит кассир
///
/// * **До кода:** сумму (по умолчанию — сколько осталось внести после
///   бонуса и прочих зачётов) и «Показать QR».
/// * **Пока покупатель платит:** код, сумму, секунды терпения кассы и
///   «Отменить ожидание». Нет связи с провайдером — строка об этом, а
///   ожидание не прерывается: деньги могли уже уйти. Кнопка «Оплатить» при
///   этом погашена (`PaymentState.amountCovered`).
/// * **Оплачено:** сумма, частичность, и сколько из неё легло в чек
///   цепочкой зачётов; если в чек не поместилось всё — сколько.
/// * **Отменил, провайдер подтвердил:** слова и «Новый код».
/// * **Отменил, а покупатель успел заплатить:** «успел оплатить до
///   отмены — N идёт в этот чек». Деньги в цепочке, чек закрывается.
/// * **Отменил, провайдер не ответил:** предупреждение не принимать другую
///   оплату и «Проверить снова».
///
/// # Недоступное гаснет и называет причину
///
/// Провайдер не настроен или вид выключен — рамка на месте, с замком, и
/// нажатие называет причину. С 2026-09-15 экран узнаёт это **при
/// открытии** (`PaymentService.qrUnavailableReason`, пункт 9 C), а не на
/// первом «Показать QR»: кассир больше не набирает сумму ради отказа.
/// Проба — `payment_qr_entry_test.dart`, «знает это при открытии».
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/payment/qr_tender.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

/// Отказы, после которых показывать код бессмысленно до правки настройки.
const _blockingRefusals = <String>{
  'error.qr_not_configured',
  'error.payment_kind_inactive',
  'error.payment_kind_unknown',
};

class QrPanel extends ConsumerStatefulWidget {
  const QrPanel({super.key});

  @override
  ConsumerState<QrPanel> createState() => _QrPanelState();
}

class _QrPanelState extends ConsumerState<QrPanel> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _tellWhy(String reason) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(key: const Key('payment_qr_denied_reason'), reason),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);
    final notifier = ref.read(paymentControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.55);

    final tender = state.qr;
    final refusal = state.qrRefusal;
    final blocked =
        tender == null && refusal != null && _blockingRefusals.contains(refusal)
        ? ErrorLocalizer.localize(context, refusal)
        : null;

    final body = Container(
      key: const Key('payment_qr_panel'),
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: tender?.phase == QrTenderPhase.cancelUnconfirmed
              ? AppColors.warning
              : scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code_2,
                size: 20,
                color: blocked == null ? AppColors.primary : muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.paymentQrTitle,
                  style: AppTextStyles.h3.copyWith(
                    color: blocked == null ? null : muted,
                  ),
                ),
              ),
              if (blocked != null)
                Icon(
                  key: const Key('payment_qr_locked'),
                  TeleposIcons.lock,
                  size: 16,
                  color: muted,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          if (blocked != null)
            Text(blocked, style: context.styles.caption.copyWith(color: muted))
          else if (tender == null)
            ..._idle(context, l10n, state, notifier)
          else
            ..._tender(context, l10n, state, notifier, tender),
          if (blocked == null && refusal != null) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              key: const Key('payment_qr_refusal'),
              ErrorLocalizer.localize(context, refusal),
              style: context.styles.caption.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );

    if (blocked == null) return body;
    return InkWell(
      onTap: () => _tellWhy(blocked),
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: body,
    );
  }

  List<Widget> _idle(
    BuildContext context,
    AppLocalizations l10n,
    PaymentState state,
    PaymentNotifier notifier,
  ) {
    // Сколько осталось внести **после** зачётов — предпросмотр той же
    // цепочки, которой разложит касса. QR в ней второй, но пока кода нет,
    // его доля — ноль, и остаток — ровно то, что можно попросить.
    final rest = state.offsets.toPay;
    if (rest <= Decimal.zero) {
      return [
        Text(
          key: const Key('payment_qr_nothing_to_pay'),
          l10n.paymentQrNothingToPay,
          style: context.styles.caption,
        ),
      ];
    }
    return [
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('payment_qr_amount'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.paymentQrAmount,
                hintText: '$rest',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          ElevatedButton.icon(
            key: const Key('payment_qr_start'),
            onPressed: state.qrBusy
                ? null
                : () {
                    final typed = Decimal.tryParse(
                      _amountController.text.trim(),
                    );
                    unawaited(
                      notifier.startQr(
                        typed == null || typed <= Decimal.zero ? rest : typed,
                      ),
                    );
                  },
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: Text(l10n.paymentQrStart),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.all(AppTheme.spacing),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _tender(
    BuildContext context,
    AppLocalizations l10n,
    PaymentState state,
    PaymentNotifier notifier,
    QrTender tender,
  ) {
    final caption = context.styles.caption;
    switch (tender.phase) {
      case QrTenderPhase.waiting:
        final payload = tender.qrPayload;
        return [
          if (payload != null)
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  key: const Key('payment_qr_code'),
                  data: payload,
                  size: 180,
                ),
              ),
            ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            key: const Key('payment_qr_waiting_amount'),
            '${tender.amount}',
            style: AppTextStyles.h3.copyWith(color: AppColors.primary),
          ),
          Text(
            key: const Key('payment_qr_waiting'),
            l10n.paymentQrWaiting(tender.secondsLeft ?? 0),
            style: caption,
          ),
          Text(l10n.paymentQrScanHint, style: caption),
          if (tender.refusalCode != null)
            Text(
              key: const Key('payment_qr_no_link'),
              '${l10n.paymentQrNoLink} '
              '(${ErrorLocalizer.localize(context, 'error.${tender.refusalCode}')})',
              style: caption.copyWith(color: AppColors.warning),
            ),
          const SizedBox(height: AppTheme.spacingSmall),
          OutlinedButton(
            key: const Key('payment_qr_cancel'),
            onPressed: state.qrBusy
                ? null
                : () => unawaited(notifier.cancelQr()),
            child: Text(l10n.paymentQrCancel),
          ),
        ];

      case QrTenderPhase.paid:
      case QrTenderPhase.paidAfterGiveUp:
        final applied = state.offsets.qr;
        final over = tender.money - applied;
        return [
          Text(
            key: const Key('payment_qr_paid'),
            tender.phase == QrTenderPhase.paid
                ? l10n.paymentQrPaid('${tender.money}')
                : l10n.paymentQrPaidAfterCancel('${tender.money}'),
            style: AppTextStyles.body.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tender.isPartial)
            Text(
              key: const Key('payment_qr_partial'),
              l10n.qrPaidPartial('${tender.money}', '${tender.amount}'),
              style: caption.copyWith(color: AppColors.warning),
            ),
          if (over > Decimal.zero)
            Text(
              key: const Key('payment_qr_over_receipt'),
              l10n.paymentQrOverReceipt('$over'),
              style: caption.copyWith(color: AppColors.warning),
            ),
        ];

      case QrTenderPhase.cancelUnconfirmed:
        return [
          Text(
            key: const Key('payment_qr_cancel_unconfirmed'),
            l10n.paymentQrCancelUnconfirmed,
            style: caption.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          OutlinedButton(
            key: const Key('payment_qr_recheck'),
            onPressed: state.qrBusy
                ? null
                : () => unawaited(notifier.pollQr(manual: true)),
            child: Text(l10n.paymentQrRecheck),
          ),
        ];

      case QrTenderPhase.cashierCancelled:
      case QrTenderPhase.patienceSpent:
      case QrTenderPhase.expired:
      case QrTenderPhase.failed:
        final words = switch (tender.phase) {
          QrTenderPhase.cashierCancelled => l10n.paymentQrCancelled,
          QrTenderPhase.patienceSpent => l10n.paymentQrPatienceSpent,
          QrTenderPhase.expired => l10n.paymentQrExpired,
          _ => l10n.paymentQrFailed,
        };
        return [
          Text(
            key: Key('payment_qr_closed_${tender.phase.name}'),
            words,
            style: caption,
          ),
          if (tender.phase == QrTenderPhase.failed &&
              tender.refusalCode != null)
            Text(
              ErrorLocalizer.localize(context, 'error.${tender.refusalCode}'),
              style: caption.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          const SizedBox(height: AppTheme.spacingSmall),
          OutlinedButton(
            key: const Key('payment_qr_restart'),
            onPressed: notifier.dismissQr,
            child: Text(l10n.paymentQrRestart),
          ),
        ];
    }
  }
}
