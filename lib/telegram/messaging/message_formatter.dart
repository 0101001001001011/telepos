class MessageFormatter {
  const MessageFormatter();

  String bold(String text) => '*$text*';

  String italic(String text) => '_${text}_';

  String code(String text) => '`$text`';

  String codeBlock(String text, [String? language]) {
    if (language != null) {
      return '```$language\n$text\n```';
    }
    return '```\n$text\n```';
  }

  String link(String text, String url) => '[$text]($url)';

  String strikethrough(String text) => '~$text~';

  String underline(String text) => '__${text}__';

  String reportHeader(String title) {
    return '${bold(title)}\n${"─" * 20}';
  }

  String keyValue(String key, dynamic value) {
    return '$key: ${bold(value.toString())}';
  }

  String bulletList(List<String> items) {
    return items.map((item) => '• $item').join('\n');
  }

  String numberedList(List<String> items) {
    return items
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
  }

  String money(num amount, String currency) {
    final formatted = amount.toStringAsFixed(2);
    return '$formatted $currency';
  }

  String dateTime(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  String date(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  String statusEmoji(bool isOk) => isOk ? '✅' : '❌';

  String percent(double value) => '${value.toStringAsFixed(1)}%';

  String get separator => '\n${"─" * 20}\n';

  String escapeMarkdown(String text) {
    const special = r'_*[]()~`>#+-=|{}.!';
    var escaped = text;
    for (final char in special.split('')) {
      escaped = escaped.replaceAll(char, '\\$char');
    }
    return escaped;
  }

  String formatSaleMessage({
    required int receiptNo,
    required String cashier,
    required num total,
    required String currency,
    required int itemCount,
    required String paymentType,
  }) {
    return '🧾 ${bold("Продажа #$receiptNo")}\n'
        '👤 Кассир: $cashier\n'
        '📦 Позиций: $itemCount\n'
        '💰 Итого: ${bold(money(total, currency))}\n'
        '💳 Оплата: $paymentType';
  }

  String formatRefundMessage({
    required int receiptNo,
    required String cashier,
    required num total,
    required String currency,
    required String reason,
  }) {
    return '🔄 ${bold("Возврат #$receiptNo")}\n'
        '👤 Кассир: $cashier\n'
        '💰 Сумма: ${bold(money(total, currency))}\n'
        '📝 Причина: $reason';
  }

  String formatErrorMessage({
    required String error,
    required String context,
    String? stackTrace,
  }) {
    var msg =
        '🚨 ${bold("Ошибка")}\n'
        '📍 Контекст: $context\n'
        '⚠️ $error';

    if (stackTrace != null) {
      msg += '\n\n${codeBlock(stackTrace)}';
    }

    return msg;
  }
}
