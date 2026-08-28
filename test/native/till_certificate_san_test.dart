/// Запасной путь по адресу: то, что доказывается только настоящим листом.
///
/// # Почему это здесь, а не рядом с остальными проверками PKI
///
/// Всё, что можно проверить без нативной библиотеки, уже проверено в
/// `test/data/pki/`. Здесь то, что без неё проверить нельзя вовсе: **лист
/// действительно выписан**, в его SAN действительно лежит `iPAddress`, и
/// рукопожатие по адресу действительно проходит. `flutter test` нативную часть
/// FFI-плагина не собирает, поэтому файл помечен `native` и в обычном наборе
/// пропущен — см. `dart_test.yaml` о том, почему это не дыра.
///
/// # Что здесь считается доказательством
///
/// SAN разбирается **своим** кодом из DER, а не спрашивается у `rk_pki`.
/// Библиотека, отвечающая на вопрос о собственной работе, доказывает только
/// свою внутреннюю согласованность: она одинаково ошиблась бы и при выписке, и
/// при чтении. [_subjectAltNames] ходит по байтам сертификата и не знает про
/// `rk_pki` ничего.
///
/// И главное — [_handshakeByAddress]. Измерено 2026-08-05 на настоящем
/// устройстве: `curl` по адресу отвечал `http=000`, потому что в листе стояли
/// только имена. Проверка ниже воспроизводит ровно это — лист без адресов даёт
/// `HandshakeException`, лист с адресами отдаёт страницу, — и без починки
/// первая половина зелёная, а вторая красная.
///
/// # Запуск
///
/// ```sh
/// cd packages/rk_pki/rust && cargo build --release && cd ../../..
/// # Windows: положить rk_pki.dll в PATH; Linux: librk_pki.so в LD_LIBRARY_PATH
/// flutter test --tags native --run-skipped test/native/
/// ```
@Tags(['native'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/pki/certificate_addresses.dart';
import 'package:telepos/data/pki/till_certificates.dart';

void main() {
  late Directory store;

  setUp(() {
    // Своё хранилище на каждую проверку: удостоверяющий центр один на каталог,
    // и лист в нём один. Общий каталог означал бы, что каждая следующая
    // проверка перевыписывает лист предыдущей, и порядок проверок стал бы
    // частью их смысла.
    store = Directory.systemTemp.createTempSync('telepos-san-test');
  });

  tearDown(() {
    try {
      store.deleteSync(recursive: true);
    } on Object {
      // Каталог, который не удалился, — мусор во временной папке, а не отказ
      // проверки. Ронять из-за него зелёный набор незачем.
    }
  });

  Future<_Issued> issue({
    List<String> dnsNames = const <String>['localhost', 'till-test.local'],
    List<String> ipAddresses = const <String>[],
    Directory? into,
  }) async {
    final opened = await TillCertificates.open(
      storeDirectory: (into ?? store).path,
      installationId: 'san-test',
      machineId: 'till-test',
    );
    if (opened is CertificateUnavailable) {
      fail(
        'нативная библиотека rk_pki не открылась: ${opened.reason}. '
        'Соберите её — cargo build --release в packages/rk_pki/rust — и '
        'положите рядом или в PATH/LD_LIBRARY_PATH.',
      );
    }
    final certificates = opened as TillCertificates;
    addTearDown(certificates.close);

    final credential = await certificates.webTransportCredential(
      dnsNames: dnsNames,
      ipAddresses: ipAddresses,
    );
    if (credential is CertificateUnavailable) {
      fail('лист не выписан: ${credential.reason}');
    }

    // Корень берётся сразу, пока хранилище открыто: клиент проверки обязан
    // доверять именно ему, а не всему, что стоит на машине.
    final root = await certificates.authorityRootPem();
    if (root is CertificateUnavailable) {
      fail('корня установки нет: ${root.reason}');
    }

    return _Issued(credential as WebTransportCredential, root as String);
  }

  group('SAN выписанного листа', () {
    test('имя и адрес оба на месте — разбор идёт по байтам DER', () async {
      final issued = await issue(
        ipAddresses: <String>['192.168.1.31', '10.8.10.23'],
      );

      final san = _subjectAltNames(issued.leaf.chainPem);

      expect(san.dnsNames, containsAll(<String>['localhost', 'till-test.local']));
      expect(
        san.ipAddresses,
        containsAll(<String>['192.168.1.31', '10.8.10.23']),
        reason:
            'ради этого списка и выпускалась rk_pki 0.4.0: без него терминал '
            'по адресу не доходит',
      );
    });

    test('без ipAddresses адресов в листе нет — состояние до починки', () async {
      // Проверка, без которой предыдущая ничего не значит: она обязана
      // краснеть, если убрать саму возможность класть адреса.
      final issued = await issue();

      final san = _subjectAltNames(issued.leaf.chainPem);

      expect(san.dnsNames, contains('till-test.local'));
      expect(san.ipAddresses, isEmpty);
    });

    test('кредентиал говорит то же, что лежит в листе', () async {
      // Разъезд между «просили» и «выписано» — это ровно тот дефект, что жил
      // до 0.4.0: касса просила адрес у библиотеки, которая его не умела, и не
      // узнавала об этом.
      final issued = await issue(ipAddresses: <String>['192.168.1.31']);
      final san = _subjectAltNames(issued.leaf.chainPem);

      expect(issued.leaf.ipAddresses, san.ipAddresses);
      expect(issued.leaf.dnsNames.toSet(), san.dnsNames.toSet());
      expect(issued.leaf.subjectAltNames, contains('192.168.1.31'));
    });
  });

  group('перевыпуск', () {
    test('адрес уехал — лист перевыписан на новый', () async {
      final was = await issue(ipAddresses: <String>['192.168.1.30']);
      final now = await issue(ipAddresses: <String>['192.168.1.31']);

      expect(now.leaf.fingerprintSha256, isNot(was.leaf.fingerprintSha256));
      expect(
        _subjectAltNames(now.leaf.chainPem).ipAddresses,
        contains('192.168.1.31'),
      );
    });

    test('ничего не менялось — лист тот же, отпечаток тот же', () async {
      // Иначе каждый подъём кассы менял бы отпечаток, а его прикалывает каждая
      // открытая страница терминала.
      final was = await issue(ipAddresses: <String>['192.168.1.30']);
      final now = await issue(ipAddresses: <String>['192.168.1.30']);

      expect(now.leaf.fingerprintSha256, was.leaf.fingerprintSha256);
    });

    test('адрес пропал — лист не трогаем', () async {
      // Условие одностороннее: лишний адрес в листе никому не мешает, а
      // перевыпуск ради него оборвал бы живые сессии.
      final was = await issue(
        ipAddresses: <String>['192.168.1.30', '10.8.10.23'],
      );
      final now = await issue(ipAddresses: <String>['192.168.1.30']);

      expect(now.leaf.fingerprintSha256, was.leaf.fingerprintSha256);
    });

    test('кассу переименовали — лист перевыписан на новое имя', () async {
      final was = await issue(dnsNames: <String>['localhost', 'till-3.local']);
      final now = await issue(dnsNames: <String>['localhost', 'till-4.local']);

      expect(now.leaf.fingerprintSha256, isNot(was.leaf.fingerprintSha256));
      expect(
        _subjectAltNames(now.leaf.chainPem).dnsNames,
        contains('till-4.local'),
      );
    });
  });

  group('рукопожатие по адресу', () {
    test('лист с адресом — страница отдаётся, лист без адреса — нет', () async {
      // Настоящий адрес этой машины, а не выдуманный: подключаться надо туда
      // же, куда пойдёт терминал.
      final addresses = await certificateAddresses();
      if (addresses.isEmpty) {
        markTestSkipped('у машины нет ни одного сетевого адреса');
        return;
      }
      final address = addresses.first;

      final withAddress = await issue(ipAddresses: <String>[address]);
      final withoutAddress = await issue(
        into: Directory.systemTemp.createTempSync('telepos-san-noaddr'),
      );

      expect(
        await _handshakeByAddress(withAddress, address),
        200,
        reason:
            'лист называет $address — по адресу должна открываться страница, '
            'и это и есть запасной путь там, где режут mDNS',
      );

      expect(
        () => _handshakeByAddress(withoutAddress, address),
        throwsA(isA<HandshakeException>()),
        reason:
            'именно так и падало до починки: curl отвечал http=000, и по '
            'этому ответу «касса выключена» от «адреса нет в листе» не '
            'отличить',
      );
    });
  });
}

/// Поднимает HTTPS на [leaf], идёт на него **по адресу** и отдаёт код ответа.
///
/// Клиент доверяет только корню этого же листа и никаким другим: доверие всему
/// хранилищу системы сделало бы проверку зависимой от того, что на машине
/// установлено, а не от того, что выписано.
///
/// Слушает `0.0.0.0`, а не петлю, ровно по той же причине, по которой это
/// делает касса: терминал — отдельное устройство, и петлю он не достанет.
Future<int> _handshakeByAddress(_Issued issued, String address) async {
  final context = pageSecurityContext(issued.leaf);
  if (context is CertificateUnavailable) {
    fail('TLS-контекст не собрался: ${context.reason}');
  }

  final server = await HttpServer.bindSecure(
    InternetAddress.anyIPv4,
    0,
    context as SecurityContext,
  );
  unawaited(
    server.forEach((request) {
      request.response
        ..statusCode = 200
        ..write('ok');
      unawaited(request.response.close());
    }),
  );

  // Корень этой установки, и только он.
  final client = HttpClient(
    context: SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(utf8.encode(issued.rootPem)),
  );

  try {
    final request = await client.getUrl(
      Uri.parse('https://$address:${server.port}/'),
    );
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
    await server.close(force: true);
  }
}

// ---------------------------------------------------------------------------
// Разбор SAN. Свой, потому что ответ библиотеки о собственной работе — не
// доказательство.
// ---------------------------------------------------------------------------

/// Выписанный лист и корень, которым его проверяют. Вместе, потому что порознь
/// они описывают разные установки, и проверка на такой паре ничего не значит.
class _Issued {
  const _Issued(this.leaf, this.rootPem);

  final WebTransportCredential leaf;
  final String rootPem;
}

/// Имена и адреса, прочитанные из расширения `subjectAltName` (OID 2.5.29.17).
class _AltNames {
  const _AltNames(this.dnsNames, this.ipAddresses);

  final List<String> dnsNames;
  final List<String> ipAddresses;
}

/// Разбирает SAN первого сертификата в цепочке PEM.
///
/// Первого — потому что лист идёт первым, а расширение корня нас не интересует
/// вовсе: браузер сверяет имя узла с листом.
_AltNames _subjectAltNames(String chainPem) {
  final der = _firstCertificateDer(chainPem);

  // OID 2.5.29.17 в DER: 06 03 55 1D 11. Ищем его как байтовую подстроку, а не
  // разбирая всю ASN.1: полный разбор X.509 здесь был бы второй реализацией
  // x509-parser, а нужен один вопрос — что лежит в этом расширении.
  const oid = <int>[0x06, 0x03, 0x55, 0x1D, 0x11];
  final at = _indexOf(der, oid);
  if (at < 0) return const _AltNames(<String>[], <String>[]);

  var cursor = at + oid.length;
  // Необязательный `critical` BOOLEAN между OID и содержимым.
  if (der[cursor] == 0x01) {
    final length = _readLength(der, cursor + 1);
    cursor = length.next + length.value;
  }
  // OCTET STRING, внутри которого лежит SEQUENCE OF GeneralName.
  if (der[cursor] != 0x04) {
    fail('после OID subjectAltName ожидался OCTET STRING, а не 0x'
        '${der[cursor].toRadixString(16)}');
  }
  final octet = _readLength(der, cursor + 1);
  cursor = octet.next;

  if (der[cursor] != 0x30) {
    fail('внутри subjectAltName ожидался SEQUENCE');
  }
  final sequence = _readLength(der, cursor + 1);
  cursor = sequence.next;
  final end = cursor + sequence.value;

  final dnsNames = <String>[];
  final ipAddresses = <String>[];
  while (cursor < end) {
    final tag = der[cursor];
    final length = _readLength(der, cursor + 1);
    final body = der.sublist(length.next, length.next + length.value);
    switch (tag) {
      // [2] dNSName — IA5String, контекстный примитивный тег.
      case 0x82:
        dnsNames.add(ascii.decode(body));
      // [7] iPAddress — сырые байты: 4 для v4, 16 для v6.
      case 0x87:
        ipAddresses.add(_formatAddress(body));
    }
    cursor = length.next + length.value;
  }
  return _AltNames(dnsNames, ipAddresses);
}

String _formatAddress(List<int> bytes) {
  if (bytes.length == 4) return bytes.join('.');
  if (bytes.length == 16) {
    return <String>[
      for (var i = 0; i < 16; i += 2)
        ((bytes[i] << 8) | bytes[i + 1]).toRadixString(16),
    ].join(':');
  }
  fail('iPAddress длиной ${bytes.length} байт — ни v4, ни v6');
}

List<int> _firstCertificateDer(String pem) {
  const begin = '-----BEGIN CERTIFICATE-----';
  const end = '-----END CERTIFICATE-----';
  final from = pem.indexOf(begin);
  final to = pem.indexOf(end, from);
  if (from < 0 || to < 0) fail('в цепочке нет ни одного сертификата PEM');
  final body = pem.substring(from + begin.length, to);
  return base64.decode(body.replaceAll(RegExp(r'\s'), ''));
}

/// Позиция длины и её значение — DER пишет длину коротко или в несколько байт.
class _Length {
  const _Length(this.value, this.next);

  /// Сколько байт содержимого.
  final int value;

  /// Индекс первого байта содержимого.
  final int next;
}

_Length _readLength(List<int> der, int at) {
  final first = der[at];
  if (first < 0x80) return _Length(first, at + 1);
  final count = first & 0x7F;
  var value = 0;
  for (var i = 1; i <= count; i++) {
    value = (value << 8) | der[at + i];
  }
  return _Length(value, at + 1 + count);
}

int _indexOf(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
