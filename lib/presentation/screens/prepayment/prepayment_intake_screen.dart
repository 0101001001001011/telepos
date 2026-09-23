import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/sale/command_key.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';

/// Приём аванса покупателя — экран, требование заказчика 2026-09-18.
///
/// # Почему свой экран, а не кассовый диалог
///
/// Кассовый диалог (`RecordCustomerPaymentDialog`) открывается **из
/// карточки контрагента**: покупатель к этому моменту уже выбран, и диалогу
/// остаётся спросить сумму. У браузерного терминала карточки контрагентов
/// нет вовсе — картотека живёт за `nav.agent`, по проводу не ездит и в
/// браузерную таблицу маршрутов не входит. Значит покупателя надо найти
/// здесь же, и находится он тем единственным способом, какой у терминала
/// есть: поиском по телефону (`PaymentService.findLoyalty`, операция
/// `pay.loyalty`).
///
/// Отсюда три шага на одном экране: найти покупателя, назвать сумму и вид
/// оплаты, подтвердить.
///
/// # Почему выдача живёт здесь же, а не своим экраном
///
/// Решение заказчика 2026-09-18: «в браузере должно работать то же, что в
/// приложении». Выдача аванса деньгами (`pay.prepaymentRefund`) требует
/// ровно того же, что приём, и в том же порядке: найти покупателя по
/// телефону, узнать у кассы остаток, назвать сумму и вид оплаты. Второй
/// экран отличался бы от этого одним словом на кнопке — и **двумя** местами,
/// где покупателя ищут, остаток читают и ключ повтора рождают. Разойтись им
/// негде ровно до первой правки.
///
/// На кассе выбор другой — там выдача **отдельный маршрут**
/// (`/prepayment-refund`), и это не непоследовательность: там маршрут был
/// единственным местом, где право вообще проверяется (докстринг
/// `AppRoutes.prepaymentRefund`). Здесь право проверяет **касса** — у
/// операции постоянное `op.creditRepay` сверх `nav.sale`, и проверяет его
/// сторож провода до обработчика. Прятать направление за вторым адресом
/// ради права, которое стоит не здесь, было бы обрядом.
///
/// **Чего этот экран НЕ доказывает:** что в ящике есть наличные. Сальдо
/// счёта выдачи — не содержимое ящика, и сторожа на это нет ни у одной
/// выдачи денег в дереве.
///
/// # Экран не считает денег — ни одной величины
///
/// Остаток аванса до взноса и сальдо после него приходят **ответами
/// кассы** (`pay.prepayment` и `pay.prepaymentIntake`). Сложить их здесь
/// было бы на один круг дешевле и означало бы второй источник правды о
/// деньгах, живущий во вкладке браузера, — тот же довод, каким его нет в
/// `WtPaymentService`.
///
/// # Слова — из словаря, отказы — по коду
///
/// Причина отказа приезжает кодом (`WireRefusal.code`), и фразу для него
/// берёт `saleRefusalErrorKeyOf` → `ErrorLocalizer` — тем же путём, каким
/// её берут продажа и возврат. Русский текст кассы на экран не едет вовсе:
/// он уходит в журнал.
class PrepaymentIntakeScreen extends StatefulWidget {
  const PrepaymentIntakeScreen({super.key});

  @override
  State<PrepaymentIntakeScreen> createState() => _PrepaymentIntakeScreenState();
}

class _PrepaymentIntakeScreenState extends State<PrepaymentIntakeScreen> {
  final _phone = TextEditingController();
  final _amount = TextEditingController();

  /// Найденный покупатель. `null` — ещё не искали или не нашли.
  LoyaltyCustomer? _customer;

  /// Сколько аванса уже внесено — ответ кассы, а не память вкладки.
  Decimal? _balance;

  /// Чем принимаются или выдаются деньги. Умолчание — наличные: тот же
  /// выбор, что у кассового диалога, и он же самый частый у кассы.
  int _tenderKindId = SystemPaymentKindIds.cash;

  /// Куда идут деньги: `false` — приём, `true` — выдача.
  ///
  /// # Почему признак, а не два экрана
  ///
  /// Разбор — в докстринге класса. Здесь важно другое: смена направления
  /// **правит форму**, то есть рождает новую заявку ([_formChanged]). Без
  /// этого кассир, нажавший «Принять», получивший обрыв и переключившийся
  /// на «Выдать», послал бы **прежний ключ** — и касса, узнав в нём повтор
  /// приёма, ответила бы «принято» на просьбу выдать.
  ///
  /// Обе стороны этого сторожит проба
  /// (`test/web/prepayment_intake_screen_test.dart`), потому что ключ на
  /// экране не рисуется и глазами его не видно.
  bool _payOut = false;

  /// Ключ **этой заявки** — чем касса узнаёт повтор.
  ///
  /// # Почему он рождается здесь, а не в кассе и не в проводе
  ///
  /// Потому что «повтор» — это свойство намерения кассира, и знает о нём
  /// только экран, на котором это намерение набрано. Касса видит два
  /// одинаковых кадра и различить их не может: покупатель, честно вносящий
  /// тысячу дважды, и оборванный провод дают ей побайтово одно и то же.
  /// Провод же не знает даже того, что кадр послан второй раз, — переслать
  /// его может и переподключившаяся вкладка, и новое нажатие.
  ///
  /// # Когда ключ обновляется — и почему именно так
  ///
  /// Ключ живёт ровно столько, сколько живёт **заполненная форма**:
  /// рождается при первом нажатии «Принять» (`??=`, тем же приёмом, что
  /// `PaymentController._completionKey`) и обнуляется от всякой правки
  /// телефона, суммы или вида оплаты ([_formChanged]).
  ///
  /// Отсюда обе нужные стороны, и обе — следствия одного правила, а не два
  /// разных механизма:
  ///
  /// - **Повтор после отказа шлёт тот же ключ.** Кассир ничего не правил,
  ///   форма та же — значит заявка та же. Касса ответит прежним исходом, и
  ///   деньги второй раз не спишутся.
  /// - **Новая заявка получает новый ключ.** Успех очищает поле суммы, и
  ///   очистка — это правка формы: ключ умирает вместе с ней. Второй взнос
  ///   той же тысячи тем же покупателем требует набрать сумму заново, то
  ///   есть родить новый ключ.
  ///
  /// Соблазн вычислять ключ из содержимого заявки (покупатель + сумма +
  /// вид) отвергнут именно из-за второго случая: тогда законный второй
  /// взнос той же суммы был бы неотличим от повтора **навсегда**, и касса
  /// молча отказалась бы принять настоящие деньги.
  String? _intakeKey;

  bool _searching = false;
  bool _submitting = false;

  /// Готовая фраза словаря — либо ключ, если код кассе новее терминала.
  String? _error;

  /// Что сказать об удачном приёме, пока кассир не начал следующий.
  String? _done;

  PaymentService get _payments => GetIt.I<PaymentService>();
  PrepaymentIntakeService get _intake => GetIt.I<PrepaymentIntakeService>();

  /// Выдача — **свой контракт**, а не метод приёмщика: у браузерной половины
  /// это другая операция провода со своим кодеком и своими отказами (разбор —
  /// в докстринге `PrepaymentRefundService`).
  PrepaymentRefundService get _refund => GetIt.I<PrepaymentRefundService>();

  @override
  void initState() {
    super.initState();
    _phone.addListener(_formChanged);
    _amount.addListener(_formChanged);
  }

  @override
  void dispose() {
    _phone.removeListener(_formChanged);
    _amount.removeListener(_formChanged);
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Форма правлена — значит это **другая заявка**.
  ///
  /// Без обнуления ключа правка была бы хуже, чем бесполезна: кассир,
  /// исправивший сумму с 1000 на 100 после отказа, послал бы прежний ключ, и
  /// касса честно ответила бы **прежним исходом на тысячу** — то есть
  /// показала бы успех приёма суммы, которую кассир только что отменил.
  ///
  /// `setState` здесь не зовётся: ключ не рисуется, и перестройка ради него
  /// была бы перестройкой на каждую набранную цифру.
  void _formChanged() => _intakeKey = null;

  /// Отказ кассы → фраза на языке кассира.
  ///
  /// Исключение чужого рода (обрыв провода, падение обработчика) сюда тоже
  /// доходит: у него нет кода, и кассир получает общее «не удалось», а
  /// подробность — журнал. Молчать нельзя — это ровно тот случай, ради
  /// которого И144 и заведён.
  String _phraseFor(Object error) {
    final what = _payOut ? 'Prepayment refund' : 'Prepayment intake';
    if (error is WireRefusal) {
      talker.warning('$what refused: ${error.code} ${error.message}');
      return ErrorLocalizer.localize(context, saleRefusalErrorKeyOf(error));
    }
    talker.error('$what failed', error);
    // Запасная фраза — **по направлению**: «аванс принять не удалось» на
    // экране выдачи отправило бы кассира искать беду не там, а исключение
    // без кода приходит сюда и при выдаче тоже (обрыв провода, падение
    // обработчика).
    return ErrorLocalizer.localize(
      context,
      _payOut
          ? 'error.$prepaymentRefundFailedCode'
          : 'error.$prepaymentIntakeFailedCode',
    );
  }

  Future<void> _find() async {
    final l10n = AppLocalizations.of(context)!;
    final phone = _phone.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _done = null;
      _customer = null;
      _balance = null;
    });

    try {
      final found = await _payments.findLoyalty(phone);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _searching = false;
          _error = l10n.prepaymentIntakeNotFound;
        });
        return;
      }
      // Остаток спрашивается **после** того, как покупатель найден, и
      // отдельным кругом: у вида «аванс» свой отказ (он заводится
      // выключенным), и получить его на поиске значило бы потерять и
      // покупателя заодно.
      final balance = await _payments.prepaymentBalance(found.id);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _customer = found;
        _balance = balance;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = _phraseFor(error);
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final customer = _customer;
    if (customer == null) return;

    final amount = Decimal.tryParse(_amount.text.trim().replaceAll(',', '.'));
    // Сумму проверяет и касса (`prepayment_amount_invalid`), и это не
    // дублирование: здесь проверка **избавляет от круга**, а запрет держит
    // касса. Убрать её здесь — лишний круг; убрать там — дыра.
    if (amount == null || amount <= Decimal.zero) {
      setState(() {
        _done = null;
        _error = l10n.customerPaymentAmountInvalid;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _done = null;
    });

    // `??=`, а не `=`: повторное нажатие по неправленой форме — та же
    // заявка, и ключ обязан быть тем же. Разбор — в докстринге [_intakeKey].
    // Ключ берётся **до** ветвления по направлению: он принадлежит заявке, а
    // не одной из двух операций, и смена направления его обнуляет
    // ([_formChanged]) — то есть сменить направление и послать прежний ключ
    // нельзя по построению.
    final key = _intakeKey ??= newCommandSessionTag();

    try {
      // Примечания обеих заявок — данные проводки, а не фраза экрана: их
      // читает человек в журнале кассы. Поэтому по-русски и не из словаря,
      // тем же приёмом, что у кассового диалога.
      //
      // Две ветви, а не одна с общим «исходом»: у приёма и у выдачи разные
      // контракты и разные исходы (разбор — в докстринге
      // `PrepaymentRefundOutcome`), и общий тип здесь пришлось бы выдумать.
      final Decimal balance;
      final String? fiscalError;
      if (_payOut) {
        final outcome = await _refund.payOutPrepayment(
          PrepaymentRefundRequest(
            key: key,
            customerId: customer.id,
            amount: amount,
            tenderKindId: _tenderKindId,
            // Основание (проводка приёма) вкладкой **не называется**: у неё
            // нет ни списка проводок покупателя, ни операции, которая бы его
            // отдала. `null` значит «не назван», и касса выпишет возврат без
            // основания — законный случай (докстринг
            // `CustomerPaymentUseCase.refundPrepayment`). Выдумать номер
            // здесь значило бы сослаться на чужой документ.
            note: l10n.prepaymentIssueTo(customer.name),
          ),
        );
        balance = outcome.balance;
        fiscalError = outcome.fiscalError;
      } else {
        final outcome = await _intake.acceptPrepayment(
          PrepaymentIntakeRequest(
            key: key,
            customerId: customer.id,
            amount: amount,
            tenderKindId: _tenderKindId,
            note: l10n.prepaymentFrom(customer.name),
          ),
        );
        balance = outcome.balance;
        fiscalError = outcome.fiscalError;
      }

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _amount.clear();
        _balance = balance;
        _done = _payOut
            ? l10n.prepaymentRefundDone(balance.toStringAsFixed(2))
            : l10n.prepaymentIntakeAccepted(balance.toStringAsFixed(2));
        // Деньги двинулись, документа нет — кассир обязан узнать об этом
        // словом. Отказ оператора денег не отменяет (докстринг
        // `PrepaymentIntakeOutcome`), поэтому это не ошибка операции, а
        // отдельная строка рядом с успехом. Показать её отказом на выдаче
        // было бы хуже всего: кассир выдал бы деньги второй раз.
        _error = fiscalError == null
            ? null
            : (_payOut
                  ? l10n.prepaymentRefundFiscalFailed
                  : l10n.prepaymentIntakeFiscalFailed);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _phraseFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final customer = _customer;
    final busy = _searching || _submitting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('prepayment-phone'),
            controller: _phone,
            enabled: !busy,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.paymentPhoneNumber,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone),
            ),
            onSubmitted: (_) => _find(),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const ValueKey('prepayment-find'),
            onPressed: busy ? null : _find,
            child: Text(l10n.prepaymentIntakeFind),
          ),
          if (customer != null) ...[
            const SizedBox(height: 20),
            Text(
              customer.name,
              key: const ValueKey('prepayment-customer'),
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.paymentPrepaymentBalance} '
              '${(_balance ?? Decimal.zero).toStringAsFixed(2)}',
              key: const ValueKey('prepayment-balance'),
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // Направление — **первым**, до суммы: кассир, набравший сумму и
            // только потом заметивший, что стоит не на том направлении,
            // потеряет её (смена направления правит форму и обнуляет ключ,
            // но поле суммы не чистит — чистит только успех).
            SegmentedButton<bool>(
              key: const ValueKey('prepayment-direction'),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.prepaymentIntakeTitle),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.prepaymentRefundTitle),
                ),
              ],
              selected: {_payOut},
              onSelectionChanged: busy
                  ? null
                  // Смена направления — **другая заявка**: без обнуления
                  // ключа повтор приёма и просьба выдать пришли бы к кассе
                  // под одним ключом, и касса ответила бы на вторую исходом
                  // первой.
                  : (s) => setState(() {
                      _payOut = s.single;
                      _done = null;
                      _error = null;
                      _formChanged();
                    }),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('prepayment-amount'),
              controller: _amount,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: _payOut
                    ? l10n.prepaymentRefundAmount
                    : l10n.customerPaymentAmount,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payments),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text(
              _payOut
                  ? l10n.prepaymentRefundTender
                  : l10n.customerPaymentTender,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              key: const ValueKey('prepayment-tender'),
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
              onSelectionChanged: busy
                  ? null
                  // Вид оплаты — часть заявки, значит его смена рождает
                  // новую: у `TextField` то же делает слушатель
                  // ([_formChanged]), а у кнопки слушателя нет.
                  : (s) => setState(() {
                      _tenderKindId = s.single;
                      _formChanged();
                    }),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('prepayment-submit'),
              onPressed: busy ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _payOut
                          ? l10n.prepaymentRefundSubmit
                          : l10n.prepaymentIntakeSubmit,
                    ),
            ),
          ],
          if (_done != null) ...[
            const SizedBox(height: 16),
            Text(
              _done!,
              key: const ValueKey('prepayment-done'),
              style: AppTextStyles.body.copyWith(
                color: scheme.primary,
                fontSize: 13,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const ValueKey('prepayment-error'),
              style: AppTextStyles.body.copyWith(
                color: scheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
