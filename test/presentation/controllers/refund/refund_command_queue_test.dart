import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble;
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';

import '../../auth/support/fakes.dart';

/// Три свойства экрана возврата, которых не видно ни в одной проверке
/// «нажали — получилось»: очередь, отсутствие утечки и точность денег.
///
/// # Почему очередь проверяется одновременностью, а не по очереди
///
/// Правило I161 — «на корзину одна команда в полёте» — существует затем, что
/// между потоками QUIC порядка нет: два быстрых нажатия могут примениться
/// наоборот. Последовательный вызов этого не проверяет вовсе: он и так
/// последователен. Проверять надо тем, что происходит **сразу**.
///
/// # Почему утечка подписки — не мелочь
///
/// Смена длится двенадцать часов. Подписка на черновик, не снятая при уходе с
/// экрана, оставляет кассу говорить в экран, которого больше нет, и такие
/// подписки копятся молча.
class _SlowRefunds implements RefundService {
  _SlowRefunds();

  /// Сколько команд выполняется прямо сейчас. Больше единицы — очередь не
  /// работает.
  int inFlight = 0;
  int maxInFlight = 0;

  final order = <String>[];

  int watchers = 0;
  int cancels = 0;

  var _version = 0;

  RefundView _view() => RefundView(
    posId: 1,
    terminalId: 7,
    version: ++_version,
    draftNo: 1,
    lines: [
      RefundLine(
        id: '11',
        productId: 42,
        name: 'Молоко',
        quantity: Decimal.parse('0.1'),
        price: Decimal.parse('1'),
      ),
      RefundLine(
        id: '12',
        productId: 43,
        name: 'Хлеб',
        quantity: Decimal.parse('0.2'),
        price: Decimal.parse('1'),
      ),
    ],
  );

  @override
  Stream<RefundView> watch(int terminalId) {
    late final StreamController<RefundView> out;
    out = StreamController<RefundView>(
      onListen: () {
        watchers++;
        out.add(_view());
      },
      onCancel: () => cancels++,
    );
    return out.stream;
  }

  Future<RefundView> _slow(String label) async {
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    order.add(label);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight--;
    return _view();
  }

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) => _slow('loadReceipt:$receiptNo');

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) => _slow('startWithoutReceipt');

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => _slow('addProduct:$productId');

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => _slow('setLine:$lineId=$quantity');

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async {
    await _slow('complete');
    return RefundOutcome(
      refundLocalId: 1,
      amount: Decimal.parse('0.3'),
      lineCount: 2,
      paymentCount: 1,
    );
  }

  @override
  Future<void> abandon(int terminalId) async {}

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => const [];
}

void main() {
  late _SlowRefunds refunds;
  late ProviderContainer container;

  setUp(() {
    app_log.installLogger(Talker());
    refunds = _SlowRefunds();
    GetIt.I
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
      ..registerSingleton<RefundService>(refunds);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await GetIt.I.reset();
  });

  Future<void> settle() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  test('две команды сразу идут по одной, а не разом (I161)', () async {
    final notifier = container.read(refundControllerProvider.notifier);
    await settle();

    // Ровно то, что делает палец на планшете: два быстрых нажатия. Ждать
    // ответа первого экран не заставляет.
    final first = notifier.updateQuantity('11', Decimal.fromInt(1));
    final second = notifier.updateQuantity('12', Decimal.fromInt(2));
    await Future.wait([first, second]);
    await settle();

    expect(
      refunds.maxInFlight,
      1,
      reason:
          'две команды в полёте разом — это порядок применения на усмотрение '
          'сети: между потоками QUIC порядка нет (I161)',
    );
    expect(refunds.order, [
      'setLine:11=1',
      'setLine:12=2',
    ], reason: 'порядок нажатий обязан сохраниться');
  });

  test('уход с экрана снимает подписку на черновик', () async {
    container.read(refundControllerProvider.notifier);
    await settle();

    expect(refunds.watchers, 1);
    expect(refunds.cancels, 0);

    container.dispose();
    await settle();

    expect(
      refunds.cancels,
      1,
      reason:
          'смена длится двенадцать часов; неснятая подписка оставляет кассу '
          'говорить в экран, которого больше нет',
    );

    // `tearDown` зовёт `dispose` второй раз — Riverpod это допускает, но
    // контейнер уже разобран, поэтому пересоздаём пустой.
    container = ProviderContainer();
  });

  test('второй такой же отказ команды объявляется заново', () async {
    // Живой шаг 7: кассир вводит количество больше проданного, читает отказ,
    // вводит снова — и **молчание**. Экран показывает отказ по переходу
    // `error`, а два одинаковых отказа подряд дают дословно один и тот же
    // текст: `next == previous`, полосы нет.
    //
    // Чистка стояла в `processRefund` и не стояла в общем ходе команды —
    // то есть кнопка денег была прикрыта, а всё остальное нет. Мерится
    // **число переходов в непустой отказ**: именно оно определяет, увидит
    // ли кассир полосу.
    GetIt.I
      ..unregister<RefundService>()
      ..registerSingleton<RefundService>(_AlwaysRefuses());
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var announcements = 0;
    container.listen(refundControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next != null && next != previous) announcements++;
    });
    container.read(refundControllerProvider.notifier);
    await settle();

    final refunds = container.read(refundControllerProvider.notifier);
    await refunds.updateQuantity('11', Decimal.fromInt(5));
    await settle();
    await refunds.updateQuantity('11', Decimal.fromInt(5));
    await settle();

    expect(
      announcements,
      2,
      reason:
          'два одинаковых отказа подряд — два объявления. Иначе второе '
          'нажатие отвечает молчанием, а молчание кассир читает как '
          '«кнопка не сработала»',
    );
  });

  test('повторный названный отказ подтверждения объявляется заново', () async {
    // **Правка «кнопка не молчит» воспроизвела дефект, который сама и
    // закрывала.** Названный отказ в `processRefund` ставится напрямую, мимо
    // `_enqueue` — то есть мимо чистки. Два подтверждения подряд дают
    // дословно один текст, и второе отвечает молчанием.
    //
    // Путь настоящий: черновик пропал на кассе → отказ показан → черновик
    // вернулся (снимок ошибку не гасит) → пропал снова → «Подтвердить».
    GetIt.I
      ..unregister<RefundService>()
      ..registerSingleton<RefundService>(_EmptyDraft());
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var announcements = 0;
    container.listen(refundControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next != null && next != previous) announcements++;
    });
    final refunds = container.read(refundControllerProvider.notifier);
    await settle();

    await refunds.processRefund();
    await settle();
    await refunds.processRefund();
    await settle();

    expect(
      announcements,
      2,
      reason:
          'кассир жмёт «Подтвердить» второй раз и обязан снова прочитать, '
          'почему нельзя, — иначе это то же молчание, ради которого '
          'заводился названный отказ',
    );
  });

  test('повторный отказ поиска объявляется заново', () async {
    // Живой шаг 10: «поиск товара на этом терминале ещё не подключён». Текст
    // один на любой запрос, и второй ввод без чистки молчит.
    GetIt.I
      ..unregister<RefundService>()
      ..registerSingleton<RefundService>(_EmptyDraft());
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var announcements = 0;
    container.listen(refundControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next != null && next != previous) announcements++;
    });
    final refunds = container.read(refundControllerProvider.notifier);
    await settle();

    await refunds.search('Молоко');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await refunds.search('Хлеб');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settle();

    expect(
      announcements,
      2,
      reason: 'второй ввод обязан ответить тем же текстом, а не тишиной',
    );
    // Ключ словаря, а не русский текст, пришитый к `error.refund_refused:`
    // (2026-09-15): кассир с казахским интерфейсом читал его буквами.
    expect(
      container.read(refundControllerProvider).error,
      isNot(matches(RegExp('[А-Яа-яЁё]'))),
    );
  });

  test('сумма к возврату считается Decimal, а не double', () async {
    // 0.1 + 0.2 в двоичной плавающей не равно 0.3 — на `double` эта проверка
    // провалится, и именно это она проверяет.
    expect(0.1 + 0.2 == 0.3, isFalse);

    container.read(refundControllerProvider.notifier);
    await settle();

    final state = container.read(refundControllerProvider);
    expect(state.items, hasLength(2));
    expect(state.selectedTotal, Decimal.parse('0.3'));
    expect(state.total, Decimal.parse('0.3'));
  });
}

/// Касса, отказывающая на любую строчную команду одним и тем же текстом.
class _AlwaysRefuses implements RefundService {
  @override
  Stream<RefundView> watch(int terminalId) => Stream.value(
    RefundView(
      posId: 1,
      terminalId: terminalId,
      version: 1,
      draftNo: 1,
      saleReceiptNo: 5001,
      salePosId: 1,
      lines: [
        RefundLine(
          id: '11',
          productId: 42,
          name: 'Молоко',
          quantity: Decimal.fromInt(2),
          price: Decimal.fromInt(500),
          maxQuantity: Decimal.fromInt(2),
        ),
      ],
    ),
  );

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => throw const WireRefusal(
    refundInvalidAmountCode,
    'по этой строке чека продано 2 — вернуть больше нельзя',
  );

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

/// Касса без черновика: подтверждать нечего, искать не через что.
class _EmptyDraft implements RefundService {
  @override
  Stream<RefundView> watch(int terminalId) => Stream.value(
    RefundView(posId: 1, terminalId: terminalId, version: 1, lines: const []),
  );

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
