/// Предупреждение о просроченной партии — **оба** пути добавления строки.
///
/// Пункт 11 ревизии 2026-09-19.
///
/// # Что эти пробы закрывают
///
/// Две разные беды одного метода, найденные при переносе вопроса на кассу:
///
/// 1. **Скан штрихкода не предупреждал вовсе.** Проверка стояла только в
///    `addProduct` — то есть при выборе товара из выдачи поиска. Главный
///    путь кассира (сканер) просроченную партию не называл ни на кассе, ни
///    в браузере, и ни одна проба этого не замечала.
/// 2. **Вопрос шёл параллельно команде.** `unawaited(_checkExpiryWarning(…))`
///    уходил до того, как строка встала в чек: кассир получал жёлтый
///    снекбар о товаре, который в чек мог и не попасть.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что расчёт «просрочено» верен — за это отвечает `LocalExpiryWarning` и
/// пробы по проводу (`test/web/wt_expiry_warning_test.dart`); здесь ответ
/// подменён. И что снекбар нарисуется: это `sale_screen.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import 'sale_cycle_test.dart' show waitForSearch;
import 'test_utils.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = createTestContainer());

  tearDown(() {
    container.dispose();
    tearDownTestDependencies();
  });

  /// Ждёт ответа на «партия просрочена?» — **по состоянию, а не по часам**.
  ///
  /// Вопрос уходит `unawaited` нарочно: касса не обязана держать кассира,
  /// пока склад думает. Значит проба обязана дождаться его сама, и ждать
  /// фиксированную паузу здесь — то самое мерцание под нагрузкой, которым
  /// этот набор уже болел (`waitForSearch` рядом, тот же довод).
  Future<void> settleWarning() async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (expiryWarningStub.asked.isNotEmpty) break;
    }
    // Ещё один оборот — ответ уже получен, осталось дать `_emit` лечь в
    // состояние.
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  /// Кладёт «Молоко» в чек путём выдачи поиска и отдаёт его `productId`.
  Future<int> addMilkFromSearch() async {
    final notifier = container.read(saleControllerProvider.notifier);
    await notifier.search('Молоко');
    await waitForSearch(container);
    final found = container.read(saleControllerProvider).searchResults.first;
    await notifier.addProduct(found);
    return found.id;
  }

  test('путь выдачи поиска: просроченная партия называет товар', () async {
    // Сначала узнаём ucode, потом объявляем его просроченным и кладём
    // второй раз: «какой товар просрочен» — часть семян, а не догадка.
    final ucode = await addMilkFromSearch();
    expiryWarningStub.expired.add(ucode);

    expect(
      container.read(saleControllerProvider).warning,
      isNull,
      reason: 'предпосылка: жёлтого ещё нет',
    );

    expiryWarningStub.asked.clear();
    await addMilkFromSearch();
    await settleWarning();

    final state = container.read(saleControllerProvider);
    expect(state.warning, isNotNull);
    expect(
      state.warning,
      contains('Молоко'),
      reason: 'кассиру называется товар, а не код',
    );
  });

  test('путь скана штрихкода: просроченная партия тоже называется', () async {
    // Красный до правки: этот путь не спрашивал про партию ни разу.
    final ucode = await addMilkFromSearch();
    final barcode = container.read(saleControllerProvider).items.first.barcode;
    expect(barcode, isNotNull, reason: 'предпосылка: у товара есть штрихкод');

    expiryWarningStub.expired.add(ucode);
    container.read(saleControllerProvider.notifier).clearWarning();
    expiryWarningStub.asked.clear();

    final ok = await container
        .read(saleControllerProvider.notifier)
        .addByBarcode(barcode!);

    expect(ok, isTrue, reason: 'предпосылка: строка встала в чек');
    await settleWarning();
    expect(
      expiryWarningStub.asked,
      contains(ucode),
      reason: 'скан обязан спросить про партию — до правки не спрашивал',
    );
    expect(container.read(saleControllerProvider).warning, contains('Молоко'));
  });

  test('годная партия жёлтого не даёт', () async {
    // Управляющая проба: «починка», ставящая предупреждение всегда, прошла
    // бы обе предыдущие.
    expiryWarningStub.asked.clear();
    await addMilkFromSearch();
    await settleWarning();

    expect(container.read(saleControllerProvider).warning, isNull);
    expect(
      expiryWarningStub.asked,
      isNotEmpty,
      reason: 'спросили — и получили «годен», а не промолчали мимо вопроса',
    );
  });

  test('о товаре, не вставшем в чек, не спрашивают', () async {
    // Вопрос уехал **за** команду. Ненайденный штрихкод в чек не ложится, и
    // спрашивать про него не о чем; до правки вопрос шёл параллельно и про
    // отвергнутый товар тоже.
    final notifier = container.read(saleControllerProvider.notifier);
    expiryWarningStub.asked.clear();

    final ok = await notifier.addByBarcode('0000000000000');

    expect(ok, isFalse, reason: 'предпосылка: такого штрихкода в базе нет');
    // Ждём столько же, сколько ждут пробы выше: «не спросили» обязано
    // означать «не спросили», а не «не успели посмотреть».
    await settleWarning();
    expect(expiryWarningStub.asked, isEmpty);
    expect(container.read(saleControllerProvider).warning, isNull);
  });
}
