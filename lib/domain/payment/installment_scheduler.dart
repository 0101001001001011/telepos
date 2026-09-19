import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:telepos/domain/money/money_millis.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Как рассрочка раскладывается по месяцам — **три схемы, и различаются
/// они только распределением надбавки**.
///
/// Общая сумма у всех трёх одна и та же: `principal + feeTotal`. Иначе
/// схема была бы не формой договора, а способом изменить цену, и выбор
/// схемы кассиром менял бы то, сколько покупатель должен, — то есть
/// раскладка стала бы вторым ценником.
///
/// Значения лежат на диске **стабильным кодом-строкой** ([code]), а не
/// индексом члена: тот же довод, что у `CertificateStatus` и
/// `PaymentKinds.fiscalTreatment` — индекс меняется от перестановки в
/// объявлении, а на диске лежат договоры, подписанные три года назад.
enum InstallmentScheme {
  /// Равные платежи: и тело, и надбавка делятся поровну.
  ///
  /// Розничная «0-0-12». Самая частая и потому первая.
  equalInstalments,

  /// Равное тело, надбавка по убывающему остатку.
  ///
  /// Платежи убывают: в первом месяце покупатель пользуется всей суммой,
  /// в последнем — одной N-й, и надбавка это отражает. Вес месяца `i` —
  /// `N − i`.
  differentiated,

  /// Надбавка целиком в первом платеже, тело поровну.
  ///
  /// Так продают там, где надбавка — это разовая комиссия за оформление,
  /// а не плата за время. Отдельная схема, а не «differentiated с одним
  /// месяцем»: срок у договора всё равно N месяцев.
  feeUpfront;

  /// Стабильный код на диске и на проводе. Совпадает с [name].
  String get code => name;

  /// Как схема называется человеку — **одно место на дерево**.
  ///
  /// Экран выбора и печатная форма договора обязаны называть её
  /// одинаково: кассир выбирает «Убывающими платежами», покупатель
  /// подписывает бумагу, где написано то же самое. Два списка названий
  /// разошлись бы молча, и подписанное отличалось бы от выбранного одним
  /// словом — а спорить потом пришлось бы с подписью.
  ///
  /// Здесь, а не в `l10n`, по измеренной причине: договор — документ на
  /// языке договора, и переводить его вместе с интерфейсом значило бы
  /// печатать разные бумаги в зависимости от того, какой язык кассир
  /// выбрал себе на экране.
  String get label => switch (this) {
    InstallmentScheme.equalInstalments => 'Равными платежами',
    InstallmentScheme.differentiated => 'Убывающими платежами',
    InstallmentScheme.feeUpfront => 'Надбавка первым платежом',
  };

  static InstallmentScheme? byCode(String? value) {
    for (final v in values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

/// Одна строка подписанного графика.
///
/// **Хранится строкой, а не выводится формулой** — шаг 2 задачи 24.
/// Аннуитет с округлением даёт остаток, который ложится в последний
/// платёж; пересчёт формулой на каждом чтении рано или поздно даст другое
/// число (сменилась версия, сменилось правило округления, сменился знак
/// после запятой), и оно **разойдётся с подписанным**. Хранение строк —
/// это хранение подписанного.
@immutable
class InstallmentScheduleLine {
  const InstallmentScheduleLine({
    required this.seq,
    required this.dueDate,
    required this.principalDue,
    required this.feeDue,
  });

  /// Номер в графике, **от нуля**. По нему и только по нему разносится
  /// погашение (FIFO, шаг 6 задачи 24).
  final int seq;

  /// Когда платёж должен быть внесён. Секунды эпохи — тем же масштабом,
  /// что `payments.time` и `gift_certificates.expiresAt`.
  final int dueDate;

  final Decimal principalDue;

  final Decimal feeDue;

  Decimal get totalDue => principalDue + feeDue;

  @override
  bool operator ==(Object other) =>
      other is InstallmentScheduleLine &&
      other.seq == seq &&
      other.dueDate == dueDate &&
      other.principalDue == principalDue &&
      other.feeDue == feeDue;

  @override
  int get hashCode => Object.hash(seq, dueDate, principalDue, feeDue);

  @override
  String toString() =>
      'InstallmentScheduleLine($seq, $dueDate, $principalDue + $feeDue)';
}

/// Срок вне допустимых значений.
const creditTermInvalidCode = 'credit_term_invalid';

/// Сумма договора не положительна: рассрочка на ноль — не договор.
const creditPrincipalInvalidCode = 'credit_principal_invalid';

/// Надбавка отрицательна.
const creditFeeInvalidCode = 'credit_fee_invalid';

/// Построение графика — **вся арифметика рассрочки, и она целыми
/// тысячными**.
///
/// # Почему не `Decimal` посередине
///
/// Потому что деление денег на N месяцев в общем случае не заканчивается:
/// `10000.001 / 3` — бесконечная дробь, и `Decimal` потребует назвать
/// точность. Названная точность — это округление, а округление,
/// применённое к каждой строке независимо, **теряет остаток**: три раза
/// по `3333.333` дают `9999.999`, и одна тысячная исчезает из
/// подписанного договора. На двадцати четырёх месяцах и трёх схемах таких
/// потерь набирается больше.
///
/// Целые тысячные ([MoneyMillis]) снимают вопрос: деление целых точно,
/// остаток от деления виден числом, и его **некуда потерять** — он
/// кладётся в последний платёж.
///
/// # Одно правило округления на все три схемы и на обе составляющие
///
/// **Каждая строка усекается вниз; последняя забирает всё, что ещё не
/// роздано.** Одно предложение, применённое к телу и к надбавке
/// раздельно, — и `Σ principalDue == principal`, `Σ feeDue == feeTotal`
/// держатся **по построению**, а не проверкой.
///
/// Второе правило («остаток в первый платёж», «остаток по крупнейшим
/// дробям») было бы вторым ответом на тот же вопрос: две схемы округляли
/// бы по-разному, и один и тот же договор, перестроенный другой схемой,
/// давал бы другой последний платёж. Ровно так расходятся две правды.
///
/// Цена названа: у [InstallmentScheme.differentiated] последняя строка
/// надбавки может оказаться на несколько тысячных больше предыдущей —
/// убывание нарушается в четвёртом знаке. Это видно глазом на бумаге и
/// стоит меньше, чем потерянный остаток.
///
/// # Даты: месяц прибавляется с прижатием к концу месяца
///
/// `DateTime(y, m + 1, 31)` в Dart **переполняется в следующий месяц**:
/// 31 января плюс месяц даёт 3 марта. Договор, подписанный 31 января на
/// 12 месяцев, получил бы график, в котором февраля нет вовсе, а март
/// встречается дважды. Поэтому день прижимается к последнему дню целевого
/// месяца ([_addMonths]), и 31 января + 1 месяц это 28 (или 29) февраля.
abstract final class InstallmentScheduler {
  /// Допустимые сроки — **закрытый список, а не «любое положительное»**.
  ///
  /// Срок в 1000 месяцев — это не рассрочка, а тысяча строк в базе на
  /// один чек и опечатка кассира, которую никто не заметит до первой
  /// печати. Список тот же, по которому меряется сторож задачи 24.
  static const List<int> allowedTerms = <int>[3, 6, 12, 24];

  /// Построить график.
  ///
  /// Отказы приходят **значением** (`WireRefusal`, I144), а не
  /// исключением наружу.
  static List<InstallmentScheduleLine> build({
    required Decimal principal,
    required Decimal feeTotal,
    required int termMonths,
    required DateTime firstDueDate,
    required InstallmentScheme scheme,
  }) {
    if (!allowedTerms.contains(termMonths)) {
      throw WireRefusal(
        creditTermInvalidCode,
        'срок рассрочки $termMonths — не из числа допустимых '
        '(${allowedTerms.join(', ')})',
      );
    }
    if (principal <= Decimal.zero) {
      throw WireRefusal(
        creditPrincipalInvalidCode,
        'сумма рассрочки $principal не положительна',
      );
    }
    if (feeTotal < Decimal.zero) {
      throw WireRefusal(
        creditFeeInvalidCode,
        'надбавка $feeTotal отрицательна',
      );
    }

    final principalMillis = MoneyMillis.of(principal);
    final feeMillis = MoneyMillis.of(feeTotal);

    final principalParts = _spreadEvenly(principalMillis, termMonths);
    final feeParts = switch (scheme) {
      InstallmentScheme.equalInstalments => _spreadEvenly(
        feeMillis,
        termMonths,
      ),
      InstallmentScheme.differentiated => _spreadByDecliningWeight(
        feeMillis,
        termMonths,
      ),
      InstallmentScheme.feeUpfront => _spreadUpfront(feeMillis, termMonths),
    };

    return <InstallmentScheduleLine>[
      for (var i = 0; i < termMonths; i++)
        InstallmentScheduleLine(
          seq: i,
          dueDate:
              _addMonths(firstDueDate, i).millisecondsSinceEpoch ~/ 1000,
          principalDue: MoneyMillis.amount(principalParts[i]),
          feeDue: MoneyMillis.amount(feeParts[i]),
        ),
    ];
  }

  /// Поровну, остаток — в последнюю строку.
  static List<int> _spreadEvenly(int total, int parts) {
    if (parts == 1) return <int>[total];
    final base = total ~/ parts;
    return <int>[
      for (var i = 0; i < parts - 1; i++) base,
      total - base * (parts - 1),
    ];
  }

  /// По убывающему весу `N, N−1, … 1`; остаток — в последнюю строку.
  ///
  /// Веса, а не «процент на остаток»: ставки у договора нет, у него есть
  /// **названная надбавка целиком**, и распределить её по времени
  /// пользования — то же самое, что распределить по остатку тела.
  static List<int> _spreadByDecliningWeight(int total, int parts) {
    if (parts == 1) return <int>[total];
    final weightSum = parts * (parts + 1) ~/ 2;
    var handed = 0;
    final out = <int>[];
    for (var i = 0; i < parts - 1; i++) {
      final share = total * (parts - i) ~/ weightSum;
      out.add(share);
      handed += share;
    }
    out.add(total - handed);
    return out;
  }

  /// Вся надбавка в первую строку.
  static List<int> _spreadUpfront(int total, int parts) => <int>[
    total,
    for (var i = 1; i < parts; i++) 0,
  ];

  /// Прибавить [months] месяцев, **прижав день к концу месяца**.
  ///
  /// Разбор — в докстринге класса. Проверяется
  /// `installment_scheduler_test`, случай «31 января, 12 месяцев».
  static DateTime _addMonths(DateTime from, int months) {
    if (months == 0) return from;
    final rawMonth = from.month - 1 + months;
    final year = from.year + rawMonth ~/ 12;
    final month = rawMonth % 12 + 1;
    // Нулевой день следующего месяца — это последний день целевого:
    // приём Dart, а не арифметика високосных лет своими руками.
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = from.day < lastDay ? from.day : lastDay;
    return DateTime(
      year,
      month,
      day,
      from.hour,
      from.minute,
      from.second,
    );
  }
}
