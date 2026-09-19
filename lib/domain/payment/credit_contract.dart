import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:telepos/domain/payment/installment_scheduler.dart';

/// Состояние договора — **стабильный код-строка на диске**.
///
/// Тот же довод, что у `CertificateStatus`: индекс члена меняется от
/// перестановки в объявлении, а на диске лежат договоры трёхлетней
/// давности.
enum CreditContractStatus {
  /// Подписан, по нему ещё должны.
  active,

  /// Погашен целиком. Ставится **записью погашения**, а не вычисляется
  /// фильтром: закрытие договора — то, о чём покупателю говорят словами
  /// и что печатают.
  closed,

  /// Отозван: подписан по ошибке. Товар при этом уже отдан, поэтому
  /// отзыв — не удаление, а состояние.
  cancelled;

  String get code => name;

  static CreditContractStatus? byCode(String? value) {
    for (final v in values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

/// Кредитный договор — **то, что подписано, и ничего сверх**.
///
/// # Граница с банковским модулем, названная явно
///
/// Она проходит по слову «подписано»:
///
/// * **Касса делает**: заводит договор с зафиксированным графиком,
///   связывает его с чеком, записывает поступления по нему, считает
///   остаток и просрочку **из хранимых строк**, печатает договор.
/// * **Касса не делает**: скоринг и одобрение покупателя, начисление
///   процентов во времени, пени и штрафы за просрочку, реструктуризацию,
///   уступку долга, разговор с банком-кредитором.
///
/// Одним предложением: **касса хранит подписанный график и то, что по
/// нему заплачено; всё, что меняет график после подписи, — банковский
/// модуль.**
///
/// Отсюда и решение хранить график строками ([InstallmentScheduleLine]),
/// а не формулой: строка — это подписанное, формула — это то, что можно
/// пересчитать иначе. Всё, что умеет пересчитывать, лежит по ту сторону
/// границы.
///
/// # Надбавки у договоров, заключённых кассой, нет — и это ответ, а не
/// упущение
///
/// [feeTotal] в модели есть, потому что подписанный договор может её
/// содержать (перенос из банковского модуля, импорт тиража), и график
/// обязан уметь такой договор представить. Но продажа в рассрочку на
/// кассе заводит договор с **нулевой** надбавкой, и довод измерим: чек,
/// уехавший оператору на 10 000, при надбавке 1 500 означал бы 1 500
/// тенге, полученных кассой **без единого фискального документа**.
/// Оператор пересчитывает `Σ line == Σ payments` с нулевым допуском и
/// про эти 1 500 не знает ничего.
///
/// Надбавка розничной рассрочки живёт в **цене товара** — там она уже
/// фискализована. Кассе остаётся продать по цене чека.
@immutable
class CreditContract {
  const CreditContract({
    required this.id,
    required this.number,
    required this.agentLocalId,
    required this.receivableAccountId,
    required this.receiptNo,
    required this.posId,
    required this.principal,
    required this.feeTotal,
    required this.downPayment,
    required this.termMonths,
    required this.scheme,
    required this.status,
    required this.signedAt,
    this.signedByUserId,
  });

  final int id;

  /// Номер договора. **Выдаёт касса**, а не оператор руками (шаг 5).
  ///
  /// Собирается из номера чека и номера кассы
  /// (`CreditContractNumber.of`) — своего счётчика у договора **нет и не
  /// надо**: счётчик чеков (`ReceiptNumbers.withNext`) уже закрепляет
  /// номер атомарно, и второй счётчик рядом был бы вторым ответом на
  /// вопрос «какой это договор». Номер, введённый руками, повторяется, а
  /// по нему ищут погашение.
  final String number;

  /// Должник.
  final int agentLocalId;

  /// Счёт, на котором лежит задолженность, — **снимок на момент
  /// заключения** (шаг 4).
  ///
  /// Не ссылка на живое поле агента (`Agents.mainAccountId`): счёт могут
  /// сменить, а долг обязан остаться там, где записан. Иначе погашение
  /// договора трёхлетней давности двигало бы счёт, которого в момент
  /// подписи не существовало.
  final int receivableAccountId;

  final int receiptNo;

  final int posId;

  /// Сумма, отданная в рассрочку. Равна строке оплаты вида
  /// `installment` в чеке — и это проверяется, а не подразумевается.
  final Decimal principal;

  /// Надбавка целиком. У договоров, заключённых кассой, — ноль; разбор в
  /// докстринге класса.
  final Decimal feeTotal;

  /// Первый взнос: сколько покупатель отдал на кассе деньгами.
  ///
  /// В график не входит — он уже уплачен. Хранится затем, чтобы
  /// напечатанный договор сходился с чеком без обращения к чеку.
  final Decimal downPayment;

  final int termMonths;

  final InstallmentScheme scheme;

  final CreditContractStatus status;

  /// Секунды эпохи.
  final int signedAt;

  final int? signedByUserId;

  /// Сколько покупатель должен по договору всего: тело плюс надбавка.
  Decimal get totalPayable => principal + feeTotal;

  bool get isLive => status == CreditContractStatus.active;

  @override
  String toString() =>
      'CreditContract($number, $totalPayable за $termMonths мес., '
      '${status.code})';
}

/// Номер договора — **одно выражение на дерево**.
///
/// Разбор, почему своего счётчика нет, — в докстринге
/// [CreditContract.number].
abstract final class CreditContractNumber {
  static String of({required int receiptNo, required int posId}) =>
      'РС-$posId-$receiptNo';
}

/// Строка графика вместе с тем, что по ней уже заплачено.
@immutable
class CreditScheduleEntry {
  const CreditScheduleEntry({
    required this.id,
    required this.contractId,
    required this.seq,
    required this.dueDate,
    required this.principalDue,
    required this.feeDue,
    required this.paid,
  });

  final int id;
  final int contractId;
  final int seq;
  final int dueDate;
  final Decimal principalDue;
  final Decimal feeDue;

  /// Сколько по этой строке уже внесено.
  ///
  /// Увеличивается **условной записью** `CreditDao.allocate` и только ею:
  /// между чтением и записью открывается ровно то окно, ради которого
  /// условная запись и заведена.
  final Decimal paid;

  Decimal get totalDue => principalDue + feeDue;

  Decimal get outstanding {
    final rest = totalDue - paid;
    return rest > Decimal.zero ? rest : Decimal.zero;
  }

  bool get isSettled => paid >= totalDue;

  /// Просрочена ли строка на момент [asOf].
  ///
  /// **Вычисляется, не хранится** (шаг 3). Фоновой работы, переживающей
  /// выключение питания, в дереве нет, и завести её значит завести вторую
  /// правду, расходящуюся с первой каждый раз, когда касса не работала
  /// сутки.
  bool isOverdueAt(int asOf) => !isSettled && dueDate < asOf;

  @override
  String toString() =>
      'CreditScheduleEntry($contractId/$seq, $paid из $totalDue)';
}

/// Что известно о договоре на момент `asOf` — **чистая функция от
/// хранимых строк**.
///
/// Ни одно поле здесь не лежит на диске, и это главное решение про
/// просрочку. Хранимая просрочка обязана кем-то обновляться; обновлять её
/// некому (фоновой работы в дереве нет), и на кассе, простоявшей
/// выключенной неделю, хранимое значение врало бы ровно неделю — молча и
/// в ту сторону, в которую дороже.
@immutable
class CreditStanding {
  const CreditStanding({
    required this.outstanding,
    required this.overdueAmount,
    required this.overdueEntries,
    required this.nextDueDate,
    required this.nextDueAmount,
  });

  /// Сколько осталось заплатить по договору целиком.
  final Decimal outstanding;

  /// Сколько из этого просрочено.
  final Decimal overdueAmount;

  /// Сколько строк графика просрочено.
  final int overdueEntries;

  /// Ближайший срок платежа. `null` — платить больше нечего.
  final int? nextDueDate;

  /// Сколько по ближайшему сроку. Ноль, если платить нечего.
  final Decimal nextDueAmount;

  bool get isOverdue => overdueEntries > 0;

  bool get isSettled => outstanding <= Decimal.zero;

  /// Посчитать по строкам графика.
  static CreditStanding of(List<CreditScheduleEntry> entries, int asOf) {
    var outstanding = Decimal.zero;
    var overdue = Decimal.zero;
    var overdueCount = 0;
    int? nextDue;
    var nextAmount = Decimal.zero;

    for (final e in entries) {
      final rest = e.outstanding;
      if (rest <= Decimal.zero) continue;
      outstanding += rest;
      if (e.isOverdueAt(asOf)) {
        overdue += rest;
        overdueCount++;
      }
      if (nextDue == null || e.dueDate < nextDue) {
        nextDue = e.dueDate;
        nextAmount = rest;
      } else if (e.dueDate == nextDue) {
        nextAmount += rest;
      }
    }

    return CreditStanding(
      outstanding: outstanding,
      overdueAmount: overdue,
      overdueEntries: overdueCount,
      nextDueDate: nextDue,
      nextDueAmount: nextAmount,
    );
  }
}

/// Договор вместе с графиком — то, что отдаёт чтение и печать.
@immutable
class CreditContractView {
  const CreditContractView({
    required this.contract,
    required this.schedule,
  });

  final CreditContract contract;
  final List<CreditScheduleEntry> schedule;

  CreditStanding standingAt(int asOf) => CreditStanding.of(schedule, asOf);
}

/// Черновик договора: всё, что раскладка оплаты знает о рассрочке **до**
/// того, как чек получил номер.
///
/// Отдельный тип, а не заполненный наполовину [CreditContract]: у
/// договора нет ни номера, ни ид, ни строк графика, пока чек не записан,
/// и объект, у которого половина полей «пока неправда», — это способ
/// прочитать неправду.
@immutable
class CreditContractDraft {
  const CreditContractDraft({
    required this.agentLocalId,
    required this.receivableAccountId,
    required this.principal,
    required this.feeTotal,
    required this.downPayment,
    required this.termMonths,
    required this.scheme,
  });

  final int agentLocalId;
  final int receivableAccountId;
  final Decimal principal;
  final Decimal feeTotal;
  final Decimal downPayment;
  final int termMonths;
  final InstallmentScheme scheme;

  @override
  String toString() =>
      'CreditContractDraft($principal + $feeTotal, $termMonths мес., '
      '${scheme.code})';
}

/// Чем кончилось погашение.
@immutable
class CreditRepayment {
  const CreditRepayment({
    required this.contractNumber,
    required this.allocated,
    required this.standing,
    required this.closed,
  });

  final String contractNumber;

  /// Сколько разнесено по графику. Равно внесённому: переплату касса
  /// **отвергает**, а не превращает во что-то другое молча.
  final Decimal allocated;

  /// Что стало с договором после разнесения.
  final CreditStanding standing;

  /// Договор закрылся этим платежом.
  final bool closed;
}
