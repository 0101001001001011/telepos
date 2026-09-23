/// **Проверка выгоды нового транспорта на самом экране.**
///
/// Провод умеет говорить первым — это доказано в
/// `test/web/wt_till_speaks_first_test.dart` на репозиториях. Здесь доказывается
/// звено, которого там нет и без которого выгоды не существует: **изменение на
/// кассе доходит до нарисованного виджета**. Кассир видит не поток, а экран.
///
/// Источник изменения настоящий: своя база drift, настоящий
/// `LocalStartupStateRepository`, настоящий `watchTables` поверх
/// `AppDatabase.tableUpdates`. Подставлено ровно одно — обёртка, считающая
/// обращения к договору, и она же в одном тесте вырождает подписку в один
/// ответ. Это и есть измеритель чувствительности: тест, который не краснеет от
/// такой подмены, доказывает не подписку, а «вопрос в одежде подписки».
///
/// # Почему пампится вручную, а не `pumpAndSettle`
///
/// На `checking` и в шапке мастера крутятся индикаторы, и `pumpAndSettle` до
/// них не сходится вовсе. Измерено дороже: `Stream.first` завершается по
/// завершению будущего ОТМЕНЫ, а отмена подписки drift под `pumpAndSettle` не
/// завершается — экран получал значение и оставался со спиннером навсегда
/// (`lib/data/database/watch_source.dart`).
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/startup/startup_state_repository_local.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/startup/startup_state_provider.dart';
import 'package:telepos/presentation/screens/setup/initial_setup_screen.dart';
import 'package:telepos/presentation/screens/setup/steps/country_step.dart';
import 'package:telepos/presentation/screens/setup/steps/unreadable_step.dart';

/// Договор кассы, у которого первый ответ не удался, а дальше всё в порядке.
///
/// Ровно тот отказ, ради которого заведён [UnreadableStep]: касса не ответила.
/// Он воспроизводится обёрткой, а не поломкой базы, потому что база должна
/// остаться настоящей — иначе второе значение приходило бы не от кассы.
///
/// [watchCalls] считает обращения к договору. Это и есть мера «спросил ли
/// экран»: подписка стоит одного обращения, опрос — каждого.
class _FlakyFirstAnswer implements StartupStateRepository {
  _FlakyFirstAnswer(this._inner);

  final StartupStateRepository _inner;

  int watchCalls = 0;

  @override
  Stream<SetupState> watch() {
    watchCalls++;
    var first = true;
    return _inner.watch().map((state) {
      if (first) {
        first = false;
        throw StateError('касса не ответила');
      }
      return state;
    });
  }
}

/// Подписка, выродившаяся в один ответ.
///
/// Обёртка над [_FlakyFirstAnswer]: первый ответ — какой бы он ни был, значение
/// или отказ, — и на этом поток закрывается. Так ведёт себя `watch().first` и
/// любой другой способ снять подписку сразу после первого ответа.
///
/// `take(1)` здесь не годится: он пропускает отказы, не считая их, и дождался бы
/// первого **значения** — то есть остался бы живой подпиской ещё на один шаг.
class _OneAnswerThenSilence implements StartupStateRepository {
  _OneAnswerThenSilence(this._inner);

  final _FlakyFirstAnswer _inner;

  int get watchCalls => _inner.watchCalls;

  @override
  Stream<SetupState> watch() {
    final out = StreamController<SetupState>();
    late final StreamSubscription<SetupState> source;
    void stop() {
      unawaited(source.cancel());
      if (!out.isClosed) out.close();
    }

    source = _inner.watch().listen(
      (state) {
        out.add(state);
        stop();
      },
      onError: (Object error, StackTrace stack) {
        out.addError(error, stack);
        stop();
      },
      onDone: stop,
    );
    out.onCancel = source.cancel;
    return out.stream;
  }
}

/// Касса, которая не отвечает совсем, пока её не спросят второй раз.
///
/// Первая подписка отказывает и закрывается — сказать второе ей нечем. Ровно
/// то состояние, из которого выводит единственная кнопка [UnreadableStep], и
/// ровно то, в котором простое перечитывание не помогло бы: у мёртвого потока
/// спрашивать нечего.
class _DeadUntilAskedAgain implements StartupStateRepository {
  _DeadUntilAskedAgain(this._inner);

  final StartupStateRepository _inner;

  int watchCalls = 0;

  @override
  Stream<SetupState> watch() {
    watchCalls++;
    if (watchCalls == 1) {
      return Stream<SetupState>.error(StateError('касса не ответила'));
    }
    return _inner.watch();
  }
}

/// Договор, который считает свои живые подписки.
///
/// Поток не заканчивается сам никогда — как и настоящие: `watchTables` на
/// кассе и `WtDispatcher.watch` в браузере живут, пока их слушают. Поэтому
/// [live] падает до нуля только от отмены, и ничего другого его обнулить не
/// может.
class _CancelWatcher implements StartupStateRepository {
  int live = 0;

  @override
  Stream<SetupState> watch() {
    late final StreamController<SetupState> out;
    out = StreamController<SetupState>(
      onListen: () {
        live++;
        out.add(const SetupState(configured: false, hasUsers: false));
      },
      onCancel: () => live--,
    );
    return out.stream;
  }
}

Widget _terminal(SharedPreferences prefs) {
  // Маршрутов два, потому что мастер сам уходит на вход, когда касса
  // оказывается настроенной. Настоящий экран входа сюда не ставится: он тянет
  // весь граф зависимостей кассы, а проверяется здесь не он, а то, что
  // нарисованное поменялось само.
  final router = GoRouter(
    initialLocation: AppRoutes.initialSetup,
    routes: [
      GoRoute(
        path: AppRoutes.initialSetup,
        builder: (_, __) => const InitialSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('ЭКРАН ВХОДА'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

/// Даёт отработать проверке (300 мс своей задержки), сигналу `tableUpdates`,
/// чтению базы и перестройке дерева.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _addCashier(AppDatabase db) => db
    .into(db.users)
    .insert(
      UsersCompanion.insert(
        id: const Value(1),
        name: const Value('Кассир'),
        status: const Value('active'),
      ),
    );

Future<void> _configureTill(AppDatabase db) =>
    db.thisPosDao.insertInitialConfig(
      companyName: 'ТОО Ромашка',
      iinbin: null,
      cashBoxName: 'Касса-1',
      countryCode: 0,
      currencyCode: null,
      currencySymbol: null,
      currencyNameShort: null,
      paperWidth: null,
      printerHeader: null,
      printerFooter: null,
      accountId: null,
      acquiringAccountId: null,
      rsaPublicKey: null,
    );

AppDatabase _register(StartupStateRepository Function(AppDatabase) build) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  GetIt.I.registerSingleton<AppDatabase>(db);
  GetIt.I.registerSingleton<StartupStateRepository>(build(db));
  return db;
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  testWidgets(
    'касса заговорила — нарисованный мастер перерисовался, ни о чём не спросив',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late _FlakyFirstAnswer till;
      final db = _register((db) {
        till = _FlakyFirstAnswer(LocalStartupStateRepository(db));
        return till;
      });
      addTearDown(db.close);

      await tester.pumpWidget(_terminal(prefs));
      await _settle(tester);

      // Касса не ответила — и это тупик: единственная кнопка здесь повторяет
      // проверку, то есть спрашивает заново. До подписки выйти отсюда можно
      // было только вопросом.
      expect(
        find.byType(UnreadableStep),
        findsOneWidget,
        reason:
            'первый ответ не удался — мастер обязан сказать это, а не '
            'предложить настройку поверх работающего магазина',
      );
      final asked = till.watchCalls;
      expect(asked, 1, reason: 'подписка стоит ровно одного обращения');

      // ИЗМЕНЕНИЕ НА КАССЕ. Экрана в этот момент никто не касается: ни
      // нажатия, ни повторной проверки, ни перезахода на маршрут.
      await _addCashier(db);
      await _settle(tester);

      expect(
        find.byType(CountryStep),
        findsOneWidget,
        reason:
            'ради этого и менялся транспорт: касса заговорила первой, и '
            'экран вышел из тупика сам',
      );
      expect(find.byType(UnreadableStep), findsNothing);
      expect(
        till.watchCalls,
        asked,
        reason:
            'ни одного нового обращения к договору — иначе это опрос, а '
            'не подписка',
      );
    },
  );

  testWidgets(
    'настроенная касса уводит мастер с экрана настройки без вопроса',
    (tester) async {
      // Второй, дорогой исход того же изменения: пока мастер предлагает
      // настройку, магазин может оказаться настроенным с другого терминала.
      // Мастер, не узнавший об этом, предлагает настроить существующий
      // магазин — тот самый вред, ради которого заведён `unreadable`.
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late _FlakyFirstAnswer till;
      final db = _register((db) {
        till = _FlakyFirstAnswer(LocalStartupStateRepository(db));
        return till;
      });
      addTearDown(db.close);

      await tester.pumpWidget(_terminal(prefs));
      await _settle(tester);
      await _addCashier(db);
      await _settle(tester);

      expect(find.byType(CountryStep), findsOneWidget);
      final asked = till.watchCalls;

      // ИЗМЕНЕНИЕ НА КАССЕ: магазин настроен.
      await _configureTill(db);
      await _settle(tester);

      expect(
        find.text('ЭКРАН ВХОДА'),
        findsOneWidget,
        reason: 'настроенная касса обязана увести с мастера сама',
      );
      expect(find.byType(CountryStep), findsNothing);
      expect(till.watchCalls, asked);
    },
  );

  testWidgets(
    '«Повторить» заводит подписку заново, а не перечитывает мёртвую',
    (tester) async {
      // Единственная кнопка тупикового экрана обязана из него выводить. Если бы
      // повтор только перечитывал текущее значение провайдера, он крутил бы
      // индикатор над потоком, который уже закончился, — и кнопка выглядела бы
      // работающей, ничего не меняя.
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late _DeadUntilAskedAgain till;
      final db = _register((db) {
        till = _DeadUntilAskedAgain(LocalStartupStateRepository(db));
        return till;
      });
      addTearDown(db.close);

      await tester.pumpWidget(_terminal(prefs));
      await _settle(tester);

      expect(find.byType(UnreadableStep), findsOneWidget);
      expect(till.watchCalls, 1);

      await tester.tap(find.text('Повторить'));
      await _settle(tester);

      expect(
        till.watchCalls,
        2,
        reason:
            'повтор обязан завести НОВУЮ подписку: у оборвавшейся спрашивать '
            'нечего',
      );
      expect(find.byType(CountryStep), findsOneWidget);
    },
  );

  test('ушёл последний слушатель — подписка снята', () async {
    // Вторая половина требования, и без неё первая — утечка. Провайдер здесь
    // единственное место, где живёт подписка: у экрана своей нет, поэтому
    // накопиться по одной на переход они не могут. Остаётся доказать, что
    // последний ушедший слушатель её закрывает.
    //
    // Дальше снятие доводит сам провод: `WtDispatcher.watch` закрывает свой
    // поток на отмене, а касса узнаёт об ушедшем подписчике по отказу записи
    // (`test/web/wt_till_speaks_first_test.dart`). Здесь проверяется звено
    // между экраном и проводом.
    final till = _CancelWatcher();
    GetIt.I.registerSingleton<StartupStateRepository>(till);

    final container = ProviderContainer();
    final subscription = container.listen<AsyncValue<SetupState>>(
      startupStateProvider,
      (_, __) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(till.live, 1, reason: 'подписка завелась');

    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(
      till.live,
      0,
      reason: 'касса не обязана читать свою базу ради вкладки, которую закрыли',
    );
    container.dispose();
  });

  testWidgets(
    'ИЗМЕРИТЕЛЬ: подписка, выродившаяся в один ответ, оставляет экран в тупике',
    (tester) async {
      // Этот тест утверждает НЕПРАВИЛЬНОЕ поведение намеренно, и в этом его
      // смысл. Он держит чувствительность двух тестов выше: если живая
      // подписка снова станет `watch().first` — одним значением и закрытым
      // потоком, — те два обязаны покраснеть. Тест, который этого не замечает,
      // доказывает не подписку, а вопрос в её одежде.
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late _OneAnswerThenSilence till;
      final db = _register((db) {
        till = _OneAnswerThenSilence(
          _FlakyFirstAnswer(LocalStartupStateRepository(db)),
        );
        return till;
      });
      addTearDown(db.close);

      await tester.pumpWidget(_terminal(prefs));
      await _settle(tester);

      expect(find.byType(UnreadableStep), findsOneWidget);

      await _addCashier(db);
      await _settle(tester);

      expect(
        find.byType(UnreadableStep),
        findsOneWidget,
        reason:
            'поток закрылся после первого ответа — сказать второе нечем, '
            'и экран остаётся тупиком до вопроса со своей стороны',
      );
      expect(till.watchCalls, 1);
    },
  );
}
