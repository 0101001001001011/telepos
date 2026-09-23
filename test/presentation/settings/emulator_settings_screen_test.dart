/// Экран встроенных эмуляторов — целиком, настоящим сокетом и настоящей
/// привязкой.
///
/// # Почему проба идёт через весь экран, а не через его куски
///
/// Обещание экрана — «включил и можешь печатать», и ломается оно ровно на
/// стыках: сокет поднят, но показан не тот порт; адрес показан, но в привязку
/// легло другое; привязка легла, но касса о ней не узнала. Каждый кусок по
/// отдельности при этом зелёный.
///
/// Поэтому здесь: щелчок по настоящему переключателю → настоящий
/// `BuiltinEmulatorHost` → соединение по показанному адресу → настоящая
/// `LocalDeviceBindingRepository` поверх памяти.
///
/// # Чего проба НЕ доказывает
///
/// Что по этой привязке напечатается чек: путь «касса → очередь → принтер»
/// проверяет `receipt_wire_stand.dart`, и повторять его здесь значило бы
/// мерить дважды одно.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/settings/builtin_emulator_settings.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/fiscal/fiscal_settings_store.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/emulators/builtin_emulator_host.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/emulator_settings_screen.dart';

/// Только `self()`: всё остальное бросает, чтобы случайная новая зависимость
/// экрана падала громко, а не возвращала правдоподобное.
class _FakeTerminalRepository implements TerminalRepository {
  _FakeTerminalRepository(this.terminalId);

  final int terminalId;

  @override
  Future<Terminal> self() async =>
      Terminal(id: terminalId, name: 'Касса-1', pointMode: PointMode.cashier);

  @override
  Future<List<Terminal>> list() => throw UnimplementedError();

  @override
  Stream<List<Terminal>> watchAll() => throw UnimplementedError();

  @override
  Stream<Terminal?> watchSelf() => throw UnimplementedError();

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) => throw UnimplementedError();

  @override
  Future<Terminal> resume({required int terminalId, required String secret}) =>
      throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) =>
      throw UnimplementedError();

  @override
  Future<void> setAllowedPaymentTypes(int terminalId, Set<PaymentType> types) =>
      throw UnimplementedError();

  @override
  Future<void> delete(int terminalId) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late DeviceBindingRepository repo;
  late BuiltinEmulatorHost host;
  late SharedPreferences prefs;
  late int terminalId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final terminal = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    terminalId = terminal.id;
    repo = LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog());

    // Свой диапазон, а не боевой 9100: тот на машине разработки занят
    // `dart devtools`, и проба мерила бы машину.
    host = BuiltinEmulatorHost(
      portRanges: {BuiltinEmulatorKind.receiptPrinter: (18660, 18669)},
    );

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    await GetIt.I.reset();
    GetIt.I.registerSingleton<DeviceBindingRepository>(repo);
    GetIt.I.registerSingleton<TerminalRepository>(
      _FakeTerminalRepository(terminalId),
    );
    GetIt.I.registerSingleton<BuiltinEmulatorHost>(host);
  });

  tearDown(() async {
    await host.stopAll();
    await GetIt.I.reset();
    await db.close();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EmulatorSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Щёлкает по виджету и даёт настоящему вводу-выводу завершиться.
  ///
  /// Без [WidgetTester.runAsync] сокет не открывается вовсе: под виджет-пробой
  /// часы поддельные, и `ServerSocket.bind` не доходит до конца — измерено,
  /// первая редакция этих проб падала на «щелчок обязан поднять сокет» с
  /// пустым адресом и без единой ошибки.
  Future<void> tapAndLetIoFinish(WidgetTester tester, Key key) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(key));
      for (var i = 0; i < 20; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
  }

  /// Читает привязку из настоящей базы — и тоже под [WidgetTester.runAsync],
  /// по той же причине, что и сокеты.
  Future<DeviceBinding?> receiptBinding(WidgetTester tester) async {
    DeviceBinding? found;
    await tester.runAsync(() async {
      final all = await repo.forTerminal(terminalId);
      for (final binding in all) {
        if (binding.deviceClass == DeviceClass.receiptPrinter) found = binding;
      }
    });
    return found;
  }

  testWidgets('щелчок поднимает сокет, и показан тот порт, где он слушает', (
    tester,
  ) async {
    await mount(tester);
    expect(
      find.byKey(const ValueKey('emulator-receiptPrinter-address')),
      findsNothing,
    );

    await tapAndLetIoFinish(
      tester,
      const ValueKey('emulator-receiptPrinter-enable'),
    );

    final address = host.addressOf(BuiltinEmulatorKind.receiptPrinter);
    expect(address, isNotNull, reason: 'щелчок обязан поднять сокет');

    // Показанное число — не украшение: по нему кассир настраивает принтер.
    expect(
      find.textContaining('${address!.port}'),
      findsWidgets,
      reason: 'экран показывает порт, который кассир впишет в привязку',
    );

    // И по этому же порту действительно принимают соединение. Тоже под
    // `runAsync`: настоящий ввод-вывод под поддельными часами виджет-пробы не
    // завершается вовсе — не падает, а висит (измерено: прогон ушёл за 600 с).
    await tester.runAsync(() async {
      final socket = await Socket.connect(address.host!, address.port!);
      addTearDown(socket.destroy);
      expect(socket.remotePort, address.port);
    });

    expect(
      BuiltinEmulatorChoice.read(
        prefs,
      ).isEnabled(BuiltinEmulatorKind.receiptPrinter),
      isTrue,
      reason: 'решение обязано пережить перезапуск, иначе привязка осиротеет',
    );
  });

  testWidgets('одно действие вписывает показанный адрес в привязку', (
    tester,
  ) async {
    await mount(tester);
    await tapAndLetIoFinish(
      tester,
      const ValueKey('emulator-receiptPrinter-enable'),
    );

    expect(
      await receiptBinding(tester),
      isNull,
      reason: 'до действия привязки нет',
    );

    await tapAndLetIoFinish(
      tester,
      const ValueKey('emulator-receiptPrinter-bind'),
    );

    final address = host.addressOf(BuiltinEmulatorKind.receiptPrinter)!;
    final binding = await receiptBinding(tester);
    expect(binding, isNotNull);
    expect(binding!.parameters['ipAddress'], address.host);
    expect(
      binding.parameters['port'],
      '${address.port}',
      reason:
          'в привязку обязан лечь ТОТ ЖЕ порт, что показан: расхождение здесь '
          'выглядит как неисправный принтер',
    );
  });

  testWidgets(
    'выключение гасит сокет, но привязку не чистит — и говорит об этом',
    (tester) async {
      await mount(tester);
      await tapAndLetIoFinish(
        tester,
        const ValueKey('emulator-receiptPrinter-enable'),
      );
      await tapAndLetIoFinish(
        tester,
        const ValueKey('emulator-receiptPrinter-bind'),
      );
      final address = host.addressOf(BuiltinEmulatorKind.receiptPrinter)!;

      await tapAndLetIoFinish(
        tester,
        const ValueKey('emulator-receiptPrinter-enable'),
      );

      expect(host.isRunning(BuiltinEmulatorKind.receiptPrinter), isFalse);
      await tester.runAsync(() async {
        await expectLater(
          Socket.connect(
            address.host!,
            address.port!,
            timeout: const Duration(seconds: 2),
          ),
          throwsA(isA<SocketException>()),
          reason: 'касса обязана увидеть отказ, а не тишину',
        );
      });

      final binding = await receiptBinding(tester);
      expect(
        binding?.parameters['port'],
        '${address.port}',
        reason:
            'молчаливая правка чужой настройки завела бы второй источник правды '
            'о том, куда касса ходит',
      );
      expect(
        find.byKey(const ValueKey('emulator-receiptPrinter-stale')),
        findsOneWidget,
        reason:
            'касса смотрит на погашенный порт — это обязано быть сказано, а не '
            'оставлено загадкой на утро',
      );
    },
  );

  // ─────────────────────────── фискальный оператор ──────────────────────────
  //
  // У ОФД привязки прибора нет: адрес живёт в фискальных настройках, и
  // «вписать одним действием» идёт туда. Проба поэтому читает
  // `FiscalSettingsStore` — то же хранилище, что и экран фискальных настроек,
  // а не память экрана эмуляторов.

  /// Поднять держателя со своими фискальными настройками и своим окном портов.
  void useFiscalHost(FiscalSettings settings) {
    host = BuiltinEmulatorHost(
      portRanges: {BuiltinEmulatorKind.fiscalOperator: (18670, 18679)},
      fiscalSettings: () async => settings,
    );
    GetIt.I
      ..unregister<BuiltinEmulatorHost>()
      ..registerSingleton<BuiltinEmulatorHost>(host);
  }

  testWidgets('на боевой кассе выключатель ОФД заперт, и причина названа', (
    tester,
  ) async {
    useFiscalHost(
      FiscalSettings(
        operatorType: FiscalOperatorType.webkassa,
        testMode: false,
        registrationNumber: '000000000001',
        cashboxUniqueNumber: 'SWK00000001',
      ),
    );
    await mount(tester);

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('emulator-fiscalOperator-enable')),
    );
    expect(
      tile.onChanged,
      isNull,
      reason:
          'выключатель, который щёлкается и откатывается, читается как '
          'неисправность кассы. Запертый — как запрет',
    );
    expect(
      find.byKey(const ValueKey('emulator-fiscalOperator-blocked')),
      findsOneWidget,
      reason:
          'карточка без причины неотличима от поломки: кассир пойдёт чинить '
          'не то',
    );
    expect(find.textContaining('боевая'), findsOneWidget);

    // И щелчок ничего не поднимает — даже если до выключателя дотянутся.
    await tapAndLetIoFinish(
      tester,
      const ValueKey('emulator-fiscalOperator-enable'),
    );
    expect(host.isRunning(BuiltinEmulatorKind.fiscalOperator), isFalse);
  });

  testWidgets('одно действие направляет фискальные настройки на эмулятор', (
    tester,
  ) async {
    // Касса без реквизитов — не боевая, эмулятор разрешён.
    useFiscalHost(FiscalSettings(testMode: false));
    await mount(tester);

    await tapAndLetIoFinish(
      tester,
      const ValueKey('emulator-fiscalOperator-enable'),
    );
    final address = host.addressOf(BuiltinEmulatorKind.fiscalOperator);
    expect(address, isNotNull, reason: 'щелчок обязан поднять сервер');

    expect(
      FiscalSettingsStore(prefs).load().baseUrl,
      isNull,
      reason: 'до действия адрес не тронут: подъём сокета — не правка настроек',
    );

    await tapAndLetIoFinish(
      tester,
      const ValueKey('emulator-fiscalOperator-bind'),
    );

    final written = FiscalSettingsStore(prefs).load();
    expect(
      written.baseUrl,
      address!.baseUrl,
      reason: 'в настройки обязан лечь ТОТ ЖЕ адрес, что показан',
    );
    expect(
      written.operatorType,
      FiscalOperatorType.webkassa,
      reason:
          'без выбранного оператора StoreFiscalSettingsSource отдаёт не эти '
          'настройки вовсе, и вписанный адрес не подхватится',
    );
    expect(
      [
        written.login,
        written.password,
        written.apiKey,
        written.cashboxUniqueNumber,
      ],
      [
        BuiltinEmulatorHost.fiscalLogin,
        BuiltinEmulatorHost.fiscalPassword,
        BuiltinEmulatorHost.fiscalApiKey,
        BuiltinEmulatorHost.fiscalCashbox,
      ],
      reason:
          'validateConfig не выпускает кассу в сеть без ключа, логина, пароля '
          'и заводского номера: половина набора выглядела бы как «код 1»',
    );
    expect(
      written.registrationNumber,
      isNull,
      reason:
          'регистрационный номер — признак боевой кассы. Вписав его, экран '
          'запер бы выключатель собственным действием',
    );
    expect(
      written.testMode,
      isTrue,
      reason:
          'заводской номер эмулятора сам по себе делает кассу боевой по тому '
          'же признаку; без испытательного режима выключатель запёрся бы на '
          'первой перезагрузке',
    );
  });

  testWidgets(
    'выключение ОФД не чистит фискальные настройки — и говорит об этом',
    (tester) async {
      useFiscalHost(FiscalSettings(testMode: true));
      await mount(tester);
      await tapAndLetIoFinish(
        tester,
        const ValueKey('emulator-fiscalOperator-enable'),
      );
      await tapAndLetIoFinish(
        tester,
        const ValueKey('emulator-fiscalOperator-bind'),
      );
      final address = host.addressOf(BuiltinEmulatorKind.fiscalOperator)!;

      await tapAndLetIoFinish(
        tester,
        const ValueKey('emulator-fiscalOperator-enable'),
      );

      expect(host.isRunning(BuiltinEmulatorKind.fiscalOperator), isFalse);
      expect(
        FiscalSettingsStore(prefs).load().baseUrl,
        address.baseUrl,
        reason:
            'молчаливая правка чужой настройки завела бы второй источник правды '
            'о том, куда касса ходит',
      );
      expect(
        find.byKey(const ValueKey('emulator-fiscalOperator-stale')),
        findsOneWidget,
        reason:
            'касса осталась смотреть на погашенный сервер: фискализация откажет, '
            'и это обязано быть сказано, а не оставлено загадкой',
      );
    },
  );
}
