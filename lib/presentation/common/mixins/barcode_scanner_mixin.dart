import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/device/emulated_scanner_source.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';

/// The three ways a barcode scanner reaches this app, from
/// [BarcodeScannerMixin]'s point of view. Used to decide *whether* this
/// mixin attaches its own keyboard handler — `serialPort` and `camera` are
/// deliberately not implemented by this mixin at all (see
/// [BarcodeScannerMixin._attachIfKeyboardWedge]); they exist here only so
/// `_loadScannerSettings` can name the mode it found without pretending it
/// is `keyboardWedge`.
///
/// Moved here (task 5(c), plan 2b, fix round 1) from the now-deleted
/// `lib/hardware/scanner/barcode_scanner_service.dart` — that file's
/// `BarcodeScannerService` class was a second, parallel implementation of
/// the same keyboard-wedge decoding this mixin does, registered in GetIt but
/// never started by any production code path (confirmed: no call site
/// anywhere called `getIt<BarcodeScannerService>()`), while this mixin is
/// the actual live path six real screens attach to
/// (`sale_screen.dart`, `movement_screen.dart`, `movement_dialog.dart`,
/// `supply_form.dart`, `supplier_return_screen.dart`,
/// `supplier_return_dialog.dart`). Deleted rather than merged into: its
/// serial-port scanning code (`SerialPort`/`SerialPortReader`) was never
/// reachable either — `_attachIfKeyboardWedge` below returns early for any
/// mode other than `keyboardWedge`, so a `serialPort`-mode binding has
/// always been a dead end here too, in both implementations, before and
/// after this change. Deleting the unused class does not remove any
/// capability that was ever live; real serial-port barcode scanning remains
/// a separate, pre-existing, still-open gap.
/// `emulated` добавлен вместе с виртуальным профилем эмулятора сканера
/// (`lib/emulators/emulated_device_profile_catalog.dart`) и, в отличие от
/// `serialPort`/`camera`, **этой примесью реализован**: иначе виртуальный
/// профиль был бы профилем, которым нельзя пользоваться, — «гейт раньше
/// способа его пройти», ровно тот дефект, который однажды уже не заметили
/// 3518 зелёных проб.
enum ScannerMode { keyboardWedge, serialPort, camera, emulated }

/// Живой декодер клавиатурного сканера для экрана, который его подмешивает.
///
/// Подмешивается **только в `State`**: решение «принимать ли скан» требует
/// знать, где экран стоит в дереве маршрутов (см. [_acceptsScans]), а без
/// `context` его не принять.
mixin BarcodeScannerMixin<T extends StatefulWidget> on State<T> {
  final _barcodeBuffer = StringBuffer();
  DateTime _lastKeyTime = DateTime.now();

  // Taken from the domain contract rather than declared here (plan 2b, task
  // 3): the settings screen that now *writes* these three rules shows the
  // same numbers as "по умолчанию" when a field is left blank, and two
  // copies of a default is exactly how the number an operator is shown
  // drifts away from the number the decoder uses.
  static const _defaultScannerMaxGapMs = ScannerRules.defaultScannerTimeoutMs;

  static const _defaultMinBarcodeLength = ScannerRules.defaultBarcodeMinLength;

  static const _defaultMaxBarcodeLength = ScannerRules.defaultBarcodeMaxLength;

  int _scannerMaxGapMs = _defaultScannerMaxGapMs;
  int _minBarcodeLength = _defaultMinBarcodeLength;
  int _maxBarcodeLength = _defaultMaxBarcodeLength;

  /// Test-only window into the resolved gap — [_scannerMaxGapMs] is private
  /// state with no other way to prove [_loadScannerSettings] actually wired
  /// `ThisPosEntries.scannerTimeoutMs` through to the live keyboard-wedge
  /// decoder. Not read by any production code.
  @visibleForTesting
  int get debugScannerMaxGapMs => _scannerMaxGapMs;

  void onBarcodeScanned(String barcode);

  /// Fire-and-forget on purpose: the previous, blob-backed version decided
  /// synchronously, but resolving a terminal's device binding is
  /// necessarily async (`TerminalRepository.self()`). Callers
  /// (`initState()` across several screens) call this synchronously and do
  /// not await it — the keyboard handler attaches a tick later than before,
  /// which nothing here depends on.
  void initBarcodeScanner() {
    unawaited(_attachIfKeyboardWedge());
  }

  Future<void> _attachIfKeyboardWedge() async {
    final mode = await _loadScannerSettings();
    if (mode == ScannerMode.emulated) {
      await _attachEmulatedScanner();
      return;
    }
    if (mode != ScannerMode.keyboardWedge) return;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  /// Источник штрихкодов — файл, а не клавиатура.
  ///
  /// Правила длины применяются те же и здесь: их применяет **читатель**, а
  /// не источник, и эмулятор не имеет права их обойти — иначе он проверял бы
  /// самого себя.
  Future<void> _attachEmulatedScanner() async {
    final binding = _emulatedScannerBinding;
    if (binding == null) return;
    // Реализация приходит из `GetIt` и есть ТОЛЬКО в стендовой сборке кассы.
    // Прямой импорт притянул бы `dart:io` в браузерный бандл через экран
    // продажи — сторож `browser_routes_test.dart` это поймал, и был прав:
    // страница не собралась бы вовсе.
    if (!GetIt.I.isRegistered<EmulatedScannerSourceFactory>()) return;
    final scanner = GetIt.I<EmulatedScannerSourceFactory>()(
      file: binding.parameters['emulFile'] ?? '',
      refuse: binding.parameters['emulRefuse'] ?? '',
    );
    final refusal = await scanner.start();
    if (refusal != null) {
      // Отказ значением, а не исключением: источник штрихкодов не имеет
      // права уронить экран продажи (И144).
      await scanner.stop();
      return;
    }
    _emulatedScanner = scanner;
    _emulatedScans = scanner.barcodes.listen((code) {
      // Тот же затвор, что у клавиатуры: скан, пришедший, пока поверх
      // экрана открыт маршрут, в чек под ним не ложится.
      if (!_acceptsScans()) return;
      if (code.length >= _minBarcodeLength &&
          code.length <= _maxBarcodeLength) {
        onBarcodeScanned(code);
      }
    }, onError: (_) {});
  }

  EmulatedScannerSource? _emulatedScanner;
  StreamSubscription<String>? _emulatedScans;
  DeviceBinding? _emulatedScannerBinding;

  void disposeBarcodeScanner() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    // Дверь остановки. Без неё каждый заход на экран продажи оставлял бы
    // за собой таймер и читателя одного и того же файла.
    unawaited(_emulatedScans?.cancel());
    _emulatedScans = null;
    unawaited(_emulatedScanner?.stop());
    _emulatedScanner = null;
  }

  /// Scanner mode from **this terminal's** scanner `DeviceBinding`
  /// (docs/system-architecture.md, section 8, И27), and the barcode length
  /// bounds plus the inter-character timeout from `ThisPosEntries` — all
  /// three are business rules about the value read, not device settings
  /// (И142): `barcodeMinLength`/`barcodeMaxLength` migrated there by schema
  /// v27, `scannerTimeoutMs` by schema v28 (task 5(c), plan 2b). None comes
  /// from the old installation-wide `hardware_settings` blob any more (plan
  /// 2, task 3) — that blob's `scannerTimeout` key is carried forward into
  /// `scannerTimeoutMs` once, by the v28 migration step itself
  /// (`lib/data/database/migrations/device_binding_migration.dart`'s
  /// `migrateLegacyScannerTimeoutMs`), not read from here.
  ///
  /// **Fix round 1 correction:** this mixin used to leave
  /// [_scannerMaxGapMs] at its fixed default forever, on the reasoning that
  /// a separate `BarcodeScannerService` was "the tested, wired reader" for
  /// `scannerTimeoutMs`. That was backwards — this mixin is the only
  /// implementation six real screens actually attach to (see [ScannerMode]'s
  /// doc comment for the full reasoning and why `BarcodeScannerService` is
  /// deleted, not merged into). [_scannerMaxGapMs] is now assigned here,
  /// the same way [_minBarcodeLength]/[_maxBarcodeLength] already were.
  Future<ScannerMode> _loadScannerSettings() async {
    try {
      // Правила чтения штрихкода — через доменный контракт
      // (`ScannerRulesRepository`), а не чтением `ThisPosEntries` из базы.
      // Задача 13: экран продажи — один из шести, кто подмешивает этот
      // декодер, и он переехал в браузерную таблицу маршрутов. Прежний код
      // звал `GetIt.I<AppDatabase>()`, то есть тянул `dart:io` и
      // `package:sqlite3/sqlite3.dart` в веб-сборку — там их нет вовсе.
      // Контракт и его кассовая реализация (`LocalScannerRulesRepository`)
      // существовали до этой задачи; менялся только читатель.
      //
      // Задача 45: правила читаются **всегда**, через `ScannerRulesReader`.
      // Прежняя проверка `isRegistered<ScannerRulesRepository>()` в браузере
      // была ложной — договор там не привязывался, и длины кода с зазором
      // молча откатывались к зашитым на продаже и возврате разом. У браузера
      // теперь свой проводной читатель (`WtScannerRules`), а незаведённую
      // привязку ловит сторож `browser_routes_test.dart`.
      final rules = await GetIt.I<ScannerRulesReader>().read();
      _minBarcodeLength = rules.effectiveBarcodeMinLength;
      _maxBarcodeLength = rules.effectiveBarcodeMaxLength;
      _scannerMaxGapMs = rules.effectiveScannerTimeoutMs;

      return await _scannerMode();
    } catch (_) {
      return ScannerMode.keyboardWedge;
    }
  }

  /// Режим сканера из привязки устройства **этого** рабочего места.
  ///
  /// Тот же отбор, что делал `resolveTerminalDeviceBindings`
  /// (`lib/data/device/terminal_device_binding_resolver.dart`), но над
  /// доменным контрактом: выключенная строка пропускается, строка, не
  /// прошедшая сверку с каталогом, — тоже (одна кривая привязка не имеет
  /// права выключить сканер), и решение принимается только при **ровно
  /// одной** оставшейся привязке класса `scanner`.
  ///
  /// `DeviceBindingRepository` есть в обоих биндингах:
  /// `LocalDeviceBindingRepository` на кассе (`service_locator.dart`) и
  /// `WtDeviceBindingRepository` в браузере (`lib/web/main_web.dart`) —
  /// то есть планшет спрашивает про **свою** привязку у кассы, а не берёт
  /// кассину.
  Future<ScannerMode> _scannerMode() async {
    // Задача 45: проверки `isRegistered` на эти три договора сняты. Все три
    // привязаны в обеих точках входа (`service_locator.dart`,
    // `lib/web/main_web.dart` — последнюю держит сторож
    // `browser_routes_test.dart`), и проверка не отличала «договора нет» от
    // «ошибки сборки». Без привязки `GetIt` бросает, и отказ ловит тот же
    // `catch` в [_loadScannerSettings] — клавиатурный режим, как и прежде,
    // но уже не как «законное» состояние.
    final terminal = await GetIt.I<TerminalRepository>().self();
    final catalog = GetIt.I<DeviceProfileCatalog>();
    final all = await GetIt.I<DeviceBindingRepository>().forTerminal(
      terminal.id,
    );

    final scanners = <DeviceBinding>[];
    for (final binding in all) {
      if (!binding.enabled) continue;
      if (binding.deviceClass != DeviceClass.scanner) continue;
      try {
        binding.validateAgainst(catalog);
      } on ArgumentError {
        continue;
      }
      scanners.add(binding);
    }
    if (scanners.length != 1) return ScannerMode.keyboardWedge;

    _emulatedScannerBinding = scanners.single;
    return switch (catalog.byId(scanners.single.profileId)?.protocol) {
      DeviceProtocol.serialScanner => ScannerMode.serialPort,
      DeviceProtocol.cameraScan => ScannerMode.camera,
      DeviceProtocol.emulated => ScannerMode.emulated,
      _ => ScannerMode.keyboardWedge,
    };
  }

  /// Принимает ли экран скан **сейчас**: поверх него нет ни одного маршрута.
  ///
  /// # Зачем (дефект живой приёмки браузерного терминала, 2026-09-13)
  ///
  /// Обработчик висит на `HardwareKeyboard.instance` — **глобально**: ему
  /// приходит каждое нажатие во всём приложении, где бы ни стоял фокус и что
  /// бы ни лежало поверх экрана. Кассир открыл оплату, набрал в поле «Номер
  /// телефона» `77011234567` и нажал `Enter` — покупатель нашёлся, а сканер
  /// экрана продажи **под** оплатой принял те же цифры за скан: полоса «Товар
  /// не найден», а с кодом существующего товара — строка в чеке посреди
  /// оплаты. Проба — `test/presentation/screens/sale/
  /// sale_scanner_under_dialog_test.dart`.
  ///
  /// # Почему маршрут, а не «фокус в текстовом поле»
  ///
  /// * **Фокус в поле — не причина, а совпадение.** Сам экран продажи держит
  ///   поле поиска, и клавиатурный сканер в браузере печатает прямо в него:
  ///   затвор «фокус в поле» выключил бы сканер на его собственном экране
  ///   (сторож — «после скана поле поиска пусто» в `wt_sale_route_test.dart`).
  ///   И наоборот: диалог без поля (подтверждение, отложенные чеки) фокуса в
  ///   поле не держит, а скан под ним в чек лечь всё равно не должен.
  /// * **Маршрут — ровно то, что сломалось:** ввод принадлежит тому, что
  ///   сверху. `ModalRoute.isCurrent` — публичный признак «сверху» у самого
  ///   Flutter, одинаковый для страницы (`/payment`) и `showDialog`.
  ///
  /// # Почему по цепочке навигаторов, а не один `isCurrent`
  ///
  /// На кассе продажа живёт во **вложенном** навигаторе `ShellRoute`
  /// (`app_router.dart`), а оплата и диалоги (`showDialog` по умолчанию
  /// `useRootNavigator: true`) открываются в **корневом**. Маршрут продажи во
  /// вложенном навигаторе при этом остаётся `isCurrent` — перекрыт маршрут
  /// оболочки уровнем выше. Поэтому проверяется каждый уровень, до корня; в
  /// браузере (`setup_router.dart`) цепочка из одного звена.
  ///
  /// Экран вне маршрута вовсе (`ModalRoute.of == null`) принимает скан: там
  /// перекрывать нечему, и так было всегда.
  bool _acceptsScans() {
    if (!mounted) return false;
    BuildContext at = context;
    while (true) {
      final route = ModalRoute.of(at);
      if (route == null) return true;
      if (!route.isCurrent) return false;
      final navigator = route.navigator;
      // Маршрут уже снят с навигатора — экрану доживать кадр, не сканировать.
      if (navigator == null) return false;
      at = navigator.context;
    }
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Нажатие не наше — и не наш буфер: цифры, набранные в поле диалога, не
    // имеют права приклеиться спереди к первому скану после его закрытия.
    // `false` — клавиша идёт дальше, к полю, в котором её и набирали.
    if (!_acceptsScans()) {
      _barcodeBuffer.clear();
      return false;
    }

    final now = DateTime.now();
    final gap = now.difference(_lastKeyTime).inMilliseconds;
    _lastKeyTime = now;

    if (gap > _scannerMaxGapMs && _barcodeBuffer.isNotEmpty) {
      _barcodeBuffer.clear();
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final barcode = _barcodeBuffer.toString();
      _barcodeBuffer.clear();

      if (barcode.length >= _minBarcodeLength &&
          barcode.length <= _maxBarcodeLength) {
        onBarcodeScanned(barcode);
        return true;
      }
      return false;
    }

    final char = event.character;
    if (char != null && RegExp(r'\d').hasMatch(char)) {
      _barcodeBuffer.write(char);
    }

    return false;
  }
}
