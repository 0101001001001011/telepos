/// Выбор вида оплаты — и разрешения рабочего места (задача 15).
///
/// # Дефект, из-за которого файл переписан
///
/// `Terminal.allowedPaymentTypes` существует с миграции v38, настраивается
/// на экране оборудования и **проверяется кассой**
/// (`LocalPaymentService._requireAllowedTypes`). Этот файл её не читал
/// вовсе: три кнопки рисовались константами. Кассир на планшете «только
/// безнал» видел «Наличная», выбирал её, набирал сумму — и получал отказ
/// на «Оплатить», после всей работы.
///
/// # Почему запрещённая кнопка не исчезает
///
/// В презентационном слое уже 33 места, где кнопка пропадает без единого
/// слова, и два из них прямо врут; честных — 11. Тридцать четвёртым это
/// место не станет. Исчезнувшая кнопка оставляет кассира с вопросом «куда
/// делись наличные» и без единого способа на него ответить: он не знает ни
/// что запрет существует, ни где он живёт, ни кто его снимает. Поэтому:
///
/// - кнопка **остаётся на своём месте**, погашенной и с замком —
///   раскладка не прыгает, и видно, что вид существует, но не здесь;
/// - под рядом стоит постоянная подпись, называющая, **что** рабочее место
///   принимает, — она появляется ровно тогда, когда хоть один вид погашен,
///   и молчит, когда запрещать нечего (иначе подпись стала бы шумом);
/// - нажатие на погашенную кнопку **не молчит**: оно называет вид, говорит,
///   где меняются виды оплаты рабочего места, и предупреждает, что касса
///   откажет в любом случае.
///
/// Образцы честного поведения в дереве — `WtNotPortedScreen`,
/// `deviceSearchUnavailable`, `printQueueUnavailable`: все трое говорят
/// словами вместо того, чтобы убрать элемент. (Четвёртым здесь стоял
/// `scannerRulesUnavailable`; пункт 11 ревизии 2026-09-19 снял саму
/// нехватку — правила сканера с планшета теперь задаются, — и образец
/// вместе с ней.)
///
/// # Четвёртая кнопка — «В долг» (задача 16)
///
/// Она стоит в том же ряду и по тем же правилам, но загорожена **не
/// набором видов рабочего места**: долг набором не сторожится вовсе
/// (`paymentTypeOfferable` отвечает про него `true` всегда, разбор —
/// `terminal.dart`). Его держат две другие вещи и третье состояние:
/// тумблер кассы `ThisPosEntries.sellInDebt`, право кассира
/// `op.sellDebt` и «касса ещё не ответила». Ответ считает домен
/// ([debtOfferOf]), причину кассир читает словами — свою на каждый из
/// трёх случаев, потому что лечатся они в трёх разных местах: в
/// настройках кассы, у администратора и в связи с кассой.
///
/// Кнопка не исчезает **ни в одном** из трёх — по той же причине, что и
/// соседние: тридцать четвёртым молчаливым исчезновением это место не
/// станет. Кассир, которому долг нужен, обязан узнать, что вид
/// существует и чего именно не хватает, а не гадать, куда смотреть.
///
/// # Это удобство, а не защита
///
/// Гашение кнопки не запрещает ничего. Запрет держит касса и только она
/// (I44, I162): `_requireAllowedTypes` стоит на `pay.card` и на
/// `pay.complete`, читает набор из базы кассы и отвечает
/// `payment_type_not_allowed` — кадру, собранному мимо этого экрана, тоже.
/// Ни одна строка здесь эту проверку не заменяет и не ослабляет; половина
/// сторожа без второй половины уже однажды означала, что защиты нет.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/presentation/screens/payment/widgets/installment_terms_dialog.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';

class PaymentTypeSelector extends ConsumerWidget {
  const PaymentTypeSelector({super.key});

  /// Виды, которые сторожит **набор рабочего места**, в том порядке, в
  /// каком они стоят на экране.
  ///
  /// Долга здесь нет намеренно, и это не «его ещё не завели»: набор видов
  /// долг не сторожит вовсе (`paymentTypeOfferable`, разбор там же). Он
  /// рисуется четвёртой кнопкой отдельно и по своим условиям; попади он
  /// в этот список, он вошёл бы и в подпись «рабочее место принимает», то
  /// есть экран объявил бы про долг запрет, которого у кассы нет.
  static const _types = <PaymentType>[
    PaymentType.cash,
    PaymentType.card,
    PaymentType.mixed,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final paymentType = ref.watch(
      paymentControllerProvider.select((s) => s.paymentType),
    );
    final allowed = ref.watch(
      paymentControllerProvider.select((s) => s.allowedPaymentTypes),
    );

    final offered = {
      for (final type in _types) type: paymentTypeOfferable(allowed, type),
    };
    final denied = _types.where((type) => !offered[type]!).toList();

    // Долг: тумблер кассы + право кассира, и ни одно не подменяет другое.
    // Право читается **из сеанса** (`hasPermissionProvider`), а не из
    // состояния экрана: сеанс — единственное место, где оно вообще есть,
    // и второй его источник разошёлся бы с первым молча.
    final debt = debtOfferOf(
      sellInDebt: ref.watch(
        paymentControllerProvider.select((s) => s.sellInDebt),
      ),
      permitted: ref.watch(hasPermissionProvider(PermissionKeys.opSellDebt)),
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSmall),
      decoration: BoxDecoration(
        color: context.semantic.canvas,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final type in _types) ...[
                if (type != _types.first)
                  const SizedBox(width: AppTheme.spacingSmall),
                Expanded(
                  child: _TypeButton(
                    key: Key('payment_type_button_${type.name}'),
                    lockKey: Key('payment_type_locked_${type.name}'),
                    label: _label(l10n, type),
                    icon: _icon(type),
                    isSelected: paymentType == type,
                    isAllowed: offered[type]!,
                    color: _color(type),
                    onTap: () {
                      if (offered[type]!) {
                        ref
                            .read(paymentControllerProvider.notifier)
                            .setPaymentType(type);
                        return;
                      }
                      _tellWhyDenied(context, l10n, type);
                    },
                  ),
                ),
              ],
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: _TypeButton(
                  key: const Key('payment_type_button_debt'),
                  lockKey: const Key('payment_type_locked_debt'),
                  label: l10n.paymentDebt,
                  icon: _icon(PaymentType.debt),
                  isSelected: paymentType == PaymentType.debt,
                  isAllowed: debt == DebtOffer.available,
                  color: _color(PaymentType.debt),
                  onTap: () {
                    if (debt == DebtOffer.available) {
                      ref
                          .read(paymentControllerProvider.notifier)
                          .setPaymentType(PaymentType.debt);
                      return;
                    }
                    _tellWhyDebtDenied(context, l10n, debt);
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: _TypeButton(
                  key: const Key('payment_type_button_installment'),
                  lockKey: const Key('payment_type_locked_installment'),
                  label: l10n.paymentInstallment,
                  icon: _icon(PaymentType.installment),
                  isSelected: paymentType == PaymentType.installment,
                  // **Тот же затвор, что у долга, и это не экономия.**
                  // Рассрочка — продажа в кредит: её пускает то же право
                  // `op.sellDebt` и тот же тумблер кассы `sellInDebt`
                  // (`LocalPaymentService._requireDebtSoldHere`). Второй
                  // затвор рядом дал бы кассу, где кредит выключен, а
                  // рассрочка работает.
                  isAllowed: debt == DebtOffer.available,
                  color: _color(PaymentType.installment),
                  onTap: () async {
                    if (debt != DebtOffer.available) {
                      _tellWhyDebtDenied(context, l10n, debt);
                      return;
                    }
                    // Срок и схему спрашиваем **до** выбора вида: вид без
                    // них касса всё равно отвергнет
                    // (`credit_term_invalid`), и кассир получил бы отказ
                    // за то, чего у него не спросили.
                    final terms = await showInstallmentTermsDialog(context);
                    if (terms == null) return;
                    ref
                        .read(paymentControllerProvider.notifier)
                        .setInstallmentTerms(
                          termMonths: terms.termMonths,
                          scheme: terms.scheme,
                        );
                  },
                ),
              ),
            ],
          ),
          if (denied.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                key: const Key('payment_types_limited_note'),
                l10n.paymentTypesLimitedHere(_allowedLabels(l10n, offered)),
                style: context.styles.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Названо словами: какой вид, где меняется, и что касса откажет всё
  /// равно.
  ///
  /// Через полосу сообщения, а не подсказку по наведению: у кассира
  /// планшет, наводить нечем, а причина нужна ровно в момент нажатия.
  void _tellWhyDenied(
    BuildContext context,
    AppLocalizations l10n,
    PaymentType type,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            key: const Key('payment_type_denied_reason'),
            l10n.paymentTypeNotAllowedHere(_label(l10n, type)),
          ),
        ),
      );
  }

  /// Почему «В долг» погашена — **своя причина на каждый случай**.
  ///
  /// Три беды лечатся в трёх разных местах: тумблер — в настройках
  /// кассы, право — у администратора, молчание кассы — в связи с ней.
  /// Один текст на три случая отправил бы кассира не туда с той же
  /// уверенностью, с какой отправляет молчащая кнопка.
  void _tellWhyDebtDenied(
    BuildContext context,
    AppLocalizations l10n,
    DebtOffer offer,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final text = switch (offer) {
      DebtOffer.notSoldHere => l10n.paymentDebtNotSoldHere,
      DebtOffer.notPermitted => l10n.paymentDebtNotPermitted,
      DebtOffer.unknown => l10n.paymentDebtPolicyUnknown,
      // Недостижимо: сюда приходят только погашенные нажатия. Молчаливого
      // `default` здесь нет намеренно — он спрятал бы новый случай, а не
      // показал его.
      DebtOffer.available => l10n.paymentDebt,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(key: const Key('payment_debt_denied_reason'), text),
        ),
      );
  }

  /// Перечень разрешённого — в порядке кнопок, теми же словами, что на
  /// самих кнопках.
  String _allowedLabels(
    AppLocalizations l10n,
    Map<PaymentType, bool> offered,
  ) => [
    for (final type in _types)
      if (offered[type]!) _label(l10n, type).toLowerCase(),
  ].join(', ');

  static String _label(AppLocalizations l10n, PaymentType type) =>
      switch (type) {
        PaymentType.cash => l10n.paymentTypeCash,
        PaymentType.card => l10n.paymentTypeCard,
        PaymentType.mixed => l10n.paymentTypeMixed,
        // Кнопки долга здесь нет (её заводит задача 16), но переключатель
        // обязан быть полным: молчаливый `default` спрятал бы новый вид, а
        // не показал. Имя у долга своё и настоящее.
        PaymentType.debt => l10n.paymentDebt,
        PaymentType.installment => l10n.paymentInstallment,
      };

  static IconData _icon(PaymentType type) => switch (type) {
    PaymentType.cash => Icons.payments_outlined,
    PaymentType.card => Icons.credit_card,
    PaymentType.mixed || PaymentType.debt => Icons.sync_alt,
    PaymentType.installment => Icons.event_repeat_outlined,
  };

  static Color _color(PaymentType type) => switch (type) {
    PaymentType.cash => AppColors.paymentCash,
    PaymentType.card => AppColors.paymentCard,
    PaymentType.mixed || PaymentType.debt => AppColors.paymentMixed,
    PaymentType.installment => AppColors.paymentMixed,
  };
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    super.key,
    required this.lockKey,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isAllowed,
    required this.color,
    required this.onTap,
  });

  final Key lockKey;
  final String label;
  final IconData icon;
  final bool isSelected;

  /// Рабочее место принимает этот вид.
  ///
  /// `false` **не убирает** кнопку и не отключает нажатие: отключённая
  /// кнопка молчит так же, как исчезнувшая. Она гаснет и получает замок, а
  /// нажатие называет причину.
  final bool isAllowed;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = !isAllowed
        ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
        : isSelected
        ? AppColors.white
        : scheme.onSurfaceVariant;

    return Material(
      // Погашенный вид не заливается своим цветом даже выбранным: цвет
      // здесь значит «этим сейчас платят», а этим платить нельзя.
      color: isSelected && isAllowed ? color : scheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing,
            horizontal: AppTheme.spacingSmall,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 24, color: foreground),
                  if (!isAllowed)
                    Positioned(
                      right: -6,
                      bottom: -2,
                      child: Icon(
                        key: lockKey,
                        TeleposIcons.lock,
                        size: 12,
                        color: foreground,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: foreground,
                  fontWeight: isSelected && isAllowed
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
