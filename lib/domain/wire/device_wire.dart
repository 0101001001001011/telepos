/// Форма `DeviceDiscovery`/`DeviceCheck` на проводе — **читатель и писатель в
/// одной паре**.
///
/// # Почему файл переехал сюда из `lib/web/`
///
/// Писатели здесь были всегда, но `lib/backend/terminal_routes.dart` их не
/// звал: у него были свои `_candidateToJson`/`_outcomeToJson`, написанные
/// отдельно, и в комментарии рядом с ними это утверждалось как решение —
/// «согласие между ними доказывает круговой тест, а не общая реализация».
/// Причина была настоящая: файл лежал в `lib/web/`, а `lib/backend/` не имеет
/// права туда смотреть.
///
/// Причина исчезла вместе с расположением. Здесь `lib/domain/` — чистый Dart,
/// куда разрешено смотреть обоим концам, — и `TillOperations` зовёт **эти**
/// функции (а до 2026-08-05 их же звал `TerminalRoutes`). Согласие сторон
/// стало структурным: расходиться нечему. Круговые тесты остались и проверяют
/// теперь саму пару.
///
/// Разбор к браузеру отношения не имеет и обязан собираться и проверяться под
/// обычным `flutter test`, без Chrome. До провода он жил в
/// `http_device_discovery.dart`/`http_device_check.dart`, а те тянули
/// `api_client.dart` и через него `dart:js_interop`, недоступный на VM, — то
/// есть проверить его было нечем. Все три файла сняты.
///
/// **Перечисления едут по имени, никогда по индексу** —
/// `lib/domain/setup/setup_draft_json.dart` — дом-образец: индекс меняет смысл
/// в тот момент, когда в перечисление вставили новый член, а эта форма решает,
/// что оператору скажут про его железо.
library;

import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/wire/terminal_wire.dart' show stringMapFromWire;

/// Reads back a [DeviceDiscoverySource] sent by name. An unrecognised name
/// means the backend is newer than this client — the same refusal
/// `deviceClassFromWireName` (`terminal_wire.dart`) makes for
/// `DeviceClass`, and for the same reason: guessing the nearest known source
/// would misreport where a candidate was actually found.
DeviceDiscoverySource deviceDiscoverySourceFromWireName(String? name) {
  for (final value in DeviceDiscoverySource.values) {
    if (value.name == name) return value;
  }
  throw StateError(
    'Касса прислала DeviceDiscoverySource="$name" по HTTP, которого не '
    'знает DeviceDiscoverySource.values '
    '(${DeviceDiscoverySource.values.map((s) => s.name).join(', ')}). '
    'Похоже, бэкенд новее этого браузерного клиента. Отказываюсь угадывать '
    'источник обнаружения.',
  );
}

Map<String, Object?> deviceCandidateToJson(DeviceCandidate candidate) => {
  'source': candidate.source.name,
  'title': candidate.title,
  'parameters': candidate.parameters,
};

/// A missing or empty `title` is refused, not defaulted to `''` (finding M2)
/// — the same rule, for the same reason, that
/// [deviceCheckOutcomeFromWireJson] already applies to `message`.
/// [DeviceCandidate.title] is the whole of what an operator picks by: an
/// empty one renders a `ListTile` with no label, and manufacturing it here
/// turns a backend defect into a row that looks choosable and says nothing.
DeviceCandidate deviceCandidateFromWireJson(Map<String, dynamic> json) {
  final title = json['title'] as String?;
  if (title == null || title.isEmpty) {
    throw StateError(
      'Касса прислала DeviceCandidate (source="${json['source']}") без '
      'непустого title — DeviceCandidate.title обязано быть непустым: по '
      'нему оператор и выбирает. Отказываюсь тихо подставлять "".',
    );
  }
  return DeviceCandidate(
    source: deviceDiscoverySourceFromWireName(json['source'] as String?),
    title: title,
    parameters: stringMapFromWire(json['parameters']),
  );
}

Map<String, Object?> deviceDiscoveryResultToJson(DeviceDiscoveryResult result) => {
  'candidates': result.candidates.map(deviceCandidateToJson).toList(),
  // Fix round 1's whole reason for existing (see device_discovery.dart's doc
  // comment on DeviceDiscoveryResult): "no devices attached" and "could not
  // reach the till" must read differently to a browser operator. Dropping
  // this field on the way to JSON would silently rebuild exactly that
  // defect one layer up.
  'failedSources': result.failedSources.map((s) => s.name).toList(),
};

DeviceDiscoveryResult deviceDiscoveryResultFromWireJson(
  Map<String, dynamic> json,
) {
  final rawCandidates = json['candidates'];
  final rawFailed = json['failedSources'];
  return DeviceDiscoveryResult(
    candidates: rawCandidates is List
        ? rawCandidates
              .whereType<Map<String, dynamic>>()
              .map(deviceCandidateFromWireJson)
              .toList()
        : const [],
    failedSources: rawFailed is List
        ? rawFailed
              .whereType<String>()
              .map(deviceDiscoverySourceFromWireName)
              .toSet()
        : const {},
  );
}

/// Reads back a [DeviceCheckReason] sent by name. Same refusal, same reason,
/// as [deviceDiscoverySourceFromWireName] — see that function's doc comment.
DeviceCheckReason deviceCheckReasonFromWireName(String? name) {
  for (final value in DeviceCheckReason.values) {
    if (value.name == name) return value;
  }
  throw StateError(
    'Касса прислала DeviceCheckReason="$name" по HTTP, которого не знает '
    'DeviceCheckReason.values '
    '(${DeviceCheckReason.values.map((r) => r.name).join(', ')}). Похоже, '
    'бэкенд новее этого браузерного клиента. Отказываюсь угадывать причину.',
  );
}

Map<String, Object?> deviceCheckOutcomeToJson(DeviceCheckOutcome outcome) => {
  'reason': outcome.reason.name,
  'message': outcome.message,
};

/// Reconstructs the outcome via `DeviceCheckOutcome.wire` — never via one of
/// the reason-specific factories, which regenerate their own message from a
/// `DeviceClass`/detail and would silently discard whatever text the till
/// actually computed (see that factory's doc comment).
///
/// A missing or empty `message` is refused, not defaulted to `''` (fix
/// round 1, minor finding): [DeviceCheckOutcome.message] advertises "Always
/// non-empty" — quietly manufacturing the one value that invariant forbids
/// would be worse than the null-check it replaces, because every later
/// reader trusts the invariant instead of re-checking it.
DeviceCheckOutcome deviceCheckOutcomeFromWireJson(Map<String, dynamic> json) {
  final message = json['message'] as String?;
  if (message == null || message.isEmpty) {
    throw StateError(
      'Касса прислала DeviceCheckOutcome (reason="${json['reason']}") без '
      'непустого message — DeviceCheckOutcome.message обязано быть '
      'непустым всегда. Отказываюсь тихо подставлять "".',
    );
  }
  return DeviceCheckOutcome.wire(
    reason: deviceCheckReasonFromWireName(json['reason'] as String?),
    message: message,
  );
}
