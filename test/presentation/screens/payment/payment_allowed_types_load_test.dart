/// Набор разрешённых видов **доезжает до экрана**, а не только рисуется,
/// если его туда положить — задача 15.
///
/// # Зачем отдельно от `payment_type_selector_test.dart`
///
/// Тот сторож утверждает про **рисование**: положили набор в состояние —
/// кнопка погасла и назвала причину. Он остаётся зелёным, если набор в
/// состояние никогда не кладут: экран честно рисует пустое множество,
/// то есть «все виды», и дефект возвращается целиком — кассир снова видит
/// «Наличная» там, где касса откажет.
///
/// Здесь проверяется вторая половина того же пути: `initialize` спрашивает
/// **то же самое рабочее место**, которым идут корзина и оплата
/// (`SaleNotifier.currentTerminalId`), берёт его набор из
/// `TerminalRepository` и кладёт в состояние. Плюс два свойства, каждое из
/// которых уже было дефектом в этом файле у соседних полей: набор
/// переживает повторный вход на экран, и неудача чтения читается как «все
/// виды», а не как «ничего нельзя».
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import '../../../helpers/mock_providers.dart';

/// Терминалы кассы, из которых экран обязан выбрать **свой**.
///
/// Список, а не один терминал: подделка, отдающая один и тот же набор на
/// любой id, пропустила бы «экран взял чужое рабочее место» — а это ровно
/// тот дефект, ради которого резолв рабочего места сведён в одно место.
class _FakeTerminals implements TerminalRepository {
  _FakeTerminals(this.terminals);

  final List<Terminal> terminals;
  bool failList = false;
  int listCalls = 0;

  @override
  Future<List<Terminal>> list() async {
    listCalls++;
    if (failList) throw StateError('касса не ответила');
    return terminals;
  }

  @override
  Stream<List<Terminal>> watchAll() => Stream.value(terminals);

  @override
  Stream<Terminal?> watchSelf() => Stream.value(terminals.firstOrNull);

  @override
  Future<Terminal> self() async => terminals.first;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const mine = Terminal(
    // `MockSaleNotifier.currentTerminalId` отдаёт 7 — это и есть «своё»
    // рабочее место в этой пробе.
    id: 7,
    name: 'Планшет в зале',
    pointMode: PointMode.cashier,
    allowedPaymentTypes: {PaymentType.card},
  );
  const other = Terminal(
    id: 8,
    name: 'Касса',
    pointMode: PointMode.cashier,
    allowedPaymentTypes: {PaymentType.cash},
  );

  late _FakeTerminals terminals;

  ProviderContainer boot({
    List<Terminal> rows = const [other, mine],
    bool failList = false,
  }) {
    if (!isLoggerReady) installLogger(Talker());
    terminals = _FakeTerminals(rows)..failList = failList;
    if (GetIt.I.isRegistered<TerminalRepository>()) {
      GetIt.I.unregister<TerminalRepository>();
    }
    GetIt.I.registerSingleton<TerminalRepository>(terminals);
    final container = ProviderContainer(
      overrides: [
        saleControllerProvider.overrideWith(MockSaleNotifier.new),
        paymentAccountsProvider.overrideWith((ref) async => <PaymentAccount>[]),
      ],
    );
    addTearDown(() {
      container.dispose();
      if (GetIt.I.isRegistered<TerminalRepository>()) {
        GetIt.I.unregister<TerminalRepository>();
      }
    });
    return container;
  }

  test('вход на экран оплаты приносит набор своего рабочего места', () async {
    final container = boot();
    final notifier = container.read(paymentControllerProvider.notifier);

    expect(
      container.read(paymentControllerProvider).allowedPaymentTypes,
      isEmpty,
      reason: 'до входа набора взяться неоткуда — иначе проба вырождена',
    );

    notifier.initialize(Decimal.fromInt(1000));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(paymentControllerProvider);
    expect(terminals.listCalls, greaterThan(0), reason: 'кассу не спросили');
    expect(
      state.allowedPaymentTypes,
      {PaymentType.card},
      reason: 'взят набор рабочего места #7, а не первого попавшегося',
    );
    expect(state.offers(PaymentType.cash), isFalse);
    expect(state.offers(PaymentType.card), isTrue);
  });

  test('повторный вход на экран набор не теряет', () async {
    final container = boot();
    final notifier = container.read(paymentControllerProvider.notifier);

    notifier.initialize(Decimal.fromInt(1000));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(paymentControllerProvider).allowedPaymentTypes, {
      PaymentType.card,
    });

    // Второй чек: `initialize` собирает состояние с нуля. Набор — свойство
    // рабочего места, а не чека, и обязан пережить сборку **сразу**, не
    // дожидаясь ответа кассы: окно «показываем всё» между входом и ответом
    // и есть тот дефект, ради которого задача делалась.
    notifier.initialize(Decimal.fromInt(500));
    expect(
      container.read(paymentControllerProvider).allowedPaymentTypes,
      {PaymentType.card},
      reason: 'между вторым входом и ответом кассы запрет не пропадает',
    );
  });

  test('касса не ответила — экран показывает все виды, а не ни одного', () async {
    final container = boot(failList: true);
    final notifier = container.read(paymentControllerProvider.notifier);

    notifier.initialize(Decimal.fromInt(1000));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(paymentControllerProvider);
    expect(
      state.allowedPaymentTypes,
      isEmpty,
      reason: 'пустое означает «все» — экран не запрещает больше кассы',
    );
    for (final type in PaymentType.values) {
      expect(state.offers(type), isTrue);
    }
  });

  test('своего рабочего места в списке нет — тоже все виды', () async {
    final container = boot(rows: const [other]);
    final notifier = container.read(paymentControllerProvider.notifier);

    notifier.initialize(Decimal.fromInt(1000));
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(paymentControllerProvider).allowedPaymentTypes,
      isEmpty,
      reason: 'чужой набор брать нельзя, и запрещать по нему — тем более',
    );
  });
}
