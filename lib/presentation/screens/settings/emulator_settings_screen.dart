import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/net/loopback.dart';
import 'package:telepos/core/settings/builtin_emulator_settings.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/emulators/builtin_emulator_host.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Единственное место, где оператор включает и выключает встроенные эмуляторы.
///
/// # Что делает включение, и чего оно НЕ делает
///
/// Делает ровно две вещи: поднимает прибор (сокет у принтера, файл-порт у
/// весов и дисплея) и показывает его адрес. Не делает — ничего с драйверами:
/// касса как ходила к приборам своими классами по адресу привязки, так и
/// ходит. Довод целиком — на [BuiltinEmulatorHost], сторож —
/// `builtin_emulator_guards_test.dart`.
///
/// # Почему адрес не вписывается в привязку сам
///
/// Привязка прибора — единственный источник правды о том, куда касса ходит.
/// Экран предлагает вписать адрес **одним действием и с показом**, но решение
/// остаётся за человеком: молчаливая правка чужой настройки завела бы второй
/// источник правды, а ширину ленты в этом проекте уже помнили четыре места, и
/// выбранная на экране не доходила ни до одного документа.
///
/// Выключение прибор гасит, а привязку не чистит: касса, оставшаяся с адресом
/// погашенного эмулятора, обязана честно сказать «прибор не отвечает». Чтобы
/// это не выглядело загадкой, экран сам показывает предупреждение.
///
/// # Почему поле веса здесь, а на вкладке диагностики его нет
///
/// Здесь это **пульт подставного прибора** — то же, что положить гирю на
/// чашу: число задаётся эмулятору, а касса читает его своим `ScalesService`,
/// своим разбором строки, своим опросом. Такое же поле на экране диагностики
/// было бы вторым источником веса в самой кассе, и первая же продажа по нему
/// ушла бы мимо прибора.
///
/// # Фискальный оператор: карточка без привязки прибора
///
/// У оператора `DeviceBinding` нет и быть не может: он не прибор этой кассы, а
/// чужая служба, и адресуется полем «Адрес сервера» фискальных настроек.
/// Поэтому его «вписать одним действием» идёт в [FiscalSettingsStore], а не в
/// [DeviceBindingRepository].
///
/// **Что именно пишет это действие и почему не меньше.** Касса не выйдет в
/// сеть, пока не заполнены адрес, логин, пароль, ключ интегратора и заводской
/// номер: `WebKassaProvider.validateConfig` отказывает раньше сокета. Впиши
/// экран один адрес — кассир получил бы «код 1» или «не указан X-API-Key» и
/// чинил бы несуществующую поломку. Поэтому пишется весь набор, известный
/// держателю, и он назван на экране **до** нажатия, а не после.
///
/// **Чего действие НЕ пишет, и это важнее.** Регистрационного номера оно не
/// трогает: заполненный регистрационный номер — признак боевой кассы, и
/// вписать его значило бы запереть выключатель собственным действием. А
/// `testMode` оно, наоборот, включает — потому что заводской номер эмулятора
/// сам по себе делает кассу боевой по тому же признаку, и без этого выключатель
/// запёрся бы на первой же перезагрузке.
///
/// **Чего экран не видит.** Он читает и пишет `FiscalSettingsStore` — тот же,
/// что экран фискальных настроек. Если оператор не выбран, касса на самом деле
/// идёт по адресу из `ThisPos` (`StoreFiscalSettingsSource`), и этой половины
/// экран не показывает. Её показывает вкладка диагностики: она читает
/// настоящий источник и метит петлю плашкой.
class EmulatorSettingsScreen extends ConsumerStatefulWidget {
  const EmulatorSettingsScreen({super.key});

  @override
  ConsumerState<EmulatorSettingsScreen> createState() =>
      _EmulatorSettingsScreenState();
}

class _EmulatorSettingsScreenState
    extends ConsumerState<EmulatorSettingsScreen> {
  BuiltinEmulatorHost get _host => GetIt.I<BuiltinEmulatorHost>();

  final _failures = <BuiltinEmulatorKind, String>{};

  /// Смотрит ли привязка прибора на **поднятый сейчас** эмулятор.
  final _boundToRunning = <BuiltinEmulatorKind, bool>{};

  /// Смотрит ли привязка на этот же компьютер вообще.
  ///
  /// Отдельно от предыдущего, потому что вопросы разные: первый — «предлагать
  /// ли вписать адрес», второй — «не осталась ли касса смотреть на погашенный
  /// эмулятор». На второй при выключенном эмуляторе сравнением с его адресом
  /// не ответить: адреса уже нет.
  final _boundLocally = <BuiltinEmulatorKind, bool>{};

  late final TextEditingController _weight = TextEditingController(
    text: _host.scaleWeight ?? '0.500',
  );

  @override
  void initState() {
    super.initState();
    unawaited(_refreshBindings());
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  /// Почему прибор включить нельзя. Спрашивается у держателя, а не решается
  /// здесь: условие, повторённое на экране, расходится с настоящим молча.
  final _refusals = <BuiltinEmulatorKind, BuiltinEmulatorRefused>{};

  /// Класс прибора — или `null` у того, кто прибором не является.
  ///
  /// Фискальный оператор — чужая служба, а не прибор этой кассы: привязки у
  /// него нет, адресуется он полем фискальных настроек.
  static DeviceClass? _classOf(BuiltinEmulatorKind kind) => switch (kind) {
    BuiltinEmulatorKind.receiptPrinter => DeviceClass.receiptPrinter,
    BuiltinEmulatorKind.scale => DeviceClass.scale,
    BuiltinEmulatorKind.customerDisplay => DeviceClass.customerDisplay,
    BuiltinEmulatorKind.fiscalOperator => null,
    BuiltinEmulatorKind.qrProvider => null,
  };

  /// Профиль по умолчанию, если привязки ещё нет.
  ///
  /// Эмулятор меняет **адрес**, а не модель прибора: на выбранной модели и
  /// проверяют шаблон чека, ширину ленты, число колонок дисплея.
  static String _defaultProfile(BuiltinEmulatorKind kind) => switch (kind) {
    BuiltinEmulatorKind.receiptPrinter => 'printer.escpos.80mm',
    BuiltinEmulatorKind.scale => 'scale.cas.pd2',
    BuiltinEmulatorKind.customerDisplay => 'display.serial.vfd',
    BuiltinEmulatorKind.fiscalOperator => '',
    BuiltinEmulatorKind.qrProvider => '',
  };

  FiscalSettingsStore get _fiscalStore =>
      FiscalSettingsStore(ref.read(sharedPreferencesProvider));

  Future<DeviceBinding?> _bindingOf(BuiltinEmulatorKind kind) async {
    final deviceClass = _classOf(kind);
    if (deviceClass == null) return null;
    final terminal = await GetIt.I<TerminalRepository>().self();
    final bindings = await GetIt.I<DeviceBindingRepository>().forTerminal(
      terminal.id,
    );
    for (final binding in bindings) {
      if (binding.deviceClass == deviceClass) return binding;
    }
    return null;
  }

  /// Адрес, на который касса пойдёт за этим прибором, — из **настройки**, а не
  /// из памяти экрана.
  ///
  /// У приборов это привязка, у оператора — «Адрес сервера» фискальных
  /// настроек. Разные хранилища, один вопрос, и ответ обязан читаться оттуда,
  /// куда экран писал: иначе «вписал» и «работает» расходятся молча.
  Future<String?> _configuredAddress(BuiltinEmulatorKind kind) async {
    if (kind == BuiltinEmulatorKind.fiscalOperator) {
      final url = _fiscalStore.load().resolvedBaseUrl;
      return (url == null || url.isEmpty) ? null : url;
    }
    if (kind == BuiltinEmulatorKind.qrProvider) return _qrBaseUrl();
    final binding = await _bindingOf(kind);
    return binding == null ? null : _addressIn(binding);
  }

  /// Address the QR provider setting points at.
  Future<String?> _qrBaseUrl() async {
    _qrSetup = GetIt.I.isRegistered<QrProviderSetupRepository>();
    if (!_qrSetup) return null;
    final view = await GetIt.I<QrProviderSetupRepository>().read();
    final url = view.baseUrl.trim();
    return url.isEmpty ? null : url;
  }

  bool _qrSetup = false;

  Future<void> _refreshBindings() async {
    final running = <BuiltinEmulatorKind, bool>{};
    final local = <BuiltinEmulatorKind, bool>{};
    final refusals = <BuiltinEmulatorKind, BuiltinEmulatorRefused>{};
    for (final kind in BuiltinEmulatorKind.values) {
      final address = _host.addressOf(kind);
      final value = await _configuredAddress(kind);
      local[kind] = value != null && _looksLocal(value);
      running[kind] =
          value != null &&
          value ==
              (kind == BuiltinEmulatorKind.fiscalOperator
                  ? address?.baseUrl
                  : address?.bindingValue);
      final refusal = await _host.refusalFor(kind);
      if (refusal != null) refusals[kind] = refusal;
    }
    if (!mounted) return;
    setState(() {
      _boundToRunning
        ..clear()
        ..addAll(running);
      _boundLocally
        ..clear()
        ..addAll(local);
      _refusals
        ..clear()
        ..addAll(refusals);
    });
  }

  /// Адрес из привязки — тем же ключом, каким его пишет экран настроек
  /// прибора: сетевой по `ipAddress`, последовательный по `comPort`.
  static String? _addressIn(DeviceBinding binding) =>
      binding.parameters['ipAddress']?.trim() ??
      binding.parameters['comPort']?.trim();

  /// Похож ли адрес на «этот же компьютер».
  ///
  /// Для сети это петля, для порта — путь в каталоге эмуляторов, а не имя
  /// `COMn`: настоящий прибор на COM от подставного по имени не отличить, и
  /// врать про него нельзя.
  ///
  /// Сетевую половину вопроса задаёт [isLoopbackUrl], а не свой разбор
  /// (I170). До правки 2026-09-19 здесь жила **третья** копия правила «это
  /// петля» — вторая была на экране диагностики, — и обе уже отставали от
  /// общей: `[::1]` в квадратных скобках, как адрес IPv6 приезжает из URL,
  /// общая считает петлёй, копии — нет. Расхождение молчаливое: «плашка не
  /// зажглась» неотличимо от исправной кассы.
  static bool _looksLocal(String address) {
    // Ссылка и голый узел разбираются одним ответом: у оператора это
    // «http://127.0.0.1:8085», у принтера — «127.0.0.1».
    if (isLoopbackUrl(address)) return true;
    return address.contains('telepos-emulators');
  }

  Future<void> _apply(BuiltinEmulatorKind kind, bool value) async {
    setState(() => _failures.remove(kind));
    await BuiltinEmulatorChoice.write(
      ref.read(sharedPreferencesProvider),
      kind,
      enabled: value,
    );

    try {
      if (value) {
        await _host.start(kind);
      } else {
        await _host.stop(kind);
      }
    } on Object catch (e) {
      // Отказ подъёма — не повод молчать и не повод падать: порт мог быть
      // занят, и кассиру нужно именно это число.
      if (!mounted) return;
      setState(() => _failures[kind] = '$e');
    }
    if (!mounted) return;
    setState(() {});
    await _refreshBindings();
  }

  /// Вписывает адрес эмулятора в привязку прибора.
  ///
  /// Через тот же [DeviceBindingRepository], которым это делает экран настроек
  /// оборудования: другой путь записи означал бы другую проверку и другую
  /// ошибку.
  Future<void> _bind(BuiltinEmulatorKind kind) async {
    final l10n = AppLocalizations.of(context)!;
    final address = _host.addressOf(kind);
    if (address == null) return;

    if (kind == BuiltinEmulatorKind.fiscalOperator) {
      await _bindFiscal(address, l10n);
      return;
    }

    if (kind == BuiltinEmulatorKind.qrProvider) {
      // Пишется тем же портом, что и экран настройки QR: другой путь записи
      // означал бы другую проверку и другую ошибку. Ключ провайдера при этом
      // не трогается, а `code` берётся уже заведённый: эмулятор меняет
      // **адрес**, а не имя провайдера, под которым деньги лягут в
      // `Payments.providerCode`.
      final setup = GetIt.I<QrProviderSetupRepository>();
      final view = await setup.read();
      await setup.save(
        baseUrl: address.baseUrl!,
        code: view.code.trim().isEmpty ? 'sbp' : view.code,
        patience: view.patience,
      );
      await _refreshBindings();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.emulatorQrBindDone)));
      return;
    }

    // Ветка выше забрала единственный вид без класса прибора; `!` здесь —
    // следствие этого, а не надежда.
    final deviceClass = _classOf(kind)!;
    final terminal = await GetIt.I<TerminalRepository>().self();
    final current = await _bindingOf(kind);

    await GetIt.I<DeviceBindingRepository>().save(
      terminal.id,
      DeviceBinding(
        deviceClass: deviceClass,
        profileId: current?.profileId ?? _defaultProfile(kind),
        parameters: address.path != null
            ? {'comPort': address.path!}
            : {'ipAddress': address.host!, 'port': '${address.port}'},
        options: current?.options ?? const {},
      ),
    );
    await _refreshBindings();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.emulatorBindDone)));
  }

  /// Направляет кассу на встроенный эмулятор ОФД — одним действием и целиком.
  ///
  /// Довод, что именно пишется и чего не пишется, — в докстринге экрана.
  /// Коротко: весь набор, без которого `validateConfig` не выпустит кассу в
  /// сеть, плюс испытательный режим; регистрационный номер — никогда.
  Future<void> _bindFiscal(
    BuiltinEmulatorAddress address,
    AppLocalizations l10n,
  ) async {
    final store = _fiscalStore;
    final current = store.load();
    await store.save(
      current.copyWith(
        // Оператора выбираем, только если он не выбран: у кассы, где уже
        // стоит WebKassa, менять нечего, а чужого оператора менять нельзя —
        // это не наше решение.
        operatorType: current.operatorType == FiscalOperatorType.none
            ? FiscalOperatorType.webkassa
            : current.operatorType,
        testMode: true,
        baseUrl: address.baseUrl,
        login: BuiltinEmulatorHost.fiscalLogin,
        password: BuiltinEmulatorHost.fiscalPassword,
        apiKey: BuiltinEmulatorHost.fiscalApiKey,
        cashboxUniqueNumber: BuiltinEmulatorHost.fiscalCashbox,
      ),
    );
    await _refreshBindings();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.emulatorFiscalBindDone)));
  }

  String _title(AppLocalizations l10n, BuiltinEmulatorKind kind) =>
      switch (kind) {
        BuiltinEmulatorKind.receiptPrinter => l10n.emulatorReceiptPrinter,
        BuiltinEmulatorKind.scale => l10n.diagnosticsTabScales,
        BuiltinEmulatorKind.customerDisplay => l10n.diagnosticsTabDisplay,
        BuiltinEmulatorKind.fiscalOperator => l10n.emulatorFiscalOperator,
        BuiltinEmulatorKind.qrProvider => l10n.emulatorQrProvider,
      };

  IconData _icon(BuiltinEmulatorKind kind, bool on) => switch (kind) {
    BuiltinEmulatorKind.receiptPrinter =>
      on ? Icons.print : Icons.print_disabled,
    BuiltinEmulatorKind.scale => Icons.monitor_weight_outlined,
    BuiltinEmulatorKind.customerDisplay => Icons.tv_outlined,
    BuiltinEmulatorKind.fiscalOperator => Icons.receipt_long_outlined,
    BuiltinEmulatorKind.qrProvider => Icons.qr_code_2,
  };

  /// Причина отказа на языке кассира.
  String _refusalText(AppLocalizations l10n, BuiltinEmulatorRefused refusal) =>
      switch (refusal.reason) {
        BuiltinEmulatorRefusalReason.liveTill => l10n.emulatorFiscalBlockedLive,
        BuiltinEmulatorRefusalReason.settingsUnknown =>
          l10n.emulatorFiscalBlockedUnknown,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.emulatorSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final kind in BuiltinEmulatorKind.values) ...[
            _card(context, l10n, kind),
            const SizedBox(height: 16),
          ],
          Text(
            l10n.emulatorSettingsHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    AppLocalizations l10n,
    BuiltinEmulatorKind kind,
  ) {
    final on = _host.isRunning(kind);
    final address = _host.addressOf(kind);
    final failure = _failures[kind];
    final fiscal = kind == BuiltinEmulatorKind.fiscalOperator;

    // Запертый выключатель показывается погашенным и с причиной рядом, а не
    // прячется: пропавшая карточка читается как «эмулятора ОФД у нас нет»,
    // и кассир пойдёт искать его в другом месте. Решение о запрете принимает
    // держатель — экран его только пересказывает.
    //
    // `&& !on` — не послабление, а обратное. Реквизиты могли вписать уже
    // после включения, и тогда запрет обязан дать **выключить** прибор, а не
    // запереть его поднятым: запертый поднятый эмулятор ОФД на кассе, ставшей
    // боевой, — ровно та беда, ради которой весь запрет и заведён.
    final refusal = _refusals[kind];
    final locked = refusal != null && !on;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: ValueKey('emulator-${kind.name}-enable'),
            value: on,
            onChanged: locked ? null : (value) => _apply(kind, value),
            title: Text(_title(l10n, kind)),
            subtitle: Text(
              on ? l10n.emulatorEnabledNote : l10n.emulatorDisabledNote,
            ),
            secondary: Icon(
              _icon(kind, on),
              color: on
                  ? AppColors.success
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (locked)
            ListTile(
              key: ValueKey('emulator-${kind.name}-blocked'),
              leading: Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(_refusalText(l10n, refusal)),
            ),
          if (failure != null)
            ListTile(
              key: ValueKey('emulator-${kind.name}-failed'),
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.emulatorStartFailed),
              subtitle: Text(failure),
            ),
          if (address != null) ...[
            ListTile(
              key: ValueKey('emulator-${kind.name}-address'),
              leading: const Icon(Icons.lan),
              title: Text(l10n.emulatorAddress),
              subtitle: Text(
                '${fiscal ? address.baseUrl : (address.path ?? '${address.host} : ${address.port}')}\n'
                '${fiscal ? l10n.emulatorFiscalAddressHint : l10n.emulatorAddressHint}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: fiscal ? address.baseUrl! : address.bindingValue,
                  ),
                ),
              ),
            ),
            if (kind == BuiltinEmulatorKind.scale) _scaleControl(l10n),
            // У провайдера QR кнопка показывается только там, где есть куда
            // писать: голая касса без контейнера и браузерная половина стойки
            // не держат. Адрес при этом виден — вписать его руками на экране
            // настройки QR никто не мешает, и прятать число хуже, чем кнопку.
            if (_boundToRunning[kind] != true &&
                (kind != BuiltinEmulatorKind.qrProvider || _qrSetup))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (fiscal)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.emulatorFiscalBindNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    FilledButton.icon(
                      key: ValueKey('emulator-${kind.name}-bind'),
                      onPressed: () => _bind(kind),
                      icon: const Icon(Icons.link),
                      label: Text(
                        fiscal
                            ? l10n.emulatorFiscalBindAction
                            : l10n.emulatorBindAction,
                      ),
                    ),
                  ],
                ),
              ),
            // Поле «локальный модуль» перебивает адрес сервера
            // (`WebKassaProvider._baseUrl` смотрит на него первым), и
            // заполненное оно отправило бы кассу мимо эмулятора молча. Экран
            // его не чистит — чужая настройка не правится без спроса, — но
            // называет вслух.
            if (fiscal && _fiscalStore.load().hasLocalModule)
              ListTile(
                key: const ValueKey('emulator-fiscalOperator-local-module'),
                leading: const Icon(
                  Icons.report_problem_outlined,
                  color: AppColors.warning,
                ),
                title: Text(l10n.emulatorFiscalLocalModuleWarning),
              ),
          ],
          if (!on && _boundLocally[kind] == true)
            ListTile(
              key: ValueKey('emulator-${kind.name}-stale'),
              leading: const Icon(
                Icons.report_problem_outlined,
                color: AppColors.warning,
              ),
              title: Text(
                fiscal
                    ? l10n.emulatorFiscalBindingStale
                    : l10n.emulatorBindingStale,
              ),
            ),
        ],
      ),
    );
  }

  /// Пульт весов: что «лежит на чаше».
  Widget _scaleControl(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: TextField(
      key: const ValueKey('emulator-scale-weight'),
      controller: _weight,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: l10n.emulatorScaleWeight,
        helperText: l10n.emulatorScaleWeightHint,
      ),
      onChanged: (value) => _host.setScaleWeight(value.trim()),
    ),
  );
}
