@Tags(['architecture'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/pay_ops.dart';

/// Заявка на оплату целиком переживает провод — **и новое поле показывает
/// себя само**.
///
/// # Чем этот сторож отличается от тех, что уже стояли
///
/// Их было два, оба зелёные, и оба молчали о настоящей дыре:
///
/// - `pay_ops_test.dart`, «заявка возвращается той же» — перечисляет поля
///   **рукой**. `qrIntentKey` (задача 22) в этот список не дописали, и
///   сторож про него не знал ничего.
/// - `pay_ops_installment_wire_test.dart` (задача 24) — сторожит **свои
///   два поля**. Он прямо назвал в докстринге, что `qrIntentKey` до
///   кодека не доехал, и всё равно не мог покраснеть: частный сторож
///   молчит ровно о том поле, которого в нём не назвали.
///
/// Измерено 2026-09-08 на `ca70bcd`: у `PaymentRequest` **17** полей, обе
/// половины кодека знали **16**. Потерялось ровно одно — `qrIntentKey`, —
/// и оплата по QR с браузерного терминала не доезжала до кассы вовсе:
/// поле читает `LocalPaymentService`, а кадр его не нёс.
///
/// # Как устроен этот
///
/// Список полей он **не держит**. Он читает объявления `final ... x;` из
/// `lib/domain/sale/payment_service.dart` и требует ключ в кадре на
/// каждое. Поле, дописанное в класс и забытое в кодеке, красит набор в
/// день добавления — без единой правки здесь.
///
/// Сверху лежит круговая поездка через **настоящий кадр**: не пара
/// вызовов кодека, а `jsonEncode` → байты → `jsonDecode` → разбор →
/// повторная запись, и сверка карт целиком. Слабую проверку («суммы
/// сошлись») она не заменяет — она её вытесняет: утверждение здесь о
/// самих полях.
void main() {
  group('перепись полей: класс против кодека', () {
    test('каждое объявленное поле заявки кладётся в кадр', () {
      final declared = _declaredFields('PaymentRequest');

      // КОНТРОЛЬНЫЙ МАРКЕР разбора исходника. Без него сломанное
      // выражение отдало бы пустое множество, и «ни одно поле не
      // потерялось» значило бы «полей не нашли вовсе».
      expect(
        declared,
        containsAll(<String>['type', 'cashReceived', 'qrIntentKey']),
        reason: 'разбор исходника сломан: известных полей в переписи нет',
      );
      expect(
        declared.length,
        greaterThanOrEqualTo(15),
        reason:
            'на ca70bcd полей 17; меньше пятнадцати — сломан разбор, '
            'а не класс',
      );

      final json = paymentRequestToWireJson(_fullRequest());
      final missing =
          declared.where((f) => !json.containsKey(_wireKeyOf(f))).toList()
            ..sort();

      expect(
        missing,
        isEmpty,
        reason:
            'поля есть в PaymentRequest и нет в кадре: ${missing.join(', ')}. '
            'Так уже случилось с qrIntentKey (задача 22): механика '
            'написана, входа нет, набор зелёный. Внесите поле в обе '
            'половины paymentRequestToWireJson/paymentRequestFromWireJson.',
      );
    });

    test('в кадре нет ключа, которому не отвечает поле класса', () {
      // Обратная сторона: ключ без дома разбор молча выбросит, и кадр
      // будет нести байты, которых никто не читает. Так выглядит
      // переименованное поле, забытое в одной половине.
      final declared = _declaredFields(
        'PaymentRequest',
      ).map(_wireKeyOf).toSet();
      final stray = paymentRequestToWireJson(
        _fullRequest(),
      ).keys.where((k) => !declared.contains(k)).toList()..sort();

      expect(
        stray,
        isEmpty,
        reason: 'ключи кадра без поля: ${stray.join(', ')}',
      );
    });

    test('каждое поле вложенной бумажки тоже кладётся в кадр', () {
      // `certificates` — список объектов, и внутри него та же болезнь
      // возможна отдельно: поле, дописанное в `CertificateTender`, до
      // кассы не доедет, а перепись выше о нём ничего не скажет.
      final declared = _declaredFields('CertificateTender');
      expect(
        declared,
        containsAll(<String>['number', 'pin']),
        reason: 'разбор исходника сломан',
      );

      final json = paymentRequestToWireJson(_fullRequest());
      final first = (json['certificates']! as List).first as Map;
      final missing = declared.where((f) => !first.containsKey(f)).toList()
        ..sort();

      expect(missing, isEmpty, reason: 'поля бумажки не в кадре: $missing');
    });
  });

  group('круговая поездка через настоящий кадр', () {
    test('заявка со всеми полями возвращается той же', () {
      final sent = paymentRequestToWireJson(_fullRequest());

      // **Настоящий кадр, а не пара вызовов.** Провод везёт байты:
      // объект, переживший кодек, но не переживший `jsonEncode` (тот же
      // `Decimal`), прошёл бы наивную пробу и умер на проводе.
      final frame = jsonEncode(sent);
      final received = (jsonDecode(frame) as Map).cast<String, Object?>();

      final back = paymentRequestFromWireJson(received);

      // Сверяется **каждое поле разом**: повторная запись разобранной
      // заявки обязана совпасть с исходной картой. Поле, потерянное
      // разбором, отсюда пропадёт; поле, уехавшее не в тот ключ, — не
      // найдётся переписью выше.
      expect(paymentRequestToWireJson(back), equals(sent));
    });

    test('КОНТРОЛЬНЫЙ МАРКЕР: пустая заявка даёт другую карту', () {
      // Без него «карты совпали» означало бы «кодек всегда возвращает
      // одно и то же», а не «он донёс названные значения».
      expect(
        paymentRequestToWireJson(PaymentRequest(type: PaymentType.cash)),
        isNot(equals(paymentRequestToWireJson(_fullRequest()))),
      );
    });

    test('значения доезжают поимённо, а не «сумма сошлась»', () {
      final back = paymentRequestFromWireJson(
        (jsonDecode(jsonEncode(paymentRequestToWireJson(_fullRequest())))
                as Map)
            .cast<String, Object?>(),
      );

      // Метки нарочно все разные: перепутанные местами поля дают
      // совпавшую сумму и разные значения.
      expect(back.type, PaymentType.mixed);
      expect(back.cashReceived, Decimal.parse('1111.001'));
      expect(back.cardAmount, Decimal.parse('2222.002'));
      expect(back.bonusUsed, Decimal.parse('3333.003'));
      expect(back.prepaymentUsed, Decimal.parse('4444.004'));
      expect(back.prepaymentReference, 'АВ-777');
      expect(back.claimedChange, Decimal.parse('5555.005'));
      expect(back.accountId, 11);
      expect(back.customerId, 22);
      expect(back.customerBin, '900101300123');
      expect(back.approvalCode, 'AC-33');
      expect(back.cardMask, '**** 4242');
      expect(back.transactionId, 'tx-44');
      expect(back.qrIntentKey, 'qr-55');
      expect(back.installmentTermMonths, 12);
      expect(back.installmentScheme, InstallmentScheme.differentiated.code);
      expect(back.certificates.map((c) => c.number).toList(), [
        'CERT-1',
        'CERT-2',
      ]);
      expect(back.certificates.map((c) => c.pin).toList(), ['1234', null]);
    });
  });

  group('ключ намерения QR — то самое поле, которого не было', () {
    test('названный ключ доезжает до кассы', () {
      // Вид оплаты при этом обычный: QR — **зачёт**, а не способ внести
      // остаток (докстринг `PaymentType.installment`, разбор «почему
      // член перечисления»). Он уменьшает сумму к доплате, и остальное
      // платится чем угодно.
      final json = paymentRequestToWireJson(
        PaymentRequest(type: PaymentType.cash, qrIntentKey: 'intent-42'),
      );
      expect(json['qrIntentKey'], 'intent-42');
      expect(
        paymentRequestFromWireJson(json).qrIntentKey,
        'intent-42',
        reason:
            'без этого LocalPaymentService не найдёт намерения и '
            'потребует денег на всю сумму чека',
      );
    });

    test('не названный — ключа в кадре нет вовсе', () {
      final json = paymentRequestToWireJson(
        PaymentRequest(type: PaymentType.cash),
      );
      expect(json.containsKey('qrIntentKey'), isFalse);
      expect(paymentRequestFromWireJson(json).qrIntentKey, isNull);
    });

    test('чужое значение читается как «не предъявлен», а не роняет разбор', () {
      // `TypeError` из кодека уехал бы на провод именем типа вместо
      // названной причины (I144). Пустая строка — тоже «не предъявлен»:
      // ключа `''` в `payment_intents` нет и быть не может.
      for (final raw in <Object?>[7, true, '', '   ', <String>[]]) {
        expect(
          paymentRequestFromWireJson(<String, Object?>{
            'type': 'cash',
            'qrIntentKey': raw,
          }).qrIntentKey,
          isNull,
          reason: 'на значении $raw',
        );
      }
    });
  });
}

/// Заявка, у которой **заполнено каждое поле**, и все метки разные.
///
/// Дописали поле в `PaymentRequest` — дописывать его сюда придётся:
/// перепись выше требует ключ в кадре, а ключ появится только если поле
/// названо. Это и есть «поле показывает себя само».
PaymentRequest _fullRequest() => PaymentRequest(
  type: PaymentType.mixed,
  cashReceived: Decimal.parse('1111.001'),
  cardAmount: Decimal.parse('2222.002'),
  bonusUsed: Decimal.parse('3333.003'),
  prepaymentUsed: Decimal.parse('4444.004'),
  prepaymentReference: 'АВ-777',
  claimedChange: Decimal.parse('5555.005'),
  accountId: 11,
  customerId: 22,
  customerBin: '900101300123',
  approvalCode: 'AC-33',
  cardMask: '**** 4242',
  transactionId: 'tx-44',
  qrIntentKey: 'qr-55',
  certificates: const [
    CertificateTender(number: 'CERT-1', pin: '1234'),
    CertificateTender(number: 'CERT-2'),
  ],
  installmentTermMonths: 12,
  installmentScheme: InstallmentScheme.differentiated.code,
);

/// Имя поля → ключ в кадре.
///
/// Сегодня они совпадают все до одного, и таблица пуста намеренно.
/// Расхождение допустимо, но оно обязано быть **названным здесь**, а не
/// подразумеваемым: иначе перепись перестанет отличать «ключ назвали
/// иначе» от «поле забыли».
const Map<String, String> _renamedOnWire = <String, String>{};

String _wireKeyOf(String field) => _renamedOnWire[field] ?? field;

/// Объявленные поля класса — **из исходника, а не из списка руками**.
///
/// Отражения в наборе нет (`dart:mirrors` во Flutter недоступен), и это
/// единственный способ, при котором новое поле краснеет само. Разбор
/// нарочно грубый: снимает строки-комментарии и строковые литералы,
/// считает скобки от заголовка класса и берёт `final <тип> <имя>;`.
/// Сломается — покраснеет контрольным маркером в пробах выше, а не
/// промолчит.
Set<String> _declaredFields(String className) {
  final raw = File(
    'lib/domain/sale/payment_service.dart',
  ).readAsStringSync().split('\n');

  final lines = raw
      .map((l) => l.trimLeft().startsWith('//') ? '' : l)
      .map((l) => l.replaceAll(RegExp("'[^']*'"), "''"))
      .toList();

  final head = lines.indexWhere(
    (l) => RegExp('^class $className\\b').hasMatch(l),
  );
  if (head < 0) return const <String>{};

  final fields = <String>{};
  var depth = 0;
  var opened = false;

  for (var i = head; i < lines.length; i++) {
    final line = lines[i];

    if (opened && depth == 1) {
      final m = RegExp(r'^\s*final\s+.*?(\w+)\s*;').firstMatch(line);
      if (m != null) fields.add(m.group(1)!);
    }

    for (final ch in line.split('')) {
      if (ch == '{') {
        depth++;
        opened = true;
      } else if (ch == '}') {
        depth--;
      }
    }

    if (opened && depth == 0) break;
  }

  return fields;
}
