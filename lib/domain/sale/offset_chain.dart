import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';

/// Цепочка зачётов чека: **бонус → QR → сертификат → аванс** — и потолок
/// каждого, посчитанный по этой цепочке **один раз**.
///
/// # Почему функция живёт в домене, а не в раскладке кассы
///
/// До этой правки цепочка была написана прямо внутри
/// `LocalPaymentService._plan` — четырьмя `if (x > room) x = room`,
/// разнесёнными по ста пятидесяти строкам между отказами. Кассе этого
/// хватало. Экрану — нет: кассир, подавший сертификат на 5000 к чеку на
/// 1200, обязан **до** нажатия «Оплатить» увидеть, что спишется 1200, а не
/// 5000, и что наличными доплачивать нечего. Посчитать это экрану было
/// нечем, кроме второй копии тех же четырёх строк.
///
/// Вторая копия — ровно тот дефект, который слияние задач 21, 22 и 23 уже
/// один раз измерило: три автора завели «остаток чека после бонуса» каждый
/// от своего нуля, и одна и та же комната выдавалась трижды. Поэтому
/// цепочка вынута сюда **целиком**, и зовут её оба: касса — чтобы
/// разложить деньги, экран — чтобы показать предпросмотр.
///
/// # Кто прав при расхождении
///
/// **Касса.** Экран кладёт в функцию остатки, которые касса сообщила ему
/// минуту назад; касса — остатки, прочитанные сейчас. Разойдутся они
/// ровно тогда, когда между чтением и оплатой второй чек потратил ту же
/// бумажку или тот же аванс, — и тогда касса разложит по-своему, а
/// условные записи (`CertificateDao.redeem`, `AccountDao.claimCredit`) не
/// дадут потратить одно дважды. Предпросмотр деньгами не становится.
///
/// # Порядок — решение слияния, а не вкусовщина
///
/// Разбор — у блока «Порядок» в `LocalPaymentService._plan`: первым берёт
/// комнату тот, кого урезать дороже. Сгорающий бонус, уже взятые деньги
/// QR, истекающий сертификат, бессрочный аванс.
///
/// Функция чистая: ни базы, ни отказов. Отказы (нет такого сертификата,
/// нет расчётного счёта, вид выключен) остаются у кассы — они про то,
/// **можно ли** зачесть, а здесь только **сколько**.
abstract final class OffsetChain {
  /// Разложить зачёты по чеку на [amount].
  ///
  /// Каждый довод — **сколько этот зачёт готов покрыть сам по себе**, до
  /// оглядки на соседей: [bonus] — просимое, уже урезанное остатком
  /// бонусного счёта; [qr] — деньги намерения; [certificateBalances] —
  /// остатки бумажек в порядке предъявления; [prepayment] — просимое,
  /// уже урезанное внесённым авансом. Урезать по сумме чека и по соседям —
  /// работа этой функции, и больше ничья.
  ///
  /// Отрицательное и нулевое читается как «этого зачёта нет»: бумажка,
  /// которой не досталось комнаты, получает ноль, а не отрицательную
  /// строку.
  static OffsetSplit split({
    required Decimal amount,
    Decimal? bonus,
    Decimal? qr,
    List<Decimal> certificateBalances = const <Decimal>[],
    Decimal? prepayment,
  }) {
    var used = Decimal.zero;

    Decimal take(Decimal? wanted) {
      final room = amount - used;
      if (wanted == null || wanted <= Decimal.zero || room <= Decimal.zero) {
        return Decimal.zero;
      }
      final taken = wanted < room ? wanted : room;
      used += taken;
      return taken;
    }

    final bonusTaken = take(bonus);
    final qrTaken = take(qr);
    // Бумажка берёт `min(остаток, сколько осталось доплатить)` — правило
    // `CertificateApplication.amountFor` (сдачи с сертификата нет, остаток
    // остаётся на нём). Зовётся здесь, а не повторяется: разбор решения
    // живёт в докстринге правила.
    final certificatesTaken = <Decimal>[
      for (final balance in certificateBalances)
        take(
          amount - used <= Decimal.zero
              ? Decimal.zero
              : CertificateApplication.amountFor(
                  balance: balance,
                  toPay: amount - used,
                ),
        ),
    ];
    final prepaymentTaken = take(prepayment);

    return OffsetSplit(
      bonus: bonusTaken,
      qr: qrTaken,
      certificates: List<Decimal>.unmodifiable(certificatesTaken),
      prepayment: prepaymentTaken,
      toPay: amount - used,
    );
  }
}

/// Сколько каждый зачёт покрыл и сколько осталось внести деньгами.
@immutable
class OffsetSplit {
  const OffsetSplit({
    required this.bonus,
    required this.qr,
    required this.certificates,
    required this.prepayment,
    required this.toPay,
  });

  final Decimal bonus;
  final Decimal qr;

  /// По бумажке на каждый предъявленный остаток, в том же порядке. Ноль —
  /// чек был покрыт раньше, и эта бумажка не гасится вовсе.
  final List<Decimal> certificates;

  final Decimal prepayment;

  /// Сколько осталось внести живыми деньгами (или долгом, рассрочкой).
  final Decimal toPay;

  /// Сумма, покрытая всеми сертификатами.
  Decimal get certificate =>
      certificates.fold(Decimal.zero, (sum, part) => sum + part);
}
