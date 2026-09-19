/// «Привязать» отвечает кассиру сразу — приёмка браузерного терминала
/// 2026-09-17.
///
/// Живьём: нажатие «Привязать» привязало терминал на кассе (он появился в
/// списке), а экран шестнадцать секунд не показывал ничего — ни ожидания,
/// ни ошибки; вход состоялся только после второго нажатия.
///
/// # Замер: экран в этом невиновен
///
/// Проба ниже **зелена на неизменном коде**. `_EnrolmentGateState._submit`
/// ставит `_submitting` до вызова кассы и снимает его в `finally`; кнопка
/// этим признаком запирается и показывает `CircularProgressIndicator`
/// внутри себя, а исход — снятый гейт при удаче, `errorText` под полем при
/// отказе — доходит сам. Снятие `_submitting` (диверсия) красит её двумя
/// утверждениями из двух.
///
/// То есть «ни ожидания, ни ошибки» шестнадцать секунд — **не свойство
/// экрана**. Названный подозреваемый: `rk_quic` 0.2.1, где ответ команды
/// доставался первому ждущему (коммит `71fd9aee`, подъём до 0.2.2 от
/// 2026-09-18 — то есть **после** приёмки 17-го). Ответ на
/// `terminals.register` при этом уходит не тому, кто его ждёт: касса
/// терминал завела, экран ответа не увидел и остался ждать, а второе
/// нажатие прошло уже другим путём. Это объяснение сходится со всеми тремя
/// наблюдениями приёмки, но на стенде 0.2.1 не перепроверялось — стенд
/// чужой процесс, и подменять под ним пакет эта работа не стала.
///
/// Проба оставлена **сторожем**: показ работы и запор кнопки живут в
/// `_EnrolmentGate` без единой проверки с той минуты, как их написали, и
/// снять их можно было бы, не покраснев нигде.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';

/// Касса, которая отвечает не сразу, — те самые шестнадцать секунд под
/// управлением пробы.
class _SlowEnrolLogin extends LoginNotifier {
  _SlowEnrolLogin(this._initial);

  final LoginState _initial;

  final gate = Completer<void>();

  int calls = 0;

  @override
  LoginState build() => _initial;

  @override
  void initialize() {
    // Состояние держит проба: настоящий `initialize()` спрашивает
    // `AuthRepository` и соседей, которых здесь никто не регистрировал.
  }

  @override
  void updateEnrolmentCode(String value) {
    state = state.copyWith(enrolmentCode: value, clearError: true);
  }

  @override
  Future<void> submitEnrolmentCode() async {
    calls++;
    await gate.future;
    state = state.copyWith(needsEnrolmentCode: false, enrolmentCode: '');
  }
}

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

  Future<_SlowEnrolLogin> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifier = _SlowEnrolLogin(
      const LoginState(needsEnrolmentCode: true, enrolmentCode: 'K7Q4M2'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginControllerProvider.overrideWith(() => notifier),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
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
    return notifier;
  }

  Finder submitButton() => find.byKey(const ValueKey('enrol-submit'));

  testWidgets('пока касса молчит, экран показывает работу', (tester) async {
    final notifier = await pumpGate(tester);

    expect(
      submitButton(),
      findsOneWidget,
      reason: 'контрольный случай: гейт привязки поднят',
    );
    expect(
      find.descendant(
        of: submitButton(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
      reason: 'контрольный случай: до нажатия работы нет',
    );

    await tester.tap(submitButton());
    await tester.pump();

    expect(notifier.calls, 1, reason: 'нажатие дошло до кассы');
    expect(
      find.descendant(
        of: submitButton(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
      reason:
          'НАЖАТИЕ «ПРИВЯЗАТЬ» НЕ ПОКАЗАЛО НИЧЕГО. Кассир шестнадцать секунд '
          'не знает, идёт ли работа, и жмёт второй раз — заводя второй '
          'терминал.',
    );
    expect(
      tester.widget<ElevatedButton>(submitButton()).onPressed,
      isNull,
      reason:
          'КНОПКА ОСТАЛАСЬ НАЖИМАЕМОЙ, пока касса отвечает: второе нажатие '
          'уходит вторым `register()`',
    );

    notifier.gate.complete();
    await tester.pumpAndSettle();

    expect(
      submitButton(),
      findsNothing,
      reason: 'удача снимает гейт — кассир идёт дальше',
    );
  });
}
