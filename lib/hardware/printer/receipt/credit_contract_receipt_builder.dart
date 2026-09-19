import 'package:decimal/decimal.dart';

import 'package:telepos/domain/payment/credit_contract.dart';

/// Печатная форма кредитного договора — задача 24.
///
/// # Что печатается и почему именно это
///
/// Договор — то, что покупатель **подписывает**, и потому на бумаге стоит
/// ровно то, что лежит в базе строками: номер, стороны, тело, первый
/// взнос, срок, схема и **весь график поимённо**. Ни одно число здесь не
/// вычисляется формулой на месте — все берутся из [CreditContractView],
/// то есть из подписанного.
///
/// Это не украшение: пересчёт на печати рано или поздно дал бы другое
/// число (сменилось правило округления, сменилась версия), и бумага
/// разошлась бы с базой. Разошедшуюся бумагу подписывают.
///
/// # Итог складывается ИЗ СТРОК ГРАФИКА, а не берётся у договора
///
/// `contract.totalPayable` дал бы то же число — сегодня. Два числа под
/// одно значение это способ однажды напечатать договор, у которого итог
/// не сходится с собственной таблицей; складывая таблицу, форма печатает
/// ровно то, что в ней стоит, и разойтись им негде.
///
/// # Чего здесь нет
///
/// Просрочки, пеней и остатка на сегодня. Договор печатается **в момент
/// подписи**, и «просрочено: 0» на нём было бы утверждением о будущем.
/// Текущее состояние показывает экран договоров, где оно и вычисляется
/// (`CreditStanding`).
/// # Почему это не `ReceiptBuilder`
///
/// Форма договора **на бумагу не уходит**: экран договоров
/// (`credit_contracts_screen.dart:307`) берёт у неё [toDebugString] и
/// показывает текст в диалоге. Единственный её вызывающий — этот экран
/// (измерено 2026-09-19).
///
/// Отсюда снят `build()`, объявленный интерфейсом `ReceiptBuilder`: он
/// отдавал `utf8.encode(toDebugString())`, то есть байты UTF-8 принтеру,
/// который `EscPosCommands.init` переключает на CP866. Позови его кто-нибудь
/// — и договор вышел бы крокозябрами. Мёртвый метод, выглядящий живым и
/// готовый напечатать мусор, опаснее отсутствующего: интерфейс обещал, что
/// форма умеет на бумагу.
class CreditContractReceiptBuilder {
  CreditContractReceiptBuilder({
    required this.view,
    required this.companyName,
    this.customerName,
    this.paperWidth = 48,
  });

  final CreditContractView view;
  final String companyName;
  final String? customerName;
  final int paperWidth;

  static const List<String> _monthNames = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  static String _date(int epochSeconds) {
    final at = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return '${at.day.toString().padLeft(2, '0')}.'
        '${at.month.toString().padLeft(2, '0')}.${at.year}';
  }

  String toDebugString() {
    final c = view.contract;
    final sb = StringBuffer();
    final line = '=' * paperWidth;
    final thin = '-' * paperWidth;

    sb.writeln(line);
    sb.writeln(_center(companyName));
    sb.writeln(_center('ДОГОВОР РАССРОЧКИ'));
    sb.writeln(_center('№ ${c.number}'));
    sb.writeln(line);
    sb.writeln('Дата: ${_date(c.signedAt)}');
    if (customerName != null) {
      sb.writeln('Покупатель: $customerName');
    }
    sb.writeln('Чек: ${c.receiptNo} (касса ${c.posId})');
    sb.writeln(thin);
    sb.writeln(_pair('Первый взнос', '${c.downPayment}'));
    sb.writeln(_pair('Сумма рассрочки', '${c.principal}'));
    if (c.feeTotal > Decimal.zero) {
      // Печатается только когда она есть: строка «Надбавка: 0» на
      // розничной рассрочке — обещание, которого никто не давал.
      sb.writeln(_pair('Надбавка', '${c.feeTotal}'));
    }
    sb.writeln(_pair('Срок, месяцев', '${c.termMonths}'));
    sb.writeln(_pair('Схема', c.scheme.label));
    sb.writeln(thin);
    sb.writeln('ГРАФИК ПЛАТЕЖЕЙ');
    sb.writeln(thin);
    for (final e in view.schedule) {
      final at = DateTime.fromMillisecondsSinceEpoch(e.dueDate * 1000);
      final when =
          '${e.seq + 1}. ${at.day.toString().padLeft(2, ' ')} '
          '${_monthNames[at.month - 1]} ${at.year}';
      sb.writeln(_pair(when, '${e.totalDue}'));
    }
    sb.writeln(thin);
    final total = view.schedule.fold(
      Decimal.zero,
      (Decimal sum, e) => sum + e.totalDue,
    );
    sb.writeln(_pair('ИТОГО К ОПЛАТЕ', '$total'));
    sb.writeln(line);
    sb.writeln('Подпись покупателя: ____________________');
    sb.writeln(line);
    return sb.toString();
  }

  String _center(String text) {
    if (text.length >= paperWidth) return text;
    final pad = (paperWidth - text.length) ~/ 2;
    return ' ' * pad + text;
  }

  String _pair(String left, String right) {
    final space = paperWidth - left.length - right.length;
    if (space < 1) return '$left $right';
    return '$left${' ' * space}$right';
  }
}
