import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/settings/customer_screen_settings.dart';
import 'package:telepos/domain/device/device_check.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_discovery.dart';
import 'package:telepos/domain/device/device_profile.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/device_profile_label.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/session_lost_handler.dart';
import 'package:telepos/app/theme/app_typography.dart';

/// Settings for the device classes that don't have their own screen —
/// scanner, scale, physical customer-facing pole display, cash drawer,
/// payment terminal — plus the unrelated "graphic customer screen on a
/// second monitor" feature. Every device section here is driven entirely by
/// [DeviceProfile] declarations from [DeviceProfileCatalog] (И31): the set
/// of fields rendered for a class comes from whichever profile the operator
/// picks, not from a hardcoded list per model.
///
/// **`barcodeMinLength`, `barcodeMaxLength`, `scannerTimeoutMs` are editable
/// here again (plan 2b, task 3).** They are business rules about the value
/// read, not device settings (И142), so they are not on a `DeviceBinding`;
/// they live on `ThisPosEntries` (schema v27 for the lengths, v28 for the
/// timeout), which is `package:telepos/data/...` and out of reach from a
/// layering-clean presentation file. Until this task there was no
/// domain-level contract to write them through, so an operator could not set
/// them at all — a setting that is readable and migrated but not editable
/// fails section 20's UI-first rule. `ScannerRulesRepository`
/// (`lib/domain/repositories/scanner_rules_repository.dart`) is that
/// contract, and [_ScannerRulesSection] below is its operator control.
///
/// **What used to live here and does not any more:**
/// - Live, no-restart-needed reconfiguration of the running scanner/scale/
///   drawer/display services. The old code unregistered and re-registered
///   GetIt singletons straight from this screen, which required importing
///   `lib/hardware/...` directly — exactly what И5 forbids from
///   presentation. A saved binding here takes effect the next time the app
///   starts (`hardware_module.dart` resolves bindings once, at DI
///   registration) — never mid-session. Consistent with И30: a
///   misconfigured device must never block a sale, and it doesn't; it also
///   simply doesn't hot-apply any more.
class HardwareSettingsScreen extends ConsumerStatefulWidget {
  const HardwareSettingsScreen({super.key});

  @override
  ConsumerState<HardwareSettingsScreen> createState() =>
      _HardwareSettingsScreenState();
}

class _HardwareSettingsScreenState
    extends ConsumerState<HardwareSettingsScreen> {
  bool _isLoading = true;
  int? _terminalId;

  // Nullable, not `late`: a missing GetIt registration must degrade this
  // screen to an "unavailable" state, never crash it out of `build()` — see
  // printer_settings_screen.dart's identical fields for the full reasoning.
  DeviceProfileCatalog? _catalog;
  DeviceBindingRepository? _bindingRepo;

  /// Писатель правил И142.
  ///
  /// **Развилки «есть привязка / нет привязки» здесь больше нет — пункт 11
  /// ревизии 2026-09-19.** Она была настоящей ровно до того дня: браузерная
  /// точка входа не привязывала `ScannerRulesRepository` вовсе, и секция
  /// говорила словами, что правил здесь не задать. Теперь `main_web.dart`
  /// привязывает `WtScannerRules` и под пишущим договором тоже (операция
  /// `scanner.saveRules`, право `settings.hardware`), а на кассе стоит
  /// `LocalScannerRulesRepository`. Обеих сборок, где этот экран вообще
  /// открывается, — две, и в обеих писатель есть: незаведённая привязка
  /// стала ошибкой сборки, а не режимом работы (правило сторожа
  /// `presentation_is_registered_test.dart`).
  ///
  /// Поле остаётся, но заполняется **прямым** резолвом в [_load] и падает
  /// там, где падение видно, а не прячет отсутствие за пустой секцией.
  late final ScannerRulesRepository _scannerRulesRepo;

  final _scannerRulesDraft = _ScannerRulesDraft();

  final _scannerDraft = DeviceBindingDraft(deviceClass: DeviceClass.scanner);
  final _scaleDraft = DeviceBindingDraft(deviceClass: DeviceClass.scale);
  final _displayDraft = DeviceBindingDraft(
    deviceClass: DeviceClass.customerDisplay,
  );
  final _drawerDraft = DeviceBindingDraft(deviceClass: DeviceClass.cashDrawer);
  final _paymentDraft = DeviceBindingDraft(
    deviceClass: DeviceClass.paymentTerminal,
  );

  // The graphic customer screen on a second monitor is NOT a DeviceClass —
  // it is a window this same process opens on another display, not a
  // peripheral with its own profile. It keeps its own SharedPreferences key,
  // deliberately not `hardware_settings`. The key and the read side of this
  // now live in `CustomerScreenChoice`/`kCustomerScreenPrefsKey`
  // (`lib/core/settings/customer_screen_settings.dart`), which
  // `lib/main.dart`'s `_maybeOpenCustomerScreen` reads from too — one parsing
  // path, not two hand-rolled ones either side of the same preference.
  bool _customerScreenEnabled = false;
  int _customerScreenMonitor = 1;
  List<String> _monitors = const [];

  /// Виды оплаты, разрешённые **этому** рабочему месту — задача 15 плана
  /// «продажа с браузерного терминала», решение заказчика №5: «планшет у
  /// кассы берёт всё, в зале — только безнал».
  ///
  /// Пустой набор означает «все виды» (`Terminal.allowedPaymentTypes`), и
  /// на этом экране он выглядит как выключенный переключатель секции: пока
  /// оператор не ограничил рабочее место, ограничений нет.
  ///
  /// **Этот экран запретом не является.** Он записывает настройку; отказ
  /// даёт касса (`LocalPaymentService`, I44/I162), и подделанная вкладка
  /// обойти его не может. Секция здесь потому, что это настройка того же
  /// рабочего места, что и его устройства выше, — и правит их один и тот же
  /// человек тем же правом `settings.hardware`.
  Set<PaymentType> _allowedPaymentTypes = const {};
  bool _paymentTypesLimited = false;

  /// Оператор трогал эту секцию в этот заход?
  ///
  /// **Без этого признака секция пишет при каждом сохранении экрана** — а
  /// экран общий: привязка принтера сохраняется той же кнопкой и уносила бы
  /// виды оплаты заодно. Круг правки 3 намерил на этом худший из исходов:
  /// набор `{debt}` (из одних не-тендеров) срезался в пустой, пустой значит
  /// «все виды», и **сохранение молча снимало ограничение** — оператор видел
  /// просто выключенный переключатель, и ничто не говорило ему, что запрет
  /// отброшен.
  ///
  /// Правило теперь простое: настройка уезжает на кассу тогда, и только
  /// тогда, когда её изменил человек.
  bool _paymentTypesTouched = false;

  /// Виды, записанные рабочему месту, которых **эта версия не знает как
  /// тендеры** (`mixed`, `debt` — см. `tenderPaymentTypes`).
  ///
  /// Срезаются из [_allowedPaymentTypes] при чтении, но не молча: секция
  /// называет их вслух. Молчание здесь было бы второй бедой того же рода —
  /// оператор видел бы «ограничений нет» там, где ограничение записано, и не
  /// знал бы, что чинить.
  Set<PaymentType> _paymentTypesUnknown = const {};

  /// `null` — эта сборка сохранить набор не может (репозиторий не
  /// зарегистрирован или мастер настройки не пройден). Секция говорит об
  /// этом прямо, а не показывает галочки, которые молча не сохранятся, —
  /// тем же приёмом, что [_scannerRulesRepo] выше.
  TerminalRepository? _terminalRepo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadMonitors();
  }

  @override
  void dispose() {
    _scannerRulesDraft.dispose();
    super.dispose();
  }

  Future<void> _loadMonitors() async {
    // Размеры собираются до обращения к словарю: `AppLocalizations.of` —
    // поиск по дереву, а `_loadMonitors` заводится из `initState`. Собрать
    // числа, дождаться ответа системы, и только потом — подписи.
    final sizes = <String>[];
    try {
      final displays = await screenRetriever.getAllDisplays();
      for (final d in displays) {
        sizes.add('${d.size.width.round()}×${d.size.height.round()}');
      }
    } catch (_) {}
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final labels = <String>[
      for (var i = 0; i < sizes.length; i++)
        l10n.hwMonitorWithSize(i + 1, sizes[i]),
    ];
    if (labels.isEmpty) {
      labels.addAll([l10n.hwMonitorNumbered(1), l10n.hwMonitorNumbered(2)]);
    }
    setState(() => _monitors = labels);
  }

  Future<void> _loadSettings() async {
    try {
      _catalog = GetIt.I<DeviceProfileCatalog>();
      final bindingRepo = GetIt.I<DeviceBindingRepository>();
      _bindingRepo = bindingRepo;
      final terminalRepo = GetIt.I<TerminalRepository>();
      _terminalRepo = terminalRepo;
      final terminal = await terminalRepo.self();
      _terminalId = terminal.id;
      // **Не-тендеры срезаются при чтении** (круг правки 2). Записать их
      // касса больше не даёт, но строка, написанная раньше запрета (или
      // рукой в базе), иначе делала бы экран бесполезным ровно там, где он
      // нужен: галочек для `mixed`/`debt` нет, а множество уезжало бы на
      // сохранение дословно — касса отвергала бы его каждый раз, и снять
      // причину с экрана было бы нельзя. Срезание превращает «вечный отказ»
      // в «набор, который оператор видит и может починить».
      _allowedPaymentTypes = terminal.allowedPaymentTypes.intersection(
        tenderPaymentTypes,
      );
      _paymentTypesUnknown = terminal.allowedPaymentTypes.difference(
        tenderPaymentTypes,
      );
      _paymentTypesLimited = _allowedPaymentTypes.isNotEmpty;
      final bindings = await bindingRepo.forTerminal(terminal.id);

      DeviceBinding? bindingFor(DeviceClass deviceClass) {
        for (final b in bindings) {
          if (b.deviceClass == deviceClass) return b;
        }
        return null;
      }

      _scannerDraft.applyBinding(bindingFor(DeviceClass.scanner));
      _scaleDraft.applyBinding(bindingFor(DeviceClass.scale));
      _displayDraft.applyBinding(bindingFor(DeviceClass.customerDisplay));
      _drawerDraft.applyBinding(bindingFor(DeviceClass.cashDrawer));
      _paymentDraft.applyBinding(bindingFor(DeviceClass.paymentTerminal));
    } on InstallationNotConfiguredException {
      // Setup wizard hasn't run yet — no terminal to load bindings for.
      // Drafts stay at their "disabled, nothing chosen" defaults. И30: a
      // settings screen with nothing configured yet must still open.
    } on SessionLost catch (error) {
      // Задача 1 фазы 2: до этой правки голый `catch (_)` ниже глотал
      // `SessionLost` и открывал экран с умолчаниями, будто ничего не
      // случилось — кассир видел пустые настройки вместо ухода на вход.
      // Дальше загружать (правила сканера, экран покупателя) нечем: тот же
      // истёкший сеанс отказал бы им тоже — выходим сразу.
      handleSessionLost(context, error);
      return;
    } catch (_) {
      // Best-effort load; the screen still opens with defaults either way.
    }

    _scannerRulesRepo = GetIt.I<ScannerRulesRepository>();
    try {
      _scannerRulesDraft.applyRules(await _scannerRulesRepo.read());
    } catch (_) {
      // Nothing set up yet — the fields stay empty, meaning "default".
    }

    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final choice = CustomerScreenChoice.read(prefs);
      _customerScreenEnabled = choice.enabled;
      _customerScreenMonitor = choice.monitor;
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final terminalId = _terminalId;
    final bindingRepo = _bindingRepo;
    final errors = <String>[];

    if (terminalId == null || bindingRepo == null) {
      errors.add(l10n.hwSetupIncompleteDevices);
    } else {
      for (final draft in [
        _scannerDraft,
        _scaleDraft,
        _displayDraft,
        _drawerDraft,
        _paymentDraft,
      ]) {
        final binding = draft.toBinding();
        if (binding == null) continue; // nothing chosen — nothing to save.
        try {
          await bindingRepo.save(terminalId, binding);
        } on SessionLost catch (error) {
          // Задача 1 фазы 2: до этой правки `SessionLost` не ловился здесь
          // вовсе — улетал выше сквозь `_saveSettings`, а тот брошен в
          // `onPressed` (`:309`) как непойманный `Future`, не дожидаемый
          // никем: исключение уходило в `runZonedGuarded`
          // (`lib/web/main_web.dart`), и кассир, нажавший «Сохранить»,
          // не получал ничего — ни зелёного снекбара, ни красного, ни
          // экрана входа.
          handleSessionLost(context, error);
          return;
        } on ArgumentError catch (e) {
          errors.add('${_classLabel(draft.deviceClass)}: ${_describe(e)}');
        }
      }
    }

    // Виды оплаты рабочего места (задача 15) сохраняются той же кнопкой, по
    // тому же доводу, что и правила сканера ниже: оператор, нажавший
    // «Сохранить», имеет в виду весь экран. Ошибка одной части попадает в
    // общий список, а не отменяет уже сохранённое.
    final terminalRepo = _terminalRepo;
    // Секцию не трогали — она молчит. Полный разбор у
    // [_paymentTypesTouched]: экран общий, и сохранение принтера не имеет
    // права переписать виды оплаты, тем более снять запрет.
    if (terminalId != null && terminalRepo != null && _paymentTypesTouched) {
      try {
        await terminalRepo.setAllowedPaymentTypes(
          terminalId,
          // Снятый переключатель означает «все виды» — пустой набор, а не
          // текущие галочки: иначе оператор, снявший ограничение, оставил
          // бы рабочее место с прежним запретом (докстринг
          // `Terminal.allowedPaymentTypes`).
          _paymentTypesLimited ? _allowedPaymentTypes : const {},
        );
        // **Запись починена — предупреждению больше нечего сообщать**
        // (круг правки 4). Прежде [_paymentTypesUnknown] считался один раз
        // при загрузке и после успешного сохранения не пересчитывался:
        // оператор делал ровно то, что велел красный текст, набор уезжал на
        // кассу верным — а экран продолжал утверждать, что запись сломана и
        // «остаётся как есть». Тот же род вреда, ради которого секция и
        // заговорила, только в другую сторону: круг 3 закрыл «оператор не
        // знает, что чинить» и открыл «оператор не знает, что починил».
        if (mounted) setState(() => _paymentTypesUnknown = const {});
      } on SessionLost catch (error) {
        handleSessionLost(context, error);
        return;
      } on WireRefusal catch (e) {
        errors.add(l10n.hwPaymentKindsError(e.message));
      }
    }

    // The three И142 rules save on the same button as the bindings — they are
    // edited on the same screen and an operator pressing "сохранить" means
    // all of it. A parse or validation failure is collected into the same
    // error list rather than aborting the bindings that already saved.
    try {
      await _scannerRulesRepo.save(_scannerRulesDraft.toRules(l10n));
    } on SessionLost catch (error) {
      // Пункт 11 ревизии 2026-09-19: с планшета запись уходит по проводу, и
      // истёкший сеанс здесь — такой же обычный исход, как у привязок выше.
      // До этой правки его не ловил никто: на кассе запись в базу `SessionLost`
      // бросить не могла вовсе.
      handleSessionLost(context, error);
      return;
    } on WireRefusal catch (e) {
      // Отказ кассы — текстом в общий список, а не тишиной: «сохранено» без
      // записи и есть то молчание, ради снятия которого заведена операция.
      errors.add('${l10n.scannerRulesTitle}: ${e.message}');
    } on ArgumentError catch (e) {
      errors.add('${l10n.scannerRulesTitle}: ${_describe(e)}');
    } on FormatException catch (e) {
      errors.add('${l10n.scannerRulesTitle}: ${e.message}');
    } on StateError catch (e) {
      errors.add('${l10n.scannerRulesTitle}: ${e.message}');
    }

    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(
        kCustomerScreenPrefsKey,
        jsonEncode({
          'enabled': _customerScreenEnabled,
          'monitor': _customerScreenMonitor,
        }),
      );
    } catch (_) {}

    if (!mounted) return;
    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.hwSettingsSaved),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('; ')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// `ArgumentError.message` alone (as thrown by
  /// `DeviceBinding.validateAgainst`) never names the offending parameter or
  /// option key — that lives in `.invalidValue`. This combines both so the
  /// operator actually sees which one, rather than a message that only
  /// blames "some" parameter.
  String _describe(ArgumentError e) {
    final value = e.invalidValue;
    if (value == null) return '${e.message}';
    return '${e.message}: $value';
  }

  String _classLabel(DeviceClass deviceClass) {
    final l10n = AppLocalizations.of(context)!;
    return switch (deviceClass) {
      DeviceClass.scanner => l10n.setupSectionScanner,
      DeviceClass.scale => l10n.hwScaleTitle,
      DeviceClass.customerDisplay => l10n.hwDisplayTitle,
      DeviceClass.cashDrawer => l10n.hwDrawerTitle,
      DeviceClass.paymentTerminal => l10n.setupSectionTerminal,
      DeviceClass.receiptPrinter => l10n.hwReceiptPrinterTitle,
      DeviceClass.labelPrinter => l10n.labelPrinterSettingsTitle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = Breakpoints.fromWidth(width) == LayoutType.desktop;
    final catalog = _catalog;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hwSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(TeleposIcons.save, color: Colors.white),
            label: Text(
              l10n.globalSave,
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : catalog == null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  l10n.hwProfileCatalogUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _RestartNotice(),
                      const SizedBox(height: 16),
                      DeviceBindingEditor(
                        title: l10n.hwScannerTitle,
                        icon: Icons.qr_code_scanner,
                        profiles: catalog.forClass(DeviceClass.scanner),
                        draft: _scannerDraft,
                        terminalId: _terminalId,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      _ScannerRulesSection(draft: _scannerRulesDraft),
                      const SizedBox(height: 20),
                      DeviceBindingEditor(
                        title: l10n.hwScaleTitle,
                        icon: Icons.scale,
                        profiles: catalog.forClass(DeviceClass.scale),
                        draft: _scaleDraft,
                        terminalId: _terminalId,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      _buildCustomerScreenSection(l10n),
                      const SizedBox(height: 20),
                      DeviceBindingEditor(
                        title: l10n.hwDisplayTitle,
                        icon: Icons.tv,
                        profiles: catalog.forClass(DeviceClass.customerDisplay),
                        draft: _displayDraft,
                        terminalId: _terminalId,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      // The drawer's old "открыть ящик" button called
                      // `ReceiptPrintService.openCashDrawer()`, which answers
                      // `bool` — "не удалось открыть ящик" and nothing more.
                      // It is gone: `DeviceCheck` opens the same drawer and
                      // can say *why* it did not (no binding at all, a
                      // binding whose profile was since edited, a platform
                      // with no drawer support, a driver this process never
                      // built). One button, six distinguishable answers
                      // instead of two.
                      DeviceBindingEditor(
                        title: l10n.hwDrawerTitle,
                        icon: Icons.point_of_sale,
                        profiles: catalog.forClass(DeviceClass.cashDrawer),
                        draft: _drawerDraft,
                        terminalId: _terminalId,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      DeviceBindingEditor(
                        title: l10n.hwTerminalsTitle,
                        icon: Icons.payment,
                        profiles: catalog.forClass(DeviceClass.paymentTerminal),
                        draft: _paymentDraft,
                        terminalId: _terminalId,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      _buildPaymentTypesSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Виды оплаты рабочего места — задача 15, решение заказчика №5.
  ///
  /// Переключатель секции отличает «ограничений нет» (пустой набор) от
  /// выбранного списка. Без него «снять все галочки» и «разрешить всё»
  /// выглядели бы одинаково, а означали бы одно и то же — и оператор,
  /// снявший последнюю галочку, думал бы, что запретил всё, тогда как
  /// пустой набор означает «все виды».
  ///
  /// Подпись под галочками говорит вслух то, ради чего задача и делалась:
  /// запрет держит касса, а не этот экран.
  Widget _buildPaymentTypesSection() {
    final l10n = AppLocalizations.of(context)!;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return _SettingsSectionCard(
      title: l10n.hardwarePaymentKinds,
      // `Icons.payment` — тот же материальный набор, которым в этом файле
      // уже помечена секция платёжного терминала: своего глифа для оплаты
      // в `TeleposIcons` нет (волны 1–2 рисовались под другие места), а
      // придумывать его ради одной секции — работа со своей спекой.
      icon: Icons.payment,
      trailing: Switch(
        key: const Key('payment_types_limit_switch'),
        value: _paymentTypesLimited,
        onChanged: _terminalRepo == null
            ? null
            : (value) => setState(() {
                _paymentTypesTouched = true;
                _paymentTypesLimited = value;
                // Включили ограничение на пустом наборе — предлагать
                // «ничего не разрешено» нельзя: такого состояния не
                // существует (пустое значит «все»). Умолчание — безнал,
                // ровно тот случай, ради которого решение принималось:
                // «планшет в зале — только безнал».
                if (value && _allowedPaymentTypes.isEmpty) {
                  _allowedPaymentTypes = const {PaymentType.card};
                }
              }),
      ),
      children: [
        if (_paymentTypesUnknown.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.hwPaymentKindsUnknown(
                _paymentTypesUnknown
                    .map((t) => _paymentTypeLabel(t).toLowerCase())
                    .join(', '),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        if (_terminalRepo == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.hwPaymentKindsUnsupported,
              style: TextStyle(color: muted, fontSize: 13),
            ),
          )
        else if (!_paymentTypesLimited)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.hardwarePaymentKindsUnrestricted,
              style: TextStyle(color: muted, fontSize: 13),
            ),
          )
        else ...[
          // **Тендеры, а не все виды** (правка круга 1): смешанная — форма
          // оплаты, а не тендер, и галочка для неё была ловушкой. Снять её
          // на наборе `{mixed}` значило собрать немое рабочее место, а
          // оставить её снятой на `{cash, card}` — запретить смешанную,
          // обе половины которой разрешены. Разбор — `tenderPaymentTypes`.
          for (final type in tenderPaymentTypes)
            CheckboxListTile(
              key: Key('payment_type_${type.name}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _allowedPaymentTypes.contains(type),
              title: Text(_paymentTypeLabel(type)),
              onChanged: (checked) => setState(() {
                _paymentTypesTouched = true;
                final next = {..._allowedPaymentTypes};
                if (checked ?? false) {
                  next.add(type);
                } else {
                  next.remove(type);
                }
                // Последнюю галочку снять нельзя: пустой набор означает
                // «все виды», и снятие последней галочки означало бы ровно
                // обратное тому, что оператор делает. Хочет снять
                // ограничение — выключает переключатель секции.
                if (next.isEmpty) return;
                _allowedPaymentTypes = next;
              }),
            ),
          const SizedBox(height: 4),
          Text(
            l10n.hwPaymentKindsEnforcedByTill,
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  String _paymentTypeLabel(PaymentType type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      PaymentType.cash => l10n.paymentCash,
      PaymentType.card => l10n.paymentCard,
      PaymentType.mixed => l10n.paymentMixed,
      PaymentType.debt => l10n.paymentDebt,
      PaymentType.installment => l10n.paymentInstallment,
    };
  }

  Widget _buildCustomerScreenSection(AppLocalizations l10n) {
    return _SettingsSectionCard(
      title: l10n.hardwareCustomerDisplayGraphic,
      icon: Icons.desktop_windows,
      trailing: Switch(
        value: _customerScreenEnabled,
        onChanged: (v) => setState(() => _customerScreenEnabled = v),
      ),
      children: [
        if (_customerScreenEnabled) ...[
          Text(
            l10n.hwCustomerDisplayGraphicDesc,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.hwCustomerDisplayMonitor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            value: _customerScreenMonitor.clamp(
              1,
              _monitors.isEmpty ? 1 : _monitors.length,
            ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              for (var i = 0; i < _monitors.length; i++)
                DropdownMenuItem(value: i + 1, child: Text(_monitors[i])),
            ],
            onChanged: (v) => setState(() => _customerScreenMonitor = v ?? 1),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.hwCustomerDisplayMonitorHint,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ] else
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.hardwareCustomerDisplayGraphicOff,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

/// A small banner reminding the operator that a saved binding takes effect
/// on the next app launch, not immediately — see this file's top doc
/// comment for why hot-reconfiguration was dropped.
class _RestartNotice extends StatelessWidget {
  const _RestartNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(TeleposIcons.info, size: 18, color: AppColors.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.hardwareRestartRequired,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mutable scratch state for one device class's binding while the operator
/// edits it. Nothing here is persisted until the screen's Save button calls
/// [DeviceBindingRepository.save] — see docs/system-architecture.md, И141/И142.
class DeviceBindingDraft {
  DeviceBindingDraft({required this.deviceClass});

  final DeviceClass deviceClass;
  bool enabled = false;
  String? profileId;
  Map<String, String> parameters = <String, String>{};
  Map<String, String> options = <String, String>{};

  /// Resets this draft from what is actually saved for [binding]'s class, or
  /// to "disabled, nothing chosen" when [binding] is `null`.
  void applyBinding(DeviceBinding? binding) {
    enabled = binding?.enabled ?? false;
    profileId = binding?.profileId;
    parameters = Map.of(binding?.parameters ?? const <String, String>{});
    options = Map.of(binding?.options ?? const <String, String>{});
  }

  /// `null` when nothing is selected — nothing to save for this class.
  DeviceBinding? toBinding() {
    final id = profileId;
    if (id == null) return null;
    return DeviceBinding(
      deviceClass: deviceClass,
      profileId: id,
      parameters: Map.of(parameters),
      options: Map.of(options),
      enabled: enabled,
    );
  }
}

/// Profile picker + dynamic parameter/option form for one [DeviceClass],
/// driven entirely by what the chosen [DeviceProfile] declares
/// (`connectionParams`, `options`) — no per-model field list is hardcoded
/// here. И31. Shared by `printer_settings_screen.dart` and
/// `label_printer_settings_screen.dart`.
///
/// **This is where the two contracts of plan 2b finally get a reader.**
/// [DeviceDiscovery] is called by the «искать» button beside every
/// connection-parameter field ([_search]); [DeviceCheck] by the «проверить
/// устройство» button ([_runCheck]). Both are resolved from get_it by their
/// *domain interface*, so this one widget works unchanged over the local
/// implementations on a till and over the HTTP ones in a browser
/// (`lib/web/main_web.dart` registers `HttpDeviceDiscovery`/`HttpDeviceCheck`
/// under the same keys). Nothing here imports `lib/hardware/` or
/// `lib/data/` — see `test/architecture/layering_test.dart`, which now pins
/// these three screens by name.
///
/// **A candidate is not a binding.** Choosing one fills a text field and
/// nothing else: the profile stays whatever the operator picked, the
/// binding is still only written by the screen's Save button. Discovery
/// says "something answers at this address", never "this is a Zebra".
class DeviceBindingEditor extends StatefulWidget {
  const DeviceBindingEditor({
    super.key,
    required this.title,
    required this.icon,
    required this.profiles,
    required this.draft,
    required this.onChanged,
    this.terminalId,
  });

  final String title;
  final IconData icon;
  final List<DeviceProfile> profiles;
  final DeviceBindingDraft draft;
  final VoidCallback onChanged;

  /// `null` until the setup wizard has produced a terminal — [DeviceCheck]
  /// is per-terminal, so the check button says "нечего проверять" rather
  /// than guessing an id.
  final int? terminalId;

  @override
  State<DeviceBindingEditor> createState() => _DeviceBindingEditorState();
}

class _DeviceBindingEditorState extends State<DeviceBindingEditor> {
  final Map<String, TextEditingController> _paramControllers = {};

  DeviceCheckOutcome? _lastOutcome;

  /// Set instead of a `bool` while a check has been requested but the
  /// contract has not answered — [_lastOutcome] alone cannot express "no
  /// result yet, and none is coming" versus "no result yet, one is on its
  /// way".
  bool _checking = false;

  /// Which connection parameter's search is currently running, or `null`.
  ///
  /// A key rather than a `bool` because the spinner has to appear on the one
  /// button that was pressed — a `bool` would either spin every button of the
  /// section at once or spin none of them.
  ///
  /// It does **not** mean searches run per field. While one is running every
  /// search button in the section is disabled (see [_buildParamFields]), and
  /// that is deliberate: [DeviceDiscovery] answers per device *class*, so a
  /// second search started from a neighbouring field would re-run the very
  /// same scan of the very same buses and return the very same candidates,
  /// after the same up-to-eight seconds. Both would then write into
  /// [_searchingParamKey], and whichever finished last would clear the
  /// spinner for both. (Finding M1: this comment used to claim the opposite
  /// of what the code does.)
  String? _searchingParamKey;

  DeviceProfile? get _selectedProfile {
    final id = widget.draft.profileId;
    if (id == null) return null;
    for (final p in widget.profiles) {
      if (p.id == id) return p;
    }
    return null; // Stale/unknown id — treated as "nothing valid selected".
  }

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant DeviceBindingEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    final profile = _selectedProfile;
    final keys =
        profile?.connectionParams.map((p) => p.key).toSet() ?? <String>{};
    _paramControllers.removeWhere((key, controller) {
      if (keys.contains(key)) return false;
      controller.dispose();
      return true;
    });
    for (final key in keys) {
      _paramControllers.putIfAbsent(
        key,
        () => TextEditingController(text: widget.draft.parameters[key] ?? ''),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectProfile(String id) {
    setState(() {
      widget.draft.profileId = id;
      widget.draft.parameters = <String, String>{};
      widget.draft.options = <String, String>{};
      _syncControllers();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _selectedProfile;
    return _SettingsSectionCard(
      title: widget.title,
      icon: widget.icon,
      trailing: Switch(
        value: widget.draft.enabled,
        onChanged: (v) {
          setState(() => widget.draft.enabled = v);
          widget.onChanged();
        },
      ),
      children: widget.draft.enabled
          ? [
              _buildProfilePicker(profile),
              if (profile != null) ...[
                const SizedBox(height: 12),
                ..._buildParamFields(profile),
                if (profile.options.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ..._buildOptionFields(profile),
                ],
                const SizedBox(height: 8),
                _buildCheckSection(),
              ],
            ]
          : [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  AppLocalizations.of(context)!.hardwareDeviceDisabled,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
    );
  }

  Widget _buildProfilePicker(DeviceProfile? profile) {
    if (widget.profiles.isEmpty) {
      return Text(
        AppLocalizations.of(context)!.hwNoProfilesForClass,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 13,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.profiles.map((p) {
        final selected = p.id == profile?.id;
        return ChoiceChip(
          label: Text(
            deviceProfileTitle(p, AppLocalizations.of(context)!),
            style: const TextStyle(fontSize: 13),
          ),
          selected: selected,
          onSelected: (_) => _selectProfile(p.id),
        );
      }).toList(),
    );
  }

  List<Widget> _buildParamFields(DeviceProfile profile) {
    if (profile.connectionParams.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            AppLocalizations.of(context)!.hwNoConnectionParams,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ];
    }
    final l10n = AppLocalizations.of(context)!;
    return profile.connectionParams.map((param) {
      final controller = _paramControllers[param.key]!;
      final searching = _searchingParamKey == param.key;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: Key('param_${profile.id}_${param.key}'),
                controller: controller,
                style: const TextStyle(
                  fontFamily: AppTypography.familyMono,
                  fontFamilyFallback: ['TeleposMono', 'monospace'],
                ),
                decoration: InputDecoration(
                  labelText: param.isRequired
                      ? '${deviceParamDescription(profile, param, l10n)} *'
                      : l10n.hwParamOptional(
                          deviceParamDescription(profile, param, l10n),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  widget.draft.parameters[param.key] = v;
                  widget.onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            // Discovery is per device *class*, not per field — one search
            // answers for every parameter of that class — but the button
            // sits beside a specific field because that is the thing it
            // fills. The candidate list is filtered to those that actually
            // carry a value for this key; see [_search].
            //
            // Which is also why a running search disables *every* search
            // button here and not merely this one: a second one would repeat
            // the identical scan. See [_searchingParamKey].
            OutlinedButton(
              key: Key('search_${profile.id}_${param.key}'),
              onPressed: _searchingParamKey != null
                  ? null
                  : () => _search(profile, param),
              child: searching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.deviceSearchButton),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Runs [DeviceDiscovery] for this section's device class, shows what came
  /// back, and — only if the operator picks one — copies that candidate's
  /// value for [param] into the field.
  ///
  /// **Why the failed sources are carried all the way here.** An empty
  /// candidate list means one of two very different things, and
  /// [DeviceDiscoveryResult.failedSources] is the only thing that tells them
  /// apart: "every source was searched and nothing is attached" versus "the
  /// network could not be swept / the appliance socket did not answer, so we
  /// do not know". Rendering both as an empty list would rebuild exactly the
  /// defect that field was added to fix, so the two produce different text —
  /// see [_DiscoveryResultsDialog].
  Future<void> _search(
    DeviceProfile profile,
    DeviceConnectionParam param,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    if (!GetIt.I.isRegistered<DeviceDiscovery>()) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.deviceSearchUnavailable)),
      );
      return;
    }

    setState(() => _searchingParamKey = param.key);
    DeviceDiscoveryResult result;
    try {
      result = await GetIt.I<DeviceDiscovery>().find(widget.draft.deviceClass);
    } on SessionLost catch (error) {
      // Пункт 4 второго круга разбора (2026-08-21). Before this fix, this
      // bare `catch (e)` below caught `SessionLost` too and showed it in the
      // same "these sources could not be searched" dialog as an unreachable
      // till — the operator's session had already ended, and the fix is to
      // log back in, not to retry the search. `WtDeviceDiscovery.find` now
      // lets `SessionLost` escape instead of folding it into
      // `DeviceDiscoveryResult.failedSources` (see its contract's docstring)
      // — this is the one place that catches it, mirroring `_runCheck`
      // below for `DeviceCheck`.
      if (!mounted) return;
      setState(() => _searchingParamKey = null);
      handleSessionLost(context, error);
      return;
    } catch (e) {
      // The contract says implementations degrade honestly rather than
      // throwing — but a settings screen must not crash if one does anyway.
      if (!mounted) return;
      setState(() => _searchingParamKey = null);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    setState(() => _searchingParamKey = null);

    final chosen = await showDialog<DeviceCandidate>(
      context: context,
      builder: (_) =>
          _DiscoveryResultsDialog(result: result, paramKey: param.key),
    );
    if (chosen == null || !mounted) return;

    final value = chosen.parameters[param.key];
    if (value == null) return; // Only key-carrying candidates are selectable.

    setState(() {
      _paramControllers[param.key]?.text = value;
      widget.draft.parameters[param.key] = value;
    });
    widget.onChanged();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.deviceSearchFieldFilled(value))),
    );
  }

  List<Widget> _buildOptionFields(DeviceProfile profile) {
    return profile.options.map((option) {
      final current = widget.draft.options[option.key];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: option.allowedValues.map((value) {
                final selected = current == value;
                return ChoiceChip(
                  key: Key('option_${profile.id}_${option.key}_$value'),
                  label: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: AppTypography.familyMono,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => widget.draft.options[option.key] = value);
                    widget.onChanged();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// The «проверить устройство» button and its last answer.
  ///
  /// **The outcome is rendered as text, never as a tick or a cross.** The
  /// reason set is specific on purpose: "ничего не привязано", "привязка
  /// ссылается на профиль, которого больше нет", "привязано, но процесс её
  /// ещё не подхватил — перезапустите", "не отвечает", "отказало" and
  /// "на этой платформе не поддерживается" send an operator to six different
  /// places. A green tick and a red cross send them to two, and
  /// [DeviceCheckReason.driverNotLive] in particular is *advice*, not a
  /// fault — collapsing it into a red cross tells someone to check the cable
  /// on a printer that works. The colour band is decoration; the two lines
  /// of text are the answer.
  Widget _buildCheckSection() {
    final l10n = AppLocalizations.of(context)!;
    final outcome = _lastOutcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outcome != null)
          Container(
            key: const Key('device_check_outcome'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            width: double.infinity,
            decoration: BoxDecoration(
              color: _outcomeColour(outcome.reason).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reasonLabel(l10n, outcome.reason),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _outcomeColour(outcome.reason),
                  ),
                ),
                const SizedBox(height: 4),
                Text(outcome.message, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        Row(
          children: [
            OutlinedButton(
              key: const Key('device_check_button'),
              onPressed: _checking ? null : _runCheck,
              child: _checking
                  ? Text(l10n.deviceCheckRunning)
                  : Text(l10n.deviceCheckButton),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.deviceCheckSavedBindingNotice,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Colour is a second, coarser cue only — every distinction an operator
  /// has to act on is in the text. Note that [DeviceCheckReason.driverNotLive]
  /// and [DeviceCheckReason.notConfigured] are deliberately *not* error-red:
  /// neither means anything is broken.
  Color _outcomeColour(DeviceCheckReason reason) => switch (reason) {
    DeviceCheckReason.ok => AppColors.success,
    DeviceCheckReason.notConfigured ||
    DeviceCheckReason.driverNotLive ||
    DeviceCheckReason.notImplemented ||
    DeviceCheckReason.notSupportedOnPlatform => AppColors.info,
    DeviceCheckReason.invalidBinding ||
    DeviceCheckReason.connectionFailed ||
    DeviceCheckReason.deviceRefused ||
    DeviceCheckReason.unexpectedError => Theme.of(context).colorScheme.error,
  };

  /// One localised headline per reason — the part of the answer this app
  /// controls. [DeviceCheckOutcome.message] itself is built by whichever
  /// implementation ran (and, over HTTP, by the till) and is shown verbatim
  /// underneath, exactly as the contract requires; it is Russian-only today,
  /// a gap recorded in this task's report rather than papered over by
  /// re-deriving a message here from a narrower set of fields.
  String _reasonLabel(
    AppLocalizations l10n,
    DeviceCheckReason reason,
  ) => switch (reason) {
    DeviceCheckReason.ok => l10n.deviceCheckReasonOk,
    DeviceCheckReason.notConfigured => l10n.deviceCheckReasonNotConfigured,
    DeviceCheckReason.invalidBinding => l10n.deviceCheckReasonInvalidBinding,
    DeviceCheckReason.driverNotLive => l10n.deviceCheckReasonDriverNotLive,
    DeviceCheckReason.connectionFailed =>
      l10n.deviceCheckReasonConnectionFailed,
    DeviceCheckReason.deviceRefused => l10n.deviceCheckReasonDeviceRefused,
    DeviceCheckReason.notSupportedOnPlatform =>
      l10n.deviceCheckReasonNotSupportedOnPlatform,
    DeviceCheckReason.notImplemented => l10n.deviceCheckReasonNotImplemented,
    DeviceCheckReason.unexpectedError => l10n.deviceCheckReasonUnexpectedError,
  };

  Future<void> _runCheck() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    if (!GetIt.I.isRegistered<DeviceCheck>()) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.deviceCheckUnavailable)),
      );
      return;
    }
    final terminalId = widget.terminalId;
    if (terminalId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.hwSetupIncompleteCheck)),
      );
      return;
    }

    setState(() => _checking = true);
    // `DeviceCheck.check` never throws by contract, with one deliberate
    // exception — `SessionLost` (see the contract's docstring). Phase-2 fix
    // wave, task 1: before this fix, the bare `catch (e)` below caught it
    // too and drew it in the same panel as an unresponsive till — the exact
    // defect task 4 existed to remove had moved one layer up and stayed.
    DeviceCheckOutcome outcome;
    try {
      outcome = await GetIt.I<DeviceCheck>().check(
        terminalId: terminalId,
        deviceClass: widget.draft.deviceClass,
      );
    } on SessionLost catch (error) {
      if (!mounted) return;
      setState(() => _checking = false);
      handleSessionLost(context, error);
      return;
    } catch (e) {
      // Пункт 7 финальной волны закрытия долга безопасности (2026-08-22):
      // сторож `no_raw_exception_on_wire_test.dart` не видел это место —
      // его белый список из трёх файлов не включал этот экран, хотя
      // `DeviceCheckOutcome.unexpectedError` кладёт текст ровно в тот же
      // исход (`_lastOutcome`), что и `wt_device_check.dart`/
      // `device_check_local.dart`, уже переведённые на `safeErrorText`.
      // `'$e'` печатал бы `SqliteException.toString()` целиком, случись она
      // здесь, — тот же разрыв, что и везде в этой работе.
      outcome = DeviceCheckOutcome.unexpectedError(safeErrorText(e));
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _lastOutcome = outcome;
    });
  }
}

/// What [DeviceDiscovery] came back with, as a picker.
///
/// Three distinct answers, never collapsed into each other:
/// 1. candidates that carry a value for this field — selectable rows;
/// 2. candidates were found but none of them fills *this* field;
/// 3. nothing was found **and** every applicable source actually ran.
///
/// Plus, independently of all three, a line naming any source that could not
/// be searched at all. An operator seeing an empty list with no such line
/// knows the search was complete; one seeing the line knows it was not.
class _DiscoveryResultsDialog extends StatelessWidget {
  const _DiscoveryResultsDialog({required this.result, required this.paramKey});

  final DeviceDiscoveryResult result;
  final String paramKey;

  static String sourceLabel(
    AppLocalizations l10n,
    DeviceDiscoverySource source,
  ) => switch (source) {
    DeviceDiscoverySource.serialPort => l10n.deviceSourceSerialPort,
    DeviceDiscoverySource.usb => l10n.deviceSourceUsb,
    DeviceDiscoverySource.network => l10n.deviceSourceNetwork,
    DeviceDiscoverySource.bluetooth => l10n.deviceSourceBluetooth,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final matching = result.candidates
        .where((c) => c.parameters.containsKey(paramKey))
        .toList();
    final failed = result.failedSources.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return AlertDialog(
      title: Text(l10n.deviceSearchTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (failed.isNotEmpty)
              Padding(
                key: const Key('discovery_failed_sources'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.deviceSearchFailedSources(
                    failed.map((s) => sourceLabel(l10n, s)).join(', '),
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (matching.isEmpty)
              Text(
                // "Nothing is attached" is only claimed when every applicable
                // source really ran. With a failed source above, the honest
                // statement is the failure line and nothing more.
                result.candidates.isNotEmpty
                    ? l10n.deviceSearchNoValueForField
                    : failed.isEmpty
                    ? l10n.deviceSearchEmpty
                    : '',
                key: const Key('discovery_empty_text'),
                style: const TextStyle(fontSize: 13),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: matching.map((candidate) {
                    return ListTile(
                      key: Key('candidate_${candidate.parameters[paramKey]}'),
                      dense: true,
                      title: Text(candidate.title),
                      subtitle: Text(
                        '${sourceLabel(l10n, candidate.source)} · '
                        '${candidate.parameters[paramKey]}',
                        style: const TextStyle(
                          fontFamily: AppTypography.familyMono,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(candidate),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.globalCancel),
        ),
      ],
    );
  }
}

/// Mutable scratch state for the three И142 barcode rules while the operator
/// edits them — the same "nothing is persisted until Save" shape as
/// [DeviceBindingDraft].
///
/// Held as text, not as `int?`, on purpose: "42x" is a state the operator can
/// be in while typing, and turning it into `null` (or into 42) on the way in
/// would silently change what they meant. It becomes a [ScannerRules] once,
/// in [toRules], where a non-number is an error the operator is told about
/// rather than a value quietly dropped.
class _ScannerRulesDraft {
  final minLength = TextEditingController();
  final maxLength = TextEditingController();
  final timeoutMs = TextEditingController();

  void applyRules(ScannerRules rules) {
    minLength.text = rules.barcodeMinLength?.toString() ?? '';
    maxLength.text = rules.barcodeMaxLength?.toString() ?? '';
    timeoutMs.text = rules.scannerTimeoutMs?.toString() ?? '';
  }

  /// Throws [FormatException] naming the offending text, or [ArgumentError]
  /// from [ScannerRules]' own validation (min above max, and so on).
  ScannerRules toRules(AppLocalizations l10n) => ScannerRules(
    barcodeMinLength: _parse(minLength.text, l10n),
    barcodeMaxLength: _parse(maxLength.text, l10n),
    scannerTimeoutMs: _parse(timeoutMs.text, l10n),
  );

  /// Blank means "unset — use the decoder's default", which is a real,
  /// storable state and not the same as zero.
  int? _parse(String raw, AppLocalizations l10n) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null) {
      throw FormatException(l10n.scannerRulesNotAnInteger(text));
    }
    return value;
  }

  void dispose() {
    minLength.dispose();
    maxLength.dispose();
    timeoutMs.dispose();
  }
}

/// Operator controls for the three И142 rules (И142, section 20's UI-first
/// rule). Saved by the screen's own Save button, alongside the bindings.
/// Пункт 11 ревизии 2026-09-19: довода «available» у секции больше нет.
/// Три поля стоят всегда — и на кассе, и на планшете. Прежняя ветка
/// «здесь их не задать» была честной ровно до того дня, когда запись
/// приехала на провод; оставленная после, она прятала бы работающую
/// настройку за текстом о её отсутствии.
class _ScannerRulesSection extends StatelessWidget {
  const _ScannerRulesSection({required this.draft});

  final _ScannerRulesDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SettingsSectionCard(
      title: l10n.scannerRulesTitle,
      icon: Icons.rule,
      children: [
        Text(
          l10n.scannerRulesSubtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        _field(
          fieldKey: 'scanner_rule_min_length',
          controller: draft.minLength,
          label: l10n.scannerRulesMinLength,
          hint: l10n.scannerRulesDefaultHint(
            '${ScannerRules.defaultBarcodeMinLength}',
          ),
        ),
        _field(
          fieldKey: 'scanner_rule_max_length',
          controller: draft.maxLength,
          label: l10n.scannerRulesMaxLength,
          hint: l10n.scannerRulesDefaultHint(
            '${ScannerRules.defaultBarcodeMaxLength}',
          ),
        ),
        _field(
          fieldKey: 'scanner_rule_timeout_ms',
          controller: draft.timeoutMs,
          label: l10n.scannerRulesTimeoutMs,
          hint: l10n.scannerRulesDefaultHint(
            '${ScannerRules.defaultScannerTimeoutMs}',
          ),
        ),
      ],
    );
  }

  Widget _field({
    required String fieldKey,
    required TextEditingController controller,
    required String label,
    required String hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      key: Key(fieldKey),
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

/// The card shell every settings section in this directory uses — icon,
/// title, optional trailing control (usually a `Switch`), then its content.
class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // `Material(transparency)` вокруг **всей** карточки, а не вокруг одного
    // виджета в одной секции: карточка рисует свой фон `Container`'ом, а
    // `ListTile` и его родня кладут подсветку нажатия на ближайший
    // `Material` — который остался бы **под** этим фоном. Flutter говорит
    // об этом утверждением («ListTile background color or ink splashes may
    // be invisible»), и оно роняет виджет-пробу, а в продукте дало бы
    // строку без отклика на нажатие.
    //
    // Круг правки 1: сначала обёртка стояла в месте вызова, у галочек видов
    // оплаты. Но карточка общая для всех секций этого экрана, и ловушка
    // ждала бы каждую следующую. Одна строка здесь снимает её для всех.
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      // `Material(transparency)` **внутри** оформления, а не вокруг него:
      // утверждение Flutter ищет `DecoratedBox` с фоном между `ListTile` и
      // ближайшим `Material`, так что обёртка снаружи его не снимает —
      // проверено, круг правки 1 наступил на это первой попыткой.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
