import 'package:flutter/widgets.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/logging/setup_logger.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';
import 'package:telepos/domain/sale/big_amount_limit.dart';

class ErrorLocalizer {
  ErrorLocalizer._();

  static String localize(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      SetupLogger.warning('ErrorLocalizer: l10n is null для key="$key"');
      return key;
    }

    final parts = key.split(':');
    final baseKey = parts[0];
    final arg1 = parts.length > 1 ? parts.sublist(1).join(':') : null;

    // Довод, написанный `safeErrorText`, — не текст для показа, а то, что
    // осталось от исключения. Два его вида читаются здесь, до словаря
    // (живая приёмка 2026-09-13: «Ошибка сохранения: minified:du»).
    if (arg1 != null) {
      final refusal = parseNamedRefusalText(arg1);
      if (refusal != null) return _localizeRefusal(l10n, baseKey, refusal);
      if (arg1 == unnamedErrorText) {
        return _withContext(l10n, baseKey, l10n.errorReasonUnknown);
      }
    }

    final result = _resolve(l10n, baseKey, arg1);
    if (result == null) {
      SetupLogger.warning(
        'ErrorLocalizer: нет перевода для key="$key" (baseKey="$baseKey", arg="$arg1"), возвращаем raw key',
      );
    } else if (result.isEmpty) {
      SetupLogger.warning('ErrorLocalizer: перевод пуст для key="$key"');
    }

    // Пустая строка возвращается так же, как её отсутствие, и это не
    // придирка. Раньше пустой перевод логировался — и отдавался наружу как
    // есть: экран рисовал карточку ошибки без единого слова. Измерено
    // 2026-08-02 на шаге 9 мастера настройки: оператор видит красную полосу и
    // не знает, что не так, а предупреждение уходит в файл, которого он не
    // читает. Ключ читается хуже перевода, но он говорит, а пустота молчит.
    if (result == null || result.isEmpty) return key;
    return result;
  }

  /// Названный отказ, доехавший сюда через `safeErrorText`.
  ///
  /// Код в словаре — фраза словаря, **ровно та же**, что показал бы путь
  /// `saleRefusalErrorKeyOf`: кассир не должен различать, каким путём отказ
  /// до него дошёл. Внешний ключ (`error.save_failed`) при этом не
  /// добавляется — «Ошибка сохранения:» перед «выберите покупателя» говорит
  /// не больше, чем сама фраза, и путь `saleRefusalErrorKeyOf` его не пишет.
  ///
  /// Кода в словаре нет — «неизвестная причина (код …)» внутри внешнего
  /// ключа, и **только код**: текст причины неизвестного кода не показывается
  /// (он русский, написан для журнала и словарём не проверен), а подобрать
  /// «похожую» фразу значило бы выдумать причину.
  static String _localizeRefusal(
    AppLocalizations l10n,
    String baseKey,
    ({String code, String reason}) refusal,
  ) {
    final mapped = saleRefusalErrorKeys[refusal.code];
    if (mapped != null) {
      final phrase = _resolve(
        l10n,
        mapped.key,
        mapped.withMessage ? refusal.reason : null,
      );
      if (phrase != null && phrase.isNotEmpty) return phrase;
      SetupLogger.warning(
        'ErrorLocalizer: код отказа "${refusal.code}" есть в карте, но ключ '
        '"${mapped.key}" словарь не разобрал',
      );
    } else {
      SetupLogger.warning(
        'ErrorLocalizer: код отказа "${refusal.code}" не в словаре '
        '(baseKey="$baseKey")',
      );
    }
    return _withContext(
      l10n,
      baseKey,
      l10n.errorRefusalUnknownCode(refusal.code),
    );
  }

  /// [details] внутри внешнего ключа, а если ключ словарю не известен —
  /// после «Неизвестная ошибка:». Никогда не сам ключ: в нём после двоеточия
  /// лежит довод `safeErrorText` вместе с текстом причины.
  static String _withContext(
    AppLocalizations l10n,
    String baseKey,
    String details,
  ) {
    final shown = _resolve(l10n, baseKey, details);
    if (shown == null || shown.isEmpty) {
      return '${l10n.errorUnknownGeneric}: $details';
    }
    return shown;
  }

  static String? _resolve(AppLocalizations l10n, String key, String? arg) {
    return switch (key) {
      'error.save_failed' =>
        arg != null ? l10n.errorSaveFailed(arg) : l10n.errorSaveFailedGeneric,
      'error.load_failed' =>
        arg != null ? l10n.errorLoadFailed(arg) : l10n.errorLoadFailedGeneric,
      'error.search_failed' =>
        arg != null
            ? l10n.errorSearchFailed(arg)
            : l10n.errorSearchFailedGeneric,
      'error.unknown' =>
        arg != null
            ? '${l10n.errorUnknownGeneric}: $arg'
            : l10n.errorUnknownGeneric,
      'error.validation' => l10n.errorFillRequired,
      // Довод — КОДЫ разделов мастера, а не их русские имена: до
      // 2026-09-22 иностранец читал здесь «организация, касса,
      // фискализация» буквами, на английском мастере.
      'error.setup_incomplete' =>
        (arg != null && arg.isNotEmpty)
            ? '${l10n.errorFillRequired}: ${_setupParts(l10n, arg)}'
            : l10n.errorFillRequired,
      'error.sale_policy_forbids' => l10n.salePolicyForbids,
      // Отказ кассы на возврате (задача 20). С 2026-09-15 довод — не текст
      // кассы, а `refusal(<код>): …` от `namedRefusalText`: код из словаря
      // показывается своей фразой в `_localizeRefusal` раньше этой строки,
      // а сюда доезжает только «неизвестная причина (код …)». Прежде здесь
      // стоял русский текст кассы («в чеке продано 2, вернуть просят 5») —
      // буквами в любом интерфейсе.
      'error.refund_refused' =>
        arg != null && arg.isNotEmpty
            ? l10n.refundRefused(arg)
            : l10n.globalError,
      // Код `invalid_amount` общий с корзиной, а фраза корзины говорит о
      // скидке больше 100 % — на возврате она отправила бы не туда.
      'error.refund_invalid_amount' => l10n.errorRefundInvalidAmount,
      'error.refund_search_unavailable' => l10n.errorRefundSearchUnavailable,
      'error.refund_nothing_selected' => l10n.errorRefundNothingSelected,
      'error.insufficient_stock' => l10n.errorInsufficientStock(arg ?? ''),
      // Задача 12: три отказа уступки, и каждый несёт свой довод — число
      // предела, имя настройки, порог подтверждения. Без довода кассир
      // узнаёт, что нельзя, и не узнаёт, что делать.
      'error.denied_policy' => l10n.errorDeniedPolicy(arg ?? ''),
      'error.denied_limit' => l10n.errorDeniedLimit(arg ?? ''),
      'error.approval_required' => l10n.errorApprovalRequired(arg ?? ''),
      // Потолок — НАСТРОЙКА кассы (схема v57) и приезжает доводом отказа.
      // До этого фраза называла зашитый «1 млн ₸» на кассе любой страны.
      // Потолок приезжает доводом отказа — вместе со знаком валюты, потому
      // что собирает его касса (`LocalSaleCheckoutService`), у которой есть
      // и число, и валюта. Экран их не добывает: браузерному терминалу
      // добывать неоткуда.
      'error.product_has_no_price' => l10n.errorProductHasNoPrice(arg ?? ''),
      // Довод — «имя товара|окно», собранный кассой: у экрана ни часов, ни
      // дерева категорий нет, а у браузерной вкладки нет и базы.
      'error.selling_hours_banned' => () {
        final parts = (arg ?? '').split('|');
        final category = parts.isNotEmpty ? parts.first : '';
        final window = parts.length > 1 ? parts[1] : '';
        // Окно могло не приехать — например, от кассы прежней сборки. Тогда
        // говорится фраза БЕЗ окна, а не «запрет .» с дырой на его месте:
        // обрывок читается как поломка продукта, а не как отказ.
        return window.isEmpty
            ? l10n.errorSellingHoursBannedNoWindow(category)
            : l10n.errorSellingHoursBanned(category, window);
      }(),
      'error.big_amount_blocked' => l10n.errorBigAmountBlocked(
        arg == null || arg.isEmpty ? '$kDefaultBigAmountLimit' : arg,
      ),
      // ── оплата и возврат: закрыто при слиянии (2026-09-07) ────────────
      //
      // Девятнадцать кодов отказа оплаты и возврата не имели ни строки в
      // карте, ни перевода. Дефект **не** внесён ни одной ветвью: сторож
      // словаря завела задача 23, коды — задачи 14, 16 и 19, и порознь ни
      // одна ветвь его не видела. Кассир с казахским интерфейсом читал бы
      // русскую фразу, пришитую к коду через запасной выход
      // `error.save_failed:<текст>`.
      'error.pay_receipt_not_found' => l10n.errorPayReceiptNotFound,
      'error.pay_not_owner' => l10n.errorPayNotOwner,
      'error.payment_already_taken' => l10n.errorPaymentAlreadyTaken,
      'error.payment_insufficient' => l10n.errorPaymentInsufficient,
      'error.payment_account_missing' => l10n.errorPaymentAccountMissing,
      'error.payment_account_not_allowed' => l10n.errorPaymentAccountNotAllowed,
      'error.payment_unbalanced' => l10n.errorPaymentUnbalanced,
      'error.payment_kind_inactive' => l10n.errorPaymentKindInactive,
      'error.payment_kind_unknown' => l10n.errorPaymentKindUnknown,
      'error.qr_intent_unknown' => l10n.errorQrIntentUnknown,
      'error.qr_intent_not_paid' => l10n.errorQrIntentNotPaid,
      // Вход в оплату по QR: отказ кассы «на чеке уже ждёт код» и восемь
      // кодов провайдера (`kQrRefusalCodes`). Коды провайдера доезжают
      // полем `QrTender.refusalCode`, а не исключением, — но показываются
      // тем же словарём, чтобы кассир в казахском интерфейсе не читал
      // `qr_network` буквами.
      'error.qr_intent_live' => l10n.errorQrIntentLive,
      'error.qr_not_configured' => l10n.errorQrNotConfigured,
      'error.qr_network' => l10n.errorQrNetwork,
      'error.qr_timeout' => l10n.errorQrTimeout,
      'error.qr_provider_busy' => l10n.errorQrProviderBusy,
      'error.qr_malformed_reply' => l10n.errorQrMalformedReply,
      'error.qr_unknown_intent' => l10n.errorQrUnknownIntent,
      'error.qr_rejected' => l10n.errorQrRejected,
      'error.qr_reverse_unsupported' => l10n.errorQrReverseUnsupported,
      // Текст кассы несёт **номер чека**, которым эти деньги уже закрыты, и
      // без него кассиру нечего искать. Пустой довод — не пустая строка, а
      // общая фраза: «уже закрыли другой чек» полезнее, чем «: » в конце.
      'error.qr_intent_already_settled' => l10n.errorQrIntentAlreadySettled(
        arg ?? '',
      ),
      // Задача 21: подарочный сертификат.
      'error.certificate_unknown' => l10n.errorCertificateUnknown,
      'error.certificate_pin_wrong' => l10n.errorCertificatePinWrong,
      'error.certificate_pin_required' => l10n.errorCertificatePinRequired,
      'error.certificate_rate_limited' => l10n.errorCertificateRateLimited,
      'error.certificate_expired' => l10n.errorCertificateExpired,
      'error.certificate_exhausted' => l10n.errorCertificateExhausted,
      'error.certificate_duplicate' => l10n.errorCertificateDuplicate,
      'error.certificate_race' => l10n.errorCertificateRace,
      'error.certificate_account_missing' =>
        l10n.errorCertificateAccountMissing,
      'error.certificate_number_taken' => l10n.errorCertificateNumberTaken,
      'error.certificate_nominal_invalid' =>
        l10n.errorCertificateNominalInvalid,
      'error.debt_customer_required' => l10n.errorDebtCustomerRequired,
      'error.debt_not_sold_here' => l10n.errorDebtNotSoldHere,
      'error.debt_account_missing' => l10n.errorDebtAccountMissing,
      'error.bonus_account_missing' => l10n.errorBonusAccountMissing,
      'error.prepayment_customer_required' =>
        l10n.errorPrepaymentCustomerRequired,
      'error.prepayment_account_missing' => l10n.errorPrepaymentAccountMissing,
      'error.prepayment_insufficient' => l10n.errorPrepaymentInsufficient,
      // Задача 24: рассрочка. Шесть бед, и лечатся они разным —
      // выбрать другой срок, взять первый взнос поменьше, выбрать
      // схему, разобраться с прошлым договором. Один ключ на шесть
      // отправил бы кассира не туда в пяти случаях из шести.
      'error.credit_term_invalid' => l10n.errorCreditTermInvalid,
      'error.credit_principal_invalid' => l10n.errorCreditPrincipalInvalid,
      'error.credit_fee_invalid' => l10n.errorCreditFeeInvalid,
      'error.credit_scheme_unknown' => l10n.errorCreditSchemeUnknown,
      'error.credit_overdue' => l10n.errorCreditOverdue,
      'error.credit_contract_duplicate' => l10n.errorCreditContractDuplicate,
      'error.loyalty_customer_unknown' => l10n.errorLoyaltyCustomerUnknown,
      'error.amount_exceeds_receipt' => l10n.errorAmountExceedsReceipt,
      'error.card_charge_unproven' => l10n.errorCardChargeUnproven,
      'error.card_terminal_misconfigured' =>
        l10n.errorCardTerminalMisconfigured,
      'error.payment_type_not_allowed' => l10n.errorPaymentTypeNotAllowed,
      'error.payments_unavailable' => l10n.errorPaymentsUnavailable,
      'error.no_refund_service' => l10n.errorNoRefundService,
      'error.refund_abandon_is_till_side' => l10n.errorRefundAbandonIsTillSide,
      'error.no_answer' => l10n.errorNoAnswer,
      // Коды провода и кассы вне продажи — 2026-09-13, сторож
      // `named_refusal_reaches_cashier_test.dart` (разбор у строк карты).
      'error.connection_lost' => l10n.errorConnectionLost,
      'error.run_incomplete' => l10n.errorRunIncomplete,
      'error.wire_mismatch' => l10n.errorWireMismatch,
      'error.till_failed' => l10n.errorTillFailed,
      'error.terminal_changed' => l10n.errorTerminalChanged,
      'error.unknown_terminal' => l10n.errorUnknownTerminal,
      'error.already_configured' => l10n.errorAlreadyConfigured,
      'error.cannot_delete_self' => l10n.errorCannotDeleteSelf,
      'error.no_drivers' => l10n.errorNoDrivers,
      'error.no_network_module' => l10n.errorNoNetworkModule,
      'error.no_session_registry' => l10n.errorNoSessionRegistry,
      'error.no_backup_transport' => l10n.errorNoBackupTransport,
      'error.backup_not_found' => l10n.errorBackupNotFound,
      'error.certificates_unavailable' => l10n.errorCertificatesUnavailable,
      'error.prepayment_intake_unavailable' =>
        l10n.errorPrepaymentIntakeUnavailable,
      'error.qr_setup_unavailable' => l10n.errorQrSetupUnavailable,
      'error.receipt_templates_unavailable' =>
        l10n.errorReceiptTemplatesUnavailable,
      'error.receipt_template_nameless' => l10n.errorReceiptTemplateNameless,
      'error.diagnostics_unavailable' => l10n.errorDiagnosticsUnavailable,
      'error.shift_desk_not_open' => l10n.errorShiftDeskNotOpen,
      'error.shift_desk_already_open' => l10n.errorShiftDeskAlreadyOpen,
      'error.shift_desk_actor_unknown' => l10n.errorShiftDeskActorUnknown,
      'error.prepayment_amount_invalid' => l10n.errorPrepaymentAmountInvalid,
      'error.prepayment_tender_invalid' => l10n.errorPrepaymentTenderInvalid,
      'error.prepayment_till_account_missing' =>
        l10n.errorPrepaymentTillAccountMissing,
      'error.prepayment_intake_failed' => l10n.errorPrepaymentIntakeFailed,
      'error.prepayment_intake_key_missing' =>
        l10n.errorPrepaymentIntakeKeyMissing,
      'error.prepayment_refund_exceeds_balance' =>
        l10n.errorPrepaymentRefundExceedsBalance,
      'error.prepayment_refund_key_missing' =>
        l10n.errorPrepaymentRefundKeyMissing,
      'error.prepayment_refund_failed' => l10n.errorPrepaymentRefundFailed,
      'error.prepayment_refund_unavailable' =>
        l10n.errorPrepaymentRefundUnavailable,
      'error.refund_stale' => l10n.errorRefundStale,
      'error.refund_wrong_draft' => l10n.errorRefundWrongDraft,
      'error.refund_not_started' => l10n.errorRefundNotStarted,
      'error.refund_empty' => l10n.errorRefundEmpty,
      'error.receipt_already_refunded' => l10n.errorReceiptAlreadyRefunded,
      'error.receipt_not_refundable' => l10n.errorReceiptNotRefundable,
      'error.line_not_in_receipt' => l10n.errorLineNotInReceipt,
      'error.sale_not_completed' => l10n.errorSaleNotCompleted,
      'error.refund_busy' => l10n.errorRefundBusy,
      'error.refund_cannot_start' => l10n.errorRefundCannotStart,
      'error.refund_installment_refused' => l10n.errorRefundInstallmentRefused,
      'error.refund_cashless_unavailable' =>
        l10n.errorRefundCashlessUnavailable,
      'error.refund_cashless_refused' => l10n.errorRefundCashlessRefused,
      'error.refund_kind_not_refundable' => l10n.errorRefundKindNotRefundable,
      'error.refund_kind_unknown' => l10n.errorRefundKindUnknown,
      'error.certificate_cash_refund_refused' =>
        l10n.errorCertificateCashRefundRefused,
      'error.certificate_refund_no_source' =>
        l10n.errorCertificateRefundNoSource,
      'error.certificate_pays_certificate' =>
        l10n.errorCertificatePaysCertificate,
      'error.credit_contract_unknown' => l10n.errorCreditContractUnknown,
      'error.credit_contract_not_active' => l10n.errorCreditContractNotActive,
      'error.credit_overpayment' => l10n.errorCreditOverpayment,
      'error.credit_repayment_invalid' => l10n.errorCreditRepaymentInvalid,
      'error.credit_allocation_race' => l10n.errorCreditAllocationRace,
      'error.kind_tender_cannot_discount' => l10n.errorKindTenderCannotDiscount,
      'error.kind_account_missing' => l10n.errorKindAccountMissing,
      'error.kind_counterparty_required' => l10n.errorKindCounterpartyRequired,
      'error.kind_provider_required' => l10n.errorKindProviderRequired,
      'error.kind_fiscal_kind_required' => l10n.errorKindFiscalKindRequired,
      'error.kind_change_not_a_tender' => l10n.errorKindChangeNotATender,
      'error.kind_system_immutable' => l10n.errorKindSystemImmutable,
      // `error.card_charge_unsettled` знал не словарь, а собственный
      // помощник экрана оплаты (`_errorText`, задача 14). При слиянии с
      // задачей 23 два перевода на одном экране остаться не могли: экран
      // зовёт `ErrorLocalizer` для всех ключей отказа кассы, и помощник
      // рядом означал бы «этот ключ переведён, остальные показаны сырьём».
      // Ключ обязан нести сумму: он единственный означает «с покупателя
      // деньги сняты, и вернуть их касса не умеет».
      'error.card_charge_unsettled' =>
        arg != null ? l10n.paymentCardChargeUnsettled(arg) : null,
      'error.mark_required' => l10n.errorMarkRequired(arg ?? ''),
      'error.order_not_found' => l10n.errorOrderNotFound,
      'error.serial_not_found' => l10n.errorSerialNotFound,
      'error.receipt_failed' =>
        arg != null
            ? '${l10n.errorReceiptFailedPrint}: $arg'
            : l10n.errorReceiptFailedPrint,
      'error.delete_failed' =>
        arg != null
            ? '${l10n.errorDeleteFailed}: $arg'
            : l10n.errorDeleteFailed,
      'error.cancel_failed' =>
        arg != null
            ? '${l10n.errorCancelFailed}: $arg'
            : l10n.errorCancelFailed,
      'error.shift_zreport_failed' =>
        arg != null
            ? '${l10n.errorShiftZreportFailed}: $arg'
            : l10n.errorShiftZreportFailed,
      'error.transition_failed' =>
        arg != null
            ? '${l10n.errorTransitionFailed}: $arg'
            : l10n.errorTransitionFailed,

      'error.no_users' => l10n.errorNoUsers,
      'error.select_user' => l10n.errorSelectUser,
      'error.pin_too_short' => l10n.errorPinTooShort,
      'error.rsa_not_configured' => l10n.errorRsaNotConfigured,
      'error.wrong_pin' => l10n.errorWrongPin,
      'error.ambiguous_pin' => l10n.errorAmbiguousPin,
      'error.no_pin_set' => l10n.errorNoPinSet,
      'error.walk_up_disabled' => l10n.errorWalkUpDisabled,
      'error.credential_unreadable' => l10n.errorCredentialUnreadable,
      'error.auth_unknown' => l10n.errorAuthUnknown,
      'error.till_not_configured' => l10n.errorTillNotConfigured,
      // Тот же код, две фразы, и это не дублирование. Первая написана для
      // входа («вход невозможен, пока не пройден мастер настройки») и там
      // верна; на экране продажи её же видел бы кассир посреди чека, где
      // про вход речи нет вовсе. Круг правки 2: разведён контекст, а не
      // причина — код на проводе остался один.
      'error.till_not_configured_sale' => l10n.errorTillNotConfiguredSale,
      'error.terminal_limit_reached' => l10n.errorTerminalLimitReached,
      'error.pairing_code_invalid' => l10n.errorPairingCodeInvalid,
      'error.terminal_secret_invalid' => l10n.errorTerminalSecretInvalid,
      'error.session_expired' => l10n.errorSessionExpired,
      'error.session_ended' => l10n.errorSessionEnded,

      // Часовым этот ключ является **только на экране продажи**: там
      // `sale_screen` ловит его раньше показа и открывает блокирующий
      // диалог. На экране оплаты он доезжает до человека сегодня и всегда
      // доезжал. Прежде его клал в состояние `completeSale` на
      // просроченной смене, а `PaymentNotifier.processPayment` копировал
      // оттуда в своё; с задачи 9 `completeSale` удалён, и потолок
      // возраста смены проверяет сама касса
      // (`LocalPaymentService._requireShiftNotOverAge`), отвечая тем же
      // кодом отказом-значением. Смена, перевалившая за сутки, пока чек
      // набирался, — обычный случай, а не край.
      //
      // Значит до этой ветки кассир на экране оплаты читал буквально
      // «error.shift_over_age», во всех пяти локалях сразу. Круг правки 2
      // завёл ветку с неверным доводом («на случай, если дойдёт»), круг
      // правки 3 довод исправил и накрыл путь пробой
      // (`payment_refusal_localized_test`).
      'error.shift_over_age' => l10n.shiftOverAgeMessage,
      'error.sale_not_initialized' => l10n.errorSaleNotInitialized,
      'error.receipt_empty' => l10n.errorReceiptEmpty,
      'error.deferred_not_found' => l10n.errorDeferredNotFound,
      // Подписка на пул отложенных чеков не поднялась (2026-09-15). Довод —
      // только «неизвестная причина (код …)» из `_localizeRefusal`: код из
      // словаря показывается своей фразой без этой обёртки.
      'error.deferred_list_unavailable' =>
        arg != null
            ? l10n.errorDeferredListUnavailableReason(arg)
            : l10n.errorDeferredListUnavailable,

      // Коды отказа корзины — задача 23. До неё их переводилось три из
      // десяти, а остальные уезжали на экран как
      // `error.save_failed:<русский текст>`: кассир с казахским или
      // узбекским интерфейсом читал русскую фразу, пришитую к коду
      // ошибки. Сторож, не дающий забыть следующий код, —
      // `test/architecture/sale_refusal_codes_localized_test.dart`.
      'error.cart_stale' => l10n.errorCartStale,
      'error.cart_wrong_receipt' => l10n.errorCartWrongReceipt,
      'error.cart_not_started' => l10n.errorCartNotStarted,
      'error.line_not_found' => l10n.errorLineNotFound,
      'error.invalid_amount' => l10n.errorInvalidAmount,
      'error.deferred_taken' => l10n.errorDeferredTaken,
      'error.cart_not_empty' => l10n.errorCartNotEmpty,
      'error.sale_not_started' => l10n.errorSaleNotStarted,
      'error.shift_not_open' => l10n.errorShiftNotOpen,

      // Коды слоя провода, доезжающие до кассира через продажу — круг
      // правки 3. Не «служебные»: `forbidden` приходит, когда оптовый чек
      // поднимает тот, кому не разрешена правка цены, а остальные три
      // говорят человеку, что делать с неисправным рабочим местом.
      'error.not_allowed' => l10n.errorNotAllowed,
      'error.no_sale_module' => l10n.errorNoSaleModule,
      'error.terminal_in_body' => l10n.errorTerminalInBody,
      'error.wholesale_in_start' => l10n.errorWholesaleInStart,

      'error.receipt_not_found' =>
        arg != null
            ? l10n.errorReceiptNotFound(arg)
            : l10n.errorReceiptNotFoundGeneric,
      'error.not_authorized' => l10n.errorNotAuthorized,

      'error.supplier_not_found' => l10n.errorSupplierNotFound,
      'error.account_not_found' => l10n.errorAccountNotFound,
      'error.product_not_found' =>
        arg != null
            ? l10n.errorProductNotFound(arg)
            : l10n.errorProductNotFoundGeneric,

      'error.name_required' => l10n.errorNameRequired,
      'error.name_too_short' => l10n.errorNameTooShort,
      'error.phone_invalid' => l10n.errorPhoneInvalid,
      'error.bin_invalid' => l10n.errorBinInvalid,
      'error.phone_exists' => l10n.errorPhoneExists,

      'error.shift_open_failed' =>
        arg != null
            ? l10n.errorShiftOpenFailed(arg)
            : l10n.errorShiftOpenFailedGeneric,
      'error.shift_close_failed' =>
        arg != null
            ? l10n.errorShiftCloseFailed(arg)
            : l10n.errorShiftCloseFailedGeneric,
      'error.shift_load_failed' =>
        arg != null
            ? l10n.errorShiftLoadFailed(arg)
            : l10n.errorShiftLoadFailedGeneric,

      'error.payment_config' => l10n.errorPaymentConfig,
      'error.sale_save_failed' => l10n.errorSaleSaveFailed,

      'error.inventory_cannot_complete' => l10n.errorInventoryCannotComplete,

      'error.no_products' => l10n.errorNoProducts,

      'error.select_country' => l10n.errorSelectCountry,
      'error.enter_org_name' => l10n.errorEnterOrgName,
      'error.enter_tax_id' =>
        arg != null ? l10n.errorEnterTaxId(arg) : l10n.errorEnterTaxIdGeneric,
      'error.tax_id_length' =>
        arg != null ? l10n.errorTaxIdLength(arg) : l10n.errorTaxIdLengthGeneric,
      'error.enter_pos_name' => l10n.errorEnterPosName,
      'error.fill_webkassa' => l10n.errorFillWebkassa,
      'error.fill_ofd' => l10n.errorFillOfd,
      'error.enter_kaspi_ip' => l10n.errorEnterKaspiIp,
      'error.enter_admin_name' => l10n.errorEnterAdminName,
      'error.admin_pin_short' => l10n.errorAdminPinShort,
      'error.seller_pin_short' => l10n.errorSellerPinShort,
      'error.check_failed' =>
        arg != null ? l10n.errorCheckFailed(arg) : l10n.errorCheckFailedGeneric,

      'error.telegram_not_initialized' => l10n.errorTelegramNotInitialized,
      'error.telegram_auth_not_initialized' =>
        l10n.errorTelegramAuthNotInitialized,
      'error.phone_send_failed' =>
        arg != null
            ? l10n.errorPhoneSendFailed(arg)
            : l10n.errorPhoneSendFailedGeneric,
      'error.qr_auth_failed' =>
        arg != null
            ? l10n.errorQrAuthFailed(arg)
            : l10n.errorQrAuthFailedGeneric,
      'error.wrong_code' =>
        arg != null ? l10n.errorWrongCode(arg) : l10n.errorWrongCodeGeneric,
      'error.wrong_password' =>
        arg != null
            ? l10n.errorWrongPassword(arg)
            : l10n.errorWrongPasswordGeneric,
      'error.registration_failed' =>
        arg != null
            ? l10n.errorRegistrationFailed(arg)
            : l10n.errorRegistrationFailedGeneric,
      'error.channel_search_failed' =>
        arg != null
            ? l10n.errorChannelSearchFailed(arg)
            : l10n.errorChannelSearchFailedGeneric,
      'error.channel_connect_failed' =>
        arg != null
            ? l10n.errorChannelConnectFailed(arg)
            : l10n.errorChannelConnectFailedGeneric,
      'error.channel_create_failed' =>
        arg != null
            ? l10n.errorChannelCreateFailed(arg)
            : l10n.errorChannelCreateFailedGeneric,

      'error.fill_client_data' => l10n.errorFillClientData,

      _ => null,
    };
  }

  /// Разделы мастера словами: коды, пришедшие доводом, — в перечень.
  ///
  /// Незнакомый код печатается как есть: молча его проглотить значило бы
  /// сказать «заполните: » и не назвать что.
  static String _setupParts(AppLocalizations l10n, String codes) => codes
      .split(',')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .map(
        (c) => switch (c) {
          'org' => l10n.setupPartOrganization,
          'pos' => l10n.setupPartTill,
          'fiscal' => l10n.setupPartFiscal,
          'equipment' => l10n.setupPartEquipment,
          'terminals' => l10n.setupPartTerminals,
          'rules' => l10n.setupPartRules,
          'user' => l10n.setupPartUser,
          _ => c,
        },
      )
      .join(', ');
}
