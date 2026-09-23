/// После продажи остаток в выдаче поиска перечитан — задача 36.
///
/// Остаток написан в каждой строке выдачи поиска экрана продажи
/// (`product_search.dart`, «Остаток: …»). Выдача живёт в `SaleState`, и
/// после проведённой продажи её никто не перечитывал: на кассе шов
/// `sale_side_effects_native.dart` перечитывал экраны каталога и остатков,
/// но не выдачу; в браузере шов был пуст целиком. Кассир, у которого на экране
/// стоял запрос, видел остаток, которого уже нет.
///
/// # Почему обе половины шва импортируются явно
///
/// `sale_side_effects.dart` выбирает половину условным импортом, а пробы идут
/// в Dart VM — то есть **браузерная половина под `flutter test` не
/// исполняется никогда**, и проба через общий файл зеленела бы на нативной.
/// Поэтому каждая половина зовётся по имени.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/product_search_result.dart';
import 'package:telepos/domain/stock/stock_changes.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_side_effects_native.dart'
    as native;
import 'package:telepos/presentation/controllers/sale/sale_side_effects_web.dart'
    as web;

/// Касса, у которой остаток товара меняется между двумя вопросами.
class _StockedCart implements CartService {
  Decimal stock = Decimal.fromInt(10);
  int searches = 0;

  @override
  Future<List<ProductSearchResult>> search(String query) async {
    searches++;
    return [
      ProductSearchResult(
        id: 7,
        name: 'Молоко',
        price: Decimal.fromInt(500),
        stock: stock,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Seam = void Function(Ref ref);

void main() {
  late _StockedCart cart;

  // Вход на экран без кассы пишет предупреждение в общий журнал
  // (`SaleNotifier._resolveTerminalId`); журнал заводит точка входа.
  setUpAll(() => talker = Talker());

  setUp(() {
    cart = _StockedCart();
    GetIt.I.registerSingleton<CartService>(cart);
  });

  tearDown(() => GetIt.I.reset());

  /// Выдача поиска устоялась: дебаунс 300 мс и ответ кассы.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  Future<ProviderContainer> searched(
    _Seam seam,
    List<void Function()> call,
  ) async {
    final after = Provider<void Function()>(
      (ref) =>
          () => seam(ref),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(saleControllerProvider, (_, __) {}, fireImmediately: true);
    call.add(() => container.read(after)());

    await container.read(saleControllerProvider.notifier).search('мол');
    await settle();
    expect(
      container.read(saleControllerProvider).searchResults.single.stock,
      Decimal.fromInt(10),
      reason: 'предпосылка: выдача показала остаток кассы',
    );
    return container;
  }

  for (final (name, seam) in <(String, _Seam)>[
    ('браузерная', web.refreshAfterSaleCompleted),
    ('кассовая', native.refreshAfterSaleCompleted),
  ]) {
    test('$name половина: после продажи остаток в выдаче — новый', () async {
      final call = <void Function()>[];
      final container = await searched(seam, call);

      // Продажа списала единицу на кассе.
      cart.stock = Decimal.fromInt(9);
      call.single();
      await settle();

      expect(
        container.read(saleControllerProvider).searchResults.single.stock,
        Decimal.fromInt(9),
        reason:
            'продажа изменила остаток, а выдача показывала прежний: кассир '
            'видит единицу товара, которой уже нет',
      );
    });
  }

  /// Чужое рабочее место — пункт 12 ревизии 2026-09-19.
  ///
  /// Пробы выше зовут шов сами: они изображают продажу, проведённую
  /// **этим** контейнером. Ровно этот случай и работал раньше. Чего не
  /// было — соседнего рабочего места: его продажа шов не зовёт ничем, и до
  /// этой правки остаток в выдаче оставался прежним навсегда.
  ///
  /// Чего проба НЕ доказывает: что событие доедет по проводу — это
  /// `test/web/wt_stock_changes_test.dart`; здесь подписка подменена.
  group('продажа соседнего рабочего места', () {
    late StreamController<int> fromTill;

    setUp(() {
      fromTill = StreamController<int>.broadcast();
      GetIt.I.registerSingleton<StockChanges>(_FromTill(fromTill.stream));
    });

    tearDown(() => fromTill.close());

    test('остаток в выдаче перечитан без единого вызова шва', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(
        saleControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await container.read(saleControllerProvider.notifier).search('мол');
      await settle();
      expect(
        container.read(saleControllerProvider).searchResults.single.stock,
        Decimal.fromInt(10),
        reason: 'предпосылка: выдача показала остаток кассы',
      );

      // Продажу провёл сосед: касса списала единицу и сказала об этом
      // подпиской. Шов этого контейнера не зовётся ни разу.
      cart.stock = Decimal.fromInt(9);
      fromTill.add(1);
      await settle();

      expect(
        container.read(saleControllerProvider).searchResults.single.stock,
        Decimal.fromInt(9),
        reason:
            'красный до правки: чужая продажа не поднимала счётчик, и '
            'кассир за соседним экраном видел единицу товара, которой '
            'уже нет',
      );
    });
  });

  test('без запроса на экране продажа кассу не спрашивает', () async {
    final after = Provider<void Function()>(
      (ref) =>
          () => web.refreshAfterSaleCompleted(ref),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(saleControllerProvider, (_, __) {}, fireImmediately: true);
    await settle();

    container.read(after)();
    await settle();

    expect(
      cart.searches,
      0,
      reason: 'перечитывать нечего — пустой запрос не вопрос к кассе',
    );
  });
}

/// Подписка «остатки кассы изменились», которой правит проба.
class _FromTill implements StockChanges {
  _FromTill(this._stream);

  final Stream<int> _stream;

  @override
  Stream<int> watch() => _stream;
}
