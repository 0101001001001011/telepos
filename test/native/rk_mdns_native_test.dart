/// Объявление кассы — на настоящем сокете, настоящей датаграммой.
///
/// # Почему файл помечен, и почему пометка не способ его обойти
///
/// `flutter test` не собирает нативную часть FFI-плагина. На машине без
/// цепочки Rust библиотеки просто нет, и каждая проверка здесь упала бы — не
/// потому что приложение сломано, а потому что проверяемое не собиралось. Файл
/// поэтому помечен `native`, и `dart_test.yaml` держит его вне обычного
/// прогона.
///
/// Почему это не дыра: **эти проверки краснеют при отсутствии библиотеки, и в
/// CI есть задача, которая запускает их с собранной.** Без файла, который
/// краснеет, зелёный набор ничего не говорит о том, какой из двух путей
/// выполнялся, — запасной зелен в любом случае.
///
/// Как запустить:
///
/// ```sh
/// cd packages/rk_mdns/rust && cargo build --release && cd ../../..
/// export RK_MDNS_LIBRARY=$PWD/packages/rk_mdns/rust/target/release/librk_mdns.so
/// flutter test --tags native --run-skipped test/native/
/// ```
///
/// # Что именно проверяется
///
/// Не «мы вызвали библиотеку», а **датаграмма в сети**. Каждая проверка ниже
/// открывает второй сокет, вступает в группу `224.0.0.251` и читает то, что
/// касса действительно отправила, — и разбирает это **своим** разбором, а не
/// тем, которым касса писала. Разбор общим кодом доказывал бы, что кодировщик
/// и декодировщик согласны между собой, и ровно ничего о том, поймёт ли их
/// планшет.
///
/// Порт взят частный, а не 5353: у Windows и macOS свой ответчик уже на 5353,
/// и его ответы попали бы в набор чужими датаграммами. Групповой адрес при
/// этом настоящий, отправка настоящая — меняется одно число.
@Tags(['native'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rk_mdns/rk_mdns.dart' as rk;
import 'package:telepos/data/transport/till_announcement.dart';

void main() {
  const port = 55353;

  test('нативная библиотека вообще загружается', () {
    final probe = rk.probeNativeLibrary();
    expect(
      probe.isUsable,
      isTrue,
      reason:
          'librk_mdns/rk_mdns.dll не найдена. Соберите её — cargo build '
          '--release в packages/rk_mdns/rust — и укажите RK_MDNS_LIBRARY на '
          'артефакт. Сейчас RK_MDNS_LIBRARY='
          '${Platform.environment['RK_MDNS_LIBRARY'] ?? '(не задана)'}. '
          'Проба ответила: $probe',
    );
  });

  late RawDatagramSocket watcher;
  late StreamController<Uint8List> heard;

  setUp(() async {
    heard = StreamController<Uint8List>.broadcast();
    watcher = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );
    watcher
      ..multicastLoopback = true
      ..listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = watcher.receive();
        if (datagram != null) heard.add(datagram.data);
      });

    // Вступить в группу на каждом интерфейсе, а не на «том, который выберет
    // таблица маршрутизации». Измерено 2026-08-05: на машине с четырьмя
    // интерфейсами обмен доходил на трёх и не доходил на выбранном по
    // умолчанию, и без этой строки набор краснел бы по причине, к коду
    // отношения не имеющей.
    for (final interface in await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    )) {
      try {
        watcher.joinMulticast(mdnsGroupV4, interface);
      } on Object {
        // Интерфейс без многоадресной рассылки. Остальные слушают.
      }
    }
  });

  tearDown(() async {
    watcher.close();
    await heard.close();
  });

  /// Ждёт датаграмму, в которой есть запись про нашу кассу.
  ///
  /// Фильтр по имени обязателен: в группе может говорить кто угодно, и первый
  /// пришедший пакет — не обязательно наш.
  ///
  /// [where] сужает ещё: ответчик за секунду отправляет пробу, объявление и
  /// повтор, и «первая датаграмма про till-4» после остановки с равной
  /// вероятностью окажется последним повтором, а не прощанием. Проверка,
  /// принявшая повтор за прощание, краснела бы через раз и по причине, к
  /// прощанию отношения не имеющей.
  Future<List<_Record>> awaitAnnouncement(
    String host, {
    bool Function(List<_Record>)? where,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    await for (final message in heard.stream) {
      final records = _parse(message);
      final ours = records
          .where((r) => r.name.toLowerCase().contains(host))
          .toList();
      if (ours.isNotEmpty && (where == null || where(ours))) {
        return records;
      }
      if (DateTime.now().isAfter(deadline)) break;
    }
    fail(
      'за восемь секунд в сети не появилось подходящей датаграммы про $host',
    );
  }

  test('объявление выходит в сеть и несёт имя, порты и адрес', () async {
    final started = await TillAnnouncement.start(
      name: 'till-3',
      httpsPort: 8787,
      quicPort: 55770,
      addresses: const ['192.168.1.50'],
      port: port,
    );
    expect(
      started,
      isA<TillAnnouncement>(),
      reason: started is AnnouncementUnavailable ? started.reason : '',
    );
    final announcement = started as TillAnnouncement;
    addTearDown(announcement.stop);

    final records = await awaitAnnouncement('till-3');

    // PTR: касса вообще есть, и вот как её зовут.
    //
    // Указателей в объявлении теперь ДВА, и выбирать надо по имени, а не
    // «первый попавшийся»: второй — `_services._dns-sd._udp.local` (RFC 6763
    // §9), тот самый, который спрашивает `avahi-browse -a`. Ответчик на Dart
    // его не отправлял, и касса была невидима для самого обычного способа
    // осмотреться в сети.
    final ptr = records.firstWhere(
      (r) => r.type == 12 && r.name == '_telepos._tcp.local',
    );
    expect(ptr.target, 'till-3._telepos._tcp.local');

    final enumeration = records.firstWhere(
      (r) => r.type == 12 && r.name == '_services._dns-sd._udp.local',
      orElse: () => fail(
        'в объявлении нет указателя перечисления служб — касса не появится '
        'в `avahi-browse -a` и в `dns-sd -B _services._dns-sd._udp`',
      ),
    );
    expect(enumeration.target, '_telepos._tcp.local');

    // SRV: где страница. Это тот порт, который откроет планшет.
    final srv = records.firstWhere((r) => r.type == 33);
    expect(srv.name, 'till-3._telepos._tcp.local');
    expect(srv.port, 8787);
    expect(srv.target, 'till-3.local');

    // A: по какому адресу. Без него запись разрешается в ничто.
    final a = records.where((r) => r.type == 1).toList();
    expect(a, isNotEmpty);
    expect(a.first.name, 'till-3.local');
    expect(a.first.address, '192.168.1.50');

    // TXT: порт QUIC — он другой и он UDP, и догадаться о нём нельзя.
    final txt = records.firstWhere((r) => r.type == 16);
    expect(txt.text, contains('quic=55770'));
    expect(txt.text, contains('scheme=https'));
  });

  test('на вопрос о службе касса отвечает, а не только вещает', () async {
    // Незапрошенное объявление живёт в кэше две минуты. Планшет, включённый
    // позже, задаёт вопрос — и если на него никто не отвечает, кассы для него
    // не существует, сколько бы она ни объявлялась до его появления.
    final announcement =
        await TillAnnouncement.start(
              name: 'till-9',
              httpsPort: 8788,
              quicPort: 55771,
              addresses: const ['10.0.0.7'],
              port: port,
            )
            as TillAnnouncement;
    addTearDown(announcement.stop);

    // Дать первому объявлению уйти, чтобы не спутать его с ответом.
    await awaitAnnouncement('till-9');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    for (final interface in await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    )) {
      for (final address in interface.addresses) {
        try {
          watcher.setRawOption(
            RawSocketOption(0, 9, Uint8List.fromList(address.rawAddress)),
          );
        } on Object {
          continue;
        }
        watcher.send(_question('_telepos._tcp.local', 12), mdnsGroupV4, port);
      }
    }

    final answer = await awaitAnnouncement('till-9');
    expect(
      answer.firstWhere((r) => r.type == 33).port,
      8788,
      reason: 'ответ на вопрос обязан нести то же, что объявление',
    );
  });

  test('прощание отзывает запись, а не оставляет её в кэше', () async {
    // Касса, которую выключили, остаётся в кэше планшета на время жизни
    // записи. Планшет всё это время будет ходить на адрес, где никого нет, и
    // отказ будет выглядеть как сетевой, а не как выключенная касса.
    final announcement =
        await TillAnnouncement.start(
              name: 'till-4',
              httpsPort: 8787,
              quicPort: 55770,
              addresses: const ['192.168.1.51'],
              port: port,
            )
            as TillAnnouncement;

    await awaitAnnouncement('till-4');

    // Подписаться ДО остановки, а не после. `stop()` возвращается уже после
    // того, как прощание ушло в сеть — в этом и смысл ожидания, — а `heard` —
    // широковещательный поток: датаграмма, пришедшая до подписки, просто
    // потеряна. Слушать после остановки означало бы ждать пять секунд того,
    // что уже случилось, и объявлять отсутствующим работающее прощание.
    final goodbyeHeard = awaitAnnouncement(
      'till-4',
      where: (ours) => ours.every((r) => r.ttl == 0),
    );
    await announcement.stop();

    final goodbye = await goodbyeHeard;
    expect(
      goodbye
          .where((r) => r.name.toLowerCase().contains('till-4'))
          .every((r) => r.ttl == 0),
      isTrue,
      reason: 'ноль в поле жизни — это и есть «забудьте про эту кассу»',
    );
  });

  test(
    'касса докладывает имя, которое заняла, а не то, о котором просили',
    () async {
      // Проба (RFC 6762 §8.1) может закончиться переименованием, и тогда
      // `till-3.local` принадлежит другой машине. Касса, которая напечатала бы в
      // журнал запрошенное имя, отправила бы оператора искать себя по адресу
      // чужого узла.
      final started = await TillAnnouncement.start(
        name: 'till-claimed',
        httpsPort: 8791,
        quicPort: null,
        addresses: const ['192.168.1.52'],
        port: port,
      );
      expect(
        started,
        isA<TillAnnouncement>(),
        reason: started is AnnouncementUnavailable ? started.reason : '',
      );
      final announcement = started as TillAnnouncement;
      addTearDown(announcement.stop);

      expect(announcement.instanceName, 'till-claimed._telepos._tcp.local');
      expect(announcement.hostName, 'till-claimed.local');
      expect(announcement.usingRequestedName, isTrue);
    },
  );

  test('вторая касса с тем же именем переименовывается, и это видно', () async {
    // То, ради чего и нужна проба. Две кассы, названные одинаково, — ошибка
    // настройки, и она обязана быть видимой, а не разрешаться тем, кто ответил
    // первым.
    final first = await TillAnnouncement.start(
      name: 'till-same',
      httpsPort: 8792,
      quicPort: null,
      addresses: const ['192.168.1.53'],
      port: port,
    );
    expect(first, isA<TillAnnouncement>());
    addTearDown((first as TillAnnouncement).stop);

    // Другой порт за тем же именем — именно так выглядят две кассы в одной
    // сети, и только это RFC 6762 §8.1 называет конфликтом: побайтово
    // одинаковые записи конфликтом не считаются.
    final second = await TillAnnouncement.start(
      name: 'till-same',
      httpsPort: 9792,
      quicPort: null,
      addresses: const ['192.168.1.54'],
      port: port,
    );
    expect(second, isA<TillAnnouncement>());
    final renamed = second as TillAnnouncement;
    addTearDown(renamed.stop);

    expect(renamed.instanceName, 'till-same-2._telepos._tcp.local');
    expect(
      renamed.hostName,
      'till-same-2.local',
      reason: 'имя узла осталось спорным, переехало только имя службы',
    );
    expect(renamed.usingRequestedName, isFalse);
    expect(
      first.usingRequestedName,
      isTrue,
      reason: 'касса, которая была первой, тоже переименовалась',
    );
  });
}

/// Вопрос в формате DNS: заголовок, одно поле вопроса, ничего больше.
Uint8List _question(String name, int type) {
  final out = BytesBuilder()
    ..add(_u16(0))
    ..add(_u16(0)) // QR=0 — это вопрос
    ..add(_u16(1))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(0));
  for (final label in name.split('.')) {
    out
      ..addByte(label.length)
      ..add(label.codeUnits);
  }
  out
    ..addByte(0)
    ..add(_u16(type))
    ..add(_u16(1));
  return out.toBytes();
}

Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v);

class _Record {
  _Record(this.name, this.type, this.ttl, this.data, this.message);

  final String name;
  final int type;
  final int ttl;
  final Uint8List data;
  final Uint8List message;

  /// Цель PTR и SRV. У SRV имя начинается после трёх двухбайтовых полей.
  String get target => type == 33
      ? _name(message, _offsetOf(data) + 6).name
      : _name(message, _offsetOf(data)).name;

  int get port => ByteData.sublistView(data).getUint16(4);

  String get address => data.join('.');

  String get text {
    final parts = <String>[];
    var i = 0;
    while (i < data.length) {
      final length = data[i];
      parts.add(String.fromCharCodes(data.sublist(i + 1, i + 1 + length)));
      i += 1 + length;
    }
    return parts.join(',');
  }

  /// Где `data` начинается внутри исходного сообщения — нужно, чтобы пойти по
  /// указателю сжатия, если он там есть.
  int _offsetOf(Uint8List part) {
    for (var i = 0; i + part.length <= message.length; i++) {
      var same = true;
      for (var j = 0; j < part.length; j++) {
        if (message[i + j] != part[j]) {
          same = false;
          break;
        }
      }
      if (same) return i;
    }
    return 0;
  }
}

/// Свой разбор ответа: тот же формат, другой код.
List<_Record> _parse(Uint8List message) {
  if (message.length < 12) return const <_Record>[];
  final view = ByteData.sublistView(message);
  if (view.getUint16(2) & 0x8000 == 0) return const <_Record>[];
  final questions = view.getUint16(4);
  final answers = view.getUint16(6);

  var offset = 12;
  for (var i = 0; i < questions; i++) {
    offset = _name(message, offset).next + 4;
  }

  final records = <_Record>[];
  for (var i = 0; i < answers; i++) {
    final read = _name(message, offset);
    offset = read.next;
    final type = view.getUint16(offset);
    final ttl = view.getUint32(offset + 4);
    final length = view.getUint16(offset + 8);
    final data = message.sublist(offset + 10, offset + 10 + length);
    records.add(_Record(read.name, type, ttl, data, message));
    offset += 10 + length;
  }
  return records;
}

class _Read {
  const _Read(this.name, this.next);
  final String name;
  final int next;
}

_Read _name(Uint8List message, int start) {
  final labels = <String>[];
  var offset = start;
  var next = -1;
  while (offset < message.length) {
    final length = message[offset];
    if (length == 0) {
      return _Read(labels.join('.'), next < 0 ? offset + 1 : next);
    }
    if (length & 0xc0 == 0xc0) {
      final target = ((length & 0x3f) << 8) | message[offset + 1];
      if (next < 0) next = offset + 2;
      offset = target;
      continue;
    }
    labels.add(
      String.fromCharCodes(message.sublist(offset + 1, offset + 1 + length)),
    );
    offset += 1 + length;
  }
  return _Read(labels.join('.'), offset);
}
