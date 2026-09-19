/// Тумблер кассы **доезжает до экрана**, а не только рисуется, если его
/// туда положить, — задача 16.
///
/// # Зачем отдельно от `payment_debt_button_test.dart`
///
/// Тот сторож утверждает про **рисование**: положили `sellInDebt` в
/// состояние — кнопка ожила или погасла и назвала причину. Он остаётся
/// зелёным в мире, где `sellInDebt` в состояние **никогда не кладут**:
/// экран честно рисует `null`, кнопка честно говорит «касса не
/// ответила», и вся задача сводится к вечно погашенной кнопке. Ровно так
/// же выглядела бы и колонка, оставшаяся без читателя.
///
/// Здесь проверяется вторая половина пути: вход на экран оплаты
/// **спрашивает кассу** и кладёт ответ в состояние; повторный вход его не
/// теряет; неудача чтения остаётся `null` («не знаем»), а не
/// превращается в `true`.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import '../../../helpers/mock_providers.dart';

/// Касса, у которой один ответ и счётчик вопросов.
class _FakePayments implements PaymentService {
  _FakePayments(this.sells);

  final bool sells;
  bool fail = false;
  int asked = 0;

  @override
  Future<bool> sellsInDebt() async {
    asked++;
    if (fail) throw StateError('касса не ответила');
    return sells;
  }

  @override
  Future<List<PaymentAccount>> accounts() async => const [];

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) async => null;

  @override
  Future<Decimal> reserveBonus(int customerId, Decimal amount) async =>
      Decimal.zero;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakePayments payments;

  ProviderContainer boot({bool sells = true, bool fail = false}) {
    if (!isLoggerReady) installLogger(Talker());
    payments = _FakePayments(sells)..fail = fail;
    if (GetIt.I.isRegistered<PaymentService>()) {
      GetIt.I.unregister<PaymentService>();
    }
    GetIt.I.registerSingleton<PaymentService>(payments);
    final container = ProviderContainer(
      overrides: [
        saleControllerProvider.overrideWith(MockSaleNotifier.new),
        paymentAccountsProvider.overrideWith((ref) async => <PaymentAccount>[]),
      ],
    );
    addTearDown(() {
      container.dispose();
      if (GetIt.I.isRegistered<PaymentService>()) {
        GetIt.I.unregister<PaymentService>();
      }
    });
    return container;
  }

  test('вход на экран оплаты спрашивает кассу про кредит', () async {
    final container = boot(sells: true);
    final notifier = container.read(paymentControllerProvider.notifier);

    expect(
      container.read(paymentControllerProvider).sellInDebt,
      isNull,
      reason: 'до входа ответу взяться неоткуда — иначе проба вырождена',
    );

    notifier.initialize(Decimal.fromInt(1000));
    await Future<void>.delayed(Duration.zero);

    expect(payments.asked, greaterThan(0), reason: 'кассу не спросили');
    expect(container.read(paymentControllerProvider).sellInDebt, isTrue);
  });

  test('выключенный тумблер доезжает так же, как включённый', () async {
    // Иначе читателем колонки был бы код, который на любую кассу отвечает
    // одинаково, — то есть не читатель.
    final container = boot(sells: false);
    container.read(paymentControllerProvider.notifier)
      ..initialize(Decimal.fromInt(1000));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(paymentControllerProvider).sellInDebt, isFalse);
  });

  test('повторный вход на экран ответ кассы не теряет', () async {
    final container = boot(sells: true);
    final notifier = container.read(paymentControllerProvider.notifier);

    notifier.initialize(Decimal.fromInt(1000));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(paymentControllerProvider).sellInDebt, isTrue);

    // Второй чек: `initialize` собирает состояние с нуля. Тумблер —
    // свойство кассы, а не чека, и обязан пережить сборку **сразу**:
    // окно «кнопка снова погасла» между входом и ответом кассы кассир
    // читает как поломку.
    notifier.initialize(Decimal.fromInt(500));
    expect(
      container.read(paymentControllerProvider).sellInDebt,
      isTrue,
      reason: 'между вторым входом и ответом кассы кнопка не гаснет',
    );
  });

  test('касса не ответила — «не знаем», а не «торгуют»', () async {
    final container = boot(sells: true, fail: true);
    container.read(paymentControllerProvider.notifier)
      ..initialize(Decimal.fromInt(1000));
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(paymentControllerProvider).sellInDebt,
      isNull,
      reason: 'молчание кассы не открывает вида оплаты, которого не включали',
    );
  });
}
