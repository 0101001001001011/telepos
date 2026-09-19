/// Касса после продажи перечитывает соседние экраны — задача 13.
///
/// # Зачем эта проба существует
///
/// До неё `sale_side_effects.dart` не упоминался **ни одним** тестом дерева,
/// и ни один тест не наблюдал перечитывания четырёх контроллеров после
/// завершения продажи. Значит опустошённая нативная половина шва — или
/// условный экспорт, перевёрнутый на браузерную, — оставляли бы кассу без
/// обновления смены, истории, каталога и остатков **при целиком зелёном
/// наборе**. Кассир продал последнюю пачку и видит её в остатках, пока не
/// переоткроет экран.
///
/// Докстринг самого шва отвергает подмену провайдера словами «забытая
/// подмена молча выключала бы обновление». Условный импорт убирает
/// забывчивость, но **не убирает молчание** — молчание убирает эта проба.
///
/// # Почему подменяются реализации, а не сами провайдеры
///
/// Наблюдаются **настоящие** `shiftControllerProvider`,
/// `historyControllerProvider`, `catalogControllerProvider`,
/// `stockRegistryControllerProvider` — те самые объекты, которые называет
/// нативная половина шва. Опечатка в цели («перечитали не тот») здесь
/// краснеет, потому что цель — не имя в списке, а сам провайдер.
///
/// Подменена только их **начинка**: настоящие `build()` читают
/// `AppDatabase` из `GetIt`, то есть поднимают drift, DAO и половину DI ради
/// вопроса «перечиталось ли». Счётчик сборок отвечает на него без этого.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/presentation/controllers/app/stock_revision.dart';

import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_side_effects.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/stock_registry/stock_registry_controller.dart';

/// Сколько раз каждый из четырёх собрался.
final builds = <String, int>{};

void _counted(String name) =>
    builds[name] = (builds[name] ?? 0) + 1;

class _SpyShift extends ShiftNotifier {
  @override
  ShiftState build() {
    _counted('shift');
    return ShiftState();
  }
}

class _SpyHistory extends HistoryNotifier {
  @override
  HistoryState build() {
    _counted('history');
    return HistoryState();
  }
}

class _SpyCatalog extends CatalogNotifier {
  @override
  CatalogState build() {
    // Подписка та же, что у настоящего `build` (задача 36) — её наличие там
    // держит сторож ниже, а не этот шпион.
    ref.watch(stockRevisionProvider);
    _counted('catalog');
    return const CatalogState();
  }
}

class _SpyStock extends StockRegistryNotifier {
  @override
  StockRegistryState build() {
    ref.watch(stockRevisionProvider);
    _counted('stock');
    return StockRegistryState();
  }
}

/// Откуда взять `Ref`: обе функции шва принимают его доводом, а рождается он
/// только внутри провайдера. Целями остаются настоящие четыре — этот нужен
/// лишь как держатель `Ref`, и ничего не наблюдает сам.
final _afterSale = Provider<void Function()>(
  (ref) => () => refreshAfterSaleCompleted(ref),
);

final _afterStart = Provider<void Function()>(
  (ref) => () => refreshShiftAfterSaleStart(ref),
);

ProviderContainer _container() => ProviderContainer(
  overrides: [
    shiftControllerProvider.overrideWith(_SpyShift.new),
    historyControllerProvider.overrideWith(_SpyHistory.new),
    catalogControllerProvider.overrideWith(_SpyCatalog.new),
    stockRegistryControllerProvider.overrideWith(_SpyStock.new),
  ],
);

/// Собирает все четыре и слушает их: провайдер, которого никто не слушает,
/// после `invalidate` не пересобирается вовсе — и проба зеленела бы на
/// пустом месте.
void _listenAll(ProviderContainer container) {
  for (final provider in [
    shiftControllerProvider,
    historyControllerProvider,
    catalogControllerProvider,
    stockRegistryControllerProvider,
  ]) {
    container.listen(provider, (_, __) {}, fireImmediately: true);
  }
}

void main() {
  setUp(builds.clear);

  test('завершённая продажа перечитывает все четыре соседних экрана', () {
    final container = _container();
    addTearDown(container.dispose);
    _listenAll(container);

    expect(
      builds,
      {'shift': 1, 'history': 1, 'catalog': 1, 'stock': 1},
      reason: 'предпосылка: все четыре собрались по одному разу',
    );

    container.read(_afterSale)();
    // `invalidate` откладывает пересборку до конца микрозадачи; слушатели
    // разбудят её сами, но не раньше.
    container.read(shiftControllerProvider);
    container.read(historyControllerProvider);
    container.read(catalogControllerProvider);
    container.read(stockRegistryControllerProvider);

    expect(
      builds,
      {'shift': 2, 'history': 2, 'catalog': 2, 'stock': 2},
      reason:
          'после завершения продажи меняется правда всех четырёх: смены '
          '(деньги в кассе), истории (новый чек), каталога и остатков '
          '(списанный товар). Не перечитанный остаток — это последняя пачка, '
          'которую кассир уже продал, а экран ещё показывает.',
    );
  });

  test('настоящие каталог и остатки подписаны на «остатки изменились»', () {
    // Шпионы выше подписываются сами, и без этого сторожа проба шва
    // зеленела бы при `build`, забывшем подписку, — каталог перестал бы
    // перечитываться после продажи при зелёном наборе (задача 36).
    for (final path in [
      'lib/presentation/controllers/catalog/catalog_controller.dart',
      'lib/presentation/controllers/stock_registry/stock_registry_controller.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final build = RegExp(
        r'State build\(\) \{[^}]*ref\.watch\(stockRevisionProvider\);',
      );
      expect(build.hasMatch(source), isTrue, reason: path);
    }
  });

  test('начало чека перечитывает смену, и только её', () {
    final container = _container();
    addTearDown(container.dispose);
    _listenAll(container);

    container.read(_afterStart)();
    container.read(shiftControllerProvider);
    container.read(historyControllerProvider);
    container.read(catalogControllerProvider);
    container.read(stockRegistryControllerProvider);

    expect(
      builds,
      {'shift': 2, 'history': 1, 'catalog': 1, 'stock': 1},
      reason:
          'начало чека могло открыть смену — и не могло изменить ни истории, '
          'ни каталога, ни остатков. Лишнее перечитывание здесь не '
          'безобидно: каталог и остатки ходят в базу.',
    );
  });
}
