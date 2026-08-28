abstract class FiscErrorsService {
  Future<List<UnfiscalizedOperation>> checkErrors();

  Future<int> getUnfiscalizedCount();

  Future<RetryFiscalizationResult> retryFiscalization({
    required int operationId,
    required bool isSale,
  });

  Future<void> skipFiscalization({
    required int operationId,
    required bool isSale,
  });

  DateTime getNextCheckTime();

  bool shouldCheckNow();
}

class UnfiscalizedOperation {
  const UnfiscalizedOperation({
    required this.operationId,
    required this.receiptNo,
    required this.amount,
    required this.time,
    required this.isSale,
    this.lastError,
    this.retryCount = 0,
  });

  final int operationId;

  final int receiptNo;

  final String amount;

  final DateTime time;

  final bool isSale;

  final String? lastError;

  final int retryCount;

  String get typeText => isSale ? 'Продажа' : 'Возврат';
}

class RetryFiscalizationResult {
  const RetryFiscalizationResult({
    required this.success,
    this.fiscalNo,
    this.ticketUrl,
    this.errorMessage,
  });

  final bool success;
  final String? fiscalNo;
  final String? ticketUrl;
  final String? errorMessage;

  factory RetryFiscalizationResult.success({
    required String fiscalNo,
    String? ticketUrl,
  }) => RetryFiscalizationResult(
    success: true,
    fiscalNo: fiscalNo,
    ticketUrl: ticketUrl,
  );

  factory RetryFiscalizationResult.failed(String message) =>
      RetryFiscalizationResult(success: false, errorMessage: message);
}

class FiscErrorsSchedule {
  FiscErrorsSchedule._();

  static const int checkHour = 12;

  static const int checkMinute = 0;

  static const int timezoneOffsetHours = 5;

  static DateTime getNextCheckTime() {
    final now = DateTime.now();

    var checkTimeUtc = DateTime.utc(
      now.year,
      now.month,
      now.day,
      checkHour - timezoneOffsetHours,
      checkMinute,
    );

    if (checkTimeUtc.isBefore(now.toUtc())) {
      checkTimeUtc = checkTimeUtc.add(const Duration(days: 1));
    }

    return checkTimeUtc.toLocal();
  }

  static bool isCheckTimeNow() {
    final now = DateTime.now().toUtc();
    final checkTimeUtc = DateTime.utc(
      now.year,
      now.month,
      now.day,
      checkHour - timezoneOffsetHours,
      checkMinute,
    );

    final diff = now.difference(checkTimeUtc).inMinutes.abs();
    return diff <= 5;
  }
}
