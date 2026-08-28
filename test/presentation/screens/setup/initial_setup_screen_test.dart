import '../../../support/settings_finders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_field_tile.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/this_pos_dao.dart';
import 'package:telepos/data/database/daos/user_dao.dart';
import 'package:telepos/data/database/daos/webkassa_receipt_dao.dart';
import 'package:telepos/presentation/controllers/setup/initial_setup_controller.dart';
import 'package:telepos/presentation/controllers/telegram/telegram_setup_controller.dart';
import 'package:telepos/presentation/screens/setup/initial_setup_screen.dart';

class TestTelegramSetupNotifier extends Notifier<TelegramSetupState>
    implements TelegramSetupNotifier {
  @override
  TelegramSetupState build() => const TelegramSetupState();

  @override
  Future<void> startInitialization() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) {
      return Future<void>.value();
    }
    return null;
  }
}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockThisPosDao extends Mock implements ThisPosDao {}

class MockUserDao extends Mock implements UserDao {}

class MockAccountDao extends Mock implements AccountDao {}

class MockWebkassaReceiptDao extends Mock implements WebkassaReceiptDao {}

void main() {
  late MockAppDatabase mockDb;
  late MockThisPosDao mockThisPosDao;
  late MockUserDao mockUserDao;
  late MockAccountDao mockAccountDao;
  late MockWebkassaReceiptDao mockWebkassaReceiptDao;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    mockDb = MockAppDatabase();
    mockThisPosDao = MockThisPosDao();
    mockUserDao = MockUserDao();
    mockAccountDao = MockAccountDao();
    mockWebkassaReceiptDao = MockWebkassaReceiptDao();

    when(() => mockDb.thisPosDao).thenReturn(mockThisPosDao);
    when(() => mockDb.userDao).thenReturn(mockUserDao);
    when(() => mockDb.accountDao).thenReturn(mockAccountDao);
    when(() => mockDb.webkassaReceiptDao).thenReturn(mockWebkassaReceiptDao);

    when(() => mockThisPosDao.exists()).thenAnswer((_) async => false);
    when(() => mockUserDao.hasUsers()).thenAnswer((_) async => false);

    final getIt = GetIt.instance;
    if (getIt.isRegistered<AppDatabase>()) {
      getIt.unregister<AppDatabase>();
    }
    getIt.registerSingleton<AppDatabase>(mockDb);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  Widget createTestWidget({InitialSetupState? initialState}) {
    return ProviderScope(
      overrides: [
        if (initialState != null)
          initialSetupControllerProvider.overrideWith(() {
            return TestInitialSetupNotifier(initialState);
          }),
        telegramSetupControllerProvider.overrideWith(
          () => TestTelegramSetupNotifier(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ru'), Locale('en')],
        locale: Locale('ru'),
        home: InitialSetupScreen(),
      ),
    );
  }

  group('InitialSetupScreen - Country Selection', () {
    testWidgets('shows country selection screen', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: const InitialSetupState(
            currentStep: InitialSetupStep.countrySelection,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Добро пожаловать в TelePOS!'), findsOneWidget);
      expect(
        find.text('Выберите вашу страну для настройки валюты и налогов'),
        findsOneWidget,
      );
    });

    testWidgets('shows all countries', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: const InitialSetupState(
            currentStep: InitialSetupStep.countrySelection,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      for (final country in CountryCode.values) {
        expect(find.text(country.countryName), findsOneWidget);
      }
    });

    testWidgets('шаг страны не отвечает на вопрос про НДС заранее', (
      tester,
    ) async {
      // Раньше ставка НДС стояла в подзаголовке каждой страны. Её убрали
      // намеренно: НДС спрашивают отдельным следующим шагом, и показывать
      // ответ до того, как задан вопрос, — значит предрешать его за человека.
      await tester.pumpWidget(
        createTestWidget(
          initialState: const InitialSetupState(
            currentStep: InitialSetupStep.countrySelection,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining('НДС'), findsNothing);
      // Валюта при этом остаётся: она и есть то, что выбор страны решает.
      expect(find.textContaining('KZT'), findsWidgets);
    });
  });

  group('InitialSetupScreen - Organization Setup', () {
    testWidgets('shows organization form', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.organizationSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Центрированного «Данные организации» здесь больше нет: заголовок шага
      // живёт в шапке мастера, а группа называет себя подписью слева. Оба
      // текста совпадают — «Организация», — поэтому их ровно два, и это не
      // дубль, а разные роли: шапка называет ШАГ, подпись называет ГРУППУ.
      expect(find.text('Данные организации'), findsNothing);
      expect(find.text('Организация'), findsNWidgets(2));

      // Звёздочка не вклеена в строку подписи: обязательность рисует сама
      // строка секции, поэтому подпись ищется целиком и без неё.
      expect(find.text('Название организации'), findsOneWidget);
      expect(find.text('БИН/ИИН'), findsOneWidget);
    });

    testWidgets('обязательные поля отмечены, необязательные — нет', (
      tester,
    ) async {
      // Название и налоговый номер решают, пустит ли шаг дальше; адреса —
      // нет. Без отметки человек упирается в погашенную кнопку «Далее» и не
      // понимает, чего от него хотят.
      await tester.pumpWidget(
        createTestWidget(
          initialState: const InitialSetupState(
            currentStep: InitialSetupStep.organizationSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      final required = tester
          .widgetList<SettingsFieldTile>(find.byType(SettingsFieldTile))
          .where((t) => t.required)
          .map((t) => t.label)
          .toSet();
      expect(required, {'Название организации', 'БИН/ИИН'});
    });

    testWidgets('shows tax ID label based on country', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.organizationSetup,
            selectedCountry: CountryCode.rub,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('ИНН'), findsOneWidget);
    });
  });

  group('InitialSetupScreen - VAT Selection', () {
    testWidgets('shows VAT selection screen', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.vatSelection,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Плаката «Налог на добавленную стоимость» нет: шаг назван в шапке
      // мастера и подписью группы — оба раза коротко, «НДС».
      expect(find.text('Налог на добавленную стоимость'), findsNothing);
      expect(find.text('НДС'), findsNWidgets(2));
      expect(find.text('Плательщик НДС'), findsOneWidget);
      expect(find.text('Без НДС'), findsOneWidget);
    });

    testWidgets('shows VAT rate for selected country', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.vatSelection,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining('Ставка НДС'), findsOneWidget);
    });
  });

  group('InitialSetupScreen - User Creation', () {
    testWidgets('шаг сотрудников — секции, а не карточки', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.employeeSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Карточек «АДМИНИСТРАТОР» и «ПРОДАВЕЦ» больше нет — есть секции с
      // подписями и переключатель второго пользователя. Плаката «Создание
      // пользователей» тоже нет: шаг назван в шапке — «Пользователи».
      expect(find.text('Создание пользователей'), findsNothing);
      expect(find.text('Пользователи'), findsOneWidget);
      expect(find.text('Кто будет работать'), findsOneWidget);
      expect(find.text('Вход по коду'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('кода по умолчанию у администратора нет', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.employeeSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Кода по умолчанию больше нет: код, который подставила касса и
      // который знает каждый, кто видел такую же кассу, — это отсутствие
      // кода, а не значение по умолчанию.
      expect(find.textContaining('0000'), findsNothing);
    });

    testWidgets('кода по умолчанию у продавца нет', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.employeeSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining('1111'), findsNothing);
    });

    testWidgets('PIN fields accept only digits', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.employeeSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      final pinField = settingsField('PIN').first;
      await tester.enterText(pinField, 'abc123def');
      await tester.pump();

      final textField = tester.widget<TextField>(pinField);
      expect(textField.inputFormatters, isNotNull);
      expect(
        textField.inputFormatters!.any((f) => f is FilteringTextInputFormatter),
        isTrue,
      );
    });

    testWidgets('PIN fields limit to 6 characters', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.employeeSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      final pinField = settingsField('PIN').first;
      final textField = tester.widget<TextField>(pinField);

      expect(
        textField.inputFormatters!.any(
          (f) => f is LengthLimitingTextInputFormatter,
        ),
        isTrue,
      );
    });

    testWidgets('admin user has PIN confirmation field', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.employeeSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Подтверждение'), findsOneWidget);
    });

    testWidgets('seller toggle switch controls visibility', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.employeeSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Пока переключатель выключен, полей продавца нет вовсе.
      final before = tester.widgetList(find.byType(TextField)).length;

      // Переключатель ниже сгиба: без прокрутки нажатие уходит в пустоту, и
      // тест «проходит» ровно потому, что ничего не нажал.
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Включённый — добавляет ровно два: имя и код.
      final after = tester.widgetList(find.byType(TextField)).length;
      expect(after, before + 2);
      expect(find.textContaining('1111'), findsNothing);
    });
  });

  group('InitialSetupScreen - Operating Mode Selection', () {
    testWidgets('shows operating mode (business type) selection screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: const InitialSetupState(
            currentStep: InitialSetupStep.operatingModeSelection,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Приглашения «Выберите тип вашего бизнеса» больше нет: оно повторяло
      // название шага, которое стоит в шапке и подписью группы.
      expect(find.text('Выберите тип вашего бизнеса'), findsNothing);
      expect(find.text('Тип бизнеса'), findsNWidgets(2));
      expect(find.text('Розничная касса'), findsOneWidget);
      expect(find.text('Ресторан / Кафе'), findsOneWidget);
    });
  });

  group('InitialSetupScreen - POS Setup', () {
    testWidgets('shows POS setup screen', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.posSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Плаката «Настройка кассы» нет: шаг назван в шапке и подписью первой
      // группы — оба раза «Касса».
      expect(find.text('Настройка кассы'), findsNothing);
      expect(find.text('Касса'), findsNWidgets(2));
      expect(find.text('Название кассы'), findsOneWidget);
      expect(find.text('ID кассы'), findsOneWidget);
    });

    testWidgets('shows paper width dropdown', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.posSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Ширина бумаги'), findsOneWidget);
    });
  });

  group('InitialSetupScreen - Summary', () {
    testWidgets('shows summary screen with all data', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.summary,
            selectedCountry: CountryCode.kzt,
            organization: const OrganizationInfo(
              companyName: 'Test Company',
              taxId: '123456789012',
              isVatPayer: true,
            ),
            posConfig: const PosConfigInfo(
              cashBoxName: 'Касса 1',
              posId: 'POS-1',
            ),
            firstUser: const EmployeeInfo(name: 'Иван Петров', pin: '0000'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Плаката «Проверьте данные» нет: итог — это список введённого, и
      // первое, что человек видит, должны быть сами значения, а не
      // приглашение их посмотреть. Шаг назван в шапке — «Проверка».
      expect(find.text('Проверьте данные'), findsNothing);
      expect(find.text('Проверка'), findsOneWidget);
      expect(find.text('Test Company'), findsOneWidget);
      expect(find.text('123456789012'), findsOneWidget);
      expect(find.text('Касса 1'), findsOneWidget);
      expect(find.text('Иван Петров'), findsOneWidget);
    });

    testWidgets('shows VAT status in summary', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.summary,
            selectedCountry: CountryCode.kzt,
            organization: const OrganizationInfo(
              companyName: 'Test',
              taxId: '123456789012',
              isVatPayer: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining('Плательщик НДС'), findsOneWidget);
    });

    testWidgets('shows second user in summary if set', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.summary,
            selectedCountry: CountryCode.kzt,
            firstUser: const EmployeeInfo(name: 'Admin', pin: '0000'),
            secondUser: const EmployeeInfo(name: 'Продавец', pin: '1111'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Секция итога подписана так же, как одноимённая секция шага.
      expect(find.text('Кто будет работать'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Продавец'), findsWidgets);
    });

    testWidgets('shows finish button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.summary,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Готово'), findsOneWidget);
    });
  });

  group('InitialSetupScreen - Progress Indicator', () {
    testWidgets('shows step number in progress', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.countrySelection,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Country used to be step 4, behind auth choice, register and verify.
      expect(find.textContaining('Шаг 1'), findsOneWidget);
    });

    testWidgets('progress indicator shows step title', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.vatSelection,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Два вхождения: название шага в шапке и подпись группы внутри шага.
      // Раньше их было три — третьим был центрированный плакат, — и именно
      // третий заказчик увидел на собранном вебе 2026-08-04.
      expect(find.text('НДС'), findsNWidgets(2));
    });
  });

  group('InitialSetupScreen - Back Navigation', () {
    testWidgets('shows back button on organization screen', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.organizationSetup,
            selectedCountry: CountryCode.kzt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('InitialSetupScreen - Error Display', () {
    testWidgets('shows error card when error is present', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialState: InitialSetupState(
            currentStep: InitialSetupStep.organizationSetup,
            selectedCountry: CountryCode.kzt,
            error: 'Test error message',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Test error message'), findsOneWidget);
    });
  });
}

class TestInitialSetupNotifier extends InitialSetupNotifier {
  TestInitialSetupNotifier(this._initialState);

  final InitialSetupState _initialState;

  @override
  InitialSetupState build() {
    return _initialState;
  }
}
