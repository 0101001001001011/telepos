import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/repositories/scanner_rules_repository_impl.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart';

/// Экран настройки видов оплаты рабочего места — задача 15, решение
/// заказчика №5.
///
/// **Чего этот набор не доказывает, и это сказано прямо:** он не доказывает,
/// что вид оплаты запрещён. Запрет держит касса, и доказан он там —
/// `test/backend/payment_types_test.dart`, где экрана нет вовсе. Здесь
/// проверяется только то, за что отвечает экран: что настройка **доезжает
/// до кассы** такой, какой её собрал оператор, и что снятое ограничение
/// действительно снимается, а не остаётся прежним запретом.
///
/// Ловушка, ради которой здесь три пробы, а не одна: пустой набор означает
/// «все виды». Значит «снять все галочки» и «разрешить всё» — это одно и то
/// же значение, и отличить намерения можно только переключателем секции.
class _RecordingTerminals implements TerminalRepository {
  _RecordingTerminals(this.terminalId, {this.allowed = const {}});

  final int terminalId;
  Set<PaymentType> allowed;
  final List<Set<PaymentType>> saved = [];

  @override
  Future<Terminal> self() async => Terminal(
    id: terminalId,
    name: 'Касса-1',
    pointMode: PointMode.cashier,
    allowedPaymentTypes: allowed,
  );

  @override
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async {
    saved.add(types);
    allowed = types;
  }

  // Остальное экран не зовёт — бросает, чтобы случайная новая зависимость
  // падала громко, а не возвращала правдоподобное.
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
  Future<void> delete(int terminalId) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late _RecordingTerminals terminals;

  Future<void> boot({Set<PaymentType> allowed = const {}}) async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final terminal = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    await db.thisPosDao.upsert(
      const ThisPosEntriesCompanion(companyName: Value('ТОО Тест')),
    );
    terminals = _RecordingTerminals(terminal.id, allowed: allowed);

    await GetIt.I.reset();
    GetIt.I.registerSingleton<DeviceProfileCatalog>(
      BuiltinDeviceProfileCatalog(),
    );
    GetIt.I.registerSingleton<DeviceBindingRepository>(
      LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog()),
    );
    GetIt.I.registerSingleton<TerminalRepository>(terminals);
    GetIt.I.registerSingleton<ScannerRulesRepository>(
      LocalScannerRulesRepository(db),
    );
  }

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Future<Widget> host() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: const HardwareSettingsScreen(),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(await host());
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byIcon(TeleposIcons.save));
    await tester.tap(find.byIcon(TeleposIcons.save));
    await tester.pumpAndSettle();
  }

  testWidgets('терминал без ограничений: галочек нет, нетронутая секция '
      'ничего не пишет', (tester) async {
    // Круг правки 3. Экран оборудования шлёт набор при **каждом**
    // сохранении, и до этой правки привязка принтера переписывала бы виды
    // оплаты заодно. Нетронутая секция обязана молчать.
    await boot();
    await open(tester);

    expect(find.byKey(const Key('payment_type_cash')), findsNothing);
    expect(
      find.text('Ограничений нет: рабочее место принимает все виды оплаты.'),
      findsOneWidget,
    );

    await save(tester);

    expect(terminals.saved, isEmpty);
  });

  testWidgets('набор с не-тендером: срезан на экране, но молча не записан', (
    tester,
  ) async {
    // Круг правки 2 научил экран срезать не-тендеры при чтении, чтобы
    // строку, написанную раньше запрета, можно было починить. Круг правки 3
    // нашёл на этом дыру: срезанное **уезжало на кассу само**, без ведома
    // оператора. Теперь срезание живёт только на экране — записывается оно
    // лишь тогда, когда оператор секцию тронул (проба ниже).
    await boot(allowed: const {PaymentType.card, PaymentType.debt});
    await open(tester);

    expect(find.byKey(const Key('payment_type_debt')), findsNothing);
    expect(find.byKey(const Key('payment_type_card')), findsOneWidget);

    await save(tester);

    expect(terminals.saved, isEmpty, reason: 'секцию не трогали');
  });

  testWidgets('набор из одних не-тендеров молча не снимает ограничение', (
    tester,
  ) async {
    // Круг правки 3, главный случай. `{debt}` срезается в **пустое**, а
    // пустое означает «все виды»: сохранение записало бы на кассу
    // отсутствие запрета. И записало бы его любое сохранение этого экрана —
    // привязка принтера в том числе, — а оператор видел бы просто
    // выключенный переключатель, и ничто не сказало бы ему, что запрет
    // отброшен.
    await boot(allowed: const {PaymentType.debt});
    await open(tester);

    await save(tester);

    expect(
      terminals.saved,
      isEmpty,
      reason: 'молчаливое снятие запрета — худший исход из возможных',
    );
  });

  testWidgets('про непонятную запись экран говорит вслух', (tester) async {
    // Молчать нельзя и в другую сторону: если бы экран просто не писал,
    // оператор видел бы «ограничений нет» на месте, где ограничение
    // записано, — и не узнал бы, что чинить.
    await boot(allowed: const {PaymentType.debt});
    await open(tester);

    expect(find.textContaining('которых эта версия не знает'), findsOneWidget);
    expect(find.textContaining('в долг'), findsOneWidget);
  });

  testWidgets('починка записывается, когда оператор её сделал', (tester) async {
    await boot(allowed: const {PaymentType.debt});
    await open(tester);

    await tapKey(tester, 'payment_types_limit_switch');
    await tapKey(tester, 'payment_type_cash');
    await save(tester);

    expect(terminals.saved, [
      {PaymentType.cash, PaymentType.card},
    ]);
  });

  testWidgets('галочки для смешанной нет — она форма, а не тендер', (
    tester,
  ) async {
    // **Восстановлено кругом 4.** Утверждение завёл круг 1, а круг 3 снёс
    // его вместе с соседней пробой — правкой по индексам, молча. Сторож
    // кассы (`setAllowedPaymentTypes` отвергает не-тендеры) вернувшуюся
    // галочку поймал бы, но **позже и хуже**: оператор увидел бы предложенный
    // ему вид оплаты, который отказывается сохраняться. Здесь дешевле.
    await boot();
    await open(tester);
    await tapKey(tester, 'payment_types_limit_switch');

    expect(find.byKey(const Key('payment_type_mixed')), findsNothing);
    expect(find.byKey(const Key('payment_type_debt')), findsNothing);
    for (final tender in tenderPaymentTypes) {
      expect(
        find.byKey(Key('payment_type_${tender.name}')),
        findsOneWidget,
        reason: tender.name,
      );
    }
  });

  testWidgets('починив запись, оператор видит, что починил', (tester) async {
    // Круг правки 4. `_paymentTypesUnknown` считался один раз при загрузке и
    // после успешного сохранения не пересчитывался: оператор делал ровно то,
    // что велит красный текст, набор уезжал на кассу верным — а экран
    // продолжал утверждать, что запись сломана и «остаётся как есть».
    //
    // Тот же род вреда, ради которого секция и заговорила: круг 3 закрыл
    // «оператор не знает, что чинить» и открыл «оператор не знает, что
    // починил».
    await boot(allowed: const {PaymentType.debt});
    await open(tester);
    expect(find.textContaining('которых эта версия не знает'), findsOneWidget);

    await tapKey(tester, 'payment_types_limit_switch');
    await tapKey(tester, 'payment_type_cash');
    await save(tester);

    expect(terminals.saved, [
      {PaymentType.cash, PaymentType.card},
    ]);
    expect(
      find.textContaining('которых эта версия не знает'),
      findsNothing,
      reason: 'запись починена — предупреждению больше нечего сообщать',
    );
  });

  testWidgets('оператор ограничивает рабочее место безналом', (tester) async {
    await boot();
    await open(tester);

    await tapKey(tester, 'payment_types_limit_switch');
    // Умолчание при включении — карта: тот самый случай, ради которого
    // решение принималось («планшет в зале — только безнал»). Пустой набор
    // предложить нельзя: он означает «все виды».
    expect(find.byKey(const Key('payment_type_card')), findsOneWidget);

    await save(tester);

    expect(terminals.saved, [
      {PaymentType.card},
    ]);
  });

  testWidgets('добавленный вид доезжает до кассы вместе с прежним', (
    tester,
  ) async {
    await boot(allowed: const {PaymentType.card});
    await open(tester);

    await tapKey(tester, 'payment_type_cash');
    await save(tester);

    expect(terminals.saved, [
      {PaymentType.cash, PaymentType.card},
    ]);
  });

  testWidgets(
    'снятое ограничение действительно снимается, а не остаётся прежним '
    'запретом',
    (tester) async {
      // Ловушка «пустое значит все» с другой стороны: если бы экран при
      // выключенном переключателе слал текущие галочки, оператор, снявший
      // ограничение, оставил бы рабочее место с тем же запретом — и увидел
      // бы зелёный снекбар.
      await boot(allowed: const {PaymentType.card});
      await open(tester);

      await tapKey(tester, 'payment_types_limit_switch');
      await save(tester);

      expect(terminals.saved, [<PaymentType>{}]);
    },
  );

  testWidgets('последнюю галочку снять нельзя — пустого набора через '
      'галочки не бывает', (tester) async {
    await boot(allowed: const {PaymentType.card});
    await open(tester);

    await tapKey(tester, 'payment_type_card');
    await save(tester);

    expect(
      terminals.saved,
      [
        {PaymentType.card},
      ],
      reason:
          'снятие последней галочки означало бы «разрешить всё» — прямо '
          'обратное тому, что делает оператор',
    );
  });
}
