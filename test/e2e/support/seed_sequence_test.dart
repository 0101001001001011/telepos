import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'seed_sequence.dart';

/// Посев уникален по построению, а не по везению часов — задача 40.
void main() {
  test('десять тысяч посевов подряд не повторяются', () {
    final seen = <int>{};
    for (var i = 0; i < 10000; i++) {
      seen.add(nextSeed());
    }
    expect(
      seen,
      hasLength(10000),
      reason:
          'два посева внутри одного тика часов обязаны различаться: иначе '
          'вторая вставка ложится на UNIQUE, и проба краснеет не за код',
    );
  });

  test('посев проб сервиса не берёт уникальность из часов', () {
    // Сторож по тексту: оба файла, где приём был найден, обязаны звать
    // счётчик, а не часы. Строки с `SinceEpoch` в других колонках (время
    // приёма, время записи) законны — это время, а не уникальность.
    const files = [
      'test/e2e/journeys/service_money_bugs_test.dart',
      'test/e2e/journeys/service_warranty_claim_test.dart',
    ];
    final clockSeed = RegExp(r"orderNumber:\s*'[^']*\$\{DateTime\.now\(\)");
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(clockSeed.hasMatch(source), isFalse, reason: path);
      expect(source, contains('nextSeed()'), reason: path);
    }
  });
}
