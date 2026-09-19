import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/app_constants.dart';
import 'package:telepos/core/utils/decimal_util.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';

enum DiscountType { percent, fixed }

class DiscountResult {
  const DiscountResult({required this.type, required this.value});

  final DiscountType type;
  final Decimal value;

  /// Сумма скидки в деньгах.
  ///
  /// # Округление до денежных знаков — здесь, а не «потом»
  ///
  /// Стояло `(subtotal * value / 100).toDecimal()` — без округления. Пока у
  /// диалога не было ни одного вызывающего, это ничего не стоило; с
  /// пробуждением (задача 18) число уходит в `setDiscountAmount`, оттуда в
  /// `LocalCartService._writeLine` → `price` → чек → ОФД. 99.99 при 33.33 %
  /// давало 33.326667 — шесть знаков при денежных трёх (P18,S3).
  ///
  /// Считаем тем же выражением, каким продукт уже считает процент от суммы
  /// (`DecimalUtil.percent`), а не заводим второе.
  Decimal calculate(Decimal subtotal) {
    if (type == DiscountType.percent) {
      return DecimalUtil.percent(subtotal, value);
    }
    return value;
  }
}

/// Ввод скидки на строку чека: процент или сумма, numpad, предпросмотр
/// суммы и **предел, названный до ввода**.
///
/// # Задача 18: диалог был написан целиком и не вызывался ниоткуда
///
/// 333 строки, ноль вызовов. Работал вместо него безымянный `TextField` с
/// подписью «Скидка» внутри `_EditItemDialog` экрана продажи: только сумма,
/// без процента, без numpad, без предела. Причина, по которой диалог столько
/// пролежал, названа в плане: он просил `maxPercent`/`maxAmount`, а взять их
/// было неоткуда — предела скидки в продукте не существовало до задачи 12.
///
/// # Предел приходит [DiscountCap] — тем же, каким отказывает касса
///
/// Не двумя числами и не настройкой экрана: [cap] — ответ
/// `DiscountPolicy.capFor(roleIndex)`, того самого читателя, которым
/// `LocalCartService._authorizeDiscount` отказывает. Второго источника
/// предела в продукте нет, и завести его здесь значило бы разрешить им
/// разойтись.
///
/// Денежный потолок из [cap] **выводится**, а не задаётся отдельно: касса
/// меряет и сумму тоже долей строки (`_shareOf`), поэтому «до скольки денег»
/// — это `subtotal × maxPercent / 100`. Округление **вниз**: диалог не имеет
/// права предложить на копейку больше, чем касса примет.
///
/// # Это удобство, а не защита (I44)
///
/// Подрезанный ввод правом не является. Предел проверяет касса доводом
/// `DiscountAuthority`, и снятие этой проверки красит
/// `test/data/sale/discount_authority_test.dart`. Диалог лишь избавляет
/// кассира от порядка «набрал → нажал → узнал».
///
/// # Браузерный терминал — задача 44
///
/// До неё диалог в браузере не открывался вовсе (кнопку прятали), а открой
/// его — бросил бы на первом кадре: символ валюты он брал сам,
/// `GetIt.I<CurrencyService>()`, а в браузере такой службы нет. Символ теперь
/// приходит доводом [currencySymbol] из условий кассы (`SaleEditTerms`),
/// вместе с пределом: деньги чека — деньги кассы, и валюта — её настройка.
class DiscountDialog extends StatefulWidget {
  const DiscountDialog({
    super.key,
    this.currentDiscount,
    this.currentType,
    this.cap,
    this.subtotal,
    required this.currencySymbol,
  });

  /// Символ валюты кассы — `SaleEditTerms.currencySymbol`.
  final String currencySymbol;

  final Decimal? currentDiscount;
  final DiscountType? currentType;

  /// Предел роли — ответ `DiscountPolicy.capFor`. `null` означает «предел
  /// не прочитан», и тогда диалог не ограничивает ввод и **не рисует
  /// строку предела**: пустая подпись «доступно до 100 %» там, где предел
  /// неизвестен, была бы обещанием, которого касса не давала.
  final DiscountCap? cap;

  /// Стоимость строки **до скидки** (`price × quantity` — то же
  /// выражение, каким меряет касса: `priceBefore × quantity`).
  final Decimal? subtotal;

  /// Потолок процента; `null` — предел не прочитан.
  Decimal? get maxPercent => cap?.maxPercent;

  /// Потолок суммы, выведенный из [cap] и [subtotal].
  ///
  /// Округление вниз (`floor`), а не `round`: при `round` предел 15 % от
  /// 33.335 дал бы 5.001 — на тысячную больше, чем касса пропустит, и
  /// кассир получил бы отказ на числе, которое диалог сам ему и разрешил.
  Decimal? get maxAmount {
    final c = cap;
    final s = subtotal;
    if (c == null || s == null || s <= Decimal.zero) return null;
    return (s * c.maxPercent / DecimalUtil.hundred)
        .toDecimal(scaleOnInfinitePrecision: AppConstants.moneyScale + 3)
        .floor(scale: AppConstants.moneyScale);
  }

  static Future<DiscountResult?> show({
    required BuildContext context,
    Decimal? currentDiscount,
    DiscountType? currentType,
    DiscountCap? cap,
    Decimal? subtotal,
    required String currencySymbol,
  }) {
    return showDialog<DiscountResult>(
      context: context,
      builder: (context) => DiscountDialog(
        currentDiscount: currentDiscount,
        currentType: currentType,
        cap: cap,
        subtotal: subtotal,
        currencySymbol: currencySymbol,
      ),
    );
  }

  /// Число для человека: без хвоста нулей у целого предела («20», не
  /// «20.0»). Тем же правилом, каким его печатает отказ кассы
  /// (`LocalCartService._say`) — кассир видит одно и то же число на экране
  /// и в отказе.
  static String say(Decimal value) => value == value.truncate()
      ? value.truncate().toString()
      : value.toString();

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  late DiscountType _type;
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _type = widget.currentType ?? DiscountType.percent;
    _controller = TextEditingController(
      text: widget.currentDiscount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = null);
      return;
    }

    try {
      final value = Decimal.parse(text.replaceAll(',', '.'));
      if (value < Decimal.zero) {
        setState(
          () =>
              _errorText = AppLocalizations.of(context)!.valueCannotBeNegative,
        );
        return;
      }

      final maxPercent = widget.maxPercent;
      if (_type == DiscountType.percent &&
          maxPercent != null &&
          value > maxPercent) {
        setState(
          () => _errorText = AppLocalizations.of(
            context,
          )!.maxPercent(DiscountDialog.say(maxPercent)),
        );
        return;
      }

      final maxAmount = widget.maxAmount;
      if (_type == DiscountType.fixed &&
          maxAmount != null &&
          value > maxAmount) {
        setState(
          () => _errorText = AppLocalizations.of(
            context,
          )!.maxAmount(_formatMoney(maxAmount)),
        );
        return;
      }

      setState(() => _errorText = null);
    } catch (_) {
      setState(
        () => _errorText = AppLocalizations.of(context)!.enterValidNumber,
      );
    }
  }

  void _submit() {
    _validate();
    if (_errorText != null) return;

    final text = _controller.text;
    if (text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    try {
      final value = Decimal.parse(text.replaceAll(',', '.'));
      Navigator.of(context).pop(DiscountResult(type: _type, value: value));
    } catch (_) {}
  }

  void _onKey(String d) {
    _controller.text = _controller.text + d;
    _validate();
  }

  void _onDot() {
    if (_controller.text.contains('.')) return;
    final base = _controller.text.isEmpty ? '0' : _controller.text;
    _controller.text = '$base.';
    _validate();
  }

  void _onBackspace() {
    final t = _controller.text;
    if (t.isEmpty) return;
    _controller.text = t.substring(0, t.length - 1);
    _validate();
  }

  void _onClear() {
    _controller.clear();
    _validate();
  }

  String get _currencySymbol => widget.currencySymbol;

  String _formatMoney(Decimal value) {
    return '${value.toStringAsFixed(2)} $_currencySymbol';
  }

  /// Строка предела под переключателем — пустой список, если предела нет.
  ///
  /// Пустой **намеренно и с доводом**: когда `cap == null`, предел не
  /// «сто процентов», а «не прочитан», и написать «доступно до 100 %»
  /// значило бы пообещать за кассу то, чего она не обещала.
  List<Widget> _limitHint(BuildContext context) {
    final cap = widget.cap;
    if (cap == null) return const [];

    final l10n = AppLocalizations.of(context)!;
    final maxAmount = widget.maxAmount;

    final String limitLine;
    if (_type == DiscountType.fixed && maxAmount != null) {
      limitLine = l10n.discountLimitAmount(_formatMoney(maxAmount), cap.source);
    } else {
      limitLine = l10n.discountLimitPercent(
        DiscountDialog.say(cap.maxPercent),
        cap.source,
      );
    }

    final approvalAbove = cap.approvalAbove;

    return [
      Container(
        key: const Key('discount_limit_hint'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(limitLine, style: context.styles.caption),
            if (approvalAbove != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.discountApprovalAbove(DiscountDialog.say(approvalAbove)),
                style: context.styles.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    Decimal? previewAmount;
    if (widget.subtotal != null &&
        _controller.text.isNotEmpty &&
        _errorText == null) {
      try {
        final value = Decimal.parse(_controller.text.replaceAll(',', '.'));
        previewAmount = DiscountResult(
          type: _type,
          value: value,
        ).calculate(widget.subtotal!);
      } catch (_) {}
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(context)!.discountTitle,
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                SegmentedButton<DiscountType>(
                  segments: [
                    const ButtonSegment(
                      value: DiscountType.percent,
                      label: Text('%'),
                    ),
                    ButtonSegment(
                      value: DiscountType.fixed,
                      label: Text(AppLocalizations.of(context)!.globalAmount),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (set) {
                    setState(() => _type = set.first);
                    _validate();
                  },
                ),
                const SizedBox(height: 12),

                // Предел — **до ввода, а не после**.
                //
                // Задача 18, требование заказчика: кассир обязан видеть, до
                // скольки можно, прежде чем набирать. До этой правки предел
                // существовал только в тексте ошибки, то есть узнать его
                // можно было единственным способом — нарушив.
                //
                // Строка перерисовывается вместе с переключателем «% /
                // сумма»: в процентах она называет процент, в сумме —
                // деньги, потому что переводить одно в другое в уме кассиру
                // не за что.
                ..._limitHint(context),

                TextField(
                  controller: _controller,
                  readOnly: true,
                  showCursor: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                  onChanged: (_) => _validate(),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: _type == DiscountType.percent ? '0' : '0.00',
                    errorText: _errorText,
                    suffixText: _type == DiscountType.percent
                        ? '%'
                        : _currencySymbol,
                    suffixStyle: AppTextStyles.h3.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: NumPad(
                    buttonSize: 48,
                    spacing: 8,
                    showEnter: true,
                    onKeyPressed: _onKey,
                    onBackspace: _onBackspace,
                    onClear: _onClear,
                    onEnter: _submit,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 168,
                    child: OutlinedButton(
                      onPressed: _onDot,
                      child: const Text('.', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ),

                if (previewAmount != null && widget.subtotal != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.discountAmount,
                          style: AppTextStyles.body,
                        ),
                        Text(
                          '-${_formatMoney(previewAmount)}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(AppLocalizations.of(context)!.globalCancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(
                          AppLocalizations.of(context)!.discountApply,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
