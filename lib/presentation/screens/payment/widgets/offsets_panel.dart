/// Вход в два зачёта, написанных целиком и не имевших входа: **аванс** и
/// **подарочный сертификат**.
///
/// # Дефект, ради которого файл заведён
///
/// Механика обоих стояла в кассе (`LocalPaymentService._plan`), кодек
/// провода возил их поля, сторож круговой поездки держал кодек, — а
/// производителей полей `prepaymentUsed` и `certificates` во всём
/// `lib/presentation/` было **ноль**. Экран оплаты предлагал пять видов, и
/// ни одним из них нельзя было ни зачесть внесённый аванс, ни погасить
/// бумажку.
///
/// # Кассир видит остаток до ввода
///
/// Обе панели показывают число **кассы**, а не догадку: остаток аванса —
/// ответ `pay.prepayment` (на кассе — прямой вызов того же метода),
/// остаток бумажки — ответ `pay.certificate`. Сколько из этого зачтётся в
/// этом чеке, считает цепочка зачётов (`OffsetChain.split`) — та же
/// функция, которой касса разложит деньги, так что предпросмотр и чек не
/// расходятся на слове «потолок».
///
/// # Недоступное гаснет и называет причину
///
/// Правило задач 15 и 16: вид не исчезает молча. Аванс без покупателя, на
/// кассе с выключенным видом или у покупателя без внесённого — панель на
/// месте, погашена, с замком, и нажатие называет причину словами.
///
/// **Предел, названный честно:** сертификат узнаёт, что его вид выключен,
/// **при первой проверке бумажки**, а не заранее. Спросить кассу о
/// справочнике видов экрану нечем — операции справочника на проводе нет, —
/// и заводить её ради одной погашенной панели значило бы добавить третью
/// операцию туда, где хватает ответа на уже заданный вопрос: касса
/// отвечает `payment_kind_inactive` на первый же номер.
///
/// # Это удобство, а не защита
///
/// Погашенная панель ничего не запрещает. Вид, остаток, ПИН и потолок
/// проверяет касса при оплате, любой заявке, включая собранную мимо этого
/// экрана (I44, I162).
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/screens/payment/widgets/qr_panel.dart';

/// Зачёт аванса найденного покупателя.
class PrepaymentPanel extends ConsumerStatefulWidget {
  const PrepaymentPanel({super.key});

  @override
  ConsumerState<PrepaymentPanel> createState() => _PrepaymentPanelState();
}

class _PrepaymentPanelState extends ConsumerState<PrepaymentPanel> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);

    // Покупатель сменился или ушёл — набранная сумма относилась к чужому
    // авансу и в поле оставаться не должна.
    ref.listen<int?>(
      paymentControllerProvider.select((s) => s.loyaltyCustomer?.id),
      (previous, next) {
        if (previous != next) _amountController.clear();
      },
    );

    final balance = state.prepaymentBalance;
    final refusal = state.prepaymentRefusal;
    final String? blocked = !state.hasLoyaltyCustomer
        ? l10n.paymentPrepaymentNeedsCustomer
        : refusal != null
        ? ErrorLocalizer.localize(context, refusal)
        : balance == null
        ? l10n.paymentPrepaymentLoading
        : balance <= Decimal.zero
        ? l10n.paymentPrepaymentNone
        : null;

    final applied = state.offsets.prepayment;

    return _OffsetSection(
      sectionKey: const Key('payment_prepayment_panel'),
      lockKey: const Key('payment_prepayment_locked'),
      title: l10n.paymentPrepaymentTitle,
      icon: Icons.payments_outlined,
      blockedReason: blocked,
      deniedKey: const Key('payment_prepayment_denied_reason'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.paymentPrepaymentBalance, style: AppTextStyles.body),
            Text(
              key: const Key('payment_prepayment_balance'),
              '$balance',
              style: AppTextStyles.h3.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('payment_prepayment_amount'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.paymentPrepaymentUse,
                  hintText: '0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                ),
                onChanged: (value) {
                  ref
                      .read(paymentControllerProvider.notifier)
                      .setPrepaymentToUse(
                        Decimal.tryParse(value) ?? Decimal.zero,
                      );
                },
              ),
            ),
            const SizedBox(width: AppTheme.spacingSmall),
            ElevatedButton(
              key: const Key('payment_prepayment_all'),
              onPressed: () {
                ref.read(paymentControllerProvider.notifier).useAllPrepayment();
                _amountController.text = '$balance';
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.all(AppTheme.spacing),
              ),
              child: Text(l10n.globalAll),
            ),
          ],
        ),
        if (applied > Decimal.zero) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            key: const Key('payment_prepayment_applied'),
            l10n.paymentPrepaymentApplied('$applied'),
            style: AppTextStyles.body.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Предъявление подарочных сертификатов — одного или нескольких.
class CertificatePanel extends ConsumerStatefulWidget {
  const CertificatePanel({super.key});

  @override
  ConsumerState<CertificatePanel> createState() => _CertificatePanelState();
}

class _CertificatePanelState extends ConsumerState<CertificatePanel> {
  final _numberController = TextEditingController();
  final _pinController = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _numberController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _present() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final pin = _pinController.text;
      final ok = await ref
          .read(paymentControllerProvider.notifier)
          .presentCertificate(
            _numberController.text,
            pin: pin.isEmpty ? null : pin,
          );
      if (ok && mounted) {
        _numberController.clear();
        _pinController.clear();
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(paymentControllerProvider);
    final split = state.offsets;

    return _OffsetSection(
      sectionKey: const Key('payment_certificate_panel'),
      lockKey: const Key('payment_certificate_locked'),
      title: l10n.paymentCertificateTitle,
      icon: Icons.card_giftcard,
      blockedReason: null,
      deniedKey: const Key('payment_certificate_denied_reason'),
      children: [
        TextField(
          key: const Key('payment_certificate_number'),
          controller: _numberController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.paymentCertificateNumber,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('payment_certificate_pin'),
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.paymentCertificatePin,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                ),
                onSubmitted: (_) => _present(),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSmall),
            ElevatedButton(
              key: const Key('payment_certificate_present'),
              onPressed: _checking ? null : _present,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.all(AppTheme.spacing),
              ),
              child: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.paymentCertificatePresent),
            ),
          ],
        ),
        for (var i = 0; i < state.certificates.length; i++) ...[
          const SizedBox(height: AppTheme.spacingSmall),
          _PresentedRow(
            certificate: state.certificates[i],
            applied: i < split.certificates.length
                ? split.certificates[i]
                : Decimal.zero,
          ),
        ],
      ],
    );
  }
}

class _PresentedRow extends ConsumerWidget {
  const _PresentedRow({required this.certificate, required this.applied});

  final PresentedCertificate certificate;
  final Decimal applied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final number = certificate.number;
    return Container(
      key: Key('payment_certificate_$number'),
      padding: const EdgeInsets.all(AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: selectedSurfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '№ $number',
                  style: AppTextStyles.productName.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  key: Key('payment_certificate_balance_$number'),
                  l10n.paymentCertificateBalance('${certificate.balance}'),
                  style: AppTextStyles.body,
                ),
                Text(
                  key: Key('payment_certificate_applied_$number'),
                  applied > Decimal.zero
                      ? l10n.paymentCertificateApplied(
                          '$applied',
                          '${certificate.balance - applied}',
                        )
                      : l10n.paymentCertificateNotNeeded,
                  style: context.styles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('payment_certificate_remove_$number'),
            onPressed: () => ref
                .read(paymentControllerProvider.notifier)
                .removeCertificate(number),
            icon: const Icon(TeleposIcons.close),
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

/// Рамка зачёта: заголовок и содержимое — либо погашенная рамка с замком
/// и причиной, которая называется и строкой, и нажатием.
class _OffsetSection extends StatelessWidget {
  const _OffsetSection({
    required this.sectionKey,
    required this.lockKey,
    required this.deniedKey,
    required this.title,
    required this.icon,
    required this.blockedReason,
    required this.children,
  });

  final Key sectionKey;
  final Key lockKey;
  final Key deniedKey;
  final String title;
  final IconData icon;

  /// `null` — зачёт доступен. Иначе — почему нет, словами.
  final String? blockedReason;
  final List<Widget> children;

  void _tellWhy(BuildContext context, String reason) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(key: deniedKey, reason),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reason = blockedReason;
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.55);

    final body = Container(
      key: sectionKey,
      padding: const EdgeInsets.all(AppTheme.spacing),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: reason == null ? AppColors.primary : muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    color: reason == null ? null : muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (reason != null)
                Icon(key: lockKey, TeleposIcons.lock, size: 16, color: muted),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          if (reason != null)
            Text(reason, style: context.styles.caption.copyWith(color: muted))
          else
            ...children,
        ],
      ),
    );

    if (reason == null) return body;
    // Погашенная рамка **принимает нажатие** и называет причину: у кассира
    // планшет, наводить нечем, а причина нужна в момент нажатия.
    return InkWell(
      onTap: () => _tellWhy(context, reason),
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: body,
    );
  }
}

/// Оба зачёта одной сворачиваемой рамкой — для узкого экрана, тем же
/// приёмом, что `LoyaltyPanelCompact`.
class OffsetsPanelCompact extends ConsumerStatefulWidget {
  const OffsetsPanelCompact({super.key});

  @override
  ConsumerState<OffsetsPanelCompact> createState() =>
      _OffsetsPanelCompactState();
}

class _OffsetsPanelCompactState extends ConsumerState<OffsetsPanelCompact> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final split = ref.watch(paymentControllerProvider.select((s) => s.offsets));
    final covered = split.qr + split.prepayment + split.certificate;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          InkWell(
            key: const Key('payment_offsets_compact_toggle'),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.paymentOffsetsTitle,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (covered > Decimal.zero)
                    Text(
                      '-$covered',
                      style: context.styles.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacing),
              child: Column(
                children: [
                  // Порядок цепочки кассы: QR → сертификат → аванс идут
                  // после бонуса, и на узком экране тоже.
                  QrPanel(),
                  SizedBox(height: AppTheme.spacing),
                  PrepaymentPanel(),
                  SizedBox(height: AppTheme.spacing),
                  CertificatePanel(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
