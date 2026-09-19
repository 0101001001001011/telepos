/// Ограничитель частоты проверок подарочного сертификата по проводу.
///
/// # Дыра, которую он закрывает (2026-09-13)
///
/// `pay.certificate` отвечает «нет такого номера» (`certificate_unknown`)
/// иначе, чем «ПИН не подошёл» (`certificate_pin_wrong`), и отвечает сразу.
/// Сеанс кассира со скриптом перебирал номера, а на найденном — ПИН, без
/// единой задержки: докстринг `PayOps.certificate` называл это пределом
/// («ограничителя частоты на проводе нет ни у одной операции»). Той же
/// дырой был и `pay.complete` с выдуманными сертификатами — дороже на чек в
/// работе, но без предела; ограничитель стоит на **обеих** операциях, иначе
/// предел одной был бы дверью в другую.
///
/// # Образец — `LoginThrottle`, и чем этот ограничитель от него отличается
///
/// Общее — не только идея, а код: счёт ведёт [FailureLedger] (вынесен из
/// `LoginThrottle` в тот же день), ключи — строки с префиксом рода, счёт
/// растёт синхронно **до** проверки (параллельный залп не проскакивает мимо
/// счёта, пункт 2 второго круга задачи 7), уборка ленивая, часы подменяемы.
///
/// Разница — в том, что делается со счётом. `LoginThrottle` **задерживает**
/// и никогда не отказывает: там ключ — имя кассира, видное на экране входа,
/// и замок по нему запирал бы честного кассира снаружи (задача 7). Здесь
/// бриф требует отказа названной причиной, и цена замка названа и
/// ограничена:
///
/// - **Запереть можно сертификат, а не кассу.** Замок по номеру отказывает
///   гашению этой бумажки на [window]. Сделать это может только владелец
///   живого сеанса кассира (`nav.sale`), и его собственный замок
///   ([perCashier]) наступает раньше, чем он успеет запереть больше двух
///   номеров за окно.
/// - **Задержка здесь не годилась бы.** Перебор ПИНа идёт по разным
///   номерам и с разных сеансов параллельно; задержка на ответ, не
///   ограничивающая числа попыток, ограничила бы только терпение скрипта.
///
/// # Три ключа, и зачем каждый
///
/// - `u:<userId>` — кассир сеанса. Не выбирается нападающим: новый кассир —
///   это новый PIN, а вход сам под `LoginThrottle`. Без сеанса (пробы,
///   голый вызов) — `s:<sessionKey>`.
/// - `t:<terminalId>` — рабочее место сеанса: два кассира за одним
///   терминалом не перебирают вдвое быстрее.
/// - `n:<номер>` — сертификат. **Единственный ключ, общий для разных
///   сеансов**: перебор ПИНа одного номера с десяти терминалов упирается в
///   него, а не в десять разных счётчиков.
///
/// # Что считается неудачей
///
/// Счёт растёт на **каждой** попытке до проверки, а после неё возвращается
/// ([CertificateAttempt.settle]) всем, кроме двух исходов — нет номера и не
/// тот ПИН. Эти два считаются **одинаково**: иначе сам замок стал бы
/// оракулом существования номера (выдуманный номер не запирался бы).
///
/// Успех возвращает **свою** единицу, а не стирает ключ
/// ([FailureLedger.giveBack]): у `LoginThrottle` успешный вход сбрасывает
/// счёт целиком, и здесь это было бы дырой — нападающий с одной настоящей
/// бумажкой перемежал бы неудачи успехами и обнулял счёт номера, накопленный
/// чужими сеансами.
///
/// # Величины
///
/// - [perNumber] = 5 неудач на номер за [window]. Кассир ошибается номером
///   или ПИНом раз-два; пять — с запасом на плохо пропечатанную бумажку.
///   Четырёхзначный ПИН (10⁴) при пяти попытках за 15 минут — **500 часов**
///   (≈ 21 сутки) непрерывного полного перебора одного номера, с любого числа
///   терминалов.
/// - [perCashier] = [perTerminal] = 10 неудач за [window]: перебор номеров
///   одним кассиром — 40 номеров в час.
/// - [window] = 15 минут от последней неудачи по ключу. Отказанная замком
///   попытка до проверки не доходит и счёта не растит — окно не
///   продлевается тем, кто стучится в запертое.
library;

import 'dart:async';

import 'package:telepos/backend/failure_ledger.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Ключ зоны «попытка уже допущена замком» — докстринг
/// [CertificateThrottle.guard], «вложенный вызов». Объект, а не строка:
/// совпасть с чужим ключом зоны он не может.
final _admittedZoneKey = Object();

/// Исходы проверки, которые считаются подбором: не та бумажка, не те цифры
/// и не набранные цифры.
///
/// «Нужен ПИН» здесь с 2026-09-15 и по тому же доводу, что «нет номера»:
/// исход, не растящий счёт, был бы бесплатной пробой — пустой ПИН отличал бы
/// настоящий номер (счёт не растёт) от выдуманного (растёт), и замок сам
/// стал бы оракулом.
const certificateGuessCodes = <String>{
  certificateUnknownCode,
  certificatePinWrongCode,
  certificatePinRequiredCode,
};

/// Запирание, о котором замок сообщает наружу — пункт 4 A7.
///
/// Без номера сертификата: журнал безопасности пишет, **кто** упёрся и в
/// какой счёт ([axes]), а не какую бумажку подбирали.
final class CertificateLock {
  const CertificateLock({
    required this.userId,
    required this.terminalId,
    required this.axes,
  });

  final int? userId;
  final int? terminalId;

  /// Какие счёты заперты: `number`, `cashier`, `terminal`.
  final Set<String> axes;
}

class CertificateThrottle {
  CertificateThrottle({
    this.perNumber = 5,
    this.perCashier = 10,
    this.perTerminal = 10,
    this.window = const Duration(minutes: 15),
    this.onLocked,
    DateTime Function()? clock,
  }) : _ledger = FailureLedger(staleAfter: window, clock: clock);

  final int perNumber;
  final int perCashier;
  final int perTerminal;
  final Duration window;
  final FailureLedger _ledger;

  /// Сообщение о запирании — журнал безопасности на кассе
  /// (`certificateLockJournalHandler`, пункт 4 A7).
  ///
  /// Зовётся **один раз на запирание ключа**, а не на каждую отказанную
  /// попытку: пока ключ заперт, время его последней неудачи не движется
  /// (отказанная попытка счёта не растит), и по нему видно, что об этом
  /// запирании уже сказано ([_reported]). Иначе стук в запертое растил бы
  /// журнал без предела — та же беда, что закрыта склейкой у `wire.denied`.
  ///
  /// Синхронный и не ждётся: улика не имеет права задержать отказ.
  final void Function(CertificateLock lock)? onLocked;

  /// Ключ → время последней неудачи, при котором о его запирании сказано.
  final Map<String, DateTime> _reported = {};

  /// Допустить попытку или отказать [certificateRateLimitedCode].
  ///
  /// Синхронно от первой строки до последней: проверка замков и рост счёта
  /// не разделены `await`, и параллельный залп видит счёт, накрученный
  /// предыдущими попытками залпа.
  ///
  /// [numbers] — все номера попытки (у `pay.complete` их может быть
  /// несколько); пустые номера ключа не заводят.
  CertificateAttempt admit({
    required int? userId,
    required int? sessionKey,
    required int? terminalId,
    required Iterable<String> numbers,
  }) {
    _ledger.forgetStale();
    _reported.removeWhere((key, _) => _ledger.countOf(key) == 0);

    final limits = <String, int>{
      userId != null ? 'u:$userId' : 's:${sessionKey ?? '-'}': perCashier,
      if (terminalId != null) 't:$terminalId': perTerminal,
      for (final raw in numbers)
        if (raw.trim().isNotEmpty) 'n:${raw.trim()}': perNumber,
    };

    final now = _ledger.now();
    Duration? wait;
    final freshlyLocked = <String>{};
    for (final MapEntry(:key, value: limit) in limits.entries) {
      if (_ledger.countOf(key) < limit) continue;
      final touched = _ledger.touchedAt(key)!;
      final left = window - now.difference(touched);
      if (wait == null || left > wait) wait = left;
      if (_reported[key] != touched) {
        _reported[key] = touched;
        freshlyLocked.add(key);
      }
    }
    if (wait != null) {
      final report = onLocked;
      if (report != null && freshlyLocked.isNotEmpty) {
        report(
          CertificateLock(
            userId: userId,
            terminalId: terminalId,
            axes: {
              for (final key in freshlyLocked)
                switch (key[0]) {
                  'n' => 'number',
                  't' => 'terminal',
                  _ => 'cashier',
                },
            },
          ),
        );
      }
      final minutes = (wait.inSeconds / 60).ceil().clamp(1, 1 << 20);
      throw WireRefusal(
        certificateRateLimitedCode,
        'слишком много неудачных проверок сертификата — повторите через '
        '$minutes мин',
      );
    }

    for (final key in limits.keys) {
      _ledger.add(key, now);
    }
    return CertificateAttempt._(_ledger, limits.keys.toList());
  }

  /// Пропускает проверку [check] через замок: допуск, проверка, расчёт.
  ///
  /// # Вложенный вызов (пункт 5 A7, 2026-09-15)
  ///
  /// Попытка, уже допущенная замком, изнутри своей проверки второй раз не
  /// допускается: вложенный `guard` зовёт [check] сразу. Так провод
  /// (`TillOperations`) может звать `PaymentService`, который сам под замком
  /// (`ThrottledPaymentService` — касса мимо провода), и попытка считается
  /// одной, а не двумя. Без этого предел номера на проводе сжимался бы вдвое
  /// ровно на той сборке, где обёртка стоит, — то есть на настоящей кассе.
  ///
  /// Признак — значение зоны, а не поле: параллельные попытки разных
  /// сеансов идут в разных зонах и друг друга не пропускают.
  Future<T> guard<T>({
    required int? userId,
    required int? sessionKey,
    required int? terminalId,
    required Iterable<String> numbers,
    required Future<T> Function() check,
  }) async {
    if (Zone.current[_admittedZoneKey] == true) return check();
    final attempt = admit(
      userId: userId,
      sessionKey: sessionKey,
      terminalId: terminalId,
      numbers: numbers,
    );
    var guessed = false;
    String? subject;
    try {
      return await runZoned(check, zoneValues: {_admittedZoneKey: true});
    } on WireRefusal catch (refusal) {
      guessed = certificateGuessCodes.contains(refusal.code);
      subject = refusal.subject;
      rethrow;
    } finally {
      attempt.settle(guessed: guessed, subject: subject);
    }
  }
}

/// Допущенная попытка: её единицы в счёте до расчёта.
final class CertificateAttempt {
  CertificateAttempt._(this._ledger, this._keys);

  final FailureLedger _ledger;
  final List<String> _keys;
  var _settled = false;

  /// [guessed] — проверка кончилась подбором (`certificateGuessCodes`):
  /// единицы кассира и рабочего места остаются. Иначе каждая возвращается —
  /// одна, своя.
  ///
  /// # Номера заявки (пункт 6 A7, 2026-09-15)
  ///
  /// У подбора остаётся единица **только того номера**, что назван
  /// [subject] (`WireRefusal.subject`); остальные номера попытки свою
  /// получают назад. До этого дня неудача одного номера в `pay.complete`
  /// засчитывалась всем: две бумажки покупателя, одна не подошла — пять
  /// повторов запирали и честную вторую, а номер, до которого проверка не
  /// дошла, получал неудачу, которой не было.
  ///
  /// [subject] не назван или не из этой попытки — единицы остаются все:
  /// не знаем, какой номер не подошёл, — не отпускаем ни один.
  void settle({required bool guessed, String? subject}) {
    if (_settled) return;
    _settled = true;
    if (!guessed) {
      _keys.forEach(_ledger.giveBack);
      return;
    }
    final failed = subject == null ? null : 'n:${subject.trim()}';
    if (failed == null || !_keys.contains(failed)) return;
    for (final key in _keys) {
      if (key.startsWith('n:') && key != failed) _ledger.giveBack(key);
    }
  }
}
