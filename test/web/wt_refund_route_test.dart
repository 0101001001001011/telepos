/// Возврат с браузерного терминала — задача 20 плана «Продажа с браузерного
/// терминала».
///
/// # Что здесь проверяется и почему именно это
///
/// Набросок задачи предлагал одну пробу — «маршрут есть в таблице и не ведёт
/// в заглушку». Её мало, и мало измеримо: маршрут можно объявить, а под ним
/// оставить экран, который в браузере не работает; реализацию контракта можно
/// написать на три метода из шести и не заметить, потому что компилятор
/// потребует остальные три, а вот **позвать** их по проводу не потребует
/// никто.
///
/// Поэтому проб пять родов:
///
/// 1. **маршрут** — и текстом (таблица), и живьём (экран строится, а не
///    заглушка);
/// 2. **весь контракт на проводе** — каждая из шести операций `RefundOps`
///    действительно уезжает кадром со своим именем, и множество покрытых
///    сверяется с `RefundOps.all`: заведут седьмую — проба покраснеет, а не
///    промолчит;
/// 3. **отказ доезжает названным** — кода `invalid_amount` от кассы хватает,
///    чтобы экран сказал, что именно не так. Возврат — место, где отказ по
///    праву обычен (количество больше проданного, чек уже возвращён, смена
///    закрыта), и «что-то пошло не так» здесь означает «терминал не умеет
///    показать половину своей работы»;
/// 4. **деньги едут строкой** (И159) — проверяется на **отправленном кадре**,
///    а не на форме кода. Сторож `test/architecture/money_over_wire_test.dart`
///    обходит только `lib/domain/wire/` и до `lib/web/` не достаёт (находка
///    задачи 20, см. `docs/internal/superpowers/reports/2026-09-06-browser-terminal-sale/
///    task-20-report.md`);
/// 5. **`abandon` по проводу не ходит** — у неё нет операции, и молчаливое
///    «ничего не делаем» здесь опаснее отказа: это метод, которым касса
///    забывает чужой черновик при смене человека за местом.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_async/fake_async.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/router/setup_router.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble, CompletionTroubleKind;
import 'package:telepos/domain/wire/pay_ops.dart' show troublesToWireJson;
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/boot_stage.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/refund_codec.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/wire_frame.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/presentation/screens/auth/login_screen.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';
import 'package:telepos/presentation/screens/terminal/terminal_home_screen.dart';
import 'package:telepos/web/wt_dispatcher.dart';
import 'package:telepos/web/wt_not_ported_screen.dart';
import 'package:telepos/web/wt_refund_service.dart';

import '../presentation/auth/support/fakes.dart';
import 'support/fake_dispatcher.dart';

// ── общее ────────────────────────────────────────────────────────────────

final _meta = CartCommandMeta(key: 'k1', baseVersion: 0, receiptNo: null);

RefundView _view({int version = 1, List<RefundLine> lines = const []}) =>
    RefundView(
      posId: 1,
      terminalId: 7,
      version: version,
      draftNo: 1,
      lines: lines,
    );

RefundLine _line() => RefundLine(
  id: '11',
  productId: 42,
  name: 'Молоко',
  quantity: Decimal.one,
  price: Decimal.parse('450.5'),
  maxQuantity: Decimal.fromInt(3),
);

String _ok(Map<String, Object?> body) => OkFrame(body).encode();

String _update(Map<String, Object?> body) => UpdateFrame(body).encode();

String _refused(String code, String detail) =>
    ErrorFrame(code, detail).encode();

/// Служба поверх сценария кадров. Возвращает и её, и запись отправленного.
({WtRefundService service, ScriptedStreams wire}) _serviceAnswering(
  String frame,
) {
  final wire = ScriptedStreams([frame]);
  return (service: WtRefundService(WtDispatcher(wire)), wire: wire);
}

/// Имя операции последнего ушедшего кадра.
///
/// Проверка «кадр вообще ушёл» стоит здесь, а не в вызывающем: метод,
/// который вернул снимок, не позвав кассу, иначе покрасил бы пробу
/// исключением `Bad state: No element` — красным без объяснения. Найдено
/// диверсией задачи 20 (снятие `setLine` с провода).
String _sentOp(ScriptedStreams wire) {
  expect(
    wire.sent,
    hasLength(1),
    reason: 'команда не ушла на кассу вовсе — метод ответил сам себе',
  );
  return (WireFrame.decode(wire.sent.single) as RequestFrame).op;
}

/// Тело последнего ушедшего кадра.
Map<String, Object?> _sentBody(ScriptedStreams wire) =>
    (WireFrame.decode(wire.sent.single) as RequestFrame).body;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    // Контроллер возврата пишет в общий журнал дерева (`app_talker`) — это
    // `late`-поле точки входа, и без установки любой такой путь падает
    // `LateInitializationError` вместо предупреждения.
    app_log.installLogger(Talker());
    _registerTerminalScope();
  });

  tearDown(() async => GetIt.I.reset());

  group('маршрут возврата в браузерной таблице', () {
    test('таблица объявляет AppRoutes.refund', () {
      // Текстовая половина: дешёвая, краснеет раньше всего и не требует
      // ни DI, ни дерева виджетов.
      final table = File(
        'lib/app/router/setup_router.dart'.replaceAll(
          '/',
          Platform.pathSeparator,
        ),
      ).readAsStringSync();

      expect(
        table,
        contains('AppRoutes.refund'),
        reason:
            'без записи в браузерной таблице /refund отвечает errorBuilder, '
            'то есть WtNotPortedScreen',
      );
    });

    testWidgets('/refund строит настоящий экран, а не заглушку', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(_prefs, router));
      await _settle(tester);

      _logIn(tester, permissions: {PermissionKeys.navRefund});

      router.go(AppRoutes.refund);
      await _settle(tester);

      expect(
        find.byType(WtNotPortedScreen),
        findsNothing,
        reason:
            'заглушка на /refund значит, что возврат с планшета так и не '
            'переехал — маршрут объявлен, а экрана под ним нет',
      );
      expect(find.byType(RefundScreen), findsOneWidget);
    });

    testWidgets('дом терминала даёт кнопку на возврат', (tester) async {
      // Маршрут, до которого нельзя дойти нажатием, — это работа, которой
      // для кассира нет. Ровно тот же дефект уже стоил круга на `/sessions`:
      // операции отзыва сеанса были заведены, обработчик готов, а вызвать
      // их из браузера было нечем — нашла это живая проверка.
      //
      // Сторож `browser_routes_test` этого не ловит и не может: он смотрит,
      // что каждый **переход** ведёт на объявленный маршрут, и молчит про
      // маршрут, на который не ведёт ни один переход.
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(_prefs, router));
      await _settle(tester);

      _logIn(tester, permissions: {PermissionKeys.navRefund});
      router.go(AppRoutes.terminalHome);
      await _settle(tester);

      final tile = find.text('Возврат');
      expect(
        tile,
        findsOneWidget,
        reason: 'кассир обязан открыть возврат нажатием, а не набором адреса',
      );

      await tester.tap(tile);
      await _settle(tester);

      expect(find.byType(RefundScreen), findsOneWidget);
    });

    testWidgets('без права nav.refund кнопки возврата нет', (tester) async {
      // Право показом, а не запретом нажатия — тем же приёмом, что у плиток
      // оборудования и сеансов. Границу всё равно держит и `redirect`
      // таблицы (проба ниже): скрытая кнопка правом не является.
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(_prefs, router));
      await _settle(tester);

      _logIn(tester, permissions: const {});
      router.go(AppRoutes.terminalHome);
      await _settle(tester);

      expect(find.text('Возврат'), findsNothing);
    });

    testWidgets('истёкший сеанс уводит с возврата на вход', (tester) async {
      // БЛОКЕР круга правки. Перевод `unknown_terminal` в `SessionLost`
      // (проба ниже) кончается на границе службы, а выше его **некому
      // поймать**: `RefundNotifier._enqueue` ловил всё голым `catch` и
      // превращал в `error.save_failed:${safeErrorText(e)}`, а тот для
      // не-`SqliteException` отдаёт **имя типа**. Кассир видел «Ошибка
      // сохранения: SessionLost» и оставался на экране возврата — тупик, из
      // которого выход только закрытием вкладки. Ровно то, что чинилось.
      //
      // Проверяется **последствием**, а не границей службы: вкладка обязана
      // оказаться на входе. Имя пробы догоняет механизм — тем же приёмом,
      // каким это уже сделала база этой ветви (`8c91171`).
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await GetIt.I.unregister<RefundService>();
      GetIt.I.registerSingleton<RefundService>(_SessionLostRefunds());

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
      );
      final router = createSetupRouter(refresh: SetupRouterRefresh(container));
      await tester.pumpWidget(_terminalWith(container, router));
      await _settle(tester);

      _logIn(tester, permissions: {PermissionKeys.navRefund});
      router.go(AppRoutes.refund);
      await _settle(tester);
      expect(
        find.byType(RefundScreen),
        findsOneWidget,
        reason: 'подготовка: экран открылся',
      );

      // Любая команда — «загрузить чек» ближе всего к первому нажатию
      // кассира.
      await container
          .read(refundControllerProvider.notifier)
          .loadReceipt(12345, 1);
      await _settle(tester);

      expect(
        find.byType(LoginScreen),
        findsOneWidget,
        reason:
            'истёкший сеанс лечится входом заново — вкладка обязана уйти на '
            'вход сама, а не показать «Ошибка сохранения: SessionLost» и '
            'остаться на экране, где ничего больше не работает',
      );
      expect(
        find.textContaining('SessionLost'),
        findsNothing,
        reason: 'имя типа исключения кассиру не показывают',
      );

      // Контейнер разбирается **внутри теста**, а не в `addTearDown`:
      // отложенные дела нотифайеров (проверка PIN у входа, подписки
      // возврата) снимаются их же `ref.onDispose`, и снять их надо до того,
      // как `flutter_test` посчитает висящий таймер дефектом теста.
      container.dispose();
      await tester.pump();
    });

    testWidgets('отказ подписки на черновик тоже уводит на вход', (
      tester,
    ) async {
      // Второй путь того же блокера, и он **не был покрыт ничем**: подмостки
      // отдавали исправный поток, а отказ бросали только команды. Разбор
      // круга снял ветку `if (e is SessionLost)` из `_listenToDraft` — набор
      // остался зелёным (`+894`).
      //
      // Путь не теоретический: право `op.refund` сторож кассы проверяет на
      // **открытии потока**, и истёкший сеанс приезжает сюда раньше, чем
      // кассир успеет нажать хоть что-нибудь.
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await GetIt.I.unregister<RefundService>();
      GetIt.I.registerSingleton<RefundService>(
        _SessionLostRefunds(watchFails: true),
      );

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
      );
      final router = createSetupRouter(refresh: SetupRouterRefresh(container));
      await tester.pumpWidget(_terminalWith(container, router));
      await _settle(tester);

      _logIn(tester, permissions: {PermissionKeys.navRefund});
      router.go(AppRoutes.refund);
      await _settle(tester);

      expect(
        find.byType(LoginScreen),
        findsOneWidget,
        reason:
            'подписка отказала истёкшим сеансом — экрану возврата нечего '
            'показывать, и оставлять на нём кассира не за чем',
      );

      container.dispose();
      await tester.pump();
    });

    testWidgets('вернувшись на возврат после входа, кассир видит живой '
        'черновик, а не вчерашний', (tester) async {
      // Измеренный тупик, найденный разбором круга правки: провайдер
      // возврата не `autoDispose`, никем не `invalidate` и живёт всю вкладку,
      // а `_listenToDraft()` звался ровно один раз из `build()`. После
      // «отказ → вход → возврат» подписка оставалась мёртвой **навсегда** —
      // экран показывал снимок, снятый до отказа, и не узнавал ни об
      // изменениях с кассы, ни о второй вкладке. Лечилось только F5.
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final refunds = _SessionLostRefunds(watchFails: true);
      await GetIt.I.unregister<RefundService>();
      GetIt.I.registerSingleton<RefundService>(refunds);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
      );
      final router = createSetupRouter(refresh: SetupRouterRefresh(container));
      await tester.pumpWidget(_terminalWith(container, router));
      await _settle(tester);

      _logIn(tester, permissions: {PermissionKeys.navRefund});
      router.go(AppRoutes.refund);
      await _settle(tester);

      expect(
        find.byType(LoginScreen),
        findsOneWidget,
        reason: 'подготовка: отказ подписки увёл на вход',
      );
      final afterFirst = refunds.watchCount;
      expect(afterFirst, greaterThanOrEqualTo(1));

      // Кассир вошёл заново и вернулся на возврат. Сеанс теперь живой.
      refunds.watchFails = false;
      _logIn(tester, permissions: {PermissionKeys.navRefund});
      router.go(AppRoutes.refund);
      await _settle(tester);

      expect(
        find.byType(RefundScreen),
        findsOneWidget,
        reason: 'с живым сеансом экран обязан открыться',
      );
      expect(
        refunds.watchCount,
        greaterThan(afterFirst),
        reason:
            'подписка на черновик обязана подняться заново — иначе экран '
            'показывает снимок до отказа и не узнаёт ни об одном изменении',
      );
      expect(
        container.read(refundControllerProvider).sessionLost,
        isNull,
        reason:
            'снять поле было нечем: copyWith писал `sessionLost ?? this'
            '.sessionLost`, а clear() зовётся только после успешного возврата',
      );

      container.dispose();
      await tester.pump();
    });

    testWidgets('экран возврата в браузере стоит в Scaffold', (tester) async {
      // У браузерной таблицы нет оболочки: `AdaptiveScaffold`, который на
      // кассе даёт экрану шапку, отступы и — главное — уклонение от
      // экранной клавиатуры, сюда не входит. Экран, построенный голым,
      // на планшете теряет сумму к возврату под клавиатурой при вводе
      // номера чека и не даёт кассиру пути назад: браузерная вкладка
      // открывается сразу на `/refund` по адресу, и стека переходов у неё
      // нет.
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(_prefs, router));
      await _settle(tester);

      _logIn(tester, permissions: {PermissionKeys.navRefund});
      router.go(AppRoutes.refund);
      await _settle(tester);

      final shell = find.ancestor(
        of: find.byType(RefundScreen),
        matching: find.byType(Scaffold),
      );
      expect(
        shell,
        findsWidgets,
        reason:
            'без Scaffold экранная клавиатура накрывает итог, а выйти с '
            'экрана нечем',
      );
      expect(
        tester.widget<Scaffold>(shell.first).resizeToAvoidBottomInset,
        isNot(false),
        reason: 'уклонение от клавиатуры выключать здесь нечем',
      );
    });

    testWidgets('без права nav.refund на /refund не пускает', (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = createSetupRouter();
      await tester.pumpWidget(_terminal(_prefs, router));
      await _settle(tester);

      _logIn(tester, permissions: const {});

      router.go(AppRoutes.refund);
      await _settle(tester);

      expect(
        find.byType(RefundScreen),
        findsNothing,
        reason: 'право проверяет таблица, а не спрятанная плитка',
      );
      expect(find.byType(TerminalHomeScreen), findsOneWidget);
    });
  });

  group('WtRefundService закрывает весь контракт', () {
    test('каждая операция RefundOps уезжает своим именем', () async {
      final covered = <String>{};

      final view = _serviceAnswering(_update(refundViewToWireJson(_view())));
      await view.service.watch(7).first;
      covered.add(_sentOp(view.wire));

      final load = _serviceAnswering(_ok(refundViewToWireJson(_view())));
      await load.service.loadReceipt(7, 12345, 1, _meta);
      covered.add(_sentOp(load.wire));

      final start = _serviceAnswering(_ok(refundViewToWireJson(_view())));
      await start.service.startWithoutReceipt(7, _meta);
      covered.add(_sentOp(start.wire));

      final add = _serviceAnswering(_ok(refundViewToWireJson(_view())));
      await add.service.addProduct(7, 42, Decimal.one, _meta);
      covered.add(_sentOp(add.wire));

      final setLine = _serviceAnswering(_ok(refundViewToWireJson(_view())));
      await setLine.service.setLineQuantity(7, '11', Decimal.one, _meta);
      covered.add(_sentOp(setLine.wire));

      final done = _serviceAnswering(
        _ok(
          refundOutcomeToWireJson(
            RefundOutcome(
              refundLocalId: 3,
              amount: Decimal.parse('450.5'),
              lineCount: 1,
              paymentCount: 1,
            ),
          ),
        ),
      );
      await done.service.complete(7, _meta);
      covered.add(_sentOp(done.wire));

      // Беды ящика после возврата — приёмка 2026-09-17. Ответ проверяется
      // разбором, а не только именем: пустой список был бы законным ответом
      // «ничего не сломалось», и потерянная беда от него неотличима.
      const trouble = CompletionTrouble(
        kind: CompletionTroubleKind.drawer,
        receiptNo: 3,
        message: 'денежный ящик не открылся',
      );
      final troubles = _serviceAnswering(_ok(troublesToWireJson([trouble])));
      expect(await troubles.service.hardwareTroubles(7, 3), [trouble]);
      covered.add(_sentOp(troubles.wire));

      expect(
        covered,
        RefundOps.all.map((op) => op.name).toSet(),
        reason:
            'браузерная реализация обязана звать КАЖДУЮ операцию каталога. '
            'Метод, который компилятор потребовал, но никто не подключил к '
            'проводу, — это кнопка, которая на планшете ничего не делает; '
            'заведённая седьмая операция без своего метода — то же самое '
            'с другой стороны.',
      );
    });

    test('ответ разбирается в снимок, а не в пустоту', () async {
      final wire = _serviceAnswering(
        _ok(refundViewToWireJson(_view(version: 4, lines: [_line()]))),
      );

      final answer = await wire.service.loadReceipt(7, 12345, 1, _meta);

      expect(answer.version, 4);
      expect(answer.lines.single.name, 'Молоко');
      expect(answer.total, Decimal.parse('450.5'));
    });

    test('abandon по проводу не ходит и отказывает названно', () async {
      // Своей операции у неё нет (докстринг `RefundOps`): черновик забывает
      // касса на входе. Молчаливый no-op здесь означал бы, что защита от
      // «сел другой человек» существует только на кассе и никто об этом не
      // узнает.
      final wire = _serviceAnswering(_ok(const {}));

      await expectLater(wire.service.abandon(7), throwsA(isA<WireRefusal>()));
      expect(
        wire.wire.sent,
        isEmpty,
        reason: 'операции refund.abandon в каталоге нет — звать нечего',
      );
    });
  });

  group('отказ кассы доезжает до экрана названным', () {
    test(
      'код и текст кассы становятся WireRefusal, а не общей ошибкой',
      () async {
        final wire = _serviceAnswering(
          _refused(
            refundInvalidAmountCode,
            'в чеке продано 2, вернуть просят 5',
          ),
        );

        await expectLater(
          wire.service.setLineQuantity(7, '11', Decimal.fromInt(5), _meta),
          throwsA(
            isA<WireRefusal>()
                .having((e) => e.code, 'code', refundInvalidAmountCode)
                .having(
                  (e) => e.message,
                  'message',
                  contains('вернуть просят 5'),
                ),
          ),
        );
      },
    );

    test('отказ подписки тоже приходит WireRefusal', () async {
      // Экран без права `op.refund` обязан не подписаться вовсе — отказ
      // сторожа приходит на открытии потока, и он тоже обязан быть назван.
      final wire = _serviceAnswering(
        _refused('forbidden', 'нет права op.refund'),
      );

      await expectLater(
        wire.service.watch(7).first,
        throwsA(isA<WireRefusal>().having((e) => e.code, 'code', 'forbidden')),
      );
    });

    test('служба переводит unknown_terminal в SessionLost', () async {
      // `unknown_terminal` — отказ, который вкладка **сама не чинит**: место
      // называет кассе `terminals.resume`, а его зовёт только вход. Пока этот
      // код приезжал рядовым отказом провода, вкладка оставалась «вошедшей»,
      // каждая команда возврата отказывала, входа никто не предлагал — тупик,
      // из которого кассир выбирается закрытием вкладки.
      //
      // Тот же вывод и то же лечение, что у `terminal_changed` (круг правки 4
      // задачи 19): войти заново. Здесь перевод стоит в возврате, а не в
      // `wt_dispatcher._errorFor`, и это осознанная граница: `_errorFor` не
      // знает имени операции, а `WtAuthRepository.login` **опирается** на то,
      // что `unknown_terminal` доедет до него `WtProtocolError` — из него он
      // делает `UnknownTerminalException`, по которой вход заводит терминал
      // заново. Перевод там, наверху, сломал бы именно ту починку, ради
      // которой затевается эта. Общий случай назван в отчёте задачи 20.
      final wire = _serviceAnswering(
        _refused('unknown_terminal', 'эта сессия ещё не завела терминал'),
      );

      await expectLater(
        wire.service.loadReceipt(7, 12345, 1, _meta),
        throwsA(isA<SessionLost>()),
      );
    });

    test(
      'истёкший сеанс остаётся SessionLost, а не отказом операции',
      () async {
        // `unauthorized` лечится входом заново, и подменять его отказом
        // операции значило бы оставить вкладку на экране возврата навсегда.
        final wire = _serviceAnswering(
          _refused('unauthorized', 'сеанс неизвестен или истёк'),
        );

        await expectLater(
          wire.service.complete(7, _meta),
          throwsA(isA<SessionLost>()),
        );
      },
    );
  });

  group('молчащая касса не оставляет кассира без ответа', () {
    test('команда возврата отказывает по пределу ожидания', () {
      // **Двенадцатый случай «починено без пробы», и он мой.** Предел был
      // поставлен кодом, а отчёт утверждал, что оба пути к молчанию закрыты
      // пробами; для этого пути это была неправда — слова `no_answer`,
      // `timeout` и `_commandTimeout` не встречались в `test/` ни разу.
      //
      // Довод «сторож дороже находки» здесь не работает: проба пишется в
      // десяток строк и идёт за доли секунды — `fakeAsync` крутит часы, а
      // транспорт открывает поток и молчит, как молчала касса живьём.
      fakeAsync((async) {
        final wire = SilentStreams();
        final service = WtRefundService(WtDispatcher(wire));

        Object? outcome;
        unawaited(
          service
              .complete(7, _meta)
              .then<void>(
                (value) => outcome = value,
                onError: (Object error) => outcome = error,
              ),
        );

        async.elapse(const Duration(seconds: 19));
        expect(
          outcome,
          isNull,
          reason: 'до предела терминал ждёт: касса бывает медленной',
        );
        expect(
          wire.sent,
          hasLength(1),
          reason: 'подготовка: запрос ушёл, молчит именно ответ',
        );

        async.elapse(const Duration(seconds: 2));

        expect(
          outcome,
          isA<WireRefusal>().having((e) => e.code, 'code', 'no_answer'),
          reason:
              'кассир нажал кнопку денег: не ответила касса — он обязан '
              'узнать, а не смотреть на невредимый черновик и гадать, '
              'нажалась ли кнопка',
        );
        expect(
          (outcome! as WireRefusal).message,
          contains('касса не ответила'),
          reason: 'состояние называется словами, а не кодом (И144)',
        );
      });
    });

    test('подписка предела не имеет — она и должна ждать', () {
      // Предел стоит на командах, а не на потоке: подписка обязана ждать
      // сколько угодно, иначе экран сам себе устроит обрыв на тихой кассе.
      fakeAsync((async) {
        final wire = SilentStreams();
        var ended = false;
        WtRefundService(
          WtDispatcher(wire),
        ).watch(7).listen((_) {}, onError: (Object _) => ended = true);

        async.elapse(const Duration(minutes: 5));

        expect(
          ended,
          isFalse,
          reason: 'молчащая подписка — не отказ: касса просто ничего не меняла',
        );
      });
    });
  });

  group('деньги пересекают провод строкой (И159)', () {
    test('количество в refund.addProduct — строка, а не число', () {
      // Проверяется отправленный кадр, а не форма кода: сторож
      // `money_over_wire_test.dart` обходит только `lib/domain/wire/`, и
      // файл `lib/web/wt_refund_service.dart` в его область не попадает
      // вовсе.
      final wire = ScriptedStreams([_ok(refundViewToWireJson(_view()))]);
      final service = WtRefundService(WtDispatcher(wire));

      // Число, на котором `double` виден: в двоичной плавающей 0.1 + 0.2 не
      // равно 0.3, и это не придирка теоретика — так уезжает вес с весов.
      expect(0.1 + 0.2 == 0.3, isFalse);
      final quantity = Decimal.parse('0.1') + Decimal.parse('0.2');

      return service.addProduct(7, 42, quantity, _meta).then((_) {
        final sent = _sentBody(wire)['quantity'];
        expect(
          sent,
          isA<String>(),
          reason: 'число на проводе теряет P18,S3 молча',
        );
        expect(sent, '0.3');
      });
    });

    test('количество в refund.setLine — строка', () async {
      final wire = ScriptedStreams([_ok(refundViewToWireJson(_view()))]);
      final service = WtRefundService(WtDispatcher(wire));

      await service.setLineQuantity(7, '11', Decimal.parse('0.755'), _meta);

      expect(_sentBody(wire)['quantity'], isA<String>());
      expect(_sentBody(wire)['quantity'], '0.755');
    });

    test('деньги снимка приезжают Decimal, а не double', () async {
      // Обратная сторона той же двери: строка «450.5» обязана стать
      // `Decimal`, иначе точность теряется на разборе, а не на отправке.
      final raw =
          jsonDecode(_ok(refundViewToWireJson(_view(lines: [_line()]))))
              as Map<String, Object?>;
      final body = raw['body']! as Map<String, Object?>;
      final lines = body['lines']! as List<Object?>;
      expect((lines.single as Map<String, Object?>)['price'], isA<String>());

      final wire = _serviceAnswering(
        _ok(refundViewToWireJson(_view(lines: [_line()]))),
      );
      final answer = await wire.service.loadReceipt(7, 12345, 1, _meta);
      expect(answer.lines.single.price, Decimal.parse('450.5'));
    });

    test('имя рабочего места в теле не едет ни у одной команды', () async {
      // Требование контракта (докстринг `RefundService`, правило 1) и повод,
      // по которому `SessionAccess.ownTerminal` здесь неприменим: назови
      // терминал в теле — и касса обязана отвергнуть кадр.
      for (final send in <Future<void> Function(RefundService s)>[
        (s) => s.loadReceipt(7, 12345, 1, _meta),
        (s) => s.startWithoutReceipt(7, _meta),
        (s) => s.addProduct(7, 42, Decimal.one, _meta),
        (s) => s.setLineQuantity(7, '11', Decimal.one, _meta),
        (s) => s.complete(7, _meta),
      ]) {
        final wire = ScriptedStreams([
          _ok(refundViewToWireJson(_view())),
          _ok(refundViewToWireJson(_view())),
        ]);
        try {
          await send(WtRefundService(WtDispatcher(wire)));
        } on Object {
          // `complete` разберётся не в тот тип — здесь важен только кадр.
        }
        expect(
          _sentBody(wire).keys,
          isNot(contains('terminalId')),
          reason:
              'имя места берёт касса из сеанса; названное в теле она обязана '
              'отвергнуть',
        );
      }
    });
  });
}

// ── подмостки маршрутизатора ─────────────────────────────────────────────

late SharedPreferences _prefs;

/// Касса, у которой сеанс истёк: подписка живая, а любая команда отвечает
/// [SessionLost].
///
/// Ровно то, что происходит после `unknown_terminal` (вкладка без рабочего
/// места) и после `unauthorized` (сеанс вымели по бездействию).
class _SessionLostRefunds implements RefundService {
  /// [watchFails] — отказывает **подписка**, а не команда.
  ///
  /// Два пути, и их надо разводить. Первая редакция этих подмостков отдавала
  /// `Stream.value(...)` для обоих, и потому путь `onError` не проходила **ни
  /// одна проба во всём дереве**: разбор круга снял ветку
  /// `if (e is SessionLost)` из `_listenToDraft` и получил
  /// `+894 All tests passed`. Строка отчёта «то же в `onError`» была не
  /// подкреплена ничем.
  ///
  /// Отказ подписки — не выдумка: сторож кассы отвечает на **открытии
  /// потока**, и истёкший сеанс приезжает так, раньше любой команды.
  _SessionLostRefunds({this.watchFails = false});

  /// Меняется по ходу пробы: сеанс кончился — поднялся заново.
  bool watchFails;

  /// Сколько раз на черновик подписались. Растёт при каждой переподписке.
  int watchCount = 0;

  @override
  Stream<RefundView> watch(int terminalId) {
    watchCount++;
    if (watchFails) {
      return Stream<RefundView>.error(
        const SessionLost('сеанс неизвестен или истёк'),
      );
    }
    return Stream.value(
      RefundView(posId: 1, terminalId: terminalId, version: 0, lines: const []),
    );
  }

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) async => throw const SessionLost('сеанс неизвестен или истёк');

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) async => throw const SessionLost('сеанс неизвестен или истёк');

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw const SessionLost('сеанс неизвестен или истёк');

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw const SessionLost('сеанс неизвестен или истёк');

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async =>
      throw const SessionLost('сеанс неизвестен или истёк');

  @override
  Future<void> abandon(int terminalId) async {}

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => const [];
}

/// Черновика нет, команд никто не шлёт — этому файлу важно, что экран
/// строится и что таблица его пускает, а не что касса считает деньги.
class _EmptyRefunds implements RefundService {
  @override
  Stream<RefundView> watch(int terminalId) => Stream.value(
    RefundView(posId: 1, terminalId: terminalId, version: 0, lines: const []),
  );

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) async => throw const WireRefusal(refundReceiptNotFoundCode, 'нет чека');

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) async => RefundView(
    posId: 1,
    terminalId: terminalId,
    version: 1,
    draftNo: 1,
    lines: const [],
  );

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw const WireRefusal(refundNotStartedCode, 'не начат');

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw const WireRefusal(refundLineNotFoundCode, 'нет строки');

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async =>
      throw const WireRefusal(refundEmptyCode, 'пусто');

  @override
  Future<void> abandon(int terminalId) async {}

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => const [];
}

Widget _terminal(SharedPreferences prefs, GoRouter router) => ProviderScope(
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

/// Тот же экран, но контейнер заведён явно — нужен пробе «истёкший сеанс
/// уводит на вход»: `redirect` обязан перечитаться **без единой навигации**,
/// когда `isLoggedIn` гаснет, а для этого `SetupRouterRefresh` должен
/// слушать тот же контейнер, что и дерево.
Widget _terminalWith(ProviderContainer container, GoRouter router) =>
    UncontrolledProviderScope(
      container: container,
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void _logIn(WidgetTester tester, {Set<String> permissions = const {}}) {
  final context = tester.element(find.byType(LoginScreen));
  ProviderScope.containerOf(context, listen: false)
      .read(appStateProvider.notifier)
      .setUserInfo(id: 7, name: 'Айгуль', role: 0, permissions: permissions);
}

/// Регистрации, без которых заставка и вход не построятся вовсе — тот же
/// набор, что в `wt_setup_router_test.dart`, плюс контракт возврата.
void _registerTerminalScope() {
  GetIt.I
    ..registerSingleton<AppBootstrap>(_BootedTill())
    ..registerSingleton<FirstLaunchRepository>(_AlreadyConfigured())
    ..registerSingleton<StartupStateRepository>(_TillState())
    ..registerSingleton<AuthRepository>(FakeAuthRepository())
    ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
    ..registerSingleton<TerminalRepository>(
      FakeTerminalRepository(
        self: () async => const Terminal(
          id: 7,
          name: 'Планшет',
          pointMode: PointMode.cashier,
        ),
      ),
    )
    ..registerSingleton<RefundService>(_EmptyRefunds());
}

class _BootedTill implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async {
    onProgress(1.0, BootStage.ready);
    return AppInitStatus.success;
  }
}

/// Живая подписка на состояние установки, которая ничем не кончается — как
/// настоящая. Тот же приём, что в `wt_setup_router_test.dart`: таймер в
/// `testWidgets` идёт по поддельным часам и остался бы висеть после разбора
/// дерева, а контроллер — нет.
class _TillState implements StartupStateRepository {
  @override
  Stream<SetupState> watch() {
    late final StreamController<SetupState> out;
    out = StreamController<SetupState>(
      onListen: () => out.add(
        const SetupState(
          configured: true,
          hasUsers: true,
          companyName: 'ТОО Ромашка',
          cashBoxName: 'Касса-1',
        ),
      ),
    );
    return out.stream;
  }
}

class _AlreadyConfigured implements FirstLaunchRepository {
  @override
  Future<FirstLaunchResult> determineResult() async =>
      FirstLaunchResult.alreadyConfigured;

  @override
  Future<List<FoundBackup>> findAvailableBackups() async => const [];

  @override
  Future<bool> restoreFromBackup(
    FoundBackup backup, {
    BootProgress? onProgress,
  }) async => false;

  @override
  Future<bool> loadGlobalData({BootProgress? onProgress}) async => false;

  @override
  Future<String> startNewPos() async => '';
}
