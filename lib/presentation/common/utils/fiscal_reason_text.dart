import 'package:telepos/domain/fiscal/fiscal_failure_reason.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Фраза причины фискального отказа — **словарём**, из кода, который пишет
/// data-слой (`FiscalFailureReason.encode`).
///
/// * код узнан — фраза вида, и рядом код оператора, если он есть
///   («Фискальный оператор недоступен (код 503)»);
/// * строка не пуста, но кода в ней нет — она записана **до** перевода
///   (старые строки очереди с русским текстом): показывается как есть, в
///   рамке словаря, чтобы человек видел, что это не фраза интерфейса;
/// * пусто — «причина не записана», а не пустая строка.
String fiscalReasonText(AppLocalizations l10n, String? stored) {
  final text = stored?.trim() ?? '';
  if (text.isEmpty) return l10n.fiscalReasonNotRecorded;
  final reason = FiscalFailureReason.parse(text);
  if (reason == null) return l10n.fiscalReasonLegacy(text);
  final phrase = fiscalReasonPhrase(l10n, reason.kind);
  final raw = reason.rawCode;
  return raw == null ? phrase : l10n.fiscalReasonWithCode(phrase, raw);
}

/// `switch` исчерпывающий и без `default`: новый вид не соберётся без
/// фразы, а фраза — без ключа во всех пяти ARB (сторож
/// `test/architecture/fiscal_reason_dictionary_test.dart`).
String fiscalReasonPhrase(
  AppLocalizations l10n,
  FiscalFailureKind kind,
) => switch (kind) {
  FiscalFailureKind.network => l10n.fiscalReasonNetwork,
  FiscalFailureKind.operatorUnavailable => l10n.fiscalReasonOperatorUnavailable,
  FiscalFailureKind.tokenExpired => l10n.fiscalReasonTokenExpired,
  FiscalFailureKind.requestNotBuilt => l10n.fiscalReasonRequestNotBuilt,
  FiscalFailureKind.tlsRejected => l10n.fiscalReasonTlsRejected,
  FiscalFailureKind.clientFault => l10n.fiscalReasonClientFault,
  FiscalFailureKind.badCredentials => l10n.fiscalReasonBadCredentials,
  FiscalFailureKind.cashboxNotFound => l10n.fiscalReasonCashboxNotFound,
  FiscalFailureKind.cashboxBlocked => l10n.fiscalReasonCashboxBlocked,
  FiscalFailureKind.offlineLimitExceeded =>
    l10n.fiscalReasonOfflineLimitExceeded,
  FiscalFailureKind.offlineNotSupported => l10n.fiscalReasonOfflineNotSupported,
  FiscalFailureKind.duplicate => l10n.fiscalReasonDuplicate,
  FiscalFailureKind.validation => l10n.fiscalReasonValidation,
  FiscalFailureKind.notEnoughMoney => l10n.fiscalReasonNotEnoughMoney,
  FiscalFailureKind.shiftError => l10n.fiscalReasonShiftError,
  FiscalFailureKind.unsupported => l10n.fiscalReasonUnsupported,
  FiscalFailureKind.notConfigured => l10n.fiscalReasonNotConfigured,
  FiscalFailureKind.unknown => l10n.fiscalReasonUnknown,
  FiscalFailureKind.offlineWindowExpired =>
    l10n.fiscalReasonOfflineWindowExpired,
  FiscalFailureKind.rowUnreadable => l10n.fiscalReasonRowUnreadable,
  FiscalFailureKind.paymentTypeNotAccepted =>
    l10n.fiscalReasonPaymentTypeNotAccepted,
};

/// Ключ ARB под вид — тем же именем, что геттер словаря. Читает сторож.
String fiscalReasonArbKey(FiscalFailureKind kind) =>
    'fiscalReason${kind.name[0].toUpperCase()}${kind.name.substring(1)}';
