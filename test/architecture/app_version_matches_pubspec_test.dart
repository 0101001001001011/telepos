/// Версия в интерфейсе совпадает с `pubspec.yaml`.
///
/// # Чем это оплачено
///
/// На съёмке маркетингового ролика в один кадр попали **две версии, и обе
/// неверные**: `TelePOS v1.6.0` в боковой панели отчётов и `v1.0.0` в строке
/// состояния, при `3.6.0+21` в `pubspec.yaml`. Запечённое число не сломало
/// ни одной проверки — его просто некому было сверять.
///
/// # Почему сторож читает `pubspec.yaml`, а не повторяет число
///
/// Сторож, в котором версия написана second раз, — третья копия того же
/// числа: он позеленеет ровно тогда, когда его поправят вместе с
/// константой, и не заметит расхождения с настоящим источником. Источник
/// один — `pubspec.yaml`, версию оттуда поднимает `build_windows_installer.ps1`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/config/app_version.dart';

void main() {
  test('kAppVersion совпадает с версией из pubspec.yaml', () {
    final pubspec = File('pubspec.yaml');
    expect(
      pubspec.existsSync(),
      isTrue,
      reason: 'сторож без pubspec.yaml зелен всегда и не проверяет ничего',
    );

    final line = pubspec.readAsLinesSync().firstWhere(
      (l) => l.startsWith('version:'),
      orElse: () => '',
    );
    expect(
      line,
      isNotEmpty,
      reason: 'в pubspec.yaml нет строки version: — сверять не с чем',
    );

    // `3.6.0+21` → `3.6.0`: номер сборки меняется чаще версии и в интерфейсе
    // человеку не нужен.
    final fromPubspec = line.split(':').last.trim().split('+').first;

    expect(
      kAppVersion,
      fromPubspec,
      reason:
          'kAppVersion разошлась с pubspec.yaml. Версию поднимают только '
          'через tools/build_windows_installer.ps1 -Bump; поправьте '
          'lib/app/config/app_version.dart под неё, а не наоборот',
    );
  });
}
