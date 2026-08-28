import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/hardware/printer/linux_printer.dart';
import 'package:telepos/hardware/printer/receipt_builder.dart';

/// Последовательный и USB-провод: что повторяется, а что не может повторяться.
///
/// Проверяется то, что доходит до устройства, а не то, сколько раз вызвана
/// запись: «повтор был» ничего не говорит о том, сколько чеков вылезло из
/// принтера.
void main() {
  /// Чек, который система действительно умеет произвести.
  Uint8List receiptBytes() {
    return (ReceiptBuilder(charWidth: 32)
          ..init()
          ..addCentered('ТОО «Дүкен №2»', bold: true)
          ..addLeft('Кассаүй: Ысык-Көл')
          ..addRow('Сумма', '1 234.005')
          ..addLine()
          ..addRow('ИТОГО', '1 234.005', bold: true)
          ..addNewLines(2)
          ..cut())
        .build();
  }

  int countSublist(List<int> haystack, List<int> needle) {
    if (needle.isEmpty) return 0;
    var found = 0;
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      var hit = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          hit = false;
          break;
        }
      }
      if (hit) found++;
    }
    return found;
  }

  LinuxPrinterManager managerFor(
    _FakeNode node, {
    List<String> nodes = const ['/dev/usb/lp0'],
    Duration reopenDelay = const Duration(milliseconds: 10),
    Duration retryBudget = const Duration(milliseconds: 400),
  }) {
    return LinuxPrinterManager(
      devicePath: '/dev/usb/lp0',
      deviceOpener: node.open,
      nodeLister: () => nodes,
      nodeExists: (path) => nodes.contains(path),
      reopenDelay: reopenDelay,
      retryBudget: retryBudget,
    );
  }

  group('Запись', () {
    test('запись, упавшая на середине, не отправляется второй раз (И29)', () async {
      // Провод не сообщает, сколько байтов из упавшей записи стало бумагой.
      // Значит повторить её нельзя: напечатается хвост чека, а следом целый.
      final payload = receiptBytes();
      final node = _FakeNode(throwAfterBytes: 40);
      final printer = managerFor(node);
      addTearDown(printer.disconnect);

      final result = await printer.printReceipt(payload);

      // Сначала — байты на устройстве: именно они, а не текст ошибки,
      // отличают «не повторили» от «повторили и напечатали лишнее».
      final everything = <int>[
        for (final device in node.devices) ...device.received,
      ];
      expect(
        everything,
        hasLength(40),
        reason: 'до устройства дошло ровно то, что оно успело принять, и всё',
      );
      expect(countSublist(everything, payload), 0);
      expect(
        node.openCalls,
        1,
        reason: 'после отданных байтов переоткрывать и слать заново нельзя',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('не подтверждена'));
      expect(
        result.errorMessage,
        contains('подтвердило 0 из ${payload.length}'),
        reason:
            'сорок байтов ушли в устройство, но подтверждения нет ни на один — '
            'сказать «отдано 0» значило бы соврать в другую сторону',
      );
      expect(
        result.errorMessage,
        contains('могла уже стать бумагой'),
        reason: 'очередь должна знать, что это не «ничего не напечатано»',
      );
    });

    test('короткая запись дописывается, а не отправляется заново', () async {
      // Обратный случай: устройство сказало, сколько байтов приняло. Это
      // решаемо — остаток дописывается, и это продолжение того же потока, а не
      // повтор.
      final payload = receiptBytes();
      final node = _FakeNode(acceptPerCall: 40);
      final printer = managerFor(node);
      addTearDown(printer.disconnect);

      final result = await printer.printReceipt(payload);

      expect(result.success, isTrue);
      expect(result.bytesSent, payload.length);

      final device = node.devices.single;
      expect(device.received, payload, reason: 'чек собрался ровно один раз');
      expect(
        countSublist(device.received, payload),
        1,
        reason: 'дописывание не должно печатать ничего дважды',
      );
      expect(device.writeCalls, (payload.length / 40).ceil());
      expect(device.flushes, 1);
    });

    test('устройство, не принявшее ни байта, не крутится в цикле', () async {
      final node = _FakeNode(acceptPerCall: 0);
      final printer = managerFor(node);
      addTearDown(printer.disconnect);

      final started = DateTime.now();
      final result = await printer.printReceipt(receiptBytes());
      final elapsed = DateTime.now().difference(started);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('не подтверждена'));
      expect(node.devices.single.writeCalls, 1);
      expect(elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('открыть устройство можно повторно — открытие ничего не печатает', () async {
      final payload = receiptBytes();
      final node = _FakeNode(failOpenFirst: 2);
      final printer = managerFor(node);
      addTearDown(printer.disconnect);

      final result = await printer.printReceipt(payload);

      expect(result.success, isTrue);
      expect(node.openCalls, 3, reason: 'два отказа открытия повторяются');
      expect(node.devices.single.received, payload);
    });

    test('число попыток открыть ограничено и по счёту, и по времени', () async {
      final node = _FakeNode(failOpenAlways: true);
      final printer = managerFor(
        node,
        reopenDelay: const Duration(milliseconds: 10),
        retryBudget: const Duration(milliseconds: 400),
      );
      addTearDown(printer.disconnect);

      final started = DateTime.now();
      final result = await printer.printReceipt(receiptBytes());
      final elapsed = DateTime.now().difference(started);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('ничего не отправлено'));
      expect(
        node.openCalls,
        lessThanOrEqualTo(LinuxPrinterManager.defaultMaxOpenAttempts),
      );
      expect(elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('когда узла нет вовсе, печать не ждёт возвращения несуществующего', () async {
      final node = _FakeNode();
      final printer = managerFor(
        node,
        nodes: const [],
        reopenDelay: const Duration(milliseconds: 300),
      );
      addTearDown(printer.disconnect);

      final started = DateTime.now();
      final result = await printer.printReceipt(receiptBytes());
      final elapsed = DateTime.now().difference(started);

      expect(result.success, isFalse);
      expect(node.openCalls, 0);
      expect(
        elapsed,
        lessThan(const Duration(milliseconds: 250)),
        reason: 'ждать нечего: узла нет — И30',
      );
    });

    test('два чека подряд доходят целиком и в порядке отправки', () async {
      final node = _FakeNode();
      final printer = managerFor(node);
      addTearDown(printer.disconnect);

      final first = receiptBytes();
      final second = (ReceiptBuilder(charWidth: 32)
            ..init()
            ..addCentered('ВОЗВРАТ')
            ..addRow('ИТОГО', '-0.005')
            ..cut())
          .build();

      expect((await printer.printReceipt(first)).success, isTrue);
      expect((await printer.printReceipt(second)).success, isTrue);

      expect(node.devices.single.received, [...first, ...second]);
    });
  });

  group('Состояние и ресурсы', () {
    test('исчезнувший узел виден как offline', () async {
      final nodes = <String>['/dev/usb/lp0'];
      final node = _FakeNode();
      final printer = LinuxPrinterManager(
        devicePath: '/dev/usb/lp0',
        deviceOpener: node.open,
        nodeLister: () => nodes,
        nodeExists: nodes.contains,
      );
      addTearDown(printer.disconnect);

      await printer.connect();
      expect((await printer.getStatus()).isReady, isTrue);

      nodes.clear(); // принтер выдернули

      final status = await printer.getStatus();
      expect(status.isReady, isFalse);
      expect(printer.isConnected, isFalse);
      expect(node.devices.single.closed, isTrue);
    });

    test('disconnect закрывает устройство', () async {
      final node = _FakeNode();
      final printer = managerFor(node);

      await printer.connect();
      await printer.disconnect();

      expect(node.devices.single.closed, isTrue);
      expect(printer.isConnected, isFalse);
    });
  });
}

/// Узел устройства: считает открытия и хранит устройства, которые выдал.
class _FakeNode {
  _FakeNode({
    this.failOpenFirst = 0,
    this.failOpenAlways = false,
    this.acceptPerCall,
    this.throwAfterBytes,
  });

  final int failOpenFirst;
  final bool failOpenAlways;

  /// Сколько байтов устройство принимает за один вызов записи.
  final int? acceptPerCall;

  /// После скольких принятых байтов запись падает — байты при этом уже ушли в
  /// устройство, и провод не сообщает, сколько именно.
  final int? throwAfterBytes;

  int openCalls = 0;
  final List<_FakeDevice> devices = [];

  PrinterCharDevice open(String path) {
    openCalls++;
    if (failOpenAlways || openCalls <= failOpenFirst) {
      throw const FileSystemException('Permission denied', '/dev/usb/lp0');
    }
    final device = _FakeDevice(
      acceptPerCall: acceptPerCall,
      throwAfterBytes: throwAfterBytes,
    );
    devices.add(device);
    return device;
  }
}

class _FakeDevice implements PrinterCharDevice {
  _FakeDevice({this.acceptPerCall, this.throwAfterBytes});

  final int? acceptPerCall;
  final int? throwAfterBytes;

  final List<int> received = [];
  int writeCalls = 0;
  int flushes = 0;
  bool closed = false;

  @override
  bool get isOpen => !closed;

  @override
  int write(Uint8List data) {
    writeCalls++;

    final limit = throwAfterBytes;
    if (limit != null) {
      final room = limit - received.length;
      if (room <= 0) {
        throw const FileSystemException('write failed', '/dev/usb/lp0');
      }
      if (data.length > room) {
        // Часть байтов устройство уже проглотило, и только потом провод упал.
        received.addAll(data.take(room));
        throw const FileSystemException('write failed', '/dev/usb/lp0');
      }
    }

    final accepted = acceptPerCall == null
        ? data.length
        : min(acceptPerCall!, data.length);
    received.addAll(data.take(accepted));
    return accepted;
  }

  @override
  void flush() => flushes++;

  @override
  void close() => closed = true;
}
