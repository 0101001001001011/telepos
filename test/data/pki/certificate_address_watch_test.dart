/// Наблюдатель за уехавшим адресом.
///
/// Проверяется одно свойство и три его следствия: смена адреса **не остаётся
/// молчаливой**, но и не превращается в поток одинаковых строк. Наблюдатель,
/// который кричит каждый тик, ничем не лучше молчащего — читать его перестанут
/// через сутки.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/pki/certificate_address_watch.dart';

void main() {
  test('лист покрывает адреса — ни одного сообщения', () async {
    final said = <List<String>>[];
    final watch = CertificateAddressWatch(
      certifiedAddresses: <String>['192.168.1.30'],
      onChange: said.add,
      sample: () async => <String>['192.168.1.30'],
    );

    await watch.checkNow();
    await watch.checkNow();

    expect(said, isEmpty);
  });

  test('адрес уехал — сказано ровно один раз, и сказан новый адрес', () async {
    var current = <String>['192.168.1.30'];
    final said = <List<String>>[];
    final watch = CertificateAddressWatch(
      certifiedAddresses: <String>['192.168.1.30'],
      onChange: said.add,
      sample: () async => current,
    );

    await watch.checkNow();
    expect(said, isEmpty, reason: 'пока адрес на месте, говорить не о чем');

    current = <String>['192.168.1.31'];
    await watch.checkNow();
    await watch.checkNow();
    await watch.checkNow();

    expect(said, <List<String>>[
      <String>['192.168.1.31'],
    ], reason: 'три проверки одного и того же состояния — одна строка');
  });

  test('адрес вернулся — об этом тоже сказано', () async {
    // Без этого лог оставляет кассу навсегда сломанной: последняя строка о ней
    // говорит «недоступна», и ничто её не отменяет.
    var current = <String>['192.168.1.31'];
    final said = <List<String>>[];
    final watch = CertificateAddressWatch(
      certifiedAddresses: <String>['192.168.1.30'],
      onChange: said.add,
      sample: () async => current,
    );

    await watch.checkNow();
    current = <String>['192.168.1.30'];
    await watch.checkNow();

    expect(said, <List<String>>[
      <String>['192.168.1.31'],
      const <String>[],
    ]);
  });

  test('перестановка адресов местами — не событие', () async {
    var current = <String>['10.8.10.23', '192.168.1.31'];
    final said = <List<String>>[];
    final watch = CertificateAddressWatch(
      certifiedAddresses: const <String>[],
      onChange: said.add,
      sample: () async => current,
    );

    await watch.checkNow();
    current = <String>['192.168.1.31', '10.8.10.23'];
    await watch.checkNow();

    expect(said, hasLength(1), reason: 'порядок задаёт система, а не событие');
  });

  test('start смотрит сразу, а не через период', () async {
    // Касса, поднявшаяся с уже уехавшим адресом, обязана сказать это на
    // подъёме. Период здесь заведомо больше ожидания, так что сработать может
    // только немедленная проверка.
    final said = <List<String>>[];
    CertificateAddressWatch(
      certifiedAddresses: <String>['192.168.1.30'],
      onChange: said.add,
      sample: () async => <String>['192.168.1.31'],
      period: const Duration(hours: 1),
    ).start();

    await Future<void>.delayed(Duration.zero);

    expect(said, <List<String>>[
      <String>['192.168.1.31'],
    ]);
  });

  test('таймер тикает и после старта, пока его не остановят', () async {
    var current = <String>['192.168.1.30'];
    final said = <List<String>>[];
    final watch = CertificateAddressWatch(
      certifiedAddresses: <String>['192.168.1.30'],
      onChange: said.add,
      sample: () async => current,
      period: const Duration(milliseconds: 5),
    )..start();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(said, isEmpty);

    current = <String>['192.168.1.31'];
    await Future<void>.delayed(const Duration(milliseconds: 40));
    watch.stop();

    expect(said, <List<String>>[
      <String>['192.168.1.31'],
    ], reason: 'смену заметил таймер, а не вызов checkNow');
  });

  test('после stop наблюдатель молчит', () async {
    var current = <String>['192.168.1.30'];
    final said = <List<String>>[];
    final watch = CertificateAddressWatch(
      certifiedAddresses: <String>['192.168.1.30'],
      onChange: said.add,
      sample: () async => current,
      period: const Duration(milliseconds: 5),
    )..start();

    await Future<void>.delayed(const Duration(milliseconds: 10));
    watch.stop();
    current = <String>['192.168.1.31'];
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(said, isEmpty);
  });

  test('повторный start не удваивает строки', () async {
    var current = <String>['192.168.1.30'];
    final said = <List<String>>[];
    final watch = CertificateAddressWatch(
      certifiedAddresses: <String>['192.168.1.30'],
      onChange: said.add,
      sample: () async => current,
      period: const Duration(milliseconds: 5),
    )..start();
    watch.start();

    current = <String>['192.168.1.31'];
    await Future<void>.delayed(const Duration(milliseconds: 40));
    watch.stop();

    expect(said, hasLength(1));
  });
}
