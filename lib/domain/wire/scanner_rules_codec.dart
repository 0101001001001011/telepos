/// Кодек правил чтения штрихкода (`ScannerRules`) — ответ операции
/// `scanner.rules` (задача 45) **и тело операции `scanner.saveRules`**
/// (пункт 11 ревизии 2026-09-19).
///
/// Одна пара на оба направления нарочно: форма правил на проводе одна, и
/// второй разборщик у записи означал бы, что касса принимает не то, что
/// отдаёт, — разойтись они могли бы молча.
///
/// Три числа, каждое может отсутствовать по существу («не задано — берётся
/// умолчание», `ScannerRules.effective*`). Поэтому `null` едет значением под
/// ключом, а **пропущенный ключ — отказ разбора**: иначе касса, забывшая
/// поле, и касса, где магазин его не задавал, выглядели бы одинаково, и
/// терминал молча читал бы коды по зашитым длинам — ровно дефект, который
/// задача 45 снимает.
library;

import 'package:telepos/domain/repositories/scanner_rules_repository.dart';

const _minKey = 'barcodeMinLength';
const _maxKey = 'barcodeMaxLength';
const _timeoutKey = 'scannerTimeoutMs';

Map<String, Object?> scannerRulesToWireJson(ScannerRules rules) => {
  _minKey: rules.barcodeMinLength,
  _maxKey: rules.barcodeMaxLength,
  _timeoutKey: rules.scannerTimeoutMs,
};

/// Проверку троицы (min ≤ max, каждое ≥ 1) делает конструктор
/// [ScannerRules]: разбор не повторяет её и не смягчает.
ScannerRules scannerRulesFromWireJson(Map<String, Object?> json) {
  for (final key in const [_minKey, _maxKey, _timeoutKey]) {
    if (!json.containsKey(key)) {
      throw FormatException('scanner.rules: в ответе нет поля $key');
    }
  }
  return ScannerRules(
    barcodeMinLength: json[_minKey] as int?,
    barcodeMaxLength: json[_maxKey] as int?,
    scannerTimeoutMs: json[_timeoutKey] as int?,
  );
}
