import 'package:telepos/domain/fiscal/fiscal_models.dart';

/// Причина фискального отказа — **код, а не фраза**.
///
/// # Что было
///
/// Строка очереди (`FiscalQueueEntry.lastError`), исход продажи
/// (`SaleFiscalization.message`, он же `fiscalMessage` на проводе) и снек
/// повтора несли **русский текст**, написанный в data-слое: «Превышено
/// автономное окно 72ч», «Некорректный ответ WebKassa (HTTP 503)», текст
/// оператора. Экран нефискализованных чеков печатал его как есть — кассир с
/// казахским или английским интерфейсом читал русский, а словарь об этих
/// фразах не знал ничего.
///
/// # Как теперь
///
/// Data-слой пишет [encode] — `fiscal(<вид>)` или `fiscal(<вид>#<код>)`.
/// Фразу строит экран, словарём (`fiscalReasonText`,
/// `lib/presentation/common/utils/fiscal_reason_text.dart`). Русский текст
/// оператора и провайдера остаётся в журнале — для разбора, не для кассира.
///
/// Колонка `lastError` — та же строка, миграции нет: старые строки с
/// русским текстом [parse] не узнаёт, и экран показывает их с пометкой
/// «записано до перевода».
enum FiscalFailureKind {
  network,
  operatorUnavailable,
  tokenExpired,
  requestNotBuilt,
  tlsRejected,
  clientFault,
  badCredentials,
  cashboxNotFound,
  cashboxBlocked,
  offlineLimitExceeded,
  offlineNotSupported,
  duplicate,
  validation,
  notEnoughMoney,
  shiftError,
  unsupported,
  notConfigured,
  unknown,

  /// Строка пережила автономное окно 72 ч — решение очереди, не оператора.
  offlineWindowExpired,

  /// Строка очереди не восстанавливается в документ.
  rowUnreadable,

  /// Вид оплаты исключён протоколом оператора (кредит, тара).
  paymentTypeNotAccepted,
}

class FiscalFailureReason {
  const FiscalFailureReason(this.kind, {this.rawCode});

  /// Вид по коду отказа. `switch` исчерпывающий и без `default`: новый
  /// `FiscalErrorCode` не соберётся, пока ему не назван вид, а виду —
  /// фраза словаря (сторож `fiscal_reason_dictionary_test.dart`).
  factory FiscalFailureReason.of(FiscalErrorCode code, {int? rawCode}) {
    final kind = switch (code) {
      FiscalErrorCode.network => FiscalFailureKind.network,
      FiscalErrorCode.operatorUnavailable =>
        FiscalFailureKind.operatorUnavailable,
      FiscalErrorCode.tokenExpired => FiscalFailureKind.tokenExpired,
      FiscalErrorCode.requestNotBuilt => FiscalFailureKind.requestNotBuilt,
      FiscalErrorCode.tlsRejected => FiscalFailureKind.tlsRejected,
      FiscalErrorCode.clientFault => FiscalFailureKind.clientFault,
      FiscalErrorCode.badCredentials => FiscalFailureKind.badCredentials,
      FiscalErrorCode.cashboxNotFound => FiscalFailureKind.cashboxNotFound,
      FiscalErrorCode.cashboxBlocked => FiscalFailureKind.cashboxBlocked,
      FiscalErrorCode.offlineLimitExceeded =>
        FiscalFailureKind.offlineLimitExceeded,
      FiscalErrorCode.offlineNotSupported =>
        FiscalFailureKind.offlineNotSupported,
      FiscalErrorCode.duplicate => FiscalFailureKind.duplicate,
      FiscalErrorCode.validation => FiscalFailureKind.validation,
      FiscalErrorCode.notEnoughMoney => FiscalFailureKind.notEnoughMoney,
      FiscalErrorCode.shiftError => FiscalFailureKind.shiftError,
      FiscalErrorCode.unsupported => FiscalFailureKind.unsupported,
      FiscalErrorCode.notConfigured => FiscalFailureKind.notConfigured,
      FiscalErrorCode.unknown => FiscalFailureKind.unknown,
      FiscalErrorCode.paymentTypeNotAccepted =>
        FiscalFailureKind.paymentTypeNotAccepted,
      // `ok` отказом не бывает; если он всё же пришёл отказом — причина
      // не названа, и выдумывать её незачем.
      FiscalErrorCode.ok => FiscalFailureKind.unknown,
    };
    return FiscalFailureReason(kind, rawCode: rawCode);
  }

  /// Причина из ответа провайдера. Свой код оператора ([FiscalResult
  /// .rawErrorCode]) едет рядом: у «оператор недоступен» это HTTP-статус, у
  /// «отказал» — код оператора. Отрицательные коды транспорта человеку не
  /// говорят ничего и не несутся.
  factory FiscalFailureReason.fromResult(FiscalResult result) {
    final raw = result.rawErrorCode;
    return FiscalFailureReason.of(
      result.errorCode,
      rawCode: raw != null && raw >= 0 ? raw : null,
    );
  }

  final FiscalFailureKind kind;
  final int? rawCode;

  static final RegExp _shape = RegExp(r'^fiscal\(([a-zA-Z]+)(?:#(\d+))?\)$');

  String encode() =>
      rawCode == null ? 'fiscal(${kind.name})' : 'fiscal(${kind.name}#$rawCode)';

  /// Обратное [encode]; `null` — строка не этого вида (записана до перевода
  /// или пуста) либо вид не известен этой сборке.
  static FiscalFailureReason? parse(String? text) {
    if (text == null) return null;
    final match = _shape.firstMatch(text.trim());
    if (match == null) return null;
    final kind = FiscalFailureKind.values.asNameMap()[match.group(1)!];
    if (kind == null) return null;
    final raw = match.group(2);
    return FiscalFailureReason(
      kind,
      rawCode: raw == null ? null : int.tryParse(raw),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FiscalFailureReason &&
      other.kind == kind &&
      other.rawCode == rawCode;

  @override
  int get hashCode => Object.hash(kind, rawCode);

  @override
  String toString() => encode();
}
