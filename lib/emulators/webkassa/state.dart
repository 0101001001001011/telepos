/// Состояние эмулятора WebKassa: смена, счётчики, токены, дедупликация,
/// журнал и пересчёт денег.
///
/// # Чего это состояние НЕ доказывает
///
/// **Оно не доказывает, что настоящая WebKassa ведёт себя так же.** Своего
/// верного числа у эмулятора нет ни одного: и номер смены, и счётчик
/// документов, и фискальный признак он выдумывает сам, а правила отказа
/// снял с [нашей] карты кодов `WebKassaProvider._mapError` — то есть с
/// нашего понимания чужого протокола, а не с протокола. Всё, что здесь можно
/// увидеть, — что **наш** конверт собран так, как мы сами договорились его
/// собирать, и что **наш** разбор ответа доходит до той ветки, которую мы
/// хотели пройти.
///
/// Поэтому:
///
/// * зелёный прогон здесь **не закрывает** «документ принят оператором» —
///   это закрывается только прогоном по `devkkm.webkassa.kz`;
/// * зелёный прогон здесь **не закрывает** «сумма в документе верна для
///   покупателя»: эмулятор сверяет сумму позиций с суммой оплат внутри
///   одного и того же конверта, и обе половины пришли от нас. Расхождение
///   документа с экраном кассы он увидеть не может — в конверте нет числа,
///   с которым сверять;
/// * зелёный прогон здесь **закрывает** «касса собрала конверт, который сама
///   же считает согласованным, и разобрала ответ по верной ветке».
///
/// # Почему `Decimal`, а не `double`
///
/// `WebKassaProvider._money` возвращает `num`: при нецелом значении —
/// `double`. Сложи эмулятор `jsonDecode`-нутые `double`, и он внесёт **свою**
/// ошибку и покраснеет на исправном коде — худший исход, какой у
/// измерительного прибора бывает. Поэтому каждое денежное поле поднимается
/// через [money] как `Decimal.parse(value.toString())` и складывается только
/// в `Decimal`. Ни одного `+` над `double` в денежном пути здесь нет, и на
/// это стоит сторож в `emulator_test.dart`.
library;

import 'package:decimal/decimal.dart';

/// Поднять денежное поле из JSON без единой операции над `double`.
///
/// `Dart` печатает кратчайшее представление, дающее ровно тот же `double`,
/// поэтому `1234.56` восстанавливается точно. Через `toString()` — а не через
/// `Decimal.parse(value as double)` — именно ради этого.
Decimal money(Object? raw) {
  if (raw == null) return Decimal.zero;
  final parsed = Decimal.tryParse(raw.toString());
  if (parsed == null) {
    throw FormatException('не денежное значение: $raw');
  }
  return parsed;
}

/// Запись журнала.
///
/// Тот же приём, что в `StandHardwareJournal`: пишется **довод, а не факт
/// вызова**. «Позван 1 раз» не отличает верный чек от чужого, поэтому каждая
/// запись несёт тело запроса, тело ответа и [reasons] — строки вида «посчитал
/// столько, в конверте столько, отказал потому-то».
class JournalEntry {
  JournalEntry({
    required this.seq,
    required this.at,
    required this.path,
    required this.request,
    required this.response,
    required this.reasons,
    required this.outcome,
  });

  final int seq;
  final DateTime at;
  final String path;
  final Map<String, Object?> request;
  final Map<String, Object?> response;

  /// Довод: что пришло, что посчитано, почему отказано. Пусто не бывает.
  final List<String> reasons;

  /// `ok` / `refused:<code>` / `killed` / `delayed` — одним словом, чтобы
  /// журнал читался глазами без разбора конверта.
  final String outcome;

  Map<String, Object?> toJson() => {
    'seq': seq,
    'at': at.toIso8601String(),
    'path': path,
    'outcome': outcome,
    'reasons': reasons,
    'request': request,
    'response': response,
  };

  /// Одна строка для консоли эмулятора.
  String get line {
    final head = '#$seq ${at.toIso8601String()} $path -> $outcome';
    final body = reasons.map((r) => '      $r').join('\n');
    return body.isEmpty ? head : '$head\n$body';
  }
}

/// Выданный токен. TTL короткий намеренно: истёкший токен — **единственный
/// естественный** вход в `WebKassaProvider._withReauthRetry`, и без него та
/// ветка не проходится ни одной живой проверкой.
class EmulatedToken {
  EmulatedToken({
    required this.value,
    required this.issuedAt,
    required this.ttl,
  });

  final String value;
  final DateTime issuedAt;
  final Duration ttl;

  bool expiredAt(DateTime now) => now.difference(issuedAt) >= ttl;
}

/// Касса, какой её видит эмулятор.
class EmulatedCashbox {
  EmulatedCashbox({
    required this.uniqueNumber,
    required this.registrationNumber,
    required DateTime now,
  }) : startedAt = now;

  /// `CashboxUniqueNumber` — ключ, по которому касса себя называет.
  final String uniqueNumber;

  /// Едет в `Data.Cashbox.RegistrationNumber`.
  final String registrationNumber;

  bool shiftOpen = false;

  /// Растёт на закрытии смены (Z-отчёт).
  int shiftNumber = 0;

  /// Номер документа внутри смены, с 1.
  int checkOrderNumber = 0;

  /// Источник `CheckNumber` — фискального признака.
  int fiscalSignSeq = 0;

  Decimal cashInDrawer = Decimal.zero;
  Decimal putMoneySum = Decimal.zero;
  Decimal takeMoneySum = Decimal.zero;

  int sellCount = 0;
  Decimal sellTotal = Decimal.zero;
  Decimal sellVat = Decimal.zero;
  int returnCount = 0;
  Decimal returnTotal = Decimal.zero;

  DateTime startedAt;

  /// Выставляется пультом: касса заблокирована оператором (код 7).
  bool blocked = false;

  /// Смена не может быть открыта (код 11) — пульт `/_emul/shift {locked:true}`.
  bool shiftLocked = false;

  /// Смена «переросла» 24 часа (код 12) — пульт `/_emul/shift {stale:true}`.
  bool shiftStale = false;

  bool offlineMode = false;
  bool offlineSupported = true;
  int offlineLimit = 0;
  int offlineDocs = 0;
  DateTime? offlineSince;

  void openShiftImplicitly(DateTime now) {
    shiftOpen = true;
    shiftNumber += 1;
    checkOrderNumber = 0;
    startedAt = now;
  }

  Map<String, Object?> toJson() => {
    'uniqueNumber': uniqueNumber,
    'registrationNumber': registrationNumber,
    'shiftOpen': shiftOpen,
    'shiftNumber': shiftNumber,
    'checkOrderNumber': checkOrderNumber,
    'fiscalSignSeq': fiscalSignSeq,
    'cashInDrawer': cashInDrawer.toString(),
    'putMoneySum': putMoneySum.toString(),
    'takeMoneySum': takeMoneySum.toString(),
    'sell': {
      'count': sellCount,
      'total': sellTotal.toString(),
      'vat': sellVat.toString(),
    },
    'saleReturn': {'count': returnCount, 'total': returnTotal.toString()},
    'startedAt': startedAt.toIso8601String(),
    'blocked': blocked,
    'shiftLocked': shiftLocked,
    'shiftStale': shiftStale,
    'offlineMode': offlineMode,
    'offlineSupported': offlineSupported,
    'offlineLimit': offlineLimit,
    'offlineDocs': offlineDocs,
    'offlineSince': offlineSince?.toIso8601String(),
  };
}

/// Как эмулятор относится к полю `Tax` при `TaxType == 100`.
///
/// **Это наше допущение, а не документированный факт.** Казахстанская
/// условность «налог в цене» даёт `Tax = round(line × TaxPercent /
/// (100 + TaxPercent), 2)`; она совпадает с тем, что считает
/// `FiscalPositionBuilder.vatFromGross`, — то есть эмулятор проверял бы наш
/// код против него же самого. Допущение, зашитое намертво, покрасило бы
/// верный код при смене условности, поэтому оно переключается, а по
/// умолчанию — `off`.
enum VatMode {
  /// Налог в цене: `Tax = line × p / (100 + p)`.
  included,

  /// Налог сверху: `Tax = line × p / 100`.
  added,

  /// Не проверять `Tax` вовсе — умолчание.
  off,
}

/// Результат пересчёта чека.
class Recount {
  Recount({
    required this.lineTotals,
    required this.positionsTotal,
    required this.paymentsTotal,
    required this.vatTotal,
    required this.reasons,
    required this.complaint,
  });

  final List<Decimal> lineTotals;
  final Decimal positionsTotal;
  final Decimal paymentsTotal;
  final Decimal vatTotal;

  /// Что именно посчитано — едет в журнал целиком.
  final List<String> reasons;

  /// `null`, если сошлось. Иначе — текст отказа с обеими суммами и разностью.
  final String? complaint;

  bool get agreed => complaint == null;
}

/// Пересчёт чека с **нулевым допуском**.
///
/// Эмулятор обязан быть строже настоящего сервиса, а не мягче: прощающий
/// эмулятор — это заглушка с дополнительным шагом.
///
/// Формула снята с того, что кладёт в конверт `WebKassaProvider`
/// (`_positionToJson`): `Count`, `Price`, необязательные `Discount` и
/// `Markup`. `totalDiscount` чека в конверт **не едет вовсе**, поэтому
/// потерянная при раскладке скидки копейка проявляется ровно как «сумма
/// позиций не равна сумме оплат» — и это ровно то, что здесь считается.
Recount recountCheck(Map<String, Object?> body, VatMode vat) {
  final reasons = <String>[];
  final positions = (body['Positions'] as List?) ?? const [];
  final payments = (body['Payments'] as List?) ?? const [];

  final lineTotals = <Decimal>[];
  var positionsTotal = Decimal.zero;
  var vatTotal = Decimal.zero;
  String? complaint;

  for (var i = 0; i < positions.length; i++) {
    final raw = positions[i];
    if (raw is! Map) {
      complaint = 'Позиция ${i + 1}: не объект';
      break;
    }
    final p = raw.cast<String, Object?>();
    final count = money(p['Count']);
    final price = money(p['Price']);
    final discount = money(p['Discount']);
    final markup = money(p['Markup']);

    // `RoundType: 2` в конверте означает округление по позициям, поэтому
    // произведение округляется до копейки прежде, чем из него вычитается
    // скидка. Это допущение эмулятора, и оно названо: см. докстринг файла.
    final gross = (count * price).round(scale: 2);
    final line = gross - discount + markup;
    lineTotals.add(line);
    positionsTotal += line;

    reasons.add(
      'позиция ${i + 1} «${p['PositionName']}»: '
      '$count × $price = $gross − $discount + $markup = $line',
    );

    final taxType = (p['TaxType'] as num?)?.toInt() ?? 0;
    if (taxType == 100) {
      final declared = money(p['Tax']);
      vatTotal += declared;
      if (vat != VatMode.off) {
        final rate = money(p['TaxPercent']);
        final expected = vat == VatMode.included
            ? (line * rate / (Decimal.fromInt(100) + rate))
                  .toDecimal(scaleOnInfinitePrecision: 4)
                  .round(scale: 2)
            : (line * rate / Decimal.fromInt(100))
                  .toDecimal(scaleOnInfinitePrecision: 4)
                  .round(scale: 2);
        reasons.add(
          'позиция ${i + 1}: НДС ${vat.name} $rate% от $line = $expected, '
          'в конверте $declared',
        );
        if (expected != declared && complaint == null) {
          complaint =
              'Позиция ${i + 1}: НДС в конверте $declared, '
              'пересчёт (${vat.name}, $rate%) даёт $expected';
        }
      }
    }
  }

  var paymentsTotal = Decimal.zero;
  for (var i = 0; i < payments.length; i++) {
    final raw = payments[i];
    if (raw is! Map) {
      complaint ??= 'Оплата ${i + 1}: не объект';
      continue;
    }
    final pay = raw.cast<String, Object?>();
    final sum = money(pay['Sum']);
    paymentsTotal += sum;
    reasons.add('оплата ${i + 1} вида ${pay['PaymentType']}: $sum');
  }

  reasons.add('сумма позиций $positionsTotal, сумма оплат $paymentsTotal');

  if (complaint == null && positionsTotal != paymentsTotal) {
    final diff = positionsTotal - paymentsTotal;
    complaint =
        'Сумма позиций $positionsTotal не равна сумме оплат $paymentsTotal '
        '(разность $diff)';
  }

  return Recount(
    lineTotals: lineTotals,
    positionsTotal: positionsTotal,
    paymentsTotal: paymentsTotal,
    vatTotal: vatTotal,
    reasons: reasons,
    complaint: complaint,
  );
}

/// Всё состояние эмулятора в одном месте.
class EmulatorState {
  EmulatorState({
    required this.cashboxes,
    required this.login,
    required this.password,
    required this.tokenTtl,
    required this.vat,
  });

  final Map<String, EmulatedCashbox> cashboxes;

  /// Учётные данные, которые эмулятор считает верными. Всё остальное —
  /// код 1 (`badCredentials`). Без этого ветка «неверный логин» недостижима.
  final String login;
  final String password;

  final Duration tokenTtl;
  final VatMode vat;

  final Map<String, EmulatedToken> tokens = {};

  /// `ExternalCheckNumber` → ответ, который уже был отдан.
  ///
  /// Самая ценная часть состояния: без неё **недостижимы обе ветки повтора** —
  /// разбор кода 14 в `WebKassaProvider._checkResult` (с 2026-09-18 это
  /// `_failure` → `duplicate`, а не «успех с пустым признаком») и
  /// `OfflineQueueingProvider.replay`'s `else if (result.errorCode ==
  /// duplicate) { remove }`. Заглушка не даёт этого никогда.
  ///
  /// Хранится **весь ответ**, включая `CheckNumber`, хотя в код 14 он не
  /// едет: он нужен пробе, чтобы утверждать «признак первой отправки такой-то,
  /// и на повторе касса его НЕ получила». Отдать его в ответ — значит
  /// выдумать оператору метод, которого у него нет.
  final Map<String, Map<String, Object?>> answered = {};

  final List<JournalEntry> journal = [];

  int _tokenSeq = 0;
  int _journalSeq = 0;

  EmulatedToken issue(DateTime now) {
    _tokenSeq += 1;
    final t = EmulatedToken(
      value: 'emul-token-$_tokenSeq',
      issuedAt: now,
      ttl: tokenTtl,
    );
    tokens[t.value] = t;
    return t;
  }

  JournalEntry record({
    required String path,
    required Map<String, Object?> request,
    required Map<String, Object?> response,
    required List<String> reasons,
    required String outcome,
    required DateTime now,
  }) {
    _journalSeq += 1;
    final entry = JournalEntry(
      seq: _journalSeq,
      at: now,
      path: path,
      request: request,
      response: response,
      reasons: reasons,
      outcome: outcome,
    );
    journal.add(entry);
    return entry;
  }

  void reset(DateTime now) {
    tokens.clear();
    answered.clear();
    journal.clear();
    _tokenSeq = 0;
    _journalSeq = 0;
    for (final entry in cashboxes.entries) {
      cashboxes[entry.key] = EmulatedCashbox(
        uniqueNumber: entry.value.uniqueNumber,
        registrationNumber: entry.value.registrationNumber,
        now: now,
      );
    }
  }

  Map<String, Object?> toJson() => {
    'cashboxes': {for (final e in cashboxes.entries) e.key: e.value.toJson()},
    'tokens': tokens.length,
    'answered': answered.keys.toList(),
    'journalLength': journal.length,
    'vat': vat.name,
    'tokenTtlSeconds': tokenTtl.inSeconds,
  };
}
