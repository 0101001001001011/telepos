/// Встроенный эмулятор: сокет настоящий, адрес показанный — тот же самый.
///
/// # Чего эти пробы НЕ доказывают
///
/// Они не говорят ничего о том, дойдёт ли до эмулятора касса: за это отвечает
/// привязка прибора и `receipt_wire_stand.dart`, где чек идёт настоящей
/// очередью печати. Здесь проверяется только держатель сокета: тот ли порт он
/// называет, тот ли гасит и не подменяет ли он по дороге чужие настройки.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/core/settings/builtin_emulator_settings.dart';
import 'package:telepos/emulators/builtin_emulator_host.dart';
import 'package:telepos/hardware/scales/scales_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Спрашивает пульт эмулятора голым сокетом.
  ///
  /// Не `HttpClient`: под `TestWidgetsFlutterBinding` он отвечает 400, не
  /// выходя в сеть, и проба «пульт отвечает» была бы зелёной при любом пульте.
  /// Измерено — первая редакция получила ровно 400.
  Future<String> ask(BuiltinEmulatorAddress address, String path) async {
    final socket = await Socket.connect(address.host!, address.controlPort!);
    const crlf = '\r\n';
    socket.write(
      'GET $path HTTP/1.1${crlf}Host: ${address.host}$crlf'
      'Connection: close$crlf$crlf',
    );
    await socket.flush();
    return socket
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
  }

  group('Держатель встроенных эмуляторов', () {
    late BuiltinEmulatorHost host;

    // Свой диапазон, а не боевой 9100: проба, дерущаяся с машиной за
    // фиксированный номер, меряет машину. Измерено в тот же час — 9100 держал
    // `dart devtools`, и первая редакция этой пробы падала именно об него.
    BuiltinEmulatorHost hostIn(int from, int to) => BuiltinEmulatorHost(
      portRanges: {BuiltinEmulatorKind.receiptPrinter: (from, to)},
    );

    setUp(() => host = hostIn(18600, 18609));
    tearDown(() => host.stopAll());

    test('боевой диапазон начинается с привычного порта принтера', () {
      expect(
        BuiltinEmulatorHost.defaultPortRanges[
          BuiltinEmulatorKind.receiptPrinter
        ],
        (9100, 9109),
        reason: 'кассир ищет глазами 9100; запас нужен, потому что его занимают',
      );
    });

    test('поднятый адрес — тот, где действительно слушает сокет', () async {
      final address = await host.start(BuiltinEmulatorKind.receiptPrinter);

      // Не «порт не ноль» и не «соединение приняли», а «байты дошли и
      // разобрались»: неверный порт проходит первую проверку, мёртвый
      // слушатель — вторую.
      final socket = await Socket.connect(address.host!, address.port!);
      addTearDown(socket.destroy);
      socket.add([0x1B, 0x40, ...'проба'.codeUnits, 0x0A]);
      await socket.flush();

      // Задание отделяется паузой в 150 мс — ждём его появления, а не спим
      // наугад. Сокет не закрываем: настоящий принтер держит его открытым, и
      // эмулятор ведёт себя так же (первая редакция пробы на этом и повисла).
      var state = '';
      for (var i = 0; i < 40 && !state.contains('"jobs":1'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        state = await ask(address, '/_emul/state');
      }

      expect(
        state,
        contains('"jobs":1'),
        reason: 'сокет открыт, но чек до разборщика не дошёл',
      );
      expect(
        host.addressOf(BuiltinEmulatorKind.receiptPrinter)?.port,
        address.port,
        reason: 'экран показывает адрес отсюда — он обязан совпасть с занятым',
      );
    });

    test('занятый порт обходится, и назван новый, а не привычный', () async {
      // Занимаем первый порт диапазона сами — ровно то, что делает на машине
      // разработки `dart devtools`, неделями сидящий на 9100.
      final squatter = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        18620,
      );
      addTearDown(squatter.close);

      host = hostIn(18620, 18629);
      final address = await host.start(BuiltinEmulatorKind.receiptPrinter);

      expect(
        address.port,
        isNot(18620),
        reason: 'занятый порт назвать нельзя: кассир впишет его в привязку',
      );
      final socket = await Socket.connect(address.host!, address.port!);
      addTearDown(socket.destroy);
      expect(socket.remotePort, address.port);
    });

    test('пульт отвечает на своём порту, и он тоже назван', () async {
      final address = await host.start(BuiltinEmulatorKind.receiptPrinter);

      final reply = await ask(address, '/_emul/state');

      expect(reply, contains('200'));
      expect(
        reply,
        contains('drawerKicks'),
        reason: 'это состояние эмулятора, а не чужой сервер на том же порту',
      );
    });

    test('повторный запуск — тот же адрес, а не перезапуск', () async {
      final first = await host.start(BuiltinEmulatorKind.receiptPrinter);
      final second = await host.start(BuiltinEmulatorKind.receiptPrinter);

      expect(
        second.port,
        first.port,
        reason: 'перезапуск порвал бы соединение очереди печати ради ничего',
      );
    });

    test('погашенный эмулятор соединения больше не принимает', () async {
      final address = await host.start(BuiltinEmulatorKind.receiptPrinter);
      await host.stop(BuiltinEmulatorKind.receiptPrinter);

      expect(host.isRunning(BuiltinEmulatorKind.receiptPrinter), isFalse);
      await expectLater(
        Socket.connect(
          address.host!,
          address.port!,
          timeout: const Duration(seconds: 2),
        ),
        throwsA(isA<SocketException>()),
        reason: 'касса обязана увидеть отказ, а не тишину',
      );
    });

    test('гасить непогашенное — не ошибка', () async {
      await host.stop(BuiltinEmulatorKind.receiptPrinter);
      expect(host.addressOf(BuiltinEmulatorKind.receiptPrinter), isNull);
    });
  });

  group('Решение оператора о встроенных эмуляторах', () {
    test('новая установка не поднимает ничего', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(
        BuiltinEmulatorChoice.read(prefs).enabled,
        isEmpty,
        reason: 'из коробки не открывается ни один сокет',
      );
    });

    test('записанное решение читается обратно', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await BuiltinEmulatorChoice.write(
        prefs,
        BuiltinEmulatorKind.receiptPrinter,
        enabled: true,
      );

      expect(
        BuiltinEmulatorChoice.read(
          prefs,
        ).isEnabled(BuiltinEmulatorKind.receiptPrinter),
        isTrue,
      );
    });

    test('значение чужого типа под ключом гасит прибор, а не бросает', () async {
      SharedPreferences.setMockInitialValues({
        builtinEmulatorPrefsKey(BuiltinEmulatorKind.receiptPrinter): 'да',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        BuiltinEmulatorChoice.read(prefs).enabled,
        isEmpty,
        reason: 'испорченная настройка не имеет права открыть сокет',
      );
    });
  });

  group('Встроенные весы — насквозь до кассы', () {
    test('вес, заданный пультом, доходит до ScalesService', () async {
      final host = BuiltinEmulatorHost();
      addTearDown(host.stopAll);

      final address = await host.start(BuiltinEmulatorKind.scale);
      expect(
        address.path,
        isNotNull,
        reason: 'у последовательного прибора адрес — путь, а не порт',
      );
      host.setScaleWeight('1.250');

      // Касса идёт к эмулятору СВОИМ `ScalesService`: своим открытием порта,
      // своим опросом, своим разбором строки. Подставь мы сюда свой источник
      // веса — проверка перестала бы говорить что-либо о настоящих весах.
      final scales = ScalesService(port: address.path);
      addTearDown(scales.dispose);
      final connected = await scales.connect();
      expect(
        connected.success,
        isTrue,
        reason: 'порт-файл обязан открыться: ${connected.errorMessage}',
      );

      final reading = await scales.weightStream.first.timeout(
        const Duration(seconds: 10),
      );
      expect(
        reading.weight.toStringAsFixed(3),
        '1.250',
        reason:
            'это и есть та самая проверка «всё в комплексе»: ничего не '
            'установлено, а вес с подставных весов дошёл до кассы',
      );
    });
  });
}
