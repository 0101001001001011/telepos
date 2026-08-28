/// Что касса решает **до** того, как что-либо уходит в сеть.
///
/// # Почему здесь больше нет датаграмм
///
/// Протокол переехал в `rk_mdns`, и вместе с ним переехали проверки на
/// настоящем сокете — в `test/native/rk_mdns_native_test.dart`, помеченные
/// `native`. Они краснеют при отсутствии собранной библиотеки, и это их
/// назначение: `flutter test` нативную часть не собирает, поэтому набор,
/// который бы её молча не нашёл, был бы зелен независимо от того, работает
/// нативный слой или его нет вовсе.
///
/// Здесь остаётся то, что можно решить без единого пакета: **отказы**. Каждый
/// из них — значение с фразой, а не исключение и не тишина (И144), потому что
/// «мы решили не объявляться», «объявление режет сеть» и «нативной части нет»
/// выглядят с планшета одинаково, а виноват в этом только один случай из трёх.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/transport/host_addresses.dart';
import 'package:telepos/data/transport/till_announcement.dart';

void main() {
  // Частный порт, а не 5353: даже когда объявление не доходит до сокета, у
  // проверки не должно быть ни одной причины задеть ответчик самой машины.
  const port = 55354;

  test('выключенное объявление — названное состояние, а не тишина', () async {
    // mDNS режут в части гостевых сетей, и оператор может выключить его сам.
    // Молча деградировавшая касса выглядит как сломанная сеть, и искать будут
    // не там.
    final outcome = await TillAnnouncement.start(
      name: 'till-3',
      httpsPort: 8787,
      quicPort: 55770,
      addresses: const ['192.168.1.50'],
      disabled: true,
      port: port,
    );

    expect(outcome, isA<AnnouncementUnavailable>());
    expect((outcome as AnnouncementUnavailable).reason, isNotEmpty);
    expect(
      outcome.reason,
      contains('выключено'),
      reason:
          'оператор, выключивший объявление, обязан узнать себя в этой фразе — '
          'иначе она неотличима от отказа',
    );
  });

  test('без адреса объявлять нечего, и это говорится вслух', () async {
    // Запись без `A` разрешается в ничто: в обозревателе служб касса видна, а
    // соединиться с ней нельзя. Это хуже, чем её отсутствие.
    final outcome = await TillAnnouncement.start(
      name: 'till-3',
      httpsPort: 8787,
      quicPort: 55770,
      addresses: const [],
      port: port,
    );

    expect(outcome, isA<AnnouncementUnavailable>());
    expect((outcome as AnnouncementUnavailable).reason, contains('адрес'));
  });

  test('занятое имя не превращается в безымянную запись', () async {
    final outcome = await TillAnnouncement.start(
      name: '   ',
      httpsPort: 8787,
      quicPort: 55770,
      addresses: const ['192.168.1.50'],
      port: port,
    );

    expect(outcome, isA<AnnouncementUnavailable>());
    expect((outcome as AnnouncementUnavailable).reason, contains('имени'));
  });

  test('отказы проверяются до того, как пакет вообще зовут', () async {
    // Всё выше отвечает одинаково и при собранной библиотеке, и без неё, и это
    // не совпадение: три проверки идут раньше единственного вызова в
    // `rk_mdns`. Обратное означало бы, что на машине без нативной части эти
    // три случая сливаются в один — «библиотеки нет», — и настроечная ошибка
    // перестаёт быть видимой ровно там, где её ищут.
    final byName = await TillAnnouncement.start(
      name: '',
      httpsPort: 8787,
      quicPort: null,
      addresses: const ['192.168.1.50'],
      port: port,
    );
    final byAddress = await TillAnnouncement.start(
      name: 'till-3',
      httpsPort: 8787,
      quicPort: null,
      addresses: const [],
      port: port,
    );

    expect(byName, isA<AnnouncementUnavailable>());
    expect(byAddress, isA<AnnouncementUnavailable>());
    expect(
      (byName as AnnouncementUnavailable).reason,
      isNot((byAddress as AnnouncementUnavailable).reason),
      reason: 'две разные ошибки настройки получили одну фразу',
    );
  });

  test('петля и адрес DHCP-отказа в объявление не попадают', () async {
    // Объявить `127.0.0.1` значит сказать планшету искать кассу внутри себя;
    // объявить `169.254.x.x` значит сказать «у меня есть адрес» ровно тогда,
    // когда его фактически нет.
    final addresses = await localIPv4Addresses();

    expect(addresses, isNot(contains('127.0.0.1')));
    expect(
      addresses.where((a) => a.startsWith('169.254.')),
      isEmpty,
      reason: 'link-local — это признак того, что DHCP не ответил',
    );
  });

  test('тип службы и время жизни записей — то, что ищет терминал', () async {
    // Числа, о которых договорились две стороны. Терминал ищет именно этот тип
    // и никакой другой, а два срока жизни отличаются намеренно: адрес машины
    // меняется по DHCP и потому живёт минуты, а факт существования службы —
    // нет.
    expect(tillServiceType, '_telepos._tcp.local');
    expect(tillHostTtl, const Duration(minutes: 2));
    expect(
      tillServiceTtl,
      greaterThan(tillHostTtl),
      reason:
          'факт существования службы обязан жить дольше адреса: иначе касса '
          'исчезает из списка каждый раз, когда DHCP выдаёт ей новый адрес',
    );
  });
}
