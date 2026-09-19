/// Ввод PIN на экране входа: клавиатура при поднятом гейте привязки и
/// честность индикатора точек.
///
/// Оба дефекта найдены живой приёмкой задачи 21 (2026-09-07) и оба
/// складывались в одну картину: кассир видел заполненный индикатор, жал
/// «Войти» и получал отказ за верный PIN, а сгоревшая попытка засчитывалась
/// настоящему кассиру.
///
/// # Почему проба подаёт события клавиш, а не зовёт `addDigit`
///
/// Дефект был **в маршруте события**, а не в буфере. `KeyboardListener`
/// обёрнут вокруг всего `Scaffold` (`login_screen.dart`, `autofocus: true`),
/// а поле ввода кода привязки — его потомок: цифру поле не съедает, и она
/// всплывает к предку, который дописывает её в PIN. Проба, зовущая
/// `notifier.addDigit(...)` напрямую, прошла бы мимо `_handleKeyEvent`
/// целиком и осталась бы зелёной при живом дефекте — то есть доказала бы
/// ровно ничего. Поэтому здесь `tester.sendKeyEvent`: событие идёт по
/// настоящему дереву фокуса, тем же путём, каким шло у заказчика.
///
/// # Как причина была изолирована живьём
///
/// Способ ввода держали постоянным и меняли **только состав кода
/// привязки**: код `FF7BV-APK6A` (две цифры) дал две точки, `CQFRJ-CCFNS`
/// (ни одной цифры) — ноль. Значит виноват не круг «набор → гейт →
/// возврат», а именно цифры кода. Код — Crockford base32
/// (`pairing_invites.dart`), поэтому число цифр в нём случайно, и дефект
/// воспроизводился «через раз».
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/auth/widgets/pin_display.dart';
import 'package:telepos/presentation/screens/auth/widgets/user_selector.dart';

/// Держит состояние таким, каким его положила проба, но **оставляет
/// настоящими все команды** — `addDigit` здесь тот самый, что в продукте.
/// Иначе проба про маршрут события проверяла бы двойник.
class _FixedLoginNotifier extends LoginNotifier {
  _FixedLoginNotifier(this._initial);

  final LoginState _initial;

  @override
  LoginState build() => _initial;

  @override
  void initialize() {
    // Состояние держит проба.
  }
}

const _cashier = UserItem(id: 7, name: 'Айгуль', role: 'Кассир');

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    GetIt.instance.registerSingleton<HostCapabilities>(
      HostCapabilities.browser,
    );
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => GetIt.instance.reset());

  Future<ProviderContainer> pump(
    WidgetTester tester,
    LoginState initial,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        loginControllerProvider.overrideWith(
          () => _FixedLoginNotifier(initial),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    return container;
  }

  /// Сколько точек закрашено — по цвету заливки, как их видит человек.
  /// `Colors.transparent` — пустая, любой другой цвет — закрашенная
  /// (`pin_display.dart`).
  ({int total, int filled}) dots(WidgetTester tester) {
    final containers = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: find.byType(PinDisplay),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .toList();
    var filled = 0;
    for (final c in containers) {
      final decoration = c.decoration! as BoxDecoration;
      if (decoration.color != Colors.transparent) filled++;
    }
    return (total: containers.length, filled: filled);
  }

  group('гейт привязки владеет клавиатурой', () {
    testWidgets('цифра при поднятом гейте НЕ попадает в буфер PIN', (
      tester,
    ) async {
      final container = await pump(
        tester,
        const LoginState(needsEnrolmentCode: true),
      );

      // Событие идёт по настоящему дереву фокуса — см. докстринг файла о
      // том, почему не `addDigit`.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      await tester.pump();

      expect(
        container.read(loginControllerProvider).enteredPin,
        isEmpty,
        reason:
            'клавиатура при поднятом гейте принадлежит полю кода привязки; '
            'цифра, дописанная в буфер PIN, уезжает на кассу как PIN и '
            'сжигает попытку настоящего кассира',
      );
    });

    testWidgets('весь набранный код привязки не оставляет ни одной точки', (
      tester,
    ) async {
      final container = await pump(
        tester,
        const LoginState(needsEnrolmentCode: true),
      );

      // Настоящий код с живого стенда — тот самый, что дал две точки до
      // починки. Набирается посимвольно, как его набирал человек.
      for (final key in const [
        LogicalKeyboardKey.keyF,
        LogicalKeyboardKey.keyF,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyV,
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.keyK,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.keyA,
      ]) {
        await tester.sendKeyEvent(key);
      }
      await tester.pump();

      expect(
        container.read(loginControllerProvider).enteredPin,
        isEmpty,
        reason: 'код FF7BV-APK6A содержит две цифры и давал две точки',
      );
    });

    testWidgets('без гейта цифра по-прежнему набирает PIN', (tester) async {
      // Обратная сторона: сторож обязан ловить утечку, а не глушить
      // клавиатуру вообще. Без этой пробы починка «return всегда» прошла бы
      // зелёной и отняла бы у кассиров физическую клавиатуру.
      final container = await pump(
        tester,
        const LoginState(users: [_cashier], selectedUser: _cashier),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      await tester.pump();

      expect(container.read(loginControllerProvider).enteredPin, '7');
    });
  });

  group('индикатор точек не насыщается', () {
    testWidgets('шесть введённых символов — шесть закрашенных точек', (
      tester,
    ) async {
      await pump(
        tester,
        const LoginState(
          users: [_cashier],
          selectedUser: _cashier,
          enteredPin: '123456',
        ),
      );

      final d = dots(tester);
      expect(
        d.total,
        LoginState.maxPinLength,
        reason:
            'мест ровно столько, сколько символов вмещает буфер '
            '(${LoginState.maxPinLength}); при четырёх местах четыре '
            'закрашенные точки означали бы «4, или 5, или 6»',
      );
      expect(
        d.filled,
        6,
        reason: 'кассир обязан видеть то, что уедет на кассу',
      );
    });

    testWidgets('пять символов — пять точек, а не четыре', (tester) async {
      await pump(
        tester,
        const LoginState(
          users: [_cashier],
          selectedUser: _cashier,
          enteredPin: '12345',
        ),
      );

      expect(dots(tester).filled, 5);
    });

    testWidgets('четыре символа — по-прежнему четыре', (tester) async {
      // Обычный случай не должен пострадать от расширения индикатора.
      await pump(
        tester,
        const LoginState(
          users: [_cashier],
          selectedUser: _cashier,
          enteredPin: '1234',
        ),
      );

      final d = dots(tester);
      expect(d.filled, 4);
      expect(d.total, LoginState.maxPinLength);
    });
  });
}
