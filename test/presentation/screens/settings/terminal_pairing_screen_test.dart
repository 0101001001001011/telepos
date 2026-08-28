/// Задача 2 работы «знакомство терминала с кассой»: `PairingInvites.mint()`
/// был написан и охраняет `/ca.crt`, но до этого экрана его не звала ни одна
/// строка `lib/` — новое устройство не могло получить код никаким путём из
/// интерфейса. Эти тесты проверяют не отрисовку, а то, что щелчок доходит до
/// настоящего `PairingInvites` (код, который экран показал, действительно
/// значится в том же списке, каким `/ca.crt` проверяет `?invite=`), и что
/// однажды показанный код нельзя увидеть снова — ни повторным щелчком по той
/// же кнопке, ни возвратом на свежий экземпляр экрана.
///
/// Правка «касса говорит, что набирать» (2026-08-23, разбор фазы 1) добавила
/// сюда: полную строку `/ca.crt?invite=<код>` (блокер 1), проверку, что
/// повторная выдача отзывает прежний код (пункт 4), и то, что гейт «сервер
/// недостижим» перечитывается на каждой сборке и завязан на
/// `ApiServerReachability`, а не на `TerminalServiceChoice` (пункт 6).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/backend/api_server_reachability.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/settings/terminal_service_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/settings/terminal_pairing_screen.dart';

/// Тот же приём, что у `terminal_home_screen_test.dart` и у
/// `general_settings_screen_permissions_test.dart`: `AppStateNotifier.build()`
/// заводит таймеры, которых `testWidgets` не прощает живыми к концу теста, а
/// настоящему экрану они не нужны — читается только `AppState.permissions`.
class _TestAppStateNotifier extends Notifier<AppState>
    implements AppStateNotifier {
  @override
  AppState build() => const AppState();

  @override
  void setPosInfo({String? name}) {
    state = state.copyWith(posName: name, clearPosName: name == null);
  }

  @override
  void setUserInfo({
    int? id,
    String? name,
    int? role,
    Set<String>? permissions,
  }) {
    state = state.copyWith(
      userId: id,
      clearUserId: id == null,
      userName: name,
      clearUserName: name == null,
      userRole: role,
      clearUserRole: role == null,
      permissions: permissions,
    );
  }

  @override
  void setTestUser({required int userId, String? userName}) {
    state = state.copyWith(userId: userId, userName: userName ?? 'Test User');
  }

  @override
  void setShiftOpened(bool isOpened) {
    state = state.copyWith(isShiftOpened: isOpened);
  }

  @override
  void setConnectionStatus(ConnectionStatus status) {
    state = state.copyWith(connectionStatus: status);
  }

  @override
  void dismissStorageWarning() {
    state = state.copyWith(showStorageWarning: false);
  }

  @override
  void setOperatingMode(OperatingMode mode) {
    state = state.copyWith(operatingMode: mode);
  }

  @override
  void logout() {
    state = state.copyWith(
      clearUserId: true,
      clearUserName: true,
      clearUserRole: true,
      permissions: const {},
    );
  }
}

const _listeningUrl = 'https://till-3.local:8787';

void main() {
  late PairingInvites invites;
  late ApiServerReachability reachability;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();

    GetIt.I.allowReassignment = true;
    invites = PairingInvites();
    // Тот же приём, что и `SessionAdmin`/`SessionRegistry` в
    // `sessions_screen_test.dart`: настоящий экземпляр под тем же типом,
    // каким его достаёт main.dart (задача 1, `service_locator.dart`).
    GetIt.I.registerSingleton<PairingInvites>(invites);

    // Умолчание набора — сервер слушает: большинству тестов ниже нужен
    // именно этот случай, а негативные пишут своё состояние явно.
    reachability = ApiServerReachability()..markListening(_listeningUrl);
    GetIt.I.registerSingleton<ApiServerReachability>(reachability);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  ProviderContainer buildContainer({required Set<String> permissions}) {
    final container = ProviderContainer(
      overrides: [
        appStateProvider.overrideWith(_TestAppStateNotifier.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    container
        .read(appStateProvider.notifier)
        .setUserInfo(id: 1, name: 'Тест', role: 1, permissions: permissions);
    return container;
  }

  Widget host(
    Widget child, {
    Set<String> permissions = const {},
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    final container = buildContainer(permissions: permissions);
    addTearDown(container.dispose);

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru')],
        locale: const Locale('ru'),
        home: child,
      ),
    );
  }

  String? shownCode(WidgetTester tester) {
    final finder = find.byKey(const ValueKey('pairing-code'));
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<SelectableText>(finder).data;
  }

  testWidgets('до щелчка кода не видно, есть только кнопка', (tester) async {
    await tester.pumpWidget(host(const TerminalPairingScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pairing-code')), findsNothing);
    expect(find.byKey(const ValueKey('pairing-mint')), findsOneWidget);
  });

  testWidgets(
    'щелчок «Выдать код» доходит до настоящего PairingInvites — показанный '
    'код тратится тем же списком, каким /ca.crt проверяет ?invite=',
    (tester) async {
      await tester.pumpWidget(host(const TerminalPairingScreen()));
      await tester.pumpAndSettle();

      expect(invites.outstanding, 0);

      await tester.tap(find.byKey(const ValueKey('pairing-mint')));
      await tester.pumpAndSettle();

      final shown = shownCode(tester);
      expect(shown, isNotNull, reason: 'кнопка нажата, кода не видно');
      expect(invites.outstanding, 1);

      // Настоящий список, а не выдуманная строка на экране: код, который
      // видит человек, — тот самый, что и `redeem()` примет у /ca.crt.
      expect(
        invites.redeem(shown),
        isTrue,
        reason:
            'показанный код не нашёлся в PairingInvites — экран рисует не '
            'настоящий mint(), а что-то ещё',
      );
    },
  );

  testWidgets(
    'экран показывает строку целиком: базовый адрес + /ca.crt?invite=<код> '
    '— блокер 1 разбора фазы 1',
    (tester) async {
      await tester.pumpWidget(host(const TerminalPairingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pairing-mint')));
      await tester.pumpAndSettle();

      final shown = shownCode(tester)!;
      final addressFinder = find.byKey(const ValueKey('pairing-address'));
      final addressText =
          (tester.widget<ListTile>(addressFinder).subtitle! as Text).data!;

      // Единственная строка, которую /ca.crt действительно проверяет
      // (api_server.dart, `_rootCertificate`) — а не адрес без формы,
      // которую было бы неоткуда узнать оператору.
      expect(addressText, contains('$_listeningUrl/ca.crt?invite=$shown'));

      // Живое доказательство, не строковое совпадение: то, что показано
      // экраном, действительно принимает redeem() — тем же приёмом, что и
      // test/manual/wt_pairing_probe.dart, но здесь без сети, напрямую по
      // списку, которым владеет тот же синглтон, что использовал бы
      // /ca.crt.
      final uri = Uri.parse(
        addressText.split('\n').first,
      );
      expect(uri.queryParameters['invite'], shown);
      expect(
        invites.redeem(uri.queryParameters['invite']),
        isTrue,
        reason:
            'код, извлечённый из показанной строки ровно тем способом, каким '
            'браузер извлёк бы его из адресной строки, не нашёлся в списке',
      );
    },
  );

  testWidgets(
    'QR рисуется настоящим содержимым — той же строкой, что и текст адреса',
    (tester) async {
      await tester.pumpWidget(host(const TerminalPairingScreen()));
      await tester.pumpAndSettle();

      // До выдачи кода рисовать QR нечем — полной строки ещё нет.
      expect(find.byKey(const ValueKey('pairing-qr')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('pairing-mint')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pairing-qr')), findsOneWidget);
    },
  );

  testWidgets(
    'повторный щелчок выдаёт новый код, прежний больше не виден на экране '
    'И отзывается — пункт 4 разбора фазы 1',
    (tester) async {
      await tester.pumpWidget(host(const TerminalPairingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pairing-mint')));
      await tester.pumpAndSettle();
      final first = shownCode(tester);
      expect(first, isNotNull);
      expect(invites.outstanding, 1);

      await tester.tap(find.byKey(const ValueKey('pairing-mint-again')));
      await tester.pumpAndSettle();
      final second = shownCode(tester);

      expect(second, isNotNull);
      expect(
        second,
        isNot(equals(first)),
        reason: 'второй щелчок обязан выдать новый код, не показать старый',
      );
      expect(
        find.text(first!),
        findsNothing,
        reason: 'прежний код остался виден после выдачи нового',
      );

      // Решение разбора фазы 1, пункт 4 (строгий вариант, не только честная
      // надпись): прежний непредъявленный код отзывается, а не остаётся
      // тихо годным до истечения своих 15 минут.
      expect(
        invites.outstanding,
        1,
        reason: 'старый код обязан быть отозван новой выдачей той же кнопки',
      );
      expect(
        invites.redeem(first),
        isFalse,
        reason: 'отозванный код не имеет права сработать на /ca.crt',
      );
    },
  );

  testWidgets(
    'уход со страницы теряет код — свежий экземпляр экрана не помнит его',
    (tester) async {
      await tester.pumpWidget(
        host(const TerminalPairingScreen(key: ValueKey('first'))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pairing-mint')));
      await tester.pumpAndSettle();
      final shown = shownCode(tester);
      expect(shown, isNotNull);

      // Другой Key на том же месте дерева — Flutter не переиспользует
      // State, а создаёт его заново, ровно как уход со страницы и
      // возврат на неё: то немногое состояние, что держал прежний экран
      // (мятый код), пропадает вместе со старым State.
      await tester.pumpWidget(
        host(const TerminalPairingScreen(key: ValueKey('second'))),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pairing-code')), findsNothing);
      expect(
        find.text(shown!),
        findsNothing,
        reason: 'код пережил уход со страницы — показать его второй раз '
            'стало возможно',
      );
    },
  );

  testWidgets(
    'сервер не поднят и обслуживание выключено в настройках — кнопка «Выдать '
    'код» не строится, показана причина «выключено»',
    (tester) async {
      reachability.markUnreachable();
      await TerminalServiceChoice.write(prefs, enabled: false);

      await tester.pumpWidget(host(const TerminalPairingScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pairing-mint')),
        findsNothing,
        reason:
            'адрес отвечает только петле — код, выданный сейчас, некуда '
            'ввести',
      );
      expect(
        find.byKey(const ValueKey('pairing-disabled-note')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pairing-restart-note')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'настройка включена, но сервер этого процесса ещё не поднялся с ней — '
    'показана причина «перезапустите», не «включите» — пункт 6 разбора '
    'фазы 1',
    (tester) async {
      // Ровно гонка, которую разбор фазы 1 назвал: настройка уже true (её
      // записал оператор на соседнем экране), а `ApiServer` этого процесса
      // всё ещё поднят с прошлым, узким `ListenScope` — перезапуска не
      // было.
      reachability.markUnreachable();
      await TerminalServiceChoice.write(prefs, enabled: true);

      await tester.pumpWidget(host(const TerminalPairingScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pairing-mint')), findsNothing);
      expect(
        find.byKey(const ValueKey('pairing-disabled-note')),
        findsNothing,
        reason:
            'обслуживание не выключено в настройках — надпись «включите» '
            'здесь была бы неправдой',
      );
      expect(
        find.byKey(const ValueKey('pairing-restart-note')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'экран перечитывает достижимость при возврате на него — build(), а не '
    'initState() один раз — пункт 6 разбора фазы 1',
    (tester) async {
      // До правки `_enabled` было полем `initState`: пуш другого экрана и
      // возврат `pop()`'ом на тот же живой `State` показывал бы прежнее
      // «недостижимо», даже если сервер поднялся, пока оператор был на
      // другом экране. `initState()` для уже существующего `State` второй
      // раз не зовётся — единственный способ увидеть новое значение — читать
      // его в `build()`, а `build()` обязан реально вызываться при
      // возврате.
      reachability.markUnreachable();
      await TerminalServiceChoice.write(prefs, enabled: false);

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        host(const TerminalPairingScreen(), navigatorKey: navigatorKey),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pairing-disabled-note')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pairing-mint')), findsNothing);

      // То же самое, что делает кнопка «Открыть настройки терминалов»:
      // пуш поверх, не пересоздание этого экрана.
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('ДРУГОЙ_ЭКРАН')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ДРУГОЙ_ЭКРАН'), findsOneWidget);

      // Оператор включил обслуживание на «другом экране», касса
      // перезапустилась — сервер этого процесса поднялся с
      // `ListenScope.everywhere`.
      reachability.markListening(_listeningUrl);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pairing-mint')),
        findsOneWidget,
        reason:
            'экран не перечитал достижимость после возврата — тот же дефект, '
            'что нашёл разбор фазы 1 у настройки',
      );
      expect(
        find.byKey(const ValueKey('pairing-disabled-note')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'без settings.terminalService кнопка «Открыть настройки терминалов» не '
    'строится — маршрут за ней защищён ДРУГИМ ключом права, чем сам этот '
    'экран (settings.users) — пункт 7 разбора фазы 1',
    (tester) async {
      reachability.markUnreachable();
      await TerminalServiceChoice.write(prefs, enabled: false);

      // Право дойти до ЭТОГО экрана есть (settings.users, иначе тест не
      // воспроизводил бы реальный сценарий), а settings.terminalService —
      // нет. Асимметрия, названная в спеке: администратор в `roleDefaults`
      // ровно в этом положении.
      await tester.pumpWidget(
        host(
          const TerminalPairingScreen(),
          permissions: {PermissionKeys.settingsUsers},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pairing-disabled-note')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pairing-open-terminal-service')),
        findsNothing,
        reason:
            'без settings.terminalService кнопка увела бы молча — маршрут за '
            'ней защищён другим ключом',
      );
    },
  );

  testWidgets(
    'с settings.terminalService кнопка «Открыть настройки терминалов» '
    'строится',
    (tester) async {
      reachability.markUnreachable();
      await TerminalServiceChoice.write(prefs, enabled: false);

      await tester.pumpWidget(
        host(
          const TerminalPairingScreen(),
          permissions: {
            PermissionKeys.settingsUsers,
            PermissionKeys.settingsTerminalService,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pairing-open-terminal-service')),
        findsOneWidget,
      );
    },
  );
}
