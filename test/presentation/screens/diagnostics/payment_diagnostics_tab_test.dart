/// Вкладка «Оплата» отвечает на «берёт ли касса безналичные деньги», а не
/// только на «что сломалось».
///
/// # Что здесь проверяется и почему именно это
///
/// Три утверждения, каждое из которых легко сделать неверным незаметно:
///
/// 1. **Пустота названа словами.** Ненастроенный провайдер и настроенный, но
///    ещё ничего не проводивший, выглядят одинаково пустым списком — и это
///    противоположные ответы наладчику.
/// 2. **Граница знания кассы стоит на экране всегда.** Тел запросов касса не
///    хранит, журнал терминала теряется при перезапуске, операций, проведённых
///    с самого терминала, касса не видит вовсе. Без этих строк вкладка
///    читается как полный отчёт, которым она не является.
/// 3. **Пометка эмулятора зажигается по адресу провайдера**, а не по
///    выключателю встроенного эмулятора. Во всех пробах этого файла
///    встроенный эмулятор не поднят вовсе — плашка обязана появиться всё
///    равно, потому что адрес смотрит на петлю.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что деньги списаны и что провайдер вообще отвечал: здесь нет ни сокета, ни
/// банка. Разговор с живым собеседником проверяется там, где он живой, —
/// `builtin_qr_provider_test.dart` и `hardware_test.dart`.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/hardware/kaspi_pos/payment_terminal_journal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/payment_diagnostics_tab.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    PaymentTerminalJournal.shared.clear();
  });

  tearDown(() async {
    PaymentTerminalJournal.shared.clear();
    await db.close();
    await GetIt.I.reset();
  });

  void wire({
    String baseUrl = 'https://pay.example.kz',
    bool configured = true,
  }) {
    GetIt.I
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<QrProviderSetupRepository>(
        _StubSetup(baseUrl: baseUrl, configured: configured),
      );
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ru'),
        home: Scaffold(body: PaymentDiagnosticsTab()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<PaymentIntent> intent({
    required String key,
    required String amount,
    QrIntentStatus status = QrIntentStatus.pending,
    String? providerIntentId,
    String? refusalCode,
    String? refusalMessage,
  }) async {
    final (row, _) = await db.paymentIntentDao.claim(
      intentKey: key,
      providerCode: 'sbp_emul',
      amount: Decimal.parse(amount),
      createdAt: DateTime(2026, 9, 19, 12),
    );
    if (providerIntentId != null) {
      await db.paymentIntentDao.attachProviderIntent(
        id: row.id,
        providerIntentId: providerIntentId,
        status: status,
      );
    }
    await db.paymentIntentDao.applyState(
      id: row.id,
      status: status,
      refusalCode: refusalCode,
      refusalMessage: refusalMessage,
    );
    return (await db.paymentIntentDao.byId(row.id))!;
  }

  testWidgets('намерение видно суммой, ключом и ответом провайдера', (
    tester,
  ) async {
    await intent(
      key: 'qr-7001-1',
      amount: '1500.00',
      status: QrIntentStatus.paid,
      providerIntentId: 'SBP00000042',
    );
    wire();

    await mount(tester);

    expect(find.textContaining('qr-7001-1'), findsWidgets);
    // Разбор раскрывается нажатием: список — это «что было», разбор — «что
    // именно ушло и что ответили», и второе читают по одной строке, а не
    // все сразу.
    await tester.tap(find.textContaining('qr-7001-1').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('SBP00000042'),
      findsOneWidget,
      reason:
          'ид на той стороне — единственное, чем касса может сослаться на '
          'операцию в кабинете провайдера',
    );
  });

  testWidgets('причина отказа названа кодом и текстом, а не общим словом', (
    tester,
  ) async {
    await intent(
      key: 'qr-7002-1',
      amount: '300.00',
      status: QrIntentStatus.failed,
      refusalCode: 'qr_rejected',
      refusalMessage: 'сумма вне допустимого предела',
    );
    wire();

    await mount(tester);
    await tester.tap(find.textContaining('qr-7002-1').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('qr_rejected'), findsOneWidget);
    expect(find.textContaining('вне допустимого предела'), findsOneWidget);
  });

  testWidgets('обмен с терминалом виден кадром, ответом и кодом одобрения', (
    tester,
  ) async {
    PaymentTerminalJournal.shared.record(
      PaymentTerminalExchange(
        at: DateTime(2026, 9, 19, 12, 30),
        operation: PaymentTerminalOperation.purchase,
        request: '1000000045000000042',
        address: '192.168.1.77:8888',
        response: '0KP0000000001000001440043******1234',
        approved: true,
        approvalCode: '000001',
        transactionId: 'KP0000000001',
      ),
    );
    wire();

    await mount(tester);
    await tester.tap(find.textContaining('покупка'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1000000045000000042'), findsOneWidget);
    expect(find.textContaining('000001'), findsWidgets);
  });

  testWidgets('провайдер не настроен — сказано словами, а не пустым списком', (
    tester,
  ) async {
    wire(baseUrl: '', configured: false);

    await mount(tester);

    expect(find.textContaining('не настроен'), findsOneWidget);
  });

  testWidgets('чего касса не знает — названо под каждой половиной', (
    tester,
  ) async {
    wire();

    await mount(tester);

    expect(
      find.textContaining('Тела запросов к провайдеру касса не хранит'),
      findsOneWidget,
      reason:
          'без этой строки список читается как полный отчёт об обмене, каким '
          'он не является',
    );
    expect(
      find.textContaining('живёт в памяти'),
      findsOneWidget,
      reason:
          'пустой журнал терминала после перезапуска неотличим от «карт не '
          'принимали» — и это надо сказать, а не дать додумать',
    );
  });

  group('Пометка «за этим адресом эмулятор»', () {
    // Во всех трёх пробах встроенный эмулятор НЕ поднят: `BuiltinEmulatorHost`
    // здесь не регистрируется вовсе. Значит плашка не может зависеть от
    // выключателя — только от адреса, и это ровно то требование, ради
    // которого группа и заведена.
    testWidgets('петля по IPv4 — плашка есть', (tester) async {
      wire(baseUrl: 'http://127.0.0.1:8890');
      await mount(tester);
      expect(
        find.byKey(const ValueKey('payment-diagnostics-emulator-banner')),
        findsOneWidget,
      );
    });

    testWidgets('петля по имени — плашка есть', (tester) async {
      wire(baseUrl: 'http://localhost:8890');
      await mount(tester);
      expect(
        find.byKey(const ValueKey('payment-diagnostics-emulator-banner')),
        findsOneWidget,
        reason:
            '`localhost` пишут руками, и он ведёт в тот же процесс, что и '
            '127.0.0.1',
      );
    });

    testWidgets('петля по IPv6 — плашка есть', (tester) async {
      wire(baseUrl: 'http://[::1]:8890');
      await mount(tester);
      expect(
        find.byKey(const ValueKey('payment-diagnostics-emulator-banner')),
        findsOneWidget,
      );
    });

    testWidgets('настоящий провайдер — плашки нет', (tester) async {
      wire(baseUrl: 'https://pay.example.kz');
      await mount(tester);
      expect(
        find.byKey(const ValueKey('payment-diagnostics-emulator-banner')),
        findsNothing,
        reason:
            'плашка на боевой кассе — это ложная тревога, и она обесценивает '
            'настоящую',
      );
    });
  });
}

/// Настройка провайдера без базы: вкладке нужен только адрес и «настроен ли».
class _StubSetup implements QrProviderSetupRepository {
  _StubSetup({required this.baseUrl, required this.configured});

  final String baseUrl;
  final bool configured;

  @override
  Future<QrProviderView> read() async => QrProviderView(
    configured: configured,
    baseUrl: baseUrl,
    code: 'sbp_emul',
    keySet: false,
    patience: QrProviderSettings.defaultPatience,
    kindActive: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у настройки QR не поднят',
  );
}
