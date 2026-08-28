import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_formatter.dart';

enum ReportType { shift, daily, sales, inventory, cashflow, fiscal }

class GeneratedReport {
  final ReportType type;
  final String title;
  final String content;
  final DateTime generatedAt;
  final Map<String, dynamic>? rawData;

  GeneratedReport({
    required this.type,
    required this.title,
    required this.content,
    required this.generatedAt,
    this.rawData,
  });
}

class ReportGenerator {
  final MessageFormatter _formatter;
  final TdLibLogger _logger;

  ReportGenerator({required TdLibLogger logger, MessageFormatter? formatter})
    : _formatter = formatter ?? const MessageFormatter(),
      _logger = logger;

  GeneratedReport generate(ReportType type, Map<String, dynamic> data) {
    _logger.logConnection('Generating report: ${type.name}');

    switch (type) {
      case ReportType.shift:
        return _generateShiftReport(data);
      case ReportType.daily:
        return _generateDailyReport(data);
      case ReportType.sales:
        return _generateSalesReport(data);
      case ReportType.inventory:
        return _generateInventoryReport(data);
      case ReportType.cashflow:
        return _generateCashflowReport(data);
      case ReportType.fiscal:
        return _generateFiscalReport(data);
    }
  }

  GeneratedReport _generateShiftReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln(_formatter.reportHeader('Z-ОТЧЁТ СМЕНЫ'));
    buffer.writeln();
    buffer.writeln(_formatter.keyValue('Смена №', data['shiftNumber'] ?? '-'));
    buffer.writeln(_formatter.keyValue('Кассир', data['cashier'] ?? '-'));
    buffer.writeln(_formatter.keyValue('Открыта', data['openTime'] ?? '-'));
    buffer.writeln(_formatter.keyValue('Закрыта', data['closeTime'] ?? '-'));
    buffer.writeln();
    buffer.writeln(_formatter.bold('Продажи'));
    buffer.writeln(
      _formatter.keyValue('  Количество', data['salesCount'] ?? 0),
    );
    buffer.writeln(_formatter.keyValue('  Сумма', data['salesTotal'] ?? '0'));
    buffer.writeln();
    buffer.writeln(_formatter.bold('Возвраты'));
    buffer.writeln(
      _formatter.keyValue('  Количество', data['refundsCount'] ?? 0),
    );
    buffer.writeln(_formatter.keyValue('  Сумма', data['refundsTotal'] ?? '0'));
    buffer.writeln();
    buffer.writeln(_formatter.bold('Оплаты'));
    buffer.writeln(
      _formatter.keyValue('  Наличные', data['cashPayments'] ?? '0'),
    );
    buffer.writeln(
      _formatter.keyValue('  Безналичные', data['cardPayments'] ?? '0'),
    );
    buffer.writeln();
    buffer.writeln(_formatter.bold('Касса'));
    buffer.writeln(
      _formatter.keyValue('  В кассе', data['cashInRegister'] ?? '0'),
    );
    buffer.writeln(
      _formatter.keyValue('  Вложения', data['investments'] ?? '0'),
    );
    buffer.writeln(_formatter.keyValue('  Изъятия', data['dividends'] ?? '0'));
    buffer.writeln(_formatter.keyValue('  Расходы', data['expenses'] ?? '0'));

    return GeneratedReport(
      type: ReportType.shift,
      title: 'Z-отчёт смены #${data['shiftNumber']}',
      content: buffer.toString(),
      generatedAt: DateTime.now(),
      rawData: data,
    );
  }

  GeneratedReport _generateDailyReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln(_formatter.reportHeader('ДНЕВНОЙ ОТЧЁТ'));
    buffer.writeln(_formatter.keyValue('Дата', data['date'] ?? '-'));
    buffer.writeln();
    buffer.writeln(_formatter.keyValue('Выручка', data['revenue'] ?? '0'));
    buffer.writeln(_formatter.keyValue('Продаж', data['salesCount'] ?? 0));
    buffer.writeln(
      _formatter.keyValue('Средний чек', data['averageCheck'] ?? '0'),
    );
    buffer.writeln(_formatter.keyValue('Возвратов', data['refundsCount'] ?? 0));
    buffer.writeln(_formatter.keyValue('Смен', data['shiftsCount'] ?? 0));

    return GeneratedReport(
      type: ReportType.daily,
      title: 'Дневной отчёт за ${data['date']}',
      content: buffer.toString(),
      generatedAt: DateTime.now(),
      rawData: data,
    );
  }

  GeneratedReport _generateSalesReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln(_formatter.reportHeader('ОТЧЁТ ПО ПРОДАЖАМ'));
    buffer.writeln(_formatter.keyValue('Период', data['period'] ?? '-'));
    buffer.writeln();
    buffer.writeln(
      _formatter.keyValue('Всего продаж', data['totalSales'] ?? 0),
    );
    buffer.writeln(_formatter.keyValue('Выручка', data['totalRevenue'] ?? '0'));
    buffer.writeln(
      _formatter.keyValue('Средний чек', data['averageCheck'] ?? '0'),
    );
    buffer.writeln();

    final topProducts = data['topProducts'] as List? ?? [];
    if (topProducts.isNotEmpty) {
      buffer.writeln(_formatter.bold('Топ товаров:'));
      buffer.writeln(
        _formatter.numberedList(topProducts.take(10).map((p) => '$p').toList()),
      );
    }

    return GeneratedReport(
      type: ReportType.sales,
      title: 'Отчёт по продажам',
      content: buffer.toString(),
      generatedAt: DateTime.now(),
      rawData: data,
    );
  }

  GeneratedReport _generateInventoryReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln(_formatter.reportHeader('ОТЧЁТ ПО ОСТАТКАМ'));
    buffer.writeln();
    buffer.writeln(
      _formatter.keyValue('Всего позиций', data['totalItems'] ?? 0),
    );
    buffer.writeln(_formatter.keyValue('В наличии', data['inStock'] ?? 0));
    buffer.writeln(_formatter.keyValue('Дефицит', data['outOfStock'] ?? 0));
    buffer.writeln(
      _formatter.keyValue('Низкий остаток', data['lowStock'] ?? 0),
    );

    return GeneratedReport(
      type: ReportType.inventory,
      title: 'Отчёт по остаткам',
      content: buffer.toString(),
      generatedAt: DateTime.now(),
      rawData: data,
    );
  }

  GeneratedReport _generateCashflowReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln(_formatter.reportHeader('ДВИЖЕНИЕ ДЕНЕЖНЫХ СРЕДСТВ'));
    buffer.writeln();
    buffer.writeln(
      _formatter.keyValue('Начальный остаток', data['openingBalance'] ?? '0'),
    );
    buffer.writeln(
      _formatter.keyValue('Наличные продажи', data['cashSales'] ?? '0'),
    );
    buffer.writeln(_formatter.keyValue('Вложения', data['investments'] ?? '0'));
    buffer.writeln(_formatter.keyValue('Расходы', data['expenses'] ?? '0'));
    buffer.writeln(_formatter.keyValue('Изъятия', data['dividends'] ?? '0'));
    buffer.writeln(
      _formatter.keyValue('Конечный остаток', data['closingBalance'] ?? '0'),
    );

    return GeneratedReport(
      type: ReportType.cashflow,
      title: 'Движение денег',
      content: buffer.toString(),
      generatedAt: DateTime.now(),
      rawData: data,
    );
  }

  GeneratedReport _generateFiscalReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln(_formatter.reportHeader('ФИСКАЛЬНЫЙ ОТЧЁТ'));
    buffer.writeln();
    buffer.writeln(
      _formatter.keyValue('Провайдер', data['ofdProvider'] ?? '-'),
    );
    buffer.writeln(
      _formatter.keyValue('Зарегистрировано', data['registeredCount'] ?? 0),
    );
    buffer.writeln(_formatter.keyValue('Ожидают', data['pendingCount'] ?? 0));
    buffer.writeln(_formatter.keyValue('Ошибки', data['errorCount'] ?? 0));
    buffer.writeln(_formatter.keyValue('Сумма НДС', data['totalVat'] ?? '0'));

    return GeneratedReport(
      type: ReportType.fiscal,
      title: 'Фискальный отчёт',
      content: buffer.toString(),
      generatedAt: DateTime.now(),
      rawData: data,
    );
  }
}
