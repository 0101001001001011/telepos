import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble;
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';

import '../../auth/support/fakes.dart';

/// Отказ кассы доезжает до кассира **названным** — требование шага 4 задачи
/// 20.
///
/// # Почему именно возврат, и почему это не придирка
///
/// Возврат — место, где отказ обычен по праву: количество больше проданного,
/// по чеку уже вернули, смена закрыта, нет права на возврат без чека. До
/// этой задачи экран показывал на **всё** это одно слово: `_refundErrorMessage`
/// знал два кода и уводил остальное в `l10n.globalError` — «Ошибка».
/// Половина работы кассы была для кассира неразличима, а действие в каждом
/// случае разное: уменьшить количество, открыть смену, позвать старшего.
///
/// # Что проверяется
///
/// Не «текст не пуст», а **текст кассы на экране**: `WireRefusal.message`
/// написан для человека и безопасен (И144), и он обязан дойти дословно, а не
/// быть заменён общим словом.
class _RefusingRefunds implements RefundService {
  _RefusingRefunds(this.refusal);

  final WireRefusal refusal;

  @override
  Stream<RefundView> watch(int terminalId) => Stream.value(
    RefundView(
      posId: 1,
      terminalId: terminalId,
      version: 3,
      draftNo: 1,
      saleReceiptNo: 12345,
      salePosId: 1,
      lines: [
        RefundLine(
          id: '11',
          productId: 42,
          name: 'Молоко',
          quantity: Decimal.fromInt(2),
          price: Decimal.parse('450'),
          maxQuantity: Decimal.fromInt(2),
        ),
      ],
    ),
  );

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) async => throw refusal;

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) async => throw refusal;

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw refusal;

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw refusal;

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async =>
      throw refusal;

  @override
  Future<void> abandon(int terminalId) async {}

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => const [];
}

Widget _app() => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(body: RefundScreen()),
  ),
);

void main() {
  setUp(() {
    app_log.installLogger(Talker());
    GetIt.I
      ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
      ..registerSingleton<TerminalRepository>(
        FakeTerminalRepository(
          self: () async => const Terminal(
            id: 1,
            name: 'Планшет',
            pointMode: PointMode.cashier,
          ),
        ),
      );
  });

  tearDown(() async => GetIt.I.reset());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('текст отказа кассы виден кассиру дословно', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    GetIt.I.registerSingleton<RefundService>(
      _RefusingRefunds(
        const WireRefusal(
          refundInvalidAmountCode,
          'в чеке продано 2, вернуть просят 5',
        ),
      ),
    );

    await tester.pumpWidget(_app());
    await settle(tester);

    final context = tester.element(find.byType(RefundScreen));
    await ProviderScope.containerOf(context, listen: false)
        .read(refundControllerProvider.notifier)
        .updateQuantity('11', Decimal.fromInt(5));
    await settle(tester);

    // Фраза словаря под код, а не текст кассы (2026-09-15): текст кассы
    // написан по-русски для журнала, и кассир с казахским интерфейсом читал
    // его буквами. Что делать — «уменьшить количество» — говорит фраза.
    expect(
      find.textContaining('Столько вернуть нельзя'),
      findsOneWidget,
      reason:
          'кассир обязан узнать, ЧТО не так: уменьшить количество, а не '
          'звать старшего',
    );
    expect(
      find.textContaining('в чеке продано 2, вернуть просят 5'),
      findsNothing,
      reason: 'текст кассы — для журнала, на экран едет фраза словаря',
    );
    expect(
      find.textContaining('скидка'),
      findsNothing,
      reason:
          'код invalid_amount общий с корзиной, но фраза корзины говорит о '
          'скидке — на возврате она отправила бы кассира не туда',
    );
    expect(
      find.text('Ошибка'),
      findsNothing,
      reason:
          '«Ошибка» на месте названной причины — это половина работы кассы, '
          'спрятанная от того, кто с ней работает',
    );
  });

  testWidgets('отсутствие права на возврат без чека тоже названо', (
    tester,
  ) async {
    // Ключ `op.refundWithoutReceipt` до задачи 19 не читала ни одна строка
    // `lib/`. Теперь он отказывает по-настоящему — и отказ обязан объяснить
    // кассиру, что дело в праве, а не в кассе.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    GetIt.I.registerSingleton<RefundService>(
      _RefusingRefunds(
        const WireRefusal('forbidden', 'нет права op.refundWithoutReceipt'),
      ),
    );

    await tester.pumpWidget(_app());
    await settle(tester);

    final context = tester.element(find.byType(RefundScreen));
    await ProviderScope.containerOf(context, listen: false)
        .read(refundControllerProvider.notifier)
        .setMode(RefundMode.withoutReceipt);
    await settle(tester);

    expect(
      find.textContaining('Недостаточно прав для этого действия'),
      findsOneWidget,
    );
    expect(
      find.textContaining('op.refundWithoutReceipt'),
      findsNothing,
      reason: 'внутренний ключ права кассиру не адресован',
    );
  });

  testWidgets('чек, которого нет, называется своим текстом', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    GetIt.I.registerSingleton<RefundService>(
      _RefusingRefunds(
        const WireRefusal(
          refundReceiptNotFoundCode,
          'чека 999999 кассы 1 на этой кассе нет',
        ),
      ),
    );

    await tester.pumpWidget(_app());
    await settle(tester);

    final context = tester.element(find.byType(RefundScreen));
    await ProviderScope.containerOf(
      context,
      listen: false,
    ).read(refundControllerProvider.notifier).loadReceipt(999999, 1);
    await settle(tester);

    // У этого случая своя строка словаря — она точнее сырого текста кассы и
    // остаётся на месте.
    expect(find.text('Чек не найден'), findsOneWidget);
  });

  testWidgets('обрыв подписки называется, а не выглядит как «товаров нет»', (
    tester,
  ) async {
    // Найдено живым прогоном 2026-09-07, шаг 8. После F5 кассир зашёл на
    // возврат и увидел «Нет товаров для возврата» — то есть **утверждение о
    // чеке** там, где на самом деле **нет ответа от кассы**. В консоли при
    // этом лежал `stream_ended`.
    //
    // Тот же класс, что «Ошибка сохранения: SessionLost»: молчание выдано за
    // ответ. Спека называет требуемое поведение прямо (шаг 10): «терминал
    // показывает названное состояние — связь с кассой потеряна».
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    GetIt.I.registerSingleton<RefundService>(_BreakingWatch());

    await tester.pumpWidget(_app());
    await settle(tester);

    expect(
      find.text('Нет товаров для возврата'),
      findsNothing,
      reason:
          'подписка оборвалась — про товары кассе сказать нечего, и говорить '
          'за неё нельзя',
    );
    expect(
      find.textContaining('Связь с кассой потеряна'),
      findsWidgets,
      reason: 'состояние обязано быть названо словами (шаг 10 спеки)',
    );
  });

  testWidgets('оборванная подписка поднимается заново сама', (tester) async {
    // `ensureWatching()` чинит подписку при **заходе на экран**. Обрыв
    // случается, когда кассир уже на экране, и ждать от него ухода и
    // возвращения — значит просить чинить провод руками.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final refunds = _BreakingWatch()..breakUntil = 1;
    GetIt.I.registerSingleton<RefundService>(refunds);

    await tester.pumpWidget(_app());
    await settle(tester);
    final afterFirst = refunds.watchCount;
    expect(
      afterFirst,
      1,
      reason:
          'подготовка: экран подписался один раз — build() и ensureWatching '
          'при заходе делят один подъём (приёмка 2026-09-17: второй бросал '
          'первый поток провода в момент рождения); подписка оборвалась',
    );

    // Даём пройти паузе перед повтором.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      refunds.watchCount,
      greaterThan(afterFirst),
      reason:
          'терминал обязан вернуться к кассе сам: корзина живёт на ней, и '
          'после возвращения связи экран продолжает работу (шаг 10 спеки)',
    );
    expect(
      find.textContaining('Связь с кассой потеряна'),
      findsNothing,
      reason: 'связь вернулась — состояние обязано смениться',
    );
  });
}

/// Касса, чья подписка **обрывается**: первый снимок пришёл, дальше тишина.
///
/// Ровно то, что нашёл живой прогон 2026-09-07 после F5:
/// `Refund: draft watch error: WireRefusal(stream_ended: подписка оборвалась
/// — состояние больше не приходит)`, а экран показал «Нет товаров для
/// возврата». Кассир видит **утверждение о чеке** там, где на самом деле
/// **нет ответа от кассы**.
class _BreakingWatch implements RefundService {
  _BreakingWatch();

  /// Сколько раз подписались. Обрыв обязан вести к переподъёму.
  int watchCount = 0;

  /// Сколько первых подписок рвутся. Дальше касса отвечает.
  ///
  /// Единица — не произвол: `build()` нотифайера и `ensureWatching` из
  /// `initState` делят **один** подъём подписки, и **второй** может прийти
  /// только от переподключения по таймеру. Иначе проба зеленела бы и без
  /// него.
  int breakUntil = 1 << 20;

  @override
  Stream<RefundView> watch(int terminalId) {
    watchCount++;
    if (watchCount > breakUntil) {
      return Stream.value(
        RefundView(
          posId: 1,
          terminalId: terminalId,
          version: 1,
          draftNo: 1,
          lines: const [],
        ),
      );
    }
    return Stream<RefundView>.error(
      const WireRefusal(
        'stream_ended',
        'подписка оборвалась — состояние больше не приходит',
      ),
    );
  }

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw UnimplementedError();

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async =>
      throw UnimplementedError();

  @override
  Future<void> abandon(int terminalId) async {}

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => const [];
}
