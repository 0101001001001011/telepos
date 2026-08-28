import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/net/listen_scope.dart';
import 'package:telepos/data/transport/webtransport_endpoint.dart';

/// Второй слушатель кассы — тот же выбор адреса, и та же ловушка.
///
/// # Почему проверяется таблица адресов, а не поднятый сокет
///
/// `startWebTransport` уходит в `package:rk_quic`, а тот — в `dart:ffi`:
/// поднять слушатель в `flutter test` нечем, нативной библиотеки рядом с
/// тестом нет. Соединение по обоим семействам поверх настоящего сокета
/// проверяется там, где библиотека есть, — `packages/rk_quic/rust/tests/
/// dual_stack.rs`, и именно там доказано, что без явного `IPV6_V6ONLY = 0`
/// сокет на `[::]` под Windows не отвечает по `127.0.0.1` (клиент отваливается
/// по таймауту за 30 секунд).
///
/// Здесь — то, чего тот тест не видит: какой адрес касса вообще просит. Без
/// этой проверки возврат строки `'0.0.0.0'` в таблицу прошёл бы через весь
/// набор зелёным, потому что ни один тест на Dart не поднимает этот сокет.
void main() {
  test('«все адреса» — это подстановочный IPv6, а не 0.0.0.0', () {
    // Краснеет ровно на том возврате, из-за которого задача и появилась.
    expect(quicAddressesFor(ListenScope.everywhere), ['[::]']);
    expect(
      quicAddressesFor(ListenScope.everywhere),
      isNot(contains('0.0.0.0')),
      reason:
          'слушатель на одном IPv4 молчит для браузера, который разрешил имя '
          'кассы в IPv6, и молчит беззвучно: Chrome сообщает '
          'QUIC_NETWORK_IDLE_TIMEOUT с num_undecryptable_packets: 0',
    );
  });

  test('у петли адреса два — одним сокетом оба семейства не закрыть', () {
    expect(quicAddressesFor(ListenScope.loopback), ['[::1]', '127.0.0.1']);
  });

  test('петля не расширяется до всех адресов ни обязательными, ни запасными', () {
    // Это про безопасность: касса без терминалов не открывает порт наружу.
    // Молчаливое расширение здесь хуже, чем неудобство, и запасной путь —
    // самое естественное место, где оно могло бы появиться незаметно.
    final all = [
      ...quicAddressesFor(ListenScope.loopback),
      ...quicFallbackAddressesFor(ListenScope.loopback),
    ];
    expect(all, isNot(contains('0.0.0.0')));
    expect(all, isNot(contains('[::]')));
  });

  test('запасной путь «всех адресов» — только IPv4 и только один', () {
    // Он существует для машины с выключенным IPv6, где `[::]` не биндится
    // вовсе: без него касса перестала бы отдавать страницу совсем, что было бы
    // регрессом против прежнего `0.0.0.0`.
    expect(quicFallbackAddressesFor(ListenScope.everywhere), ['0.0.0.0']);
  });
}
