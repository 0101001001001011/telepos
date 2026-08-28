import 'package:flutter/widgets.dart';
import 'package:telepos/core/logging/setup_logger.dart';
import 'package:telepos/l10n/app_localizations.dart';

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
      'error.setup_incomplete' =>
        (arg != null && arg.isNotEmpty)
            ? '${l10n.errorFillRequired}: $arg'
            : l10n.errorFillRequired,
      'error.insufficient_stock' => l10n.errorInsufficientStock(arg ?? ''),
      'error.big_amount_blocked' => l10n.errorBigAmountBlocked,
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
      'error.terminal_limit_reached' => l10n.errorTerminalLimitReached,
      'error.pairing_code_invalid' => l10n.errorPairingCodeInvalid,
      'error.terminal_secret_invalid' => l10n.errorTerminalSecretInvalid,
      'error.session_expired' => l10n.errorSessionExpired,
      'error.session_ended' => l10n.errorSessionEnded,

      'error.sale_not_initialized' => l10n.errorSaleNotInitialized,
      'error.receipt_empty' => l10n.errorReceiptEmpty,
      'error.deferred_not_found' => l10n.errorDeferredNotFound,

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
}
