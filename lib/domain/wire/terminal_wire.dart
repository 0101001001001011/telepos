/// Форма [Terminal] и [DeviceBinding] на проводе — **читатель и писатель в
/// одной паре**.
///
/// # Почему файл переехал сюда из `lib/web/`
///
/// До 2026-08-04 каждая из этих форм была написана дважды и вручную: читатель
/// жил здесь, писатель — в `lib/backend/terminal_routes.dart` (`_toJson`,
/// `_bindingToJson`), а третья копия писателя привязки лежала прямо в теле
/// `HttpDeviceBindingRepository.save`. Рядом с писателем это было записано
/// прямо: «эта пара функций написана независимо по обе стороны провода… а не
/// через общий код, и согласие между ними доказывает круговой тест, а не общая
/// реализация».
///
/// Круговой тест доказывает согласие только тех полей, которые в нём названы.
/// Поле, добавленное на одной стороне и забытое на другой, он не заметит —
/// заметить нечего, теста на новое поле никто не написал. Ровно так и жила
/// форма `setup.state`: писатель никогда не слал `hasUsers`, читатель его
/// читал, и браузерный терминал вечно видел «пользователей нет».
///
/// Здесь пара — одна функция туда и одна обратно, видимые обоим концам.
/// Согласие стало структурным: писатель и читатель нельзя изменить порознь,
/// потому что менять нечего порознь. Круговые тесты остались и проверяют
/// теперь саму пару — что она не теряет полей на круге.
///
/// # Почему это `lib/domain/`, а не `lib/data/` и не `lib/web/`
///
/// Форма провода — общий договор кассы и терминала, и оба конца обязаны
/// собираться из одного описания. `lib/domain/` — единственный каталог, куда
/// разрешено смотреть и `lib/backend/`, и `lib/web/`: он чистый Dart, без
/// `dart:ffi`, `dart:js_interop` и Flutter. Сторож — `test/architecture/
/// layering_test.dart`.
///
/// # Перечисления едут по имени, никогда по индексу
///
/// Дом-образец — `lib/domain/setup/setup_draft_json.dart`. Индекс меняет смысл
/// в тот момент, когда в перечисление вставили новый член, а здесь ездят
/// [PointMode] (вопрос прав доступа) и [DeviceClass] (что за железо).
library;

import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';

/// Пишет [Terminal] в форму провода. Обратная — [terminalFromWireJson].
Map<String, Object?> terminalToWireJson(Terminal terminal) => {
  'id': terminal.id,
  'name': terminal.name,
  'pointMode': terminal.pointMode.name,
  // Задача 15: набор видов оплаты — свойство рабочего места. Списком имён,
  // не маской: то же правило, что у `pointMode` выше. Пустой список —
  // законное значение и означает «все виды»
  // (`Terminal.allowedPaymentTypes`), поэтому едет всегда, а не «только
  // если не пуст»: умолчание на чтении было бы тем же самым значением, но
  // молчание на проводе не отличить от «сторона старше и поля не знает».
  'allowedPaymentTypes': paymentTypeNames(terminal.allowedPaymentTypes),
};

/// Читает [Terminal] из формы провода. Обратная — [terminalToWireJson].
Terminal terminalFromWireJson(Map<String, dynamic> json) {
  final id = json['id'] as int? ?? 0;
  return Terminal(
    id: id,
    name: json['name'] as String? ?? '',
    pointMode: pointModeFromWireName(
      json['pointMode'] as String?,
      terminalId: id,
    ),
    allowedPaymentTypes: paymentTypesFromWire(
      json['allowedPaymentTypes'],
      terminalId: id,
    ),
  );
}

/// Читает набор видов оплаты из того, что пришло на его месте.
///
/// Отсутствие поля — законное «пусто», то есть «все виды»: касса старше
/// задачи 15 его не шлёт, и это ровно то поведение, которое у неё было.
/// Незнакомое **имя** — отказ ([paymentTypesFromNames]), а не выбрасывание:
/// разбор там объясняет, почему выбрасывание превратило бы запрет в
/// разрешение.
Set<PaymentType> paymentTypesFromWire(Object? raw, {required int terminalId}) {
  if (raw is! List) return const {};
  return paymentTypesFromNames(
    raw.map((value) => '$value'),
    terminalId: terminalId,
  );
}

/// Пишет [TerminalEnrollment] в форму провода — ответ `terminals.register`
/// (задача 4 плана «знакомство терминала с кассой»). Обратная —
/// [terminalEnrollmentFromWireJson].
///
/// `secret` едет значением, не отпечатком — это единственный обмен, где ему
/// разрешено это делать: [TerminalRepository.register] отдаёт его вызывающему
/// ровно один раз, и это тот самый раз. Ни один другой ответ на проводе
/// (`terminals.list`, `terminals.self`, …) секрет не несёт — они собираются
/// из [terminalToWireJson], у которого этого поля нет структурно.
Map<String, Object?> terminalEnrollmentToWireJson(
  TerminalEnrollment enrollment,
) => {
  'terminal': terminalToWireJson(enrollment.terminal),
  'secret': enrollment.secret,
};

/// Читает [TerminalEnrollment] из формы провода. Обратная —
/// [terminalEnrollmentToWireJson].
///
/// Отсутствующий/не-объектный терминал здесь не законное значение, в отличие
/// от `terminals.self` ([terminalFromWireJson] через `_decodeTerminalSelf`,
/// `till_ops.dart`): заведение либо состоялось и прислало терминал с
/// секретом, либо ответило отказом (`WireRefusal`), до этой точки разбора не
/// дойдя вовсе — третьего, «завёлся, но неизвестно как», исхода нет.
TerminalEnrollment terminalEnrollmentFromWireJson(Map<String, dynamic> json) {
  final raw = json['terminal'];
  if (raw is! Map<String, dynamic>) {
    throw StateError('касса не прислала заведённый терминал');
  }
  return (
    terminal: terminalFromWireJson(raw),
    secret: json['secret'] as String? ?? '',
  );
}

/// Переводит присланное по проводу имя режима в [PointMode].
///
/// `LocalTerminalRepository` отказывается угадывать режим, когда хранимое
/// число выходит за диапазон `PointMode.values`: режим — это вопрос прав
/// доступа, а не отображения, и молчаливая замена на `cashier` незаметно
/// выдаёт один режим за другой. Эта сторона контракта читает то же поле по
/// имени, а не по индексу, но два биндинга одного контракта не должны
/// расходиться в поведении на плохом входе — значит здесь тоже явный отказ,
/// а не `orElse: () => PointMode.cashier`.
PointMode pointModeFromWireName(String? name, {required int terminalId}) {
  for (final mode in PointMode.values) {
    if (mode.name == name) return mode;
  }
  throw StateError(
    'Терминал #$terminalId прислал pointMode="$name", которого не знает '
    'PointMode.values (${PointMode.values.map((m) => m.name).join(', ')}). '
    'Похоже, вторая сторона провода новее этой. Отказываюсь угадывать '
    'режим — это вопрос прав доступа, а не отображения.',
  );
}

/// Пишет одну привязку устройства в форму провода. Обратная —
/// [deviceBindingFromWireJson].
///
/// Одна функция на три места, которые раньше писали эту форму каждое своё:
/// `TerminalRoutes._bindingToJson` (касса отдаёт список),
/// `HttpDeviceBindingRepository.save` (терминал сохраняет одну) и — по кругу —
/// тест. [DeviceBinding.enabled] едет всегда, а не «только если false»:
/// умолчание на чтении молча включило бы выключенное устройство.
Map<String, Object?> deviceBindingToWireJson(DeviceBinding binding) => {
  'deviceClass': binding.deviceClass.name,
  'profileId': binding.profileId,
  'parameters': binding.parameters,
  'options': binding.options,
  'enabled': binding.enabled,
};

/// Читает одну привязку устройства из формы провода — сторона провода
/// `DeviceBindingRepository` (`lib/domain/terminal/device_binding_repository.dart`).
/// Обратная — [deviceBindingToWireJson].
///
/// Та же симметрия, что у [pointModeFromWireName]: `LocalDeviceBindingRepository`
/// отказывается угадывать нераспознанное хранимое имя `deviceClass`, и эта
/// сторона контракта обязана отказываться на том же самом плохом входе —
/// явным исключением, а не подстановкой ближайшего известного класса.
/// `profileId`/`parameters`/`options`/`enabled` не проверяются здесь против
/// каталога — это работа [DeviceBinding.validateAgainst], которую вызывает
/// код, использующий эту привязку, а не разбор провода.
DeviceBinding deviceBindingFromWireJson(
  Map<String, dynamic> json, {
  required int terminalId,
}) {
  final className = json['deviceClass'] as String?;
  return DeviceBinding(
    deviceClass: deviceClassFromWireName(className, terminalId: terminalId),
    profileId: json['profileId'] as String? ?? '',
    parameters: stringMapFromWire(json['parameters']),
    options: stringMapFromWire(json['options']),
    enabled: json['enabled'] as bool? ?? true,
  );
}

/// Переводит присланное по проводу имя [DeviceClass].
///
/// Та же причина, что у [pointModeFromWireName]: локальный биндинг
/// отказывается угадывать нераспознанное хранимое имя класса устройства, и
/// эта сторона контракта не должна расходиться с ней на том же плохом входе.
DeviceClass deviceClassFromWireName(String? name, {required int terminalId}) {
  for (final value in DeviceClass.values) {
    if (value.name == name) return value;
  }
  throw StateError(
    'Терминал #$terminalId прислал deviceClass="$name", которого не знает '
    'DeviceClass.values (${DeviceClass.values.map((c) => c.name).join(', ')}). '
    'Похоже, вторая сторона провода новее этой. Отказываюсь угадывать '
    'класс устройства.',
  );
}

/// Читает сумку строк (`parameters`, `options`) из чего угодно, что пришло на
/// её месте. Отсутствие — законное «пусто»; не-объект — тоже пусто, потому что
/// сумка не несёт смысла сама по себе, весь смысл в её ключах.
Map<String, String> stringMapFromWire(Object? raw) {
  if (raw is! Map) return const {};
  return raw.map((key, value) => MapEntry('$key', '$value'));
}
