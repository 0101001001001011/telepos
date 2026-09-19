/// Выдача поиска закрывается вместе с добавлением товара — приёмка
/// 2026-09-17.
///
/// # Что измерено живьём
///
/// Кассир набирает штрихкод в поле поиска и жмёт `Enter` раньше, чем
/// истекут 300 мс задержки `SaleNotifier.search`. Товар встаёт в чек, поле
/// чистится — а через 300 мс выдача **открывается снова**, уже поверх
/// пустого поля, и ловит следующее нажатие. Дважды за приёмку это дало
/// лишнюю позицию в чеке: кассир целился в «ОПЛАТИТЬ», попадал в список.
///
/// # Почему проба на контроллере, а не на виджете
///
/// Дефект — не в разметке: виджет чистит и поле, и состояние (`onSubmitted`,
/// `product_search.dart`), и делает это правильно. Взведённый таймер живёт в
/// контроллере, и увидеть его можно только оттуда. Виджетная проба на ту же
/// беду краснела бы по времени пробы, а не по существу.
///
/// Касса под контроллером — настоящая (`LocalCartService` над базой в
/// памяти, `test_utils.dart`): подделка `CartService.search`, отвечающая
/// мгновенно, гонку таймера с ответом кассы не воспроизводит вовсе.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

import 'test_utils.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = createTestContainer();
  });

  tearDown(() {
    container.dispose();
    tearDownTestDependencies();
  });

  /// Задержка поиска — 300 мс (`SaleNotifier.search`). Ждём заведомо дольше:
  /// проба обязана увидеть **сработавший** таймер, а не разойтись с ним.
  const afterDebounce = Duration(milliseconds: 450);

  test(
    'товар, пробитый штрихкодом, не открывает выдачу поиска задним числом',
    () async {
      final notifier = container.read(saleControllerProvider.notifier);
      await notifier.startNewSale();

      // Ровно то, что делает поле: каждое нажатие — `search`, и последнее
      // взводит таймер. `Enter` приходит раньше, чем тот сработает.
      await notifier.search('4607001234567');
      expect(
        container.read(saleControllerProvider).searchResults,
        isEmpty,
        reason:
            'контрольный случай: до истечения задержки выдачи ещё нет — '
            'именно поэтому `Enter` уходит дорогой штрихкода',
      );

      final added = await notifier.addByBarcode('4607001234567');
      expect(added, isTrue, reason: 'товар с этим штрихкодом есть в базе');

      expect(
        container.read(saleControllerProvider).searchResults,
        isEmpty,
        reason: 'сразу после добавления выдача закрыта — это работало и до '
            'починки',
      );

      await Future<void>.delayed(afterDebounce);

      expect(
        container.read(saleControllerProvider).searchResults,
        isEmpty,
        reason:
            'ОТЛОЖЕННЫЙ ПОИСК ОТКРЫЛ ВЫДАЧУ ПОВЕРХ ПУСТОГО ПОЛЯ. Кассир '
            'пробил товар, список закрылся — и через 300 мс открылся сам, '
            'перехватив следующее нажатие. Снятие таймера — '
            '`SaleNotifier.addByBarcode`.',
      );
      expect(
        container.read(saleControllerProvider).searchQuery,
        isEmpty,
        reason: 'запрос тоже не должен воскреснуть',
      );
    },
  );

  test('товар, добавленный из выдачи, не открывает её задним числом', () async {
    final notifier = container.read(saleControllerProvider.notifier);
    await notifier.startNewSale();

    await notifier.search('Молоко');
    await Future<void>.delayed(afterDebounce);
    final results = container.read(saleControllerProvider).searchResults;
    expect(
      results,
      isNotEmpty,
      reason: 'контрольный случай: касса действительно нашла товар по имени',
    );

    // Кассир набирает следующий запрос и, не дождавшись выдачи, тычет в
    // строку старой — плитка быстрых товаров и виртуальная клавиатура
    // приходят сюда же, мимо поля.
    await notifier.search('Хлеб');
    await notifier.addProduct(results.first);

    await Future<void>.delayed(afterDebounce);

    expect(
      container.read(saleControllerProvider).searchResults,
      isEmpty,
      reason:
          'ОТЛОЖЕННЫЙ ПОИСК ОТКРЫЛ ВЫДАЧУ ПОСЛЕ ДОБАВЛЕНИЯ ТОВАРА. Снятие '
          'таймера — `SaleNotifier.addProduct`.',
    );
  });

  test('опоздавший ответ кассы на прежний запрос выдачу не открывает', () async {
    final notifier = container.read(saleControllerProvider.notifier);
    await notifier.startNewSale();

    // Вторая половина той же беды, со стороны кассы: таймер сработал, касса
    // ищет, а кассир тем временем очистил поле. Ответ на прежний запрос
    // обязан быть выброшен — иначе выдача откроется поверх пустого поля
    // ровно тем же способом, только медленнее. Снятие таймера от этого не
    // спасает: он уже сработал.
    //
    // Касса подменяется **после** начала чека и только на поиске: база в
    // памяти отвечает за единицы миллисекунд, и без задержки окна, в
    // котором ответ опаздывает, попросту нет — проба зеленела бы на любом
    // коде (случай «у замера тоже бывает зелёный цвет»).
    final real = GetIt.I<CartService>();
    GetIt.I.unregister<CartService>();
    GetIt.I.registerSingleton<CartService>(_SlowSearchCart(real));

    await notifier.search('Молоко');
    // 300 мс задержки + часть ответа кассы: таймер сработал, ответ ещё в
    // полёте.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await notifier.search('');

    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(
      container.read(saleControllerProvider).searchResults,
      isEmpty,
      reason:
          'ОТВЕТ КАССЫ НА ОТМЕНЁННЫЙ ЗАПРОС ОТКРЫЛ ВЫДАЧУ поверх пустого '
          'поля. Сторож запроса — `SaleNotifier.search`, тот же, что у '
          '`_refreshSearch`.',
    );
  });
}

/// Касса, которая ищет медленно. Всё остальное этой пробе не нужно и
/// бросает: подменённая касса, у которой молча работает **всё**, скрыла бы
/// от пробы собственную ошибку подмены.
class _SlowSearchCart implements CartService {
  _SlowSearchCart(this._inner);

  final CartService _inner;

  @override
  Future<List<ProductSearchResult>> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _inner.search(query);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'этой пробе нужен только поиск, а позвали ${invocation.memberName}',
  );
}
