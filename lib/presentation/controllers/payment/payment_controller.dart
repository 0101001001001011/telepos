/// Экран оплаты — задача 14 плана «Продажа с браузерного терминала».
///
/// # Шесть операций уехали за контракт, пятнадцать остались
///
/// За `PaymentService` ушло то, что **меняет правду о деньгах или трогает
/// железо** (I163): счета, клиент лояльности, потолок бонуса, эквайринг и
/// завершение оплаты. Осталось состояние экрана — цифровая клавиатура,
/// активное поле, «без сдачи», раскладка номиналов, выбор вида оплаты:
/// они ничего не пишут и ни с каким устройством не разговаривают, а круг
/// по сети за нажатие цифры — расход, а не осторожность.
///
/// # `PaymentState.change` — это предпросмотр, а не деньги
///
/// Геттер остался и считает сдачу на экране, потому что кассир обязан
/// видеть её **до** того, как нажмёт «оплатить». Настоящее число
/// приходит от кассы в [SaleOutcome.change] и им же уезжает в чек; экран
/// свой предпросмотр в кассу не отправляет как истину — он кладёт его в
/// [PaymentRequest.claimedChange], откуда касса берёт его **только для
/// сверки** (докстринг `PaymentService`).
///
/// # Базы здесь больше нет — задача 17
///
/// Двумя дорогами она сюда приходила, и обе закрыты без единой новой
/// операции провода:
///
/// 1. **`denominationsProvider`** звал `GetIt.I<AppDatabase>()` ради одного
///    `int?` — страны кассы. Теперь он спрашивает `StartupStateRepository`,
///    у которого на кассе drift, а в браузере подписка `setup.state`, где
///    `countryCode` **уже ехал** с нулём читателей (см. докстринг провайдера);
/// 2. **четыре `ref.invalidate`** после успешной оплаты импортировали смену,
///    историю, каталог и остатки — а каждый из этих четырёх импортирует базу
///    напрямую. Теперь это `refreshAfterSaleCompleted(ref)` — шов, заведённый
///    задачей 13 для экрана продажи ровно от той же беды.
///
/// Ни одного прямого импорта `lib/data/` в этом файле не осталось, и держит
/// это не обещание, а сторож: `test/architecture/browser_routes_test.dart`,
/// «экран оплаты компилируем браузерной сборкой» — он ходит по графу
/// импортов, а не по строкам файла, и одного прыжка через контроллер ему
/// довольно.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/command_key.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/sale/offset_chain.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_side_effects.dart';

/// Виды оплаты, счета и клиент лояльности переехали в домен
/// (`lib/domain/sale/payment_service.dart`) и реэкспортируются отсюда: на
/// них ссылается интерфейс, а домен их знает раньше — `PaymentType` нужен
/// каталогу операций провода и, с задачи 15, самому `Terminal`.
/// Ответ «предлагать ли долг» считает домен, а не экран, — задача 16.
/// Реэкспортируется отсюда по той же причине, что и [PaymentType]:
/// селектор видов оплаты знает контроллер и не должен знать двух разных
/// мест, из которых берётся один и тот же ответ.
export 'package:telepos/domain/sale/debt_offer.dart'
    show DebtOffer, debtOfferOf;

export 'package:telepos/domain/sale/payment_service.dart'
    show
        CardCharge,
        CardChargeOutcome,
        LoyaltyCustomer,
        PaymentAccount,
        PaymentRequest,
        PaymentType,
        SaleOutcome;

enum PaymentInputField { cash, card }

/// Сертификат, предъявленный к этому чеку и **проверенный кассой**.
///
/// Остаток — ответ кассы на `PaymentService.findCertificate`, а не число,
/// набранное кассиром: экран показывает его до гашения, чтобы кассир знал,
/// сколько спишется и сколько останется на бумажке. Гасит касса, при
/// оплате, условной записью — этот остаток она перечитает сама.
@immutable
class PresentedCertificate {
  const PresentedCertificate({
    required this.number,
    required this.balance,
    this.pin,
    this.expiresAt,
  });

  final String number;

  /// ПИН, набранный кассиром. Живёт в памяти экрана до оплаты — касса
  /// спросит его снова при гашении. В журнал не пишется.
  final String? pin;

  final Decimal balance;

  /// Секунды эпохи. `null` — бессрочный.
  final int? expiresAt;

  CertificateTender get tender => CertificateTender(number: number, pin: pin);

  @override
  String toString() => 'PresentedCertificate($number, $balance)';
}

@immutable
class PaymentState {
  PaymentState({
    required this.totalAmount,
    this.paymentType = PaymentType.cash,
    Decimal? cashReceived,
    Decimal? cardAmount,
    this.selectedAccountId,
    this.loyaltyCustomer,
    Decimal? bonusToUse,
    this.iin,
    this.isProcessing = false,
    this.error,
    this.activeInput = PaymentInputField.cash,
    this.cashInputText = '',
    this.cardInputText = '',
    this.terminalApprovalCode,
    this.terminalCardMask,
    this.terminalTransactionId,
    this.terminalChargedAmount,
    this.allowedPaymentTypes = const {},
    this.sellInDebt,
    this.installmentTermMonths,
    this.installmentScheme,
    this.certificates = const <PresentedCertificate>[],
    this.prepaymentBalance,
    this.prepaymentRefusal,
    Decimal? prepaymentToUse,
    this.qr,
    this.qrRefusal,
    this.qrBusy = false,
  }) : cashReceived = cashReceived ?? Decimal.zero,
       cardAmount = cardAmount ?? Decimal.zero,
       bonusToUse = bonusToUse ?? Decimal.zero,
       prepaymentToUse = prepaymentToUse ?? Decimal.zero;

  /// Сертификаты, проверенные кассой, в порядке предъявления — тот же
  /// порядок уедет в заявку, и в нём же касса разложит комнату чека.
  final List<PresentedCertificate> certificates;

  /// Сколько аванса внесено найденным покупателем — **ответ кассы**
  /// (`PaymentService.prepaymentBalance`).
  ///
  /// `null` — не спрошено (покупателя нет), ещё не ответила или отказала;
  /// различает их [prepaymentRefusal] и [loyaltyCustomer].
  final Decimal? prepaymentBalance;

  /// Почему аванс недоступен — ключ отказа кассы (`error.payment_kind_inactive`,
  /// `error.prepayment_account_missing`, …). Экран гасит зачёт и называет
  /// эту причину, а не прячет его.
  final String? prepaymentRefusal;

  /// Сколько аванса кассир **просит** зачесть. Сколько зачтётся на деле —
  /// [offsets] (`OffsetSplit.prepayment`): урезает цепочка, а не экран.
  final Decimal prepaymentToUse;

  /// Оплата по QR этого чека — **ответ кассы** (`PaymentService.startQr`,
  /// `pollQr`, `cancelQr`). `null` — код не показывали.
  ///
  /// Деньги из неё идут в цепочку зачётов **только когда они есть**
  /// ([QrTender.usable]): показанный, но не оплаченный код — это обещание,
  /// а не деньги, и предпросмотр, вычевший его из суммы к оплате, отпустил
  /// бы покупателя с товаром за приложение банка, которое он ещё не открыл.
  final QrTender? qr;

  /// Почему последний вопрос о QR не получил ответа — ключ отказа кассы
  /// или провода. `error.qr_not_configured` и `error.payment_kind_inactive`
  /// гасят панель с причиной; прочее показывается строкой под ней.
  final String? qrRefusal;

  /// Вопрос о QR в полёте — кнопки панели погашены.
  final bool qrBusy;

  final Decimal totalAmount;

  final PaymentType paymentType;

  final Decimal cashReceived;

  final Decimal cardAmount;

  final int? selectedAccountId;

  final LoyaltyCustomer? loyaltyCustomer;

  final Decimal bonusToUse;

  final String? iin;

  final bool isProcessing;

  final String? error;

  /// Срок рассрочки, выбранный кассиром, — задача 24.
  ///
  /// `null` у всех прочих видов оплаты и **сразу после смены вида**:
  /// протухший срок был бы заявкой, где вид один, а условия договора
  /// другие.
  final int? installmentTermMonths;

  /// Схема графика, выбранная кассиром.
  final InstallmentScheme? installmentScheme;

  final PaymentInputField activeInput;

  final String cashInputText;

  final String cardInputText;

  final String? terminalApprovalCode;

  final String? terminalCardMask;

  final String? terminalTransactionId;

  /// Сумма, на которую карта **проведена**.
  ///
  /// Реквизиты выше годны ровно для неё: касса помнит проведение по
  /// рабочему месту, чеку и **сумме** (`LocalPaymentService._cardCharges`)
  /// и отвергает код одобрения, относящийся к другому платежу. Как только
  /// безналичная часть стала другой, реквизиты снимаются — см. `_state`.
  final Decimal? terminalChargedAmount;

  /// Виды оплаты, разрешённые **рабочему месту**, за которым сидит этот
  /// экран — задача 15, решение заказчика №5.
  ///
  /// Пустое множество означает «все», и это не удобство, а требование
  /// миграции v38 (докстринг `Terminal.allowedPaymentTypes`). Тем же
  /// пустым множеством читается **всякая неудача чтения**: набор так и
  /// не доехал, терминала не нашли, касса ответила отказом. Обратное —
  /// «не прочитали, значит запретим» — остановило бы кассу, которой
  /// ничего не запрещали; «не прочитали, значит покажем всё» оставляет
  /// её ровно там, где она была до этой задачи, и запрет по-прежнему
  /// держит касса.
  ///
  /// **Это не защита.** Спрятанная (здесь — погашенная) кнопка правом не
  /// является: касса проверяет набор сама
  /// (`LocalPaymentService._requireAllowedTypes`, I162), и проверка эта
  /// не снимается ничем на экране. Поле существует затем, чтобы кассир не
  /// набирал сумму наличными на планшете «только безнал» и не узнавал об
  /// этом последним нажатием.
  final Set<PaymentType> allowedPaymentTypes;

  /// Торгует ли **эта касса** в долг — `ThisPosEntries.sellInDebt`,
  /// тумблер мастера настройки «Разрешить продажу в кредит» (задача 16).
  ///
  /// `null` — **касса ещё не ответила**, и это третье состояние, а не
  /// второе «нельзя». Умолчание здесь обратное умолчанию задачи 15
  /// ([allowedPaymentTypes] читает всякую неудачу как «все виды»), и
  /// разница не в осторожности, а в направлении настройки: там набор
  /// **сужает** разрешённое по умолчанию, здесь тумблер **добавляет**
  /// вид, которого по умолчанию нет. «Не прочитали, значит торгуют в
  /// кредит» открыло бы кассиру вид оплаты, которого владелец точки не
  /// включал, — и кончилось бы отказом кассы после выбора покупателя.
  ///
  /// Молча кнопка при этом не гаснет: `null` показывается своей причиной
  /// («касса ещё не ответила»), а не общим «нельзя», — разбор у
  /// [DebtOffer.unknown].
  ///
  /// **Это не защита.** Запрет держит касса и отвечает
  /// `debt_not_sold_here` любому кадру, включая собранный мимо экрана.
  final bool? sellInDebt;

  /// Предлагать ли [type] кассиру на этом рабочем месте.
  ///
  /// Ответ считает домен ([paymentTypeOfferable]), а не экран: смешанная
  /// проверяется кассой по половинам, и вывести её из одного лишь
  /// `contains` нельзя.
  bool offers(PaymentType type) =>
      paymentTypeOfferable(allowedPaymentTypes, type);

  bool get isTerminalAuthorized => terminalApprovalCode != null;

  /// Сколько каждый зачёт покроет в этом чеке — **предпросмотр той же
  /// функцией, которой разложит касса** (`OffsetChain.split`).
  ///
  /// Второго расчёта потолков здесь нет и заводить его нельзя: слияние
  /// задач 21–23 измерило, чем кончаются три копии «остатка после бонуса»
  /// — одна и та же комната выдавалась трижды. Экран кладёт в функцию то,
  /// что знает: бонус, остатки проверенных кассой бумажек и просимый аванс,
  /// урезанный внесённым.
  ///
  /// **QR встал вторым звеном — туда же, где его ставит касса**, а не
  /// своей формулой рядом: деньги оплаченного намерения ([QrTender.money])
  /// идут доводом `qr` той же функции. До входа в QR здесь стояло «QR сюда
  /// не входит — ключа намерения экран не производит»; теперь производит,
  /// и предпросмотр обязан показывать ту же раскладку, что сделает касса,
  /// — иначе кассир увидел бы «доплатить 1000» при оплаченном телефоном
  /// чеке. Только оплаченные и ещё не легшие в чек деньги: код в ожидании
  /// — не деньги.
  OffsetSplit get offsets {
    final balance = prepaymentBalance ?? Decimal.zero;
    final paidByQr = qr;
    return OffsetChain.split(
      amount: totalAmount,
      bonus: bonusToUse,
      qr: paidByQr != null && paidByQr.usable ? paidByQr.money : null,
      certificateBalances: [for (final c in certificates) c.balance],
      prepayment: prepaymentToUse > balance ? balance : prepaymentToUse,
    );
  }

  /// Сколько внести деньгами после всех зачётов.
  ///
  /// До входа в аванс и сертификат здесь стояло `totalAmount - bonusToUse`
  /// — ровно та форма, которая молча не знала бы о бумажке, покрывшей
  /// полчека, и потребовала бы с покупателя наличных на всю сумму.
  Decimal get amountToPay => offsets.toPay;

  /// Безналичная часть — сколько уйдёт в эквайринг.
  ///
  /// Та же формула, по которой её считает касса
  /// (`LocalPaymentService._plan`), и это **сознательный дубль**, а не
  /// упущение: экран обязан назвать платёжному терминалу сумму **до**
  /// того, как касса что-либо посчитает, — иначе карту нечем проводить.
  /// Расхождение не проходит молча: касса сверяет проведение со своей
  /// цифрой (`_requireCardProof`) и отвергает то, чего не проводила.
  ///
  /// Круг правки 3: до него экран звал эквайринг **только** при чистой
  /// карте, а касса требовала доказательства при **любой** безналичной
  /// части — то есть смешанная оплата и долг с картой на кассе с
  /// привязанным Kaspi были невозможны вовсе.
  Decimal get cardPortion {
    switch (paymentType) {
      case PaymentType.cash:
        return Decimal.zero;
      case PaymentType.card:
        return amountToPay;
      case PaymentType.mixed:
      case PaymentType.debt:
      case PaymentType.installment:
        return cardAmount > amountToPay ? amountToPay : cardAmount;
    }
  }

  Decimal get change {
    if (paymentType == PaymentType.cash) {
      final diff = cashReceived - amountToPay;
      return diff > Decimal.zero ? diff : Decimal.zero;
    }
    if (paymentType == PaymentType.mixed) {
      final totalReceived = cashReceived + cardAmount;
      final diff = totalReceived - amountToPay;
      return diff > Decimal.zero ? diff : Decimal.zero;
    }
    return Decimal.zero;
  }

  Decimal get remaining {
    switch (paymentType) {
      case PaymentType.cash:
        final diff = amountToPay - cashReceived;
        return diff > Decimal.zero ? diff : Decimal.zero;
      case PaymentType.card:
        return Decimal.zero;
      case PaymentType.mixed:
        final totalReceived = cashReceived + cardAmount;
        final diff = amountToPay - totalReceived;
        return diff > Decimal.zero ? diff : Decimal.zero;
      case PaymentType.debt:
      case PaymentType.installment:
        // Остаток в долг — это и есть долг, а не «недоплата»: кассир
        // видит, сколько уйдёт на баланс покупателя. У рассрочки то же
        // число — **тело будущего договора**: сколько останется в график
        // после первого взноса.
        final diff = amountToPay - (cashReceived + cardAmount);
        return diff > Decimal.zero ? diff : Decimal.zero;
    }
  }

  /// Кнопка «Оплатить» доступна.
  ///
  /// **Два условия, и они про разное:** деньги сходятся ([amountCovered])
  /// и оплата ещё не идёт. Второе — свойство **экрана**, а не операции, и
  /// путать их дорого: круг правки 5 поставил признак обработки первой
  /// строкой обработчика нажатия, а `processPayment` первой строкой
  /// спрашивала этот геттер — сторож от второго нажатия отбивал **первое**,
  /// и десктопная касса переставала проводить оплату вовсе (кассир жмёт, и
  /// ничего не происходит, бесконечно).
  ///
  /// Поэтому операция спрашивает [amountCovered], а не этот геттер:
  /// признак обработки не участвует в решении «можно ли завершить» на
  /// входе в собственную операцию.
  bool get canComplete => !isProcessing && amountCovered;

  /// Денег хватает на чек — без оглядки на то, идёт ли уже оплата.
  ///
  /// # Тот же дефект найден дважды, двумя ветвями, под разными именами
  ///
  /// Задача 16 пришла к этому же геттеру своим путём и назвала его
  /// `isReadyToPay`. Её разбор: экран поднимает признак обработки **до**
  /// вызова (`payment_screen._handleComplete`, круг правки 5 задачи 14 —
  /// защита от двойного нажатия), а `processPayment` первой строкой
  /// спрашивал `canComplete`, в который тот же признак входит. Нажатие
  /// «ОПЛАТИТЬ» само себе запрещало оплату: `canComplete=false` в первой
  /// же строке журнала, метод возвращал `false`, ничего не сделав.
  /// Найдено виджет-пробой (`payment_visible_signal_test.dart`) — той
  /// самой, которую разбор потребовал завести, потому что ни одна проба
  /// до неё **не нажимала кнопку**: все дёргали контроллер напрямую, мимо
  /// признака. Воспроизведено на базе `4daacda`.
  ///
  /// При слиянии взята версия задачи 14 целиком, и довод не в имени:
  /// задача 16 вынула условие из `processPayment` и **не положила ничего
  /// взамен** — операция стала повторно входимой по контракту. `_completing`
  /// в версии задачи 14 и есть тот третий слой, который задача 16 только
  /// объявляет; плюс та версия закрывает предел «запись вне перехвата».
  /// `isReadyToPay` снят, ссылки на него перенацелены сюда.
  ///
  /// **Пробы держим обе**, и ни одна не поглощает другую: виджет-проба
  /// задачи 16 утверждает про **увиденное кассиром** (нажал — оплата
  /// пошла), проба задачи 14 — про **доехавшее до кассы** (один
  /// `PaymentService.complete` на два нажатия).
  ///
  /// Защита от двойного нажатия осталась тройной: сторож
  /// `if (preState.isProcessing) return;` на входе в обработчик, погасшая
  /// кнопка ([canComplete]) и составной ключ повтора у самой кассы
  /// (`LocalPaymentService._completions`).
  bool get amountCovered {
    // **Пока касса ждёт ответа провайдера, чек не закрывается ничем.**
    // Покупатель, может быть, прямо сейчас подтверждает оплату в
    // приложении банка; закрыть чек наличными поверх — взять с него
    // дважды, и второй раз деньги станут деньгами без чека. Кассир
    // сначала отменяет ожидание — и узнаёт ответ провайдера.
    if (qr?.phase.blocksCompletion ?? false) return false;
    switch (paymentType) {
      case PaymentType.cash:
        return cashReceived >= amountToPay;
      case PaymentType.card:
        return true;
      case PaymentType.mixed:
        return (cashReceived + cardAmount) >= amountToPay;
      case PaymentType.debt:
      case PaymentType.installment:
        // В долг и в рассрочку оплата доступна всегда: остаток и есть
        // смысл операции. Право на неё проверяет касса до вызова
        // обработчика (I44, I162), а не спрятанная кнопка; срок и схему
        // рассрочки проверяет она же.
        return true;
    }
  }

  bool get hasLoyaltyCustomer => loyaltyCustomer != null;

  Decimal get availableBonus => loyaltyCustomer?.bonusBalance ?? Decimal.zero;

  PaymentState copyWith({
    Decimal? totalAmount,
    PaymentType? paymentType,
    Decimal? cashReceived,
    Decimal? cardAmount,
    int? selectedAccountId,
    bool clearSelectedAccountId = false,
    LoyaltyCustomer? loyaltyCustomer,
    bool clearLoyaltyCustomer = false,
    Decimal? bonusToUse,
    String? iin,
    bool clearIin = false,
    bool? isProcessing,
    String? error,
    bool clearError = false,
    PaymentInputField? activeInput,
    String? cashInputText,
    String? cardInputText,
    String? terminalApprovalCode,
    String? terminalCardMask,
    String? terminalTransactionId,
    Decimal? terminalChargedAmount,
    bool clearTerminalData = false,
    Set<PaymentType>? allowedPaymentTypes,
    bool? sellInDebt,
    int? installmentTermMonths,
    InstallmentScheme? installmentScheme,
    bool clearInstallment = false,
    List<PresentedCertificate>? certificates,
    Decimal? prepaymentBalance,
    String? prepaymentRefusal,
    Decimal? prepaymentToUse,
    bool clearPrepayment = false,
    QrTender? qr,
    bool clearQr = false,
    String? qrRefusal,
    bool clearQrRefusal = false,
    bool? qrBusy,
  }) {
    return PaymentState(
      // QR принадлежит **чеку**, а не покупателю: смена покупателя его не
      // сбрасывает — деньги, заплаченные телефоном, остаются деньгами
      // этого чека.
      qr: clearQr ? qr : (qr ?? this.qr),
      qrRefusal: clearQrRefusal ? qrRefusal : (qrRefusal ?? this.qrRefusal),
      qrBusy: qrBusy ?? this.qrBusy,
      certificates: certificates ?? this.certificates,
      // Аванс принадлежит **покупателю**: сменился или ушёл покупатель —
      // остаток, отказ и просимая сумма сбрасываются вместе
      // (`clearPrepayment`), иначе чужой аванс уехал бы в заявку под новым
      // `customerId`. Переданные рядом значения при этом берутся — так
      // сброс и первый ответ кассы пишутся одной записью.
      prepaymentBalance: clearPrepayment
          ? prepaymentBalance
          : (prepaymentBalance ?? this.prepaymentBalance),
      prepaymentRefusal: clearPrepayment
          ? prepaymentRefusal
          : (prepaymentRefusal ?? this.prepaymentRefusal),
      prepaymentToUse: clearPrepayment
          ? prepaymentToUse
          : (prepaymentToUse ?? this.prepaymentToUse),
      totalAmount: totalAmount ?? this.totalAmount,
      paymentType: paymentType ?? this.paymentType,
      cashReceived: cashReceived ?? this.cashReceived,
      cardAmount: cardAmount ?? this.cardAmount,
      selectedAccountId: clearSelectedAccountId
          ? null
          : (selectedAccountId ?? this.selectedAccountId),
      loyaltyCustomer: clearLoyaltyCustomer
          ? null
          : (loyaltyCustomer ?? this.loyaltyCustomer),
      bonusToUse: bonusToUse ?? this.bonusToUse,
      iin: clearIin ? null : (iin ?? this.iin),
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : (error ?? this.error),
      activeInput: activeInput ?? this.activeInput,
      cashInputText: cashInputText ?? this.cashInputText,
      cardInputText: cardInputText ?? this.cardInputText,
      terminalApprovalCode: clearTerminalData
          ? null
          : (terminalApprovalCode ?? this.terminalApprovalCode),
      terminalCardMask: clearTerminalData
          ? null
          : (terminalCardMask ?? this.terminalCardMask),
      terminalTransactionId: clearTerminalData
          ? null
          : (terminalTransactionId ?? this.terminalTransactionId),
      terminalChargedAmount: clearTerminalData
          ? null
          : (terminalChargedAmount ?? this.terminalChargedAmount),
      // Набор видов [clearTerminalData] не касается: это свойство рабочего
      // места, а не реквизиты одного проведения карты.
      allowedPaymentTypes: allowedPaymentTypes ?? this.allowedPaymentTypes,
      sellInDebt: sellInDebt ?? this.sellInDebt,
      // Срок и схема **стираются** сменой вида оплаты (`clearInstallment`)
      // — иначе чек, начатый рассрочкой и переключённый на наличные,
      // унёс бы с собой срок, которого кассир больше не выбирал, и касса
      // получила бы заявку, где вид один, а условия договора другие. Поле
      // читается только при `PaymentType.installment`, но оставлять в
      // состоянии протухшее значение — тот же класс, что реквизиты карты
      // после смены вида (`clearTerminalData` выше).
      installmentTermMonths: clearInstallment
          ? null
          : (installmentTermMonths ?? this.installmentTermMonths),
      installmentScheme: clearInstallment
          ? null
          : (installmentScheme ?? this.installmentScheme),
    );
  }
}

class PaymentNotifier extends Notifier<PaymentState> {
  /// Оплата за контрактом. Резолвится лениво, тем же приёмом, что
  /// `SaleNotifier._cart`: под браузером сюда встанет `WtPaymentService`,
  /// и экран об этом не узнает.
  PaymentService get _payments => GetIt.I<PaymentService>();

  /// Ключ повтора одной попытки оплаты.
  ///
  /// Мнётся один раз на **чек**, а не на нажатие: кассир, нажавший
  /// «оплатить» второй раз после того, как ответ не дошёл, обязан получить
  /// свой прежний итог, а не вторую оплату (`PaymentService.complete`,
  /// раздел про повтор). Сбрасывается, когда оплата удалась — следующий
  /// чек начинает свою попытку с чистого ключа.
  String? _completionKey;

  /// Завершение оплаты уже идёт.
  ///
  /// Своя защита операции от повторного входа, **отдельная** от
  /// `PaymentState.isProcessing`: тот принадлежит экрану, выставляется им
  /// же до зова эквайринга и потому не может служить входным условием
  /// самой операции — на этом смешении десктопная касса переставала
  /// проводить оплату вовсе.
  bool _completing = false;

  /// Чек, которому принадлежит [_completionKey].
  int? _keyReceiptNo;

  /// Экран закрыт, а ответ кассы ещё в полёте.
  ///
  /// Тот же приём и по той же причине, что `SaleNotifier._disposed`: все
  /// шесть операций асинхронны, и между вопросом и ответом экран может
  /// быть закрыт (кассир ушёл, вкладку выгрузили) — запись в `state`
  /// после этого не гонка, а обычный ход событий, на котором Riverpod
  /// бросает «Ref … after it has been disposed».
  ///
  /// Заведён кругом правки 3, и нашёл его не разбор, а собственная
  /// правка: пока неудачный автоподбор счёта только писал в журнал,
  /// ветка была безобидной; как только она стала **сбрасывать выбор**,
  /// закрытый экран начал ронять сценарий.
  bool _disposed = false;

  @override
  PaymentState build() {
    ref.onDispose(() {
      _disposed = true;
      _stopQrPolling();
    });
    return PaymentState(totalAmount: Decimal.zero);
  }

  /// Единственная дверь для записи состояния экрана оплаты.
  ///
  /// Делает две вещи, и обе — про то, что случилось **между** вопросом и
  /// ответом.
  ///
  /// **Экран закрыт.** Все шесть операций асинхронны, и запись после
  /// закрытия — обычный ход событий, на котором Riverpod бросает «Ref …
  /// after it has been disposed».
  ///
  /// **Предел, названный замером: эта защита не работает по построению.**
  /// Почти каждая запись имеет вид `_state = state.copyWith(...)`, то есть
  /// **геттер `state` читается раньше**, чем сюда доходит управление, — и
  /// бросает именно он. Проб на это нет ни одной.
  ///
  /// Числа из круга правки 5 («25 записей из 26») были неверны и убраны:
  /// записей около тридцати пяти, `initialize` перестала быть исключением
  /// в том же коммите, а девять настоящих `if (_disposed) return` предел
  /// не упоминал вовсе — то есть он был преувеличен и в другую сторону.
  /// Считать их заново здесь незачем: важно не число, а форма.
  ///
  /// Оговорка «плюс одна строка стоит вне перехвата» снята — **строки
  /// больше нет**: резолв терминала и первая запись состояния уехали
  /// внутрь `try` вместе с починкой входа в оплату, и на это есть проба
  /// (`payment_card_reset_test.dart`, «закрытие до входа в кассу не
  /// выпускает исключение наружу»).
  ///
  /// Сегодня недостижимо: провайдер оплаты никем не сбрасывается и сам не
  /// самоуничтожается, так что закрытия при живом обмене не случается.
  /// Станет достижимым в тот день, когда это изменят, — и сломается
  /// сразу, потому что защита стоит **после** чтения, а не до него.
  /// Настоящая починка — не трогать `state` в вызывающих (передавать
  /// изменение функцией, а читать текущее значение уже за проверкой), и
  /// это переписывание всех двадцати шести мест, а не довесок к кругу
  /// правки.
  ///
  /// **Реквизиты карты устарели.** Круг правки 4 нашёл, что правка
  /// карточной суммы после **удачного** проведения списывала с покупателя
  /// второй раз: память кассы о проведении ключуется суммой, а экран
  /// реквизиты не сбрасывал. Механизм был и до задачи 14 (для чистой
  /// карты — через правку бонуса), но круг 3 распространил зов эквайринга
  /// на смешанную оплату и долг, где карточная часть — поле, которое
  /// кассир правит постоянно, а отказ по конфликту счетов сам по себе
  /// правдоподобный повод к правке.
  ///
  /// Сброс мог бы стоять в `setCardAmount`, в трёх методах клавиатуры и в
  /// потолке бонуса — пяти местах, из которых шестое забудут. Здесь он
  /// один и **выведен из данных**: реквизиты годны ровно для той суммы, на
  /// которую карта проведена ([PaymentState.terminalChargedAmount]).
  ///
  /// **Кассиру говорится словами.** Снятые реквизиты значат, что прежнее
  /// проведение осталось **непогашенным**: деньги с покупателя сняты, в
  /// чек они не попадут, и отменить их касса не умеет — операции отмены у
  /// платёжного терминала в дереве нет вовсе. Молчать значило бы оставить
  /// кассира в уверенности, что возвращать нечего.
  set _state(PaymentState next) {
    if (_disposed) return;
    final charged = next.terminalChargedAmount;
    if (charged != null && charged != next.cardPortion) {
      // Сторож стоит на пути, который зовётся и до того, как точка входа
      // назначила журнал (виджет-пробы, браузерная сборка до подъёма), —
      // отсюда проверка готовности. Тот же приём, что у `isLoggerReady`
      // в самом журнале.
      if (isLoggerReady) {
        talker.warning(
          'Payment: card charge $charged left unsettled — card part became '
          '${next.cardPortion}',
        );
      }
      state = next.copyWith(
        clearTerminalData: true,
        error: '$cardChargeUnsettledKey:$charged',
      );
      return;
    }
    state = next;
  }

  /// Тот же вход, что и [_state], в форме метода — для мест, где запись
  /// читается как действие, а не как присваивание.
  void _emit(PaymentState next) => _state = next;

  /// Новая попытка снимает прежний отказ — **до** вопроса кассе.
  ///
  /// Приёмка 2026-09-17: экран показывает отказ, когда ключ ошибки
  /// **сменился** (`payment_screen.dart`, `ref.listen`). Второй подряд
  /// неверный ПИН давал тот же ключ, состояние не менялось, и кассир,
  /// нажав «Проверить», не видел ничего — будто кнопка не сработала.
  /// Сброс перед попыткой делает каждый отказ переходом «нет → есть».
  void _forgetRefusal() {
    if (state.error != null) _emit(state.copyWith(clearError: true));
  }

  /// Забыть проведение карты.
  ///
  /// [settled] — проведение попало в чек, забывать его безопасно. Иначе
  /// деньги на устройстве **остались**, и кассир обязан узнать сумму.
  ///
  /// Круг правки 5: сторож, выведенный из данных ([_state]), до двух путей
  /// не доезжал — смена вида оплаты (**одно нажатие «Наличные»** после
  /// проведения) и повторный вход на экран стирали реквизиты вместе с
  /// суммой, и «погашено» становилось неотличимо от «непогашено».
  /// Устранимая причина названа разбором: **после успешного завершения
  /// реквизиты не снимались**. Теперь снимаются здесь же, и любое
  /// уцелевшее значение суммы на этих путях означает «непогашено».
  void _forgetCardCharge({required bool settled}) {
    final charged = state.terminalChargedAmount;
    if (charged == null) return;
    if (settled) {
      _state = state.copyWith(clearTerminalData: true);
      return;
    }
    if (isLoggerReady) {
      talker.warning('Payment: card charge $charged left unsettled — reset');
    }
    _state = state.copyWith(
      clearTerminalData: true,
      error: '$cardChargeUnsettledKey:$charged',
    );
  }

  /// Метка команды оплаты: чек и версия — из состояния экрана продажи,
  /// то есть из снимка, который прислала касса. Второго источника правды
  /// о номере чека у экрана нет и быть не должно.
  CartCommandMeta _meta() {
    final sale = ref.read(saleControllerProvider);
    // Ключ живёт **внутри одного чека**: сменился номер — сменился и
    // ключ. Круг правки 1 нашёл, чем это чревато у соседа: касса
    // ключевала память о проведённой карте одним ключом команды, и
    // переживший смену чека ключ отдавал следующему чеку чужое одобрение.
    // Там это починено составным ключом (`LocalPaymentService
    // ._cardCharges`); здесь — тем, что ключ не переживает чек вовсе.
    if (_keyReceiptNo != sale.receiptNo) {
      _completionKey = null;
      _keyReceiptNo = sale.receiptNo;
    }
    return CartCommandMeta(
      key: _completionKey ??= _newKey(),
      baseVersion: sale.version,
      receiptNo: sale.receiptNo,
    );
  }

  /// Ключ идемпотентности оплаты — общей функцией, а не третьей копией.
  ///
  /// **Здесь лежала третья копия того самого дефекта**, ради которого
  /// [newCommandSessionTag] и был заведён: `Random().nextInt(1 << 32)`. В
  /// Dart VM это 4294967296, **в браузере — ноль**: `<<` в JavaScript
  /// 32-битный. `Random.nextInt(0)` бросает `RangeError`, провайдер уходит
  /// в состояние ошибки целиком, и экран не строится вовсе — серый
  /// прямоугольник во всю страницу. Ровно так 2026-09-07 не открывался
  /// экран возврата.
  ///
  /// Копия жила при полностью зелёном наборе, и не по недосмотру сторожа:
  /// `web_safe_shifts_test.dart` и его двойник в `browser_routes_test.dart`
  /// ходят по замыканию импортов **браузерной сборки**, а экран оплаты в
  /// неё не входил — маршрут был заглушкой. Задача 17 внесла файл в
  /// замыкание, и сторож покраснел тем же прогоном, не дожидаясь браузера.
  ///
  /// Отсюда правило шире этой правки: перенос экрана в браузер
  /// заканчивается прогоном сторожей **замыкания**, а не только своих проб.
  /// Сторож, чьё множество задаётся переносимой работой, до неё зелен не
  /// потому, что дефекта нет.
  static String _newKey() => newCommandSessionTag();

  void initialize(Decimal amount) {
    // Повторный вход на экран стирал память о проведении молча. Состояние
    // здесь собирается с нуля, поэтому сообщение о непогашенном
    // проведении переносится в него руками — иначе оно потерялось бы тем
    // же способом, каким терялась сама память.
    _forgetCardCharge(settled: false);
    _state = PaymentState(
      totalAmount: amount,
      error: state.error,
      // Набор видов — свойство рабочего места, а не чека: он переживает
      // повторный вход на экран так же, как переживает его само рабочее
      // место. Собрать состояние с нуля и потерять его значило бы на
      // втором чеке снова показать кассиру всё, что кассе запрещено.
      allowedPaymentTypes: state.allowedPaymentTypes,
      // Тумблер кассы переживает повторный вход по той же причине, что и
      // набор видов: он свойство кассы, а не чека. Потеряв его здесь, мы
      // на втором чеке снова показали бы кассиру «касса ещё не
      // ответила» на месте живой кнопки.
      sellInDebt: state.sellInDebt,
      // **QR переживает повторный вход, если чек тот же.** Код, показанный
      // покупателю, и деньги, которые он уже заплатил телефоном, не
      // исчезают оттого, что кассир вернулся к товарам и снова открыл
      // оплату; забыть их здесь значило бы закрыть чек наличными поверх
      // оплаченного (деньги стали бы деньгами без чека) или показать
      // второй код при живом первом. Чек другой — прежний QR к нему не
      // относится.
      qr: _qrOfCurrentReceipt(),
    );
    if (state.qr == null) {
      _stopQrPolling();
      _qrAttemptKey = null;
    } else if (state.qr!.phase == QrTenderPhase.waiting) {
      _startQrPolling();
    }
    unawaited(_loadAllowedPaymentTypes());
    unawaited(_loadSellInDebt());
    unawaited(_loadQrReadiness());
  }

  /// Спросить кассу, можно ли показать код QR — при открытии экрана.
  ///
  /// Пункт 9 C (2026-09-15): панель узнавала «не настроено / вид выключен»
  /// только на первом «Показать QR», и кассир набирал сумму ради отказа.
  /// Ответ кладётся в [PaymentState.qrRefusal] **тем же ключом**, что положил
  /// бы отказ `startQr`, — панель гаснет тем же путём, каким гасла на
  /// нажатии (`_blockingRefusals` в `qr_panel.dart`).
  ///
  /// Живой код или оплаченные деньги этого чека ответ не трогает: касса,
  /// у которой настройку сняли посреди ожидания, не имеет права спрятать
  /// код, по которому покупатель, может быть, уже платит.
  ///
  /// Неудача вопроса — молча: запрет держит `startQr`, и кассир узнает
  /// причину на нажатии, как до этой правки.
  Future<void> _loadQrReadiness() async {
    try {
      final code = await _payments.qrUnavailableReason();
      if (_disposed || code == null || state.qr != null) return;
      _emit(state.copyWith(qrRefusal: 'error.$code'));
    } catch (e) {
      talker.warning('Payment: QR readiness unavailable: ${safeErrorText(e)}');
    }
  }

  /// Спросить кассу, торгует ли она в долг — задача 16.
  ///
  /// Первое чтение `ThisPosEntries.sellInDebt` со стороны экрана. Ответ
  /// не ожидается вызывающим: экран оплаты обязан открыться и без него,
  /// а до ответа кнопка «В долг» стоит погашенной и говорит **почему**
  /// («касса ещё не ответила»), а не молчит.
  ///
  /// # Почему неудача не читается как «торгуют»
  ///
  /// Обратное умолчанию соседа, и это не разнобой: набор видов
  /// **сужает** разрешённое, поэтому его неудача читается «все» — экран
  /// не имеет права запретить больше кассы. Тумблер **добавляет** вид,
  /// которого по умолчанию нет, и его неудача, прочитанная как
  /// «торгуют», предложила бы кассиру вид оплаты, которого владелец
  /// точки не включал. Оставляем `null` — «не знаем», со своими словами.
  Future<void> _loadSellInDebt() async {
    try {
      final sells = await _payments.sellsInDebt();
      if (_disposed) return;
      _state = state.copyWith(sellInDebt: sells);
    } catch (e) {
      talker.warning('Payment: debt policy unavailable: $e');
    }
  }

  /// Спросить кассу, что разрешено этому рабочему месту — задача 15.
  ///
  /// # Почему в `initialize`, а не в провайдере рядом со счетами
  ///
  /// Рабочее место здесь **то же самое**, которым идут корзина и оплата:
  /// `SaleNotifier.currentTerminalId()` заведён ровно затем, чтобы соседние
  /// контроллеры не резолвили его вторым, своим способом (докстринг там
  /// же). Отдельный провайдер завёл бы второй способ — и разошёлся бы
  /// молча, показав кассиру набор чужого рабочего места.
  ///
  /// # Почему ошибка читается как «все виды»
  ///
  /// Разбор — у [PaymentState.allowedPaymentTypes]. Коротко: запрет держит
  /// касса, и экран, промолчавший из-за сети, не имеет права запретить
  /// больше неё.
  ///
  /// Ответ не ожидается вызывающим: экран оплаты обязан открыться и без
  /// него. Кнопки гаснут в тот момент, когда набор доехал, — и до этого
  /// момента ведут себя ровно так, как вели до задачи 15.
  Future<void> _loadAllowedPaymentTypes() async {
    try {
      final terminalId = await ref
          .read(saleControllerProvider.notifier)
          .currentTerminalId();
      if (terminalId == null || _disposed) return;
      final terminals = await GetIt.I<TerminalRepository>().list();
      if (_disposed) return;
      for (final terminal in terminals) {
        if (terminal.id != terminalId) continue;
        _state = state.copyWith(
          allowedPaymentTypes: terminal.allowedPaymentTypes,
        );
        return;
      }
      talker.warning(
        'Payment: terminal $terminalId is not in the list — '
        'payment types shown unrestricted',
      );
    } catch (e) {
      talker.warning('Payment: allowed payment types unavailable: $e');
    }
  }

  /// Сменить вид оплаты.
  ///
  /// **Предел, названный честно (круг правки 4): подбор счёта не
  /// ожидается.** Метод возвращается сразу, а `_autoSelectAccount` идёт
  /// своим чередом — то есть между сменой вида оплаты и появлением счёта
  /// есть окно, в которое кассир успевает нажать «оплатить». Круг правки
  /// 3 не убрал гонку, а сделал её исход **названным отказом** вместо
  /// сырого исключения из базы. Убрать её целиком значит сделать смену
  /// вида оплаты ожидаемой на экране — то есть завести кассиру ожидание
  /// там, где его сегодня нет.
  void setPaymentType(PaymentType type) {
    // Смена вида оплаты стирала реквизиты вместе с суммой проведения —
    // одного нажатия «Наличные» после проведения хватало, чтобы деньги на
    // устройстве потерялись молча.
    _forgetCardCharge(settled: false);
    final unsettled = state.error;
    _state = state.copyWith(
      paymentType: type,
      cashReceived: Decimal.zero,
      cardAmount: Decimal.zero,
      clearError: unsettled == null,
      error: unsettled,
      activeInput: PaymentInputField.cash,
      cashInputText: '',
      cardInputText: '',
      clearTerminalData: true,
      clearInstallment: true,
    );

    _autoSelectAccount(cash: type == PaymentType.cash);
  }

  /// Кассир выбрал срок и схему рассрочки — задача 24.
  ///
  /// Вид оплаты ставится **тем же движением**: срок без вида ничего не
  /// значит, а вид без срока касса отвергает названным отказом
  /// (`credit_term_invalid`). Два раздельных вызова дали бы состояние, в
  /// котором одно уже выбрано, а другое ещё нет, — и кассир успел бы
  /// нажать «Оплатить» между ними.
  ///
  /// Порядок внутри обязателен: [setPaymentType] стирает срок
  /// (`clearInstallment`), поэтому он идёт **первым**, а срок пишется
  /// после него. Наоборот — и метод стёр бы то, что сам же и положил.
  void setInstallmentTerms({
    required int termMonths,
    required InstallmentScheme scheme,
  }) {
    setPaymentType(PaymentType.installment);
    _state = state.copyWith(
      installmentTermMonths: termMonths,
      installmentScheme: scheme,
    );
  }

  /// Счёт по умолчанию под выбранный вид оплаты.
  ///
  /// Раньше это были два почти одинаковых метода, каждый со своим
  /// обращением к базе. Теперь список счетов приходит одним ответом кассы,
  /// и умолчание видно в нём самом: [PaymentAccount.isDefault] помечает
  /// счета кассы.
  ///
  /// **Не нашли — сбрасываем, а не оставляем прежний** (круг правки 3).
  /// До этого на кассе без видимых банковских счетов автоподбор ничего не
  /// находил и **молча оставлял** счёт, выбранный нажатием «Наличные», —
  /// то есть счёт кассы уезжал в теле смешанной оплаты, а там наличная
  /// часть уже занимала его собой, и две строки платежей сталкивались в
  /// базе по уникальному ключу. Пустой выбор честнее: касса подберёт
  /// счёт сама тем же аварийным путём, каким заводит счета на криво
  /// настроенной установке.
  Future<void> _autoSelectAccount({required bool cash}) async {
    try {
      final accounts = await _payments.accounts();
      if (_disposed) return;
      final wanted = accounts.where((a) => a.isDefault == cash);
      _emit(
        wanted.isEmpty
            ? state.copyWith(clearSelectedAccountId: true)
            : state.copyWith(selectedAccountId: wanted.first.id),
      );
    } catch (e) {
      // Умолчание — удобство, а не условие оплаты: кассир выберет счёт
      // сам. Так было и до провода.
      talker.warning('Payment: default account unresolved: $e');
      if (_disposed) return;
      _emit(state.copyWith(clearSelectedAccountId: true));
    }
  }

  void setCashReceived(Decimal amount) {
    final text = amount > Decimal.zero ? amount.toString() : '';
    _state = state.copyWith(
      cashReceived: amount,
      cashInputText: text,
      clearError: true,
    );
  }

  void addCash(Decimal amount) {
    final newAmount = state.cashReceived + amount;
    _state = state.copyWith(
      cashReceived: newAmount,
      cashInputText: newAmount.toString(),
      clearError: true,
    );
  }

  void setExactAmount() {
    _state = state.copyWith(
      cashReceived: state.amountToPay,
      cashInputText: state.amountToPay.toString(),
      clearError: true,
    );
  }

  void clearCashReceived() {
    _state = state.copyWith(cashReceived: Decimal.zero, cashInputText: '');
  }

  void setCardAmount(Decimal amount) {
    final text = amount > Decimal.zero ? amount.toString() : '';
    _state = state.copyWith(
      cardAmount: amount,
      cardInputText: text,
      clearError: true,
    );
  }

  void setActiveInput(PaymentInputField field) {
    _state = state.copyWith(activeInput: field);
  }

  void numpadKey(String key) {
    if (state.activeInput == PaymentInputField.cash) {
      final newText = state.cashInputText + key;
      final amount = Decimal.tryParse(newText) ?? Decimal.zero;
      _state = state.copyWith(
        cashInputText: newText,
        cashReceived: amount,
        clearError: true,
      );
    } else {
      final newText = state.cardInputText + key;
      final amount = Decimal.tryParse(newText) ?? Decimal.zero;
      _state = state.copyWith(
        cardInputText: newText,
        cardAmount: amount,
        clearError: true,
      );
    }
  }

  void numpadBackspace() {
    if (state.activeInput == PaymentInputField.cash) {
      if (state.cashInputText.isEmpty) return;
      final newText = state.cashInputText.substring(
        0,
        state.cashInputText.length - 1,
      );
      final amount = newText.isEmpty
          ? Decimal.zero
          : (Decimal.tryParse(newText) ?? Decimal.zero);
      _state = state.copyWith(cashInputText: newText, cashReceived: amount);
    } else {
      if (state.cardInputText.isEmpty) return;
      final newText = state.cardInputText.substring(
        0,
        state.cardInputText.length - 1,
      );
      final amount = newText.isEmpty
          ? Decimal.zero
          : (Decimal.tryParse(newText) ?? Decimal.zero);
      _state = state.copyWith(cardInputText: newText, cardAmount: amount);
    }
  }

  void numpadClear() {
    if (state.activeInput == PaymentInputField.cash) {
      _state = state.copyWith(cashReceived: Decimal.zero, cashInputText: '');
    } else {
      _state = state.copyWith(cardAmount: Decimal.zero, cardInputText: '');
    }
  }

  void selectAccount(int accountId) {
    _state = state.copyWith(selectedAccountId: accountId);
  }

  Future<void> searchLoyaltyCustomer(String phone) async {
    // Отсев коротких номеров — на экране: кассир набирает номер по цифре,
    // и круг по проводу за каждую цифру был бы расходом без пользы.
    if (phone.length < 10) {
      _state = state.copyWith(
        clearLoyaltyCustomer: true,
        clearPrepayment: true,
      );
      return;
    }

    try {
      final found = await _payments.findLoyalty(phone);
      if (_disposed) return;
      if (found == null) {
        _emit(
          state.copyWith(clearLoyaltyCustomer: true, clearPrepayment: true),
        );
        return;
      }
      // Тот же покупатель, найденный повторно (кассир дописал цифру), —
      // не повод забывать остаток и набранный зачёт.
      final sameCustomer = state.loyaltyCustomer?.id == found.id;
      _emit(
        state.copyWith(loyaltyCustomer: found, clearPrepayment: !sameCustomer),
      );
      if (!sameCustomer) await _loadPrepayment(found.id);
    } catch (e) {
      talker.warning('Payment: loyalty lookup failed: $e');
      if (_disposed) return;
      _emit(state.copyWith(clearLoyaltyCustomer: true, clearPrepayment: true));
    }
  }

  void clearLoyaltyCustomer() {
    _state = state.copyWith(
      clearLoyaltyCustomer: true,
      bonusToUse: Decimal.zero,
      clearPrepayment: true,
    );
  }

  /// Спросить кассу, сколько аванса внёс покупатель [customerId].
  ///
  /// Зовётся **сразу, как покупатель найден** — кассир видит остаток до
  /// того, как решит, сколько зачесть, а не после отказа. Отказ кассы
  /// (вид выключен, у покупателя нет расчётного счёта) не глотается: он
  /// ложится в [PaymentState.prepaymentRefusal], и панель аванса гаснет,
  /// называя причину.
  ///
  /// Ответ, опоздавший к другому покупателю, отбрасывается: остаток одного
  /// человека не должен лечь под имя другого.
  Future<void> _loadPrepayment(int customerId) async {
    try {
      final balance = await _payments.prepaymentBalance(customerId);
      if (_disposed || state.loyaltyCustomer?.id != customerId) return;
      _emit(state.copyWith(prepaymentBalance: balance));
    } catch (e) {
      talker.warning('Payment: prepayment balance unavailable: $e');
      if (_disposed || state.loyaltyCustomer?.id != customerId) return;
      _emit(state.copyWith(prepaymentRefusal: _errorKeyOf(e)));
    }
  }

  /// Сколько аванса кассир просит зачесть.
  ///
  /// **Потолка здесь нет, и это не забывчивость.** Сколько зачтётся,
  /// считает цепочка зачётов ([PaymentState.offsets]) — та же функция, что
  /// у кассы; экран хранит просьбу, а показывает результат цепочки.
  void setPrepaymentToUse(Decimal amount) {
    _state = state.copyWith(
      prepaymentToUse: amount > Decimal.zero ? amount : Decimal.zero,
    );
  }

  /// Зачесть весь внесённый аванс — сколько поместится в чек, решит цепочка.
  void useAllPrepayment() =>
      setPrepaymentToUse(state.prepaymentBalance ?? Decimal.zero);

  /// Предъявить сертификат [number] — касса проверяет бумажку и называет
  /// остаток **до** гашения.
  ///
  /// Возвращает `true`, если бумажка принята к этому чеку. Отказ кассы
  /// (нет такого, не тот ПИН, срок вышел, вид выключен) ложится в
  /// [PaymentState.error] ключом и показывается словами.
  ///
  /// Повтор той же бумажки отбивается здесь же, без круга к кассе: касса
  /// отвергла бы его при оплате (`certificate_duplicate`), но кассир узнал
  /// бы об этом последним нажатием.
  Future<bool> presentCertificate(String number, {String? pin}) async {
    final trimmed = number.trim();
    if (trimmed.isEmpty) return false;
    _forgetRefusal();
    if (state.certificates.any((c) => c.number == trimmed)) {
      _state = state.copyWith(error: 'error.$certificateDuplicateCode');
      return false;
    }
    final typedPin = (pin == null || pin.isEmpty) ? null : pin;
    try {
      final found = await _payments.findCertificate(trimmed, pin: typedPin);
      if (_disposed) return false;
      if (state.certificates.any((c) => c.number == trimmed)) {
        _emit(state.copyWith(error: 'error.$certificateDuplicateCode'));
        return false;
      }
      _emit(
        state.copyWith(
          certificates: [
            ...state.certificates,
            PresentedCertificate(
              number: trimmed,
              pin: typedPin,
              balance: found.balance,
              expiresAt: found.expiresAt,
            ),
          ],
          clearError: true,
        ),
      );
      return true;
    } catch (e) {
      // Номер — в журнал, ПИН — никогда (докстринг `CertificateTender.pin`).
      talker.warning('Payment: certificate $trimmed refused: $e');
      if (_disposed) return false;
      _emit(state.copyWith(error: _errorKeyOf(e)));
      return false;
    }
  }

  /// Снять бумажку с этого чека. Касса её не касалась — снимать нечего,
  /// кроме строки на экране.
  void removeCertificate(String number) {
    _state = state.copyWith(
      certificates: [
        for (final c in state.certificates)
          if (c.number != number) c,
      ],
    );
  }

  /// Сколько бонуса засчитать.
  ///
  /// Потолок ставит **касса** ([PaymentService.reserveBonus]): остаток
  /// бонусного счёта — её правда, а не экрана. Второй потолок, сумма
  /// чека, накладывается здесь же и повторно на кассе при завершении
  /// оплаты — из двух мест он не расходится, потому что оба берут одно и
  /// то же число, а решает всё равно последнее (докстринг контракта).
  Future<void> setBonusToUse(Decimal amount) async {
    _forgetRefusal();
    final customer = state.loyaltyCustomer;
    if (customer == null || amount <= Decimal.zero) {
      _state = state.copyWith(bonusToUse: Decimal.zero);
      return;
    }

    try {
      var allowed = await _payments.reserveBonus(customer.id, amount);
      if (_disposed) return;
      if (allowed > state.totalAmount) allowed = state.totalAmount;
      _emit(state.copyWith(bonusToUse: allowed));
    } catch (e) {
      talker.warning('Payment: bonus refused: $e');
      if (_disposed) return;
      _emit(state.copyWith(bonusToUse: Decimal.zero, error: _errorKeyOf(e)));
    }
  }

  Future<void> useAllBonus() => setBonusToUse(state.availableBonus);

  void setIin(String? iin) {
    if (iin == null || iin.isEmpty) {
      _state = state.copyWith(clearIin: true);
    } else {
      _state = state.copyWith(iin: iin);
    }
  }

  /// Провести карту через эквайринг **этого** рабочего места.
  ///
  /// Разговор с устройством уехал за контракт целиком: привязка,
  /// перевод суммы в тиыны, сам обмен и потолок «не больше стоимости
  /// чека». Здесь остался только перенос кода подтверждения в состояние
  /// экрана — он потом уедет в чек как реквизит платежа.
  ///
  /// **Названное изменение:** до этой задачи привязка бралась у терминала
  /// **самой кассы** (`TerminalRepository.self()`), а не у того рабочего
  /// места, которое нажало кнопку. На десктопе это одно и то же; у
  /// браузерного терминала — разные вещи, и он получал бы чужой
  /// эквайринг.
  Future<CardCharge> chargeCardViaTerminal(Decimal amount) async {
    final terminalId = await ref
        .read(saleControllerProvider.notifier)
        .currentTerminalId();
    if (terminalId == null) {
      talker.warning('Payment: terminal unknown — manual card path');
      return const CardCharge(outcome: CardChargeOutcome.notConfigured);
    }

    try {
      final charge = await _payments.chargeCard(terminalId, amount, _meta());
      if (_disposed) {
        // Экран закрыт, а карта **проведена**: деньги двинулись, и
        // молчаливое «отказано» здесь было бы худшим из возможного.
        // Круг правки 4: прежде запись состояния бросала, свой же
        // перехват её глотал и возвращал отказ на одобренную банком
        // карту.
        talker.warning(
          'Payment: card charge ${charge.outcome.name} arrived after the '
          'screen was closed — approval=${charge.approvalCode}',
        );
        return charge;
      }
      if (charge.isApproved) {
        _state = state.copyWith(
          terminalApprovalCode: charge.approvalCode,
          terminalCardMask: charge.cardMask,
          terminalTransactionId: charge.transactionId,
          terminalChargedAmount: amount,
        );
      }
      return charge;
    } catch (e, stack) {
      // Отказ кассы (нет чека, сумма больше чека) для экрана — то же
      // самое, что отказ банка: карту не провели. Текст берётся
      // безопасным (`safeErrorText`) — в снекбар не должно уехать нутро
      // чужого исключения.
      talker.error('Payment: card charge failed: $e', e, stack);
      // **Ключом, а не текстом исключения.** Сообщение уходит в полосу
      // экрана, и там оно проходит через `ErrorLocalizer` — тем же путём,
      // что `PaymentState.error`. Прежнее `safeErrorText(e)` отдавало
      // экрану строку, которую словарь не узнаёт, и кассир читал код
      // отказа буквально.
      return CardCharge(
        outcome: CardChargeOutcome.declined,
        message: _errorKeyOf(e),
      );
    }
  }

  // ── оплата по QR ───────────────────────────────────────────────────────
  //
  // # Кто ждёт и кто сдаётся
  //
  // **Спрашивает экран, сдаётся касса.** Экран опрашивает кассу раз в
  // [qrPollEvery], пока фаза `waiting`, и перестаёт на любой другой фазе,
  // на отмене и на закрытии контейнера. Срок терпения экран не знает и не
  // считает: это настройка кассы, и круг, пришедший после срока, касса
  // закрывает сама — отменой у провайдера (`patienceSpent`). Экран лишь
  // показывает секунды, которые назвала касса.
  //
  // # Три опасных места, и что с ними сделано
  //
  // * **Закрыть чек при живом коде** — нельзя: [PaymentState.amountCovered]
  //   ложно, пока фаза `waiting` или `cancelUnconfirmed`.
  // * **Отмена разошлась с оплатой** — ответ отмены читается: «уже
  //   оплачено» даёт `paidAfterGiveUp`, и деньги идут в этот чек цепочкой.
  // * **Ответ опроса опоздал к отмене** — опрос в полёте во время отмены
  //   не имеет права вернуть экран в «ждём»: его ответ отбрасывается, если
  //   фаза уже не `waiting` (см. [pollQr]).

  /// Как часто экран спрашивает кассу, пока покупатель платит.
  static const qrPollEvery = Duration(seconds: 2);

  /// Ключ **попытки** показать код — не чека.
  ///
  /// Мнётся на первое нажатие «Показать QR» и **переживает неудачу**:
  /// вкладка, не дождавшаяся ответа, повторяет тем же ключом и получает
  /// прежнее намерение, а не второй код, по которому покупатель мог бы
  /// заплатить ещё раз. Сбрасывается, когда попытка кончилась — отменой,
  /// отказом провайдера или оплатой.
  String? _qrAttemptKey;
  Timer? _qrTimer;
  bool _qrAsking = false;

  /// Рабочее место, показавшее код. Намерение принадлежит ему, и
  /// спрашивать о нём надо тем же именем (на проводе — из сеанса).
  int? _qrTerminalId;

  QrTender? _qrOfCurrentReceipt() {
    final current = state.qr;
    if (current == null) return null;
    final receiptNo = ref.read(saleControllerProvider).receiptNo;
    return current.receiptNo == null || current.receiptNo == receiptNo
        ? current
        : null;
  }

  /// Показать покупателю код на [amount].
  Future<void> startQr(Decimal amount) async {
    final current = state.qr;
    if (state.qrBusy) return;
    // Живой код или оплаченные деньги — второй код не показывается: первый
    // ещё может быть оплачен, а вторые деньги не поместятся в чек.
    if (current != null && (current.phase.blocksCompletion || current.usable)) {
      return;
    }
    try {
      final terminalId = await ref
          .read(saleControllerProvider.notifier)
          .currentTerminalId();
      if (_disposed) return;
      if (terminalId == null) {
        _emit(state.copyWith(qrRefusal: 'error.till_not_configured'));
        return;
      }
      _qrTerminalId = terminalId;
      final sale = ref.read(saleControllerProvider);
      final key = _qrAttemptKey ??= _newKey();
      _emit(state.copyWith(qrBusy: true, clearQr: true, clearQrRefusal: true));
      final tender = await _payments.startQr(
        terminalId,
        amount,
        CartCommandMeta(
          key: key,
          baseVersion: sale.version,
          receiptNo: sale.receiptNo,
        ),
      );
      if (_disposed) return;
      _applyQr(tender);
    } catch (e) {
      talker.warning('Payment: QR start refused: ${safeErrorText(e)}');
      if (_disposed) return;
      // Ключ попытки **не сбрасывается**: ответ мог не дойти при уже
      // заведённом намерении, и повтор тем же ключом его найдёт.
      _emit(state.copyWith(qrBusy: false, qrRefusal: _errorKeyOf(e)));
    }
  }

  /// Один вопрос кассе о живом коде.
  ///
  /// [manual] — кассир нажал «Проверить снова» при неподтверждённой
  /// отмене; иначе ответ принимается только пока экран ещё ждёт.
  Future<void> pollQr({bool manual = false}) async {
    final tender = state.qr;
    final terminalId = _qrTerminalId;
    if (_disposed || _qrAsking || tender == null || terminalId == null) {
      return;
    }
    _qrAsking = true;
    try {
      final next = await _payments.pollQr(terminalId, tender.intentKey);
      if (_disposed) return;
      final now = state.qr;
      // Ответ опоздал: попытка сменилась, отмена в полёте или ожидание уже
      // кончено другим ответом. Вернуть экран в «ждём» он права не имеет.
      if (now == null || now.intentKey != next.intentKey) return;
      if (state.qrBusy) return;
      if (!manual && now.phase != QrTenderPhase.waiting) return;
      _applyQr(next);
    } catch (e) {
      talker.warning('Payment: QR poll failed: ${safeErrorText(e)}');
      if (_disposed) return;
      // Касса не ответила — **ожидание не кончено**: деньги могли уйти.
      // Кассир видит причину, опрос продолжается.
      _emit(state.copyWith(qrRefusal: _errorKeyOf(e)));
    } finally {
      _qrAsking = false;
    }
  }

  /// Кассир прервал ожидание. Ответ провайдера на отмену читается.
  Future<void> cancelQr() async {
    final tender = state.qr;
    final terminalId = _qrTerminalId;
    if (tender == null || terminalId == null || state.qrBusy) return;
    _stopQrPolling();
    _emit(state.copyWith(qrBusy: true));
    try {
      final next = await _payments.cancelQr(terminalId, tender.intentKey);
      if (_disposed) return;
      _applyQr(next);
    } catch (e) {
      talker.warning('Payment: QR cancel failed: ${safeErrorText(e)}');
      if (_disposed) return;
      _emit(state.copyWith(qrBusy: false, qrRefusal: _errorKeyOf(e)));
      // Отмена не дошла до кассы — касса по-прежнему ждёт, и экран тоже.
      if (state.qr?.phase == QrTenderPhase.waiting) _startQrPolling();
    }
  }

  /// Убрать с панели кончившуюся попытку без денег — чтобы показать новый
  /// код. Живой код и оплаченные деньги так не убираются.
  void dismissQr() {
    final tender = state.qr;
    if (tender == null) return;
    if (tender.phase.blocksCompletion || tender.usable) return;
    _stopQrPolling();
    _qrAttemptKey = null;
    _emit(state.copyWith(clearQr: true, clearQrRefusal: true));
  }

  void _applyQr(QrTender tender) {
    _emit(
      state.copyWith(
        qr: tender,
        qrBusy: false,
        // Отказ провайдера на живом коде (`qr_network`) едет в самом
        // ответе, а не в [PaymentState.qrRefusal]: тот — про вопрос к
        // кассе, и прошлый отказ провода ответ кассы снимает.
        clearQrRefusal: true,
      ),
    );
    if (tender.phase == QrTenderPhase.waiting) {
      _startQrPolling();
    } else {
      _stopQrPolling();
    }
    if (!tender.phase.blocksCompletion) _qrAttemptKey = null;
  }

  void _startQrPolling() {
    _qrTimer ??= Timer.periodic(qrPollEvery, (_) => unawaited(pollQr()));
  }

  void _stopQrPolling() {
    _qrTimer?.cancel();
    _qrTimer = null;
  }

  void setProcessing(bool value) =>
      _state = state.copyWith(isProcessing: value);

  /// Исход последнего [processPayment] — задача 16, круг правки 1.
  ///
  /// В [PaymentState] не кладётся нарочно: состояние экрана
  /// перестраивается и переживает уход с экрана хуже, а этот исход нужен
  /// ровно один раз и ровно тому, кто только что нажал «Оплатить», —
  /// чтобы сказать ему про нефискальный чек и про непринятую печать.
  SaleOutcome? get lastOutcome => _lastOutcome;
  SaleOutcome? _lastOutcome;

  /// Рабочее место, которое оплатило [_lastOutcome]. Беда чека отдаётся
  /// его владельцу, а не любому, кто назовёт номер (докстринг
  /// [PaymentService.hardwareTroubles]), — значит спрашивать надо тем же
  /// именем, каким оплачивали.
  int? _lastTerminalId;

  /// Беды железа чека [receiptNo] — печать и ящик исполняет касса, и их
  /// исход приходит **после** ответа об успехе оплаты (докстринг
  /// [PaymentService.hardwareTroubles]). Спрашивать до успеха нельзя:
  /// это вернуло бы ожидание железа под другим именем.
  Future<List<CompletionTrouble>> hardwareTroubles(int receiptNo) async {
    final terminalId = _lastTerminalId;
    if (terminalId == null) return const [];
    return _payments.hardwareTroubles(terminalId, receiptNo);
  }

  /// Провести оплату.
  ///
  /// Весь расчёт денег — у кассы: она сводит чек, ставит потолок бонусу,
  /// выбирает счета и **считает сдачу**. Экран отправляет заявку и
  /// показывает то, что вернулось.
  ///
  /// Возвращает `true`, если деньги приняты, — включая случай повтора
  /// ([SaleOutcome.repeat]): чек оплачен один раз, и для кассира это
  /// успех, а не «нажмите ещё раз».
  Future<bool> processPayment() async {
    // Печатается **то, на чём принято решение**, а не соседний предикат.
    // До этой правки строка несла `canComplete`, и после разведения
    // условий она печатала `false` на **каждой здоровой** продаже: экран
    // ставит признак обработки раньше зова. А ведь именно по этой строке
    // дефект и опознали — следующий либо погнался бы за призраком, либо
    // отмахнулся от настоящего `canComplete=false`, «оно всегда так».
    talker.info(
      'Payment: processPayment called, amountCovered=${state.amountCovered}, '
      'canComplete=${state.canComplete}, type=${state.paymentType}, '
      'amount=${state.amountToPay}, cash=${state.cashReceived}',
    );
    // **Не `canComplete`**: тот геттер несёт ещё и «оплата уже идёт» —
    // признак, который выставляет сам экран **перед** зовом этой
    // операции. Спрашивать его здесь значит отбивать собственное первое
    // нажатие (см. докстринг `PaymentState.canComplete`).
    if (!state.amountCovered) return false;
    // Повторный вход всё же отбивается — но своим признаком, который
    // никто снаружи не выставляет.
    if (_completing) {
      talker.warning(
        'Payment: complete already in flight — second call '
        'ignored',
      );
      return false;
    }
    _completing = true;

    try {
      final terminalId = await ref
          .read(saleControllerProvider.notifier)
          .currentTerminalId();
      if (terminalId == null) {
        _state = state.copyWith(error: 'error.till_not_configured');
        return false;
      }

      _state = state.copyWith(isProcessing: true, clearError: true);

      final outcome = await _payments.complete(
        terminalId,
        PaymentRequest(
          type: state.paymentType,
          cashReceived: state.cashReceived,
          cardAmount: state.cardAmount,
          bonusUsed: state.bonusToUse,
          // Зачёт аванса — **то, что кассир видел** в предпросмотре
          // цепочки, а не сырая просьба: касса урежет по своему остатку
          // ещё раз и спишет условной записью (`AccountDao.claimCredit`).
          // Покупатель — тот же `customerId` ниже.
          prepaymentUsed: state.offsets.prepayment,
          // Бумажки — номером и ПИНом, в порядке предъявления. Сколько
          // спишется с каждой, касса считает сама той же цепочкой.
          certificates: [for (final c in state.certificates) c.tender],
          // Ключ оплаченного намерения — **ключ, а не сумма**: сколько
          // денег в намерении, касса читает у себя. Код в ожидании сюда
          // не попадает — до кассы его не пустит `amountCovered`, а
          // пропусти — касса ответит `qr_intent_not_paid`.
          qrIntentKey: (state.qr?.usable ?? false) ? state.qr!.intentKey : null,
          // Предпросмотр экрана, а не деньги: касса считает свою сдачу и
          // берёт это число **только для сверки** (докстринг
          // `PaymentRequest.claimedChange`).
          claimedChange: state.change,
          accountId: state.selectedAccountId,
          customerId: state.loyaltyCustomer?.id,
          customerBin: state.iin,
          approvalCode: state.terminalApprovalCode,
          cardMask: state.terminalCardMask,
          transactionId: state.terminalTransactionId,
          // Срок и схема рассрочки. Ни одного денежного поля: тело
          // договора считает касса как остаток чека, а надбавки у
          // договора, заключённого кассой, нет вовсе (докстринг
          // `PaymentRequest`, раздел «Чего здесь НЕТ»).
          installmentTermMonths: state.installmentTermMonths,
          installmentScheme: state.installmentScheme?.code,
        ),
        _meta(),
      );

      _lastOutcome = outcome;
      _lastTerminalId = terminalId;

      talker.info(
        'Payment: done receipt=${outcome.receiptNo} amount=${outcome.amount} '
        'change=${outcome.change} repeat=${outcome.repeat} '
        'fiscal=${outcome.fiscal.state.name}',
      );

      // Ключ отработал: следующая продажа начинает свою попытку заново.
      _completionKey = null;

      if (_disposed) {
        // Деньги взяты, чек проведён — экрана уже нет. Обновлять ему
        // нечего, но исход обязан быть успехом: вызывающий не должен
        // узнать «не получилось» о том, что получилось (круг правки 4).
        //
        // **Память о проведении здесь не гасится, и это ответ, а не
        // пропуск.** Гасить её значит читать `state`, а он после закрытия
        // бросает — ровно так круг правки 5 и сломал эту ветвь, поставив
        // `_forgetCardCharge` строкой выше: бросок ловил собственный
        // `catch`, и вызывающий получал `false` о взятых деньгах.
        //
        // Гасить нечего по существу: память о проведении живёт **в
        // состоянии этого экрана**, а его больше нет — вместе с ним ушла
        // и сумма проведения. Некому показать сообщение и некому его
        // потерять. Единственный, кто помнит проведение после этого, —
        // касса (`LocalPaymentService._cardCharges`), и она снимает свою
        // запись сама, когда чек оплачен (`_forgetCharges`).
        talker.warning(
          'Payment: receipt ${outcome.receiptNo} completed after the screen '
          'was closed',
        );
        return true;
      }

      // Проведение **погашено** — оно в чеке. Без этой строки «погашено» и
      // «непогашено» были неразличимы, и сторож выше ругался бы на
      // честно проведённую карту (круг правки 5). Стоит **после** ветви
      // закрытого экрана: она читает `state`, и до неё дело доходит
      // только тогда, когда читать есть что.
      _forgetCardCharge(settled: true);

      // Экраны, которые деньги только что сдвинули. Раньше это делал
      // `SaleNotifier.completeSale`; теперь завершение живёт за
      // контрактом, а обновление экранов — там, где эти экраны и живут.
      //
      // **Через шов, а не четырьмя импортами (задача 17).** Смена, история,
      // каталог и остатки импортируют базу кассы напрямую, и до этой задачи
      // экран оплаты тянул её отсюда одним прыжком — той же дорогой, какой
      // её тянул экран продажи до задачи 13. Шов у этого уже был
      // (`sale_side_effects.dart`), с готовой обеими половинами; здесь он
      // просто наконец позван вторым читателем. На браузерном терминале
      // этих четырёх экранов нет вовсе, и web-половина пуста по существу,
      // а не «пока».
      refreshAfterSaleCompleted(ref);

      // Деньги QR легли в этот чек — панели больше нечего показывать, а
      // следующий чек начинается без чужого намерения.
      _stopQrPolling();
      _qrAttemptKey = null;
      _state = state.copyWith(isProcessing: false, clearQr: true);
      return true;
    } catch (e, stack) {
      // Перехват **не имеет права бросить сам**: круг правки 4 нашёл, что
      // обновление соседних экранов после закрытия контейнера бросало,
      // перехват его ловил, а его собственная запись бросала снова — и
      // исключение уходило наружу оттуда, где деньги уже двинулись.
      talker.error('Payment: processPayment error: $e', e, stack);
      if (_disposed) return false;
      _state = state.copyWith(isProcessing: false, error: _errorKeyOf(e));
      return false;
    } finally {
      // Снимается на **каждом** выходе, включая отказы и броски: иначе
      // одна неудача запирала бы кассу до пересоздания экрана.
      _completing = false;
    }
  }

  /// Отказ кассы — ключом для экрана, а не текстом исключения.
  ///
  /// **Предел, названный замером (круг правки 4): ключи нигде не
  /// переводятся.** `error.payment_account_conflict`,
  /// `error.card_charge_unsettled`, `error.shift_over_age` и прочие
  /// доезжают до кассира **буквальной строкой** — словаря `AppLocalizations`
  /// под них нет, и экран показывает то, что пришло. Ключ вместо текста
  /// заведён затем, чтобы перевод стал возможен; сам перевод — работа
  /// экранов оплаты и продажи, и делать её посреди круга правки значило бы
  /// трогать то, что круг не чинил.
  ///
  /// `WireRefusal` несёт код, который придумал обработчик, и он
  /// безопасен по построению (докстринг `WireRefusal`); всё остальное
  /// проходит через `safeErrorText`, чтобы в интерфейс не уехало нутро
  /// чужой библиотеки.
  static String _errorKeyOf(Object error) => error is WireRefusal
      ? 'error.${error.code}'
      : 'error.save_failed:${safeErrorText(error)}';
}

/// Ключ сообщения о непогашенном проведении карты — единственный из всех
/// ключей отказа, который **переведён** (круг правки 5).
///
/// Он означает «с покупателя сняты деньги, и вернуть их касса не умеет»;
/// остальные ключи доезжают до кассира буквальной строкой — это общий
/// предел задачи, названный у [PaymentNotifier._errorKeyOf]. Сумма едет
/// после двоеточия: `error.card_charge_unsettled:650`.
const cardChargeUnsettledKey = 'error.card_charge_unsettled';

final paymentControllerProvider =
    NotifierProvider<PaymentNotifier, PaymentState>(PaymentNotifier.new);

/// Счета, на которые касса принимает деньги.
///
/// Пустой список при отказе — как и было: выбор счёта это удобство, и
/// экран оплаты не имеет права не открыться из-за него. Разница в том,
/// что теперь список приходит от кассы, а не собирается двумя запросами
/// к базе прямо здесь.
final paymentAccountsProvider = FutureProvider<List<PaymentAccount>>((
  ref,
) async {
  try {
    return await GetIt.I<PaymentService>().accounts();
  } catch (e) {
    talker.warning('Payment: accounts unavailable: $e');
    return const [];
  }
});

/// Банкноты страны кассы.
///
/// Раньше здесь стоял свой `switch` по коду страны — второй список тех же
/// денег. Третий лежал константой у счётчика купюр в смене и от страны не
/// зависел вовсе. Теперь источник один: [CountryCode.banknotes].
List<Decimal> _getDenominationsForCountry(int? countryCode) {
  final country =
      (countryCode != null &&
          countryCode >= 0 &&
          countryCode < CountryCode.values.length)
      ? CountryCode.values[countryCode]
      : CountryCode.kzt;
  return country.banknotes.map(Decimal.fromInt).toList();
}

/// Раскладка номиналов — по стране кассы.
///
/// # Почему `StartupStateRepository`, а не новая операция провода
///
/// Экрану нужен ровно один `int?` — `ThisPos.countryCode`. Он **уже едет**
/// в браузер полем `SetupState.countryCode` подписки `setup.state`, и
/// докстринг самого поля это признаёт: «сегодня не читает ни один
/// вызывающий... появится читатель — поле уже едет». Читатель появился
/// здесь. Заводить ради страны седьмую операцию `pay.*` значило бы послать
/// по проводу второй раз то, что уже пришло первый.
///
/// Договор один на оба переплёта: касса даёт `LocalStartupStateRepository`
/// (drift), браузер — `WtStartupStateRepository` (подписка). До задачи 17
/// здесь стоял `GetIt.I<AppDatabase>()`, и это было **единственное**
/// обращение экрана оплаты к базе — то самое, из-за которого весь узел
/// оплаты не собирался веб-сборкой.
///
/// `watch().first` — то же, чем пользуется заставка: одно значение из
/// потока честно означает «сейчас», а подписка при этом снимается. Отказ
/// (провод лёг, кассы нет) даёт умолчание, а не пустой экран: раскладка
/// номиналов — удобство, и экран оплаты не имеет права не открыться
/// из-за неё. Тот же довод, что у `paymentAccountsProvider` выше.
final denominationsProvider = FutureProvider<List<Decimal>>((ref) async {
  try {
    final setup = await GetIt.I<StartupStateRepository>().watch().first;
    return _getDenominationsForCountry(setup.countryCode);
  } catch (e) {
    talker.warning('Payment: country unavailable, default denominations: $e');
    return _getDenominationsForCountry(null);
  }
});

final canCompletePaymentProvider = Provider<bool>((ref) {
  return ref.watch(paymentControllerProvider.select((s) => s.canComplete));
});

/// Сдача — **предпросмотр экрана**, не деньги.
///
/// Кассир обязан видеть её до того, как нажмёт «оплатить». Настоящее
/// число считает касса и возвращает в `SaleOutcome.change`; это — то, что
/// экран показывает до ответа.
final changeAmountProvider = Provider<Decimal>((ref) {
  return ref.watch(paymentControllerProvider.select((s) => s.change));
});
