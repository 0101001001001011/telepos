import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/app_constants.dart';

/// Версия приложения обязана быть одна.
///
/// Написан 2026-08-04, когда экран запуска печатал `v3.3.0` при версии
/// `3.5.0+19` в `pubspec.yaml`. Механика была такая: на сплеше стоял литерал
/// как запасное значение, `BuildConfig` никто не регистрировал, — и запасное
/// значение стало единственным. Экран уверенно показывал версию, которой не
/// существовало уже две минорных.
///
/// Выдуманная версия хуже отсутствующей: поддержка спрашивает «какая версия»,
/// получает ответ и начинает искать дефект не в том выпуске.
///
/// Тест держит ровно одно утверждение: число в коде совпадает с числом в
/// `pubspec.yaml`. Пока литералов было два, «не забыть поправить оба» было
/// обязанностью человека; теперь расхождение не проходит в main.
void main() {
  test('AppConstants.appVersion совпадает с версией в pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(
      match,
      isNotNull,
      reason: 'в pubspec.yaml не нашлась строка version: X.Y.Z',
    );

    expect(
      AppConstants.appVersion,
      match!.group(1),
      reason: 'версия в app_constants.dart разошлась с pubspec.yaml — '
          'поправьте обе или уберите вторую',
    );
  });
}
