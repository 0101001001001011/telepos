/// Умолчание порта HTTP-зеркала стенда не садится на порт управления.
///
/// Приёмка 2026-09-13: второй стенд подняли с `TELEPOS_STAND_PORT=8971` и
/// `TELEPOS_STAND_CONTROL=8972` без `TELEPOS_STAND_HTTP`; зеркало взяло
/// «страница + 1» = 8972, и дверь управления на подъёме упала «адрес занят».
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/stand_ports.dart';

void main() {
  test('управление на «странице + 1» — зеркало берёт другой порт', () {
    final port = standPlainHttpPort(page: 8971, control: 8972);
    expect(port, isNot(8972));
    expect(port, isNot(8971));
  });

  test('без столкновения умолчание прежнее — «страница + 1»', () {
    expect(standPlainHttpPort(page: 8787, control: 8799), 8788);
  });

  test('названный порт берётся как есть', () {
    expect(
      standPlainHttpPort(page: 8787, control: 8799, explicit: '9001'),
      9001,
    );
  });

  test('названный порт управления — отказ словами, а не «адрес занят»', () {
    expect(
      () => standPlainHttpPort(page: 8787, control: 8799, explicit: '8799'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
