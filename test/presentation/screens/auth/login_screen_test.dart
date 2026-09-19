import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret_storage.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/auth/widgets/pin_keypad.dart';
import 'package:telepos/presentation/screens/auth/widgets/user_selector.dart';

import '../../../support/contrast.dart';
import '../../auth/support/fakes.dart';
import 'package:telepos/domain/shift/shift_status.dart';

/// Держит `LoginState` таким, каким его положит тест, — без единого
/// GetIt-договора: `initialize()`, которое `LoginScreen.initState` зовёт
/// безусловно, здесь ничего не делает, а не спрашивает `AuthRepository` и
/// соседей, которых в этих тестах не регистрировал никто.
///
/// Используется тремя тестами группы, которым нужен только зафиксированный
/// `LoginState` на экране, — не четвёртым («после успешного входа»): круг
/// правок 4 фазы 2 нашёл, что тот тест раньше воспроизводил поведение
/// настоящего `_onSession` этим же приёмом (`simulateSuccessfulLogin()`
/// сама писала `clearSessionEndedReason: true`) вместо того, чтобы его
/// проверять — убери `clearSessionEndedReason: true` из настоящего
/// `_onSession`, и тест остался бы зелёным. Тот тест ниже поднимает
/// настоящий `LoginNotifier` вместо этого класса.
class _FixedLoginNotifier extends LoginNotifier {
  _FixedLoginNotifier(this._initial);

  final LoginState _initial;

  @override
  LoginState build() => _initial;

  @override
  void initialize() {
    // Тест держит состояние сам — см. докстринг класса.
  }
}

void main() {
  group('LoginScreen — sessionEndedReason (круг правок 1, задача 5)', () {
    late SharedPreferences prefs;

    setUp(() async {
      // `getPostLoginRoute()` (позван из `ref.listen` в `LoginScreen.build`
      // на успешном входе) спрашивает `HostCapabilities.ownsData`;
      // `HostCapabilities.browser` даёт короткий путь без дальнейших
      // GetIt-договоров — прямиком на `AppRoutes.terminalHome`.
      GetIt.instance.registerSingleton<HostCapabilities>(
        HostCapabilities.browser,
      );
      // `LanguageSwitcher` в шапке `LoginScreen` тянет `localeProvider`, а
      // тот — `sharedPreferencesProvider`: без переопределения экран не
      // строится вовсе, ещё до того, как дело доходит до баннера.
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() => GetIt.instance.reset());

    Future<BuildContext> pumpLoginScreen(
      WidgetTester tester,
      LoginNotifier notifier,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginControllerProvider.overrideWith(() => notifier),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ru'), Locale('en')],
            locale: const Locale('ru'),
            routerConfig: GoRouter(
              initialLocation: AppRoutes.login,
              routes: [
                GoRoute(
                  path: AppRoutes.login,
                  builder: (context, state) => const LoginScreen(),
                ),
                // Плейсхолдер, а не настоящий дом терминала: этот тест
                // проверяет баннер причины, а не маршрут после входа —
                // ему достаточно знать, что экран входа остался позади.
                GoRoute(
                  path: AppRoutes.terminalHome,
                  builder: (context, state) =>
                      const Scaffold(body: Text('ЗА ЭКРАНОМ ВХОДА')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return tester.element(find.byType(LoginScreen));
    }

    testWidgets('причина есть — текст на экране есть', (tester) async {
      final notifier = _FixedLoginNotifier(
        const LoginState(sessionEndedReason: 'error.session_expired'),
      );
      final context = await pumpLoginScreen(tester, notifier);

      expect(
        find.text(AppLocalizations.of(context)!.errorSessionExpired),
        findsOneWidget,
        reason:
            'сеанс истёк по прямой улике (`expiresAt` в прошлом) — экран '
            'обязан назвать это словами, а не открыться пустой формой',
      );
    });

    testWidgets(
      'причина есть (сеанс отозван/выметен) — другой текст, но тоже виден',
      (tester) async {
        final notifier = _FixedLoginNotifier(
          const LoginState(sessionEndedReason: 'error.session_ended'),
        );
        final context = await pumpLoginScreen(tester, notifier);

        expect(
          find.text(AppLocalizations.of(context)!.errorSessionEnded),
          findsOneWidget,
        );
        // Разные ключи — разные слова: истёкший срок и погашенный кассой
        // сеанс не смешиваются в один текст только потому, что оба ведут на
        // этот же экран.
        expect(
          find.text(AppLocalizations.of(context)!.errorSessionExpired),
          findsNothing,
        );
      },
    );

    // Задача 47: значку смены нужно третье состояние. До входа смену никто
    // не спрашивал — ни касса (сеанса ещё нет), ни экран (локального чтения
    // смены нет ни на кассе, ни в браузере), — а значок красился «Смена
    // закрыта»: умолчание `false` читалось как измерение. Красный на
    // `9ac079a5`: `LoginState.isShiftOpened` по умолчанию `false`.
    testWidgets('до входа смена «неизвестно», а не «закрыта»', (tester) async {
      const user = UserItem(id: 4, name: 'Айгуль');
      final notifier = _FixedLoginNotifier(
        const LoginState(users: [user], selectedUser: user),
      );
      final context = await pumpLoginScreen(tester, notifier);
      final l10n = AppLocalizations.of(context)!;

      expect(
        find.text(l10n.loginShiftUnknown),
        findsOneWidget,
        reason: 'никто не спрашивал — значок обязан сказать «неизвестно»',
      );
      expect(
        find.text(l10n.loginShiftClosed),
        findsNothing,
        reason:
            '«закрыта» — утверждение о смене, которого никто не делал: '
            'умолчание не имеет права выглядеть как измерение',
      );
    });

    testWidgets('причины нет — текста нет', (tester) async {
      final notifier = _FixedLoginNotifier(const LoginState());
      final context = await pumpLoginScreen(tester, notifier);

      expect(
        find.text(AppLocalizations.of(context)!.errorSessionExpired),
        findsNothing,
      );
      expect(
        find.text(AppLocalizations.of(context)!.errorSessionEnded),
        findsNothing,
      );
    });

    testWidgets('после успешного входа — текста нет: экран уходит дальше сам '
        '(настоящий _onSession, не подделка)', (tester) async {
      // Круг правок 4 фазы 2: раньше здесь стоял
      // `_FixedLoginNotifier.simulateSuccessfulLogin()`, который сам писал
      // `clearSessionEndedReason: true` в состояние — воспроизводил
      // поведение `_onSession`, а не проверял его. Здесь — настоящий
      // `LoginNotifier` с настоящим `AuthRepository`/`TerminalIdentity`
      // через GetIt (`support/fakes.dart`, задача 7), и гашение баннера
      // доказывает настоящий `_onSession`, а не тест напрямую.
      final auth = FakeAuthRepository(
        AuthSession(
          token: 'tok-fresh',
          userId: 7,
          name: 'Айгуль',
          role: 'cashier',
          permissions: const {'nav.sale'},
          operatingMode: 0,
          pointMode: 'selfService',
          shift: ShiftStatus.closed,
          issuedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 30)),
          terminalId: 1,
        ),
      );
      // Пункт 2 фазы 3/4 закрытия долга: браузер больше не находит
      // terminalId в TerminalIdentity — каждая сессия обязана предъявить
      // себя кассе заново (_resolveTerminalId). С задачи 7 плана «знакомство
      // терминала с кассой» (разбор блокера) `register()` без кода привязки
      // всегда отказывает `pairing_code_invalid` — этому тесту код
      // спрашивать не о чем, поэтому терминал приходит тем же путём, каким
      // приходит настоящая вкладка, пережившая F5: секретом, предъявленным
      // через `resume()`.
      GetIt.instance
        ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
        ..registerSingleton<TerminalSecretStorage>(
          FakeTerminalSecretStorage()
            ..write(1, FakeTerminalRepository.fakeSecret),
        )
        ..registerSingleton<TerminalRepository>(
          FakeTerminalRepository(
            resume: (terminalId, secret) async => const Terminal(
              id: 1,
              name: 'Терминал у кассы',
              pointMode: PointMode.selfService,
            ),
          ),
        )
        ..registerSingleton<AuthRepository>(auth);

      final notifier = LoginNotifier();
      final context = await pumpLoginScreen(tester, notifier);

      // Предпосылка заведена настоящим путём отказа сеанса — `sessionLost()`,
      // тем же самым, каким его теперь зовёт экран настроек, поймавший
      // `SessionLost` (задача 1), а не положена в состояние напрямую.
      notifier.sessionLost(
        const SessionLost('test: сеанс неизвестен или истёк'),
      );
      await tester.pumpAndSettle();

      final expected = AppLocalizations.of(context)!.errorSessionEnded;
      expect(
        find.text(expected),
        findsOneWidget,
        reason: 'предпосылка теста — баннер сперва виден',
      );

      // Настоящий вход: единственный кассир от `watchUsers()` уже
      // автовыбран, PIN идёт через реальные `addDigit`/автопроверку на
      // шестой цифре — их разбирает настоящий `_verifyPin`, а он на
      // успехе зовёт настоящий `_onSession`.
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      // Проверка состояния напрямую, а не только отсутствия текста на
      // экране — до этой строки красноты не было вовсе (пере-ревью
      // финального разбора): успешный вход и без `clearSessionEndedReason`
      // уводит с экрана самой навигацией (`isAuthenticated` меняет
      // маршрут), и `find.text(expected)` находил бы «ничего» что с
      // гашением причины, что без него — экран пуст в обоих случаях,
      // потому что его уже нет на дереве. `notifier.state` читается
      // напрямую и не зависит от того, жив ли ещё `LoginScreen`.
      expect(
        notifier.state.sessionEndedReason,
        isNull,
        reason:
            'настоящий _onSession обязан погасить причину прежнего '
            'окончания сеанса на свежем действующем — красный без '
            '`clearSessionEndedReason: true` в _onSession',
      );

      await tester.pumpAndSettle();

      expect(
        find.text(expected),
        findsNothing,
        reason:
            'человек вошёл — продолжать держать «сеанс завершён» на экране '
            'значило бы врать о том, что происходит прямо сейчас',
      );
      expect(
        find.byType(LoginScreen),
        findsNothing,
        reason:
            'успешный вход уводит с этого экрана целиком, не только '
            'гасит баннер на месте',
      );
    });
  });

  // Задача 7 плана «знакомство терминала с кассой», разбор блокера: сторона
  // терминала — форма ввода кода привязки на этом же `/login`, замещающая
  // выбор кассира целиком, пока `LoginState.needsEnrolmentCode` истинно (см.
  // `_EnrolmentGate`, `login_screen.dart`). Здесь — то, чего не может
  // доказать `login_controller_test.dart`: что настоящий виджет действительно
  // рисует форму, поле реагирует на настоящий ввод, а кнопка «Привязать»
  // недоступна на пустом поле.
  group('LoginScreen — гейт кода привязки (задача 7, разбор блокера)', () {
    late SharedPreferences prefs;

    setUp(() async {
      GetIt.instance.registerSingleton<HostCapabilities>(
        HostCapabilities.browser,
      );
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() => GetIt.instance.reset());

    Future<void> pumpFixed(
      WidgetTester tester,
      LoginState state, {
      ThemeData? theme,
    }) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginControllerProvider.overrideWith(
              () => _FixedLoginNotifier(state),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme ?? AppTheme.light,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ru'), Locale('en')],
            locale: const Locale('ru'),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final (name, theme) in <(String, ThemeData)>[
      ('светлая', AppTheme.light),
      ('тёмная', AppTheme.dark),
    ]) {
      testWidgets(
        '$name: рамка поля кода привязки видна — контраст с поверхностью '
        'берёт порог 3:1 (WCAG 1.4.11 для границ элементов)',
        (tester) async {
          await pumpFixed(
            tester,
            const LoginState(needsEnrolmentCode: true),
            theme: theme,
          );

          final field = tester.widget<TextField>(
            find.byKey(const ValueKey('enrol-code-field')),
          );
          // Действующая рамка спокойного состояния: `InputDecorator` берёт
          // `enabledBorder`, а если его нет — общий `border`. Читать надо с
          // тем же запасным вариантом, иначе тест упал бы на разыменовании
          // `null` вместо того, чтобы измерить цвет, — то есть краснел бы не
          // по той причине, которую сторожит.
          final decoration = field.decoration!;
          final border =
              (decoration.enabledBorder ?? decoration.border!)
                  as OutlineInputBorder;
          final ratio = contrast(
            border.borderSide.color,
            theme.colorScheme.surface,
          );

          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason:
                'красный до правки: `border: const OutlineInputBorder()` без '
                'цвета выходил из темы — `AppTheme.inputDecorationTheme` '
                'нарочно ставит `InputBorder.none` всем границам, — и '
                '`BorderSide()` давал ЧЁРНУЮ линию по умолчанию: 21.0 на '
                'светлой (неуместно громко) и 1.5 на тёмной, то есть не видно '
                'вовсе. Волосяная линия темы порога тоже не берёт (1.26 и '
                '1.23) — она разделяет строки внутри секции, а не очерчивает '
                'единственное поле экрана-гейта. `primary` берёт обе: 3.31 и '
                '6.22. Найдено живой проверкой 2026-08-24, измерено 2026-08-27',
          );
        },
      );
    }

    testWidgets(
      'гейт замещает выбор кассира — поля выбора кассира и PIN-панели на '
      'экране нет вовсе',
      (tester) async {
        await pumpFixed(tester, const LoginState(needsEnrolmentCode: true));

        expect(
          find.byKey(const ValueKey('enrol-code-field')),
          findsOneWidget,
          reason: 'красный без правки: `_EnrolmentGate` не существовал, '
              'экран показал бы обычный выбор кассира',
        );
        expect(find.byType(PinKeypad), findsNothing);
        expect(find.byType(PinKeypadCompact), findsNothing);
      },
    );

    testWidgets(
      'причина «старое устройство без секрета» видна словами, а не общим '
      '«попробуйте ещё раз»',
      (tester) async {
        await pumpFixed(
          tester,
          const LoginState(
            needsEnrolmentCode: true,
            error: 'error.terminal_secret_invalid',
          ),
        );

        final context = tester.element(find.byType(LoginScreen));
        expect(
          find.text(AppLocalizations.of(context)!.errorTerminalSecretInvalid),
          findsOneWidget,
        );
        expect(
          find.text(AppLocalizations.of(context)!.errorAuthUnknown),
          findsNothing,
          reason: 'старое устройство без секрета не имеет права смешиваться '
              'с общим «касса не смогла ответить»',
        );
      },
    );

    testWidgets(
      'кнопка «Привязать» недоступна на пустом поле и включается после ввода',
      (tester) async {
        await pumpFixed(tester, const LoginState(needsEnrolmentCode: true));

        Widget findButton() =>
            tester.widget(find.byKey(const ValueKey('enrol-submit')));
        ElevatedButton button() => findButton() as ElevatedButton;

        expect(
          button().onPressed,
          isNull,
          reason: 'пустое поле — нечего отправлять',
        );

        await tester.enterText(
          find.byKey(const ValueKey('enrol-code-field')),
          'ABC123',
        );
        await tester.pump();

        expect(
          button().onPressed,
          isNotNull,
          reason: 'красный без правки: поле было не связано ни с чем, кнопка '
              'не реагировала на ввод',
        );
      },
    );
  });

  // Живая проверка задачи 7 (`code-format-and-live-report.md`, пункты 4 и
  // 5, 2026-08-24) нашла: причина гейта видна, но обрывается многоточием —
  // `InputDecoration.errorText` без `errorMaxLines` по умолчанию режет
  // мягкий перенос на первой строке (докстринг `errorMaxLines` во Flutter
  // SDK, `input_decorator.dart`). Действие («Enter a new pairing code» /
  // «Get a new code from the till operator») не попадало на экран вовсе.
  //
  // `find.text(...)` тут не годится сам по себе: `Text` хранит полную
  // строку независимо от того, обрезал ли её рендер — тест на одном лишь
  // `find.text` был бы зелёным и на сломанной реализации (см. тест «причина
  // видна словами» выше в этом файле). Доказательство — по факту рендера:
  // `RenderParagraph.didExceedMaxLines`, тот же приём, что в
  // `test/theme/app_text_styles_test.dart` (там — цвет из отрисованного
  // дерева, не из объявления стиля; здесь — то же самое для переноса строк).
  group(
    'LoginScreen — причина гейта не обрезается (найдено живой проверкой '
    '2026-08-24)',
    () {
      late SharedPreferences prefs;

      setUp(() async {
        GetIt.instance.registerSingleton<HostCapabilities>(
          HostCapabilities.browser,
        );
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      });

      tearDown(() => GetIt.instance.reset());

      Future<BuildContext> pumpFixedAtSize(
        WidgetTester tester,
        LoginState state,
        Size size,
        Locale locale,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loginControllerProvider.overrideWith(
                () => _FixedLoginNotifier(state),
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // Все пять языков кассы (l10n.yaml,
              // preferred-supported-locales), не только ru/en: длина строки —
              // это то самое, из-за чего резало, и самая длинная не обязана
              // быть на языке разработки.
              supportedLocales: const [
                Locale('ru'),
                Locale('en'),
                Locale('kk'),
                Locale('ky'),
                Locale('uz'),
              ],
              locale: locale,
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        return tester.element(find.byType(LoginScreen));
      }

      // 800×1024 — тот же «планшет», что в `TestBreakpoints.tablet`
      // (`test/golden/golden_test_helpers.dart`); 1280×800 — тот же
      // «широкий экран кассы» (`TestBreakpoints.desktop`), тем же приёмом
      // проверки на двух ширинах, которым в проекте уже сняты эталоны
      // (`wt_unavailable_look_test.dart`, `wizard_look_test.dart`).
      for (final width in const {
        'узкий (планшет, 800)': Size(800, 1024),
        'широкий (касса, 1280)': Size(1280, 800),
      }.entries) {
        for (final locale in const [
          Locale('ru'),
          Locale('en'),
          Locale('kk'),
          Locale('ky'),
          Locale('uz'),
        ]) {
          testWidgets(
            'старое устройство без секрета — причина целиком, '
            '${width.key}, ${locale.languageCode}',
            (tester) async {
              final context = await pumpFixedAtSize(
                tester,
                const LoginState(
                  needsEnrolmentCode: true,
                  error: 'error.terminal_secret_invalid',
                ),
                width.value,
                locale,
              );

              final text = AppLocalizations.of(
                context,
              )!.errorTerminalSecretInvalid;
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(text),
              );

              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason:
                    'красный без errorMaxLines: строка «$text» '
                    '(${locale.languageCode}) обрезается многоточием, '
                    'инструкция в её хвосте не попадает на экран',
              );
            },
          );

          testWidgets(
            'неверный код привязки — причина целиком, '
            '${width.key}, ${locale.languageCode}',
            (tester) async {
              final context = await pumpFixedAtSize(
                tester,
                const LoginState(
                  needsEnrolmentCode: true,
                  error: 'error.pairing_code_invalid',
                ),
                width.value,
                locale,
              );

              final text = AppLocalizations.of(
                context,
              )!.errorPairingCodeInvalid;
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(text),
              );

              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason:
                    'красный без errorMaxLines: строка «$text» '
                    '(${locale.languageCode}) обрезается многоточием, '
                    'инструкция в её хвосте не попадает на экран',
              );
            },
          );
        }
      }
    },
  );
}
