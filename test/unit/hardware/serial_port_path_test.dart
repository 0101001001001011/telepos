/// Путь последовательного прибора: имя устройства и путь файла — разные вещи.
///
/// # Почему это не косметика
///
/// Касса дописывала `\\.\` ко всякому порту. Для `COM10` это обязательно, для
/// пути файла — смертельно: Windows читает `\\.\C:\…` как **сетевой** путь и
/// отказывает с errno 53. Пока портом бывало только имя COM, разницы не было;
/// с решением заказчика «эмулятор без установки стороннего драйвера» она
/// появилась сразу.
///
/// # Проба идёт через настоящий файл, а не через строку
///
/// Сравнивать полученный путь со строкой значило бы проверить, что функция
/// делает то, что написано в функции. Здесь другое: файл **открывается тем
/// самым путём**, который она вернула, — и та же проба на старом поведении
/// падала бы (проверено измерением до правки).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/hardware/serial/serial_port_path.dart';

void main() {
  test('путь файла открывается тем путём, который вернула функция', () async {
    final dir = Directory.systemTemp.createTempSync('telepos_serial_path');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}scale.txt')
      ..writeAsStringSync('ST,GS,  1.250kg\r\n');

    final raf = await File(serialPortPath(file.path)).open();
    addTearDown(raf.close);
    final bytes = await raf.read(await raf.length());

    expect(
      String.fromCharCodes(bytes),
      contains('1.250'),
      reason:
          'до правки этот же путь получал префикс устройства и отказывал с '
          'errno 53 — измерено',
    );
  });

  test('имя COM-порта получает префикс устройства — иначе COM10 не открыть', () {
    final path = serialPortPath('COM10');

    if (Platform.isWindows) {
      expect(path, r'\\.\COM10');
    } else {
      expect(
        path,
        'COM10',
        reason: 'пространства устройств Windows на этой платформе нет',
      );
    }
  });

  test('регистр имени не меняет решения: в настройках пишут по-разному', () {
    final upper = serialPortPath('COM3');
    final lower = serialPortPath('com3');

    expect(
      lower.endsWith('com3'),
      isTrue,
      reason: 'имя не переписывается — Windows его и так не различает',
    );
    expect(
      lower.startsWith(r'\\'),
      upper.startsWith(r'\\'),
      reason: 'иначе `com3` в настройках вёл бы себя иначе, чем `COM3`',
    );
  });

  test('уже готовый путь устройства не обрастает вторым префиксом', () {
    expect(serialPortPath(r'\\.\COM11'), r'\\.\COM11');
  });

  test('путь Unix не трогается', () {
    expect(serialPortPath('/dev/ttyUSB0'), '/dev/ttyUSB0');
  });
}
